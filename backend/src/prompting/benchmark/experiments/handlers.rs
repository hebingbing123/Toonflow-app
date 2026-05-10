//! 实验运行与变体快照 HTTP 处理器。

use axum::{
    extract::{Path, Query, State},
    http::{HeaderMap, StatusCode},
    response::{IntoResponse, Response},
    Json,
};
use serde::{Deserialize, Serialize};
use serde_json::json;
use uuid::Uuid;

use crate::publish::ab_testing::{
    aggregate_comparisons, compare_variants, fetch_quality_metrics, fetch_token_metrics,
    ABTestConfig, ABTestResult, ABVariant,
};
use crate::{auth::require_user_uuid, error::ApiError, state::AppState};

use super::{
    cost_optimization::{
        calculate_full_replay_cost, calculate_stage_scope_savings, calculate_tier_savings,
        estimate_artifact_reuse_savings, SampleTier, Stage, TokenSavingsEstimate,
    },
    types::{
        CreateExperimentBody, ExperimentDetail, ExperimentRun, ExperimentVariant,
        ListExperimentsQuery,
    },
    validation::{validate_experiment_dependencies, validate_sample_tier, validate_stage_scope},
};

#[derive(Debug, Clone, Deserialize, Serialize, utoipa::ToSchema)]
#[serde(rename_all = "camelCase")]
pub struct ABCompareCaseBody {
    pub test_case_id: String,
    pub baseline_job_id: Uuid,
    pub optimized_job_id: Uuid,
}

#[derive(Debug, Clone, Deserialize, Serialize, utoipa::ToSchema)]
#[serde(rename_all = "camelCase")]
pub struct ABCompareRequestBody {
    pub cases: Vec<ABCompareCaseBody>,
    #[serde(default)]
    pub config: Option<ABCompareConfigBody>,
    #[serde(default)]
    pub persist: Option<bool>,
    #[serde(default)]
    pub name: Option<String>,
}

#[derive(Debug, Clone, Deserialize, Serialize, utoipa::ToSchema)]
#[serde(rename_all = "camelCase")]
pub struct ABCompareConfigBody {
    pub min_token_reduction_pct: f64,
    pub max_quality_drop: f64,
    pub min_quality_score: f64,
    pub significance_threshold: f64,
}

#[derive(Debug, Clone, Serialize, utoipa::ToSchema)]
#[serde(rename_all = "camelCase")]
pub struct ABComparisonLite {
    pub test_case_id: String,
    pub quality_regression: bool,
    pub token_reduction_pct: f64,
    pub quality_score_diff: Option<f64>,
    pub p_value: Option<f64>,
    pub passed: bool,
    pub failure_reasons: Vec<String>,
}

#[derive(Debug, Clone, Serialize, utoipa::ToSchema)]
#[serde(rename_all = "camelCase")]
pub struct ABCompareResponseBody {
    #[serde(skip_serializing_if = "Option::is_none")]
    pub run_id: Option<Uuid>,
    pub total_cases: usize,
    pub passed_cases: usize,
    pub failed_cases: usize,
    pub avg_token_reduction_pct: f64,
    pub avg_quality_diff: f64,
    pub quality_regressions: usize,
    pub passed: bool,
    pub comparisons: Vec<ABComparisonLite>,
}

#[derive(Debug, Clone, Serialize, sqlx::FromRow, utoipa::ToSchema)]
#[serde(rename_all = "camelCase")]
pub struct ABCompareRunRow {
    pub id: Uuid,
    pub name: Option<String>,
    pub created_at: chrono::DateTime<chrono::Utc>,
    pub config: serde_json::Value,
    pub summary: serde_json::Value,
}

#[derive(Debug, Clone, Serialize, utoipa::ToSchema)]
#[serde(rename_all = "camelCase")]
pub struct ABCompareRunDetail {
    pub run: ABCompareRunRow,
    pub cases: Vec<ABCompareCasePersisted>,
}

#[derive(Debug, Clone, Serialize, sqlx::FromRow, utoipa::ToSchema)]
#[serde(rename_all = "camelCase")]
pub struct ABCompareCasePersisted {
    pub id: Uuid,
    pub test_case_id: String,
    pub baseline_job_id: Uuid,
    pub optimized_job_id: Uuid,
    pub comparison: serde_json::Value,
    pub created_at: chrono::DateTime<chrono::Utc>,
}

/// 创建实验运行
#[utoipa::path(
    post,
    path = "/api/v1/benchmark/experiments",
    request_body = CreateExperimentBody,
    responses(
        (status = 201, description = "Experiment created", body = ExperimentDetail),
        (status = 400, description = "Invalid request"),
        (status = 401, description = "Unauthorized"),
    ),
    tag = "benchmark",
    security(("bearerAuth" = []))
)]
pub async fn create_experiment(
    State(state): State<AppState>,
    headers: HeaderMap,
    Json(body): Json<CreateExperimentBody>,
) -> Result<Response, ApiError> {
    let user_id = require_user_uuid(&state, &headers)?;
    let pool = state.require_pool()?;

    // 校验样本层级
    validate_sample_tier(&body.sample_tier).map_err(|e| ApiError::BadRequest(e.to_string()))?;

    // 校验阶段范围
    validate_stage_scope(&body.stage_scope).map_err(|e| ApiError::BadRequest(e.to_string()))?;

    // 校验至少有一个变体
    if body.variants.is_empty() {
        return Err(ApiError::BadRequest(
            "At least one variant is required".into(),
        ));
    }

    // 校验每个变体的快照完整性
    for variant in &body.variants {
        super::validation::validate_variant_snapshot(variant)
            .map_err(|e| ApiError::BadRequest(e.to_string()))?;
    }

    // 开启事务
    let mut tx = pool
        .begin()
        .await
        .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    // 创建实验运行
    let experiment = sqlx::query_as::<_, ExperimentRun>(
        r#"
        INSERT INTO app_experiment_run (owner_user_id, name, status, sample_tier, stage_scope)
        VALUES ($1, $2, 'draft', $3, $4)
        RETURNING id, owner_user_id, name, status, sample_tier, stage_scope,
                  baseline_variant_id, created_at, started_at, completed_at
        "#,
    )
    .bind(user_id)
    .bind(&body.name)
    .bind(&body.sample_tier)
    .bind(json!(body.stage_scope))
    .fetch_one(&mut *tx)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    // 创建变体
    let mut variants = Vec::new();
    let mut baseline_variant_id: Option<Uuid> = None;

    for variant_body in &body.variants {
        let is_baseline = body
            .baseline_variant_label
            .as_ref()
            .map(|label| label == &variant_body.label)
            .unwrap_or(false);

        let variant = sqlx::query_as::<_, ExperimentVariant>(
            r#"
            INSERT INTO app_experiment_variant
                (experiment_run_id, label, is_baseline, skill_snapshot, prompt_snapshot,
                 memory_budget_snapshot, observation_policy_snapshot, model_route_snapshot, notes)
            VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9)
            RETURNING id, experiment_run_id, label, is_baseline,
                      skill_snapshot, prompt_snapshot, memory_budget_snapshot,
                      observation_policy_snapshot, model_route_snapshot, notes
            "#,
        )
        .bind(experiment.id)
        .bind(&variant_body.label)
        .bind(is_baseline)
        .bind(json!(&variant_body.skill_snapshot))
        .bind(json!(&variant_body.prompt_snapshot))
        .bind(json!(&variant_body.memory_budget_snapshot))
        .bind(json!(&variant_body.observation_policy_snapshot))
        .bind(json!(&variant_body.model_route_snapshot))
        .bind(&variant_body.notes)
        .fetch_one(&mut *tx)
        .await
        .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

        if is_baseline {
            baseline_variant_id = Some(variant.id);
        }

        variants.push(variant);
    }

    // 更新基线变体 ID
    if let Some(baseline_id) = baseline_variant_id {
        sqlx::query(
            r#"
            UPDATE app_experiment_run
            SET baseline_variant_id = $1
            WHERE id = $2
            "#,
        )
        .bind(baseline_id)
        .bind(experiment.id)
        .execute(&mut *tx)
        .await
        .map_err(|e| ApiError::DatabaseError(e.to_string()))?;
    }

    tx.commit()
        .await
        .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    // 重新查询完整实验信息
    let experiment = sqlx::query_as::<_, ExperimentRun>(
        r#"
        SELECT id, owner_user_id, name, status, sample_tier, stage_scope,
               baseline_variant_id, created_at, started_at, completed_at
        FROM app_experiment_run
        WHERE id = $1
        "#,
    )
    .bind(experiment.id)
    .fetch_one(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    Ok((
        StatusCode::CREATED,
        Json(ExperimentDetail {
            experiment,
            variants,
        }),
    )
        .into_response())
}

/// 列出实验运行
#[utoipa::path(
    get,
    path = "/api/v1/benchmark/experiments",
    params(ListExperimentsQuery),
    responses(
        (status = 200, description = "List of experiments", body = Vec<ExperimentRun>),
        (status = 401, description = "Unauthorized"),
    ),
    tag = "benchmark",
    security(("bearerAuth" = []))
)]
pub async fn list_experiments(
    State(state): State<AppState>,
    headers: HeaderMap,
    Query(query): Query<ListExperimentsQuery>,
) -> Result<Json<Vec<ExperimentRun>>, ApiError> {
    let user_id = require_user_uuid(&state, &headers)?;
    let pool = state.require_pool()?;

    let limit = query.limit.unwrap_or(50).min(100);
    let offset = query.offset.unwrap_or(0);

    let mut sql = String::from(
        r#"
        SELECT id, owner_user_id, name, status, sample_tier, stage_scope,
               baseline_variant_id, created_at, started_at, completed_at
        FROM app_experiment_run
        WHERE owner_user_id = $1
        "#,
    );

    let mut bind_count = 1;

    if query.status.is_some() {
        bind_count += 1;
        sql.push_str(&format!(" AND status = ${}", bind_count));
    }

    if query.sample_tier.is_some() {
        bind_count += 1;
        sql.push_str(&format!(" AND sample_tier = ${}", bind_count));
    }

    sql.push_str(" ORDER BY created_at DESC");
    bind_count += 1;
    sql.push_str(&format!(" LIMIT ${}", bind_count));
    bind_count += 1;
    sql.push_str(&format!(" OFFSET ${}", bind_count));

    let mut query_builder = sqlx::query_as::<_, ExperimentRun>(&sql).bind(user_id);

    if let Some(status) = query.status {
        query_builder = query_builder.bind(status);
    }

    if let Some(sample_tier) = query.sample_tier {
        query_builder = query_builder.bind(sample_tier);
    }

    let experiments = query_builder
        .bind(limit)
        .bind(offset)
        .fetch_all(pool)
        .await
        .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    Ok(Json(experiments))
}

/// 获取实验运行详情
#[utoipa::path(
    get,
    path = "/api/v1/benchmark/experiments/{id}",
    params(
        ("id" = Uuid, Path, description = "Experiment ID")
    ),
    responses(
        (status = 200, description = "Experiment detail", body = ExperimentDetail),
        (status = 401, description = "Unauthorized"),
        (status = 404, description = "Experiment not found"),
    ),
    tag = "benchmark",
    security(("bearerAuth" = []))
)]
pub async fn get_experiment(
    State(state): State<AppState>,
    headers: HeaderMap,
    Path(id): Path<Uuid>,
) -> Result<Json<ExperimentDetail>, ApiError> {
    let user_id = require_user_uuid(&state, &headers)?;
    let pool = state.require_pool()?;

    let experiment = sqlx::query_as::<_, ExperimentRun>(
        r#"
        SELECT id, owner_user_id, name, status, sample_tier, stage_scope,
               baseline_variant_id, created_at, started_at, completed_at
        FROM app_experiment_run
        WHERE id = $1 AND owner_user_id = $2
        "#,
    )
    .bind(id)
    .bind(user_id)
    .fetch_optional(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?
    .ok_or(ApiError::NotFound)?;

    let variants = sqlx::query_as::<_, ExperimentVariant>(
        r#"
        SELECT id, experiment_run_id, label, is_baseline,
               skill_snapshot, prompt_snapshot, memory_budget_snapshot,
               observation_policy_snapshot, model_route_snapshot, notes
        FROM app_experiment_variant
        WHERE experiment_run_id = $1
        ORDER BY is_baseline DESC, label ASC
        "#,
    )
    .bind(id)
    .fetch_all(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    Ok(Json(ExperimentDetail {
        experiment,
        variants,
    }))
}

/// 启动实验运行
#[utoipa::path(
    post,
    path = "/api/v1/benchmark/experiments/{id}/start",
    params(
        ("id" = Uuid, Path, description = "Experiment ID")
    ),
    responses(
        (status = 200, description = "Experiment started", body = ExperimentRun),
        (status = 400, description = "Invalid state or missing dependencies"),
        (status = 401, description = "Unauthorized"),
        (status = 404, description = "Experiment not found"),
    ),
    tag = "benchmark",
    security(("bearerAuth" = []))
)]
pub async fn start_experiment(
    State(state): State<AppState>,
    headers: HeaderMap,
    Path(id): Path<Uuid>,
) -> Result<Json<ExperimentRun>, ApiError> {
    let user_id = require_user_uuid(&state, &headers)?;
    let pool = state.require_pool()?;

    // 检查实验状态
    let experiment = sqlx::query_as::<_, ExperimentRun>(
        r#"
        SELECT id, owner_user_id, name, status, sample_tier, stage_scope,
               baseline_variant_id, created_at, started_at, completed_at
        FROM app_experiment_run
        WHERE id = $1 AND owner_user_id = $2
        "#,
    )
    .bind(id)
    .bind(user_id)
    .fetch_optional(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?
    .ok_or(ApiError::NotFound)?;

    if experiment.status != "draft" {
        return Err(ApiError::BadRequest(format!(
            "Experiment must be in 'draft' status to start, current status: {}",
            experiment.status
        )));
    }

    // 校验依赖
    let validation_errors = validate_experiment_dependencies(pool, id)
        .await
        .map_err(|e| ApiError::BadRequest(e.to_string()))?;

    if !validation_errors.is_empty() {
        let error_messages: Vec<String> = validation_errors
            .iter()
            .map(|e| format!("{}: {}", e.variant_label, e.missing_dependencies.join(", ")))
            .collect();

        return Err(ApiError::BadRequest(format!(
            "Dependency validation failed: {}",
            error_messages.join("; ")
        )));
    }

    // 更新状态为 queued
    let experiment = sqlx::query_as::<_, ExperimentRun>(
        r#"
        UPDATE app_experiment_run
        SET status = 'queued', started_at = now()
        WHERE id = $1
        RETURNING id, owner_user_id, name, status, sample_tier, stage_scope,
                  baseline_variant_id, created_at, started_at, completed_at
        "#,
    )
    .bind(id)
    .fetch_one(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    Ok(Json(experiment))
}

/// 取消实验运行
#[utoipa::path(
    post,
    path = "/api/v1/benchmark/experiments/{id}/cancel",
    params(
        ("id" = Uuid, Path, description = "Experiment ID")
    ),
    responses(
        (status = 200, description = "Experiment cancelled", body = ExperimentRun),
        (status = 400, description = "Invalid state"),
        (status = 401, description = "Unauthorized"),
        (status = 404, description = "Experiment not found"),
    ),
    tag = "benchmark",
    security(("bearerAuth" = []))
)]
pub async fn cancel_experiment(
    State(state): State<AppState>,
    headers: HeaderMap,
    Path(id): Path<Uuid>,
) -> Result<Json<ExperimentRun>, ApiError> {
    let user_id = require_user_uuid(&state, &headers)?;
    let pool = state.require_pool()?;

    // 检查实验状态
    let experiment = sqlx::query_as::<_, ExperimentRun>(
        r#"
        SELECT id, owner_user_id, name, status, sample_tier, stage_scope,
               baseline_variant_id, created_at, started_at, completed_at
        FROM app_experiment_run
        WHERE id = $1 AND owner_user_id = $2
        "#,
    )
    .bind(id)
    .bind(user_id)
    .fetch_optional(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?
    .ok_or(ApiError::NotFound)?;

    if !["draft", "queued", "running"].contains(&experiment.status.as_str()) {
        return Err(ApiError::BadRequest(format!(
            "Cannot cancel experiment in '{}' status",
            experiment.status
        )));
    }

    // 更新状态为 cancelled
    let experiment = sqlx::query_as::<_, ExperimentRun>(
        r#"
        UPDATE app_experiment_run
        SET status = 'cancelled'
        WHERE id = $1
        RETURNING id, owner_user_id, name, status, sample_tier, stage_scope,
                  baseline_variant_id, created_at, started_at, completed_at
        "#,
    )
    .bind(id)
    .fetch_one(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    Ok(Json(experiment))
}

/// 估算实验成本与节省
#[utoipa::path(
    get,
    path = "/api/v1/benchmark/experiments/{id}/cost-estimate",
    params(
        ("id" = Uuid, Path, description = "Experiment ID")
    ),
    responses(
        (status = 200, description = "Cost estimate", body = TokenSavingsEstimate),
        (status = 401, description = "Unauthorized"),
        (status = 404, description = "Experiment not found"),
    ),
    tag = "benchmark",
    security(("bearerAuth" = []))
)]
pub async fn estimate_cost(
    State(state): State<AppState>,
    headers: HeaderMap,
    Path(id): Path<Uuid>,
) -> Result<Json<TokenSavingsEstimate>, ApiError> {
    let user_id = require_user_uuid(&state, &headers)?;
    let pool = state.require_pool()?;

    // 获取实验信息
    let experiment = sqlx::query_as::<_, ExperimentRun>(
        r#"
        SELECT id, owner_user_id, name, status, sample_tier, stage_scope,
               baseline_variant_id, created_at, started_at, completed_at
        FROM app_experiment_run
        WHERE id = $1 AND owner_user_id = $2
        "#,
    )
    .bind(id)
    .bind(user_id)
    .fetch_optional(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?
    .ok_or(ApiError::NotFound)?;

    // 解析样本分层
    let sample_tier: SampleTier = experiment
        .sample_tier
        .parse()
        .map_err(|e: String| ApiError::BadRequest(e))?;

    // 解析阶段范围
    let stage_scope: Vec<String> = serde_json::from_value(experiment.stage_scope.clone())
        .map_err(|e| ApiError::BadRequest(format!("Invalid stage_scope: {}", e)))?;

    let stages: Result<Vec<Stage>, _> = stage_scope.iter().map(|s| s.parse::<Stage>()).collect();

    let stages = stages.map_err(|e: String| ApiError::BadRequest(e))?;

    // 获取样本总数（假设从 benchmark_case 表查询）
    let total_samples: i64 = sqlx::query_scalar(
        r#"
        SELECT COUNT(*)
        FROM app_benchmark_case
        WHERE owner_user_id = $1
        "#,
    )
    .bind(user_id)
    .fetch_one(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    let total_samples = total_samples as usize;

    // 计算全量重跑成本
    let full_replay_tokens = calculate_full_replay_cost(total_samples, &stages);

    // 计算样本分层节省
    let tier_savings = calculate_tier_savings(&sample_tier, total_samples, &stages);

    // 计算阶段范围节省
    let suggested_sample_count = (total_samples as f64 * sample_tier.sample_ratio()) as usize;
    let stage_scope_savings = calculate_stage_scope_savings(&stages, suggested_sample_count);

    // 估算中间产物复用节省（假设 30% 复用率）
    let artifact_reuse_savings =
        estimate_artifact_reuse_savings(suggested_sample_count, &stages, 0.3);

    // 获取变体（用于生成每个变体的估算）
    let variants = sqlx::query_as::<_, ExperimentVariant>(
        r#"
        SELECT id, experiment_run_id, label, is_baseline,
               skill_snapshot, prompt_snapshot, memory_budget_snapshot,
               observation_policy_snapshot, model_route_snapshot, notes
        FROM app_experiment_variant
        WHERE experiment_run_id = $1
        ORDER BY is_baseline DESC, label ASC
        LIMIT 1
        "#,
    )
    .bind(id)
    .fetch_optional(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    let variant_id = variants.map(|v| v.id).unwrap_or_else(Uuid::new_v4);

    // 构建估算结果
    let mut estimate = TokenSavingsEstimate::new(id, variant_id);
    estimate.full_replay_tokens = full_replay_tokens;
    estimate.tier_savings = tier_savings;
    estimate.stage_scope_savings = stage_scope_savings;
    estimate.artifact_reuse_savings = artifact_reuse_savings;

    // 计算实际 token 消耗（全量 - 所有节省）
    estimate.actual_tokens = full_replay_tokens
        .saturating_sub(tier_savings)
        .saturating_sub(stage_scope_savings)
        .saturating_sub(artifact_reuse_savings);

    estimate.update_total_savings();

    Ok(Json(estimate))
}

#[utoipa::path(
    post,
    path = "/api/v1/benchmark/ab/compare",
    request_body = ABCompareRequestBody,
    responses(
        (status = 200, description = "A/B 对比结果", body = ABCompareResponseBody),
        (status = 400, description = "Invalid request"),
        (status = 401, description = "Unauthorized"),
        (status = 500, description = "Server error"),
    ),
    tag = "benchmark",
    security(("bearerAuth" = []))
)]
pub async fn compare_ab_jobs(
    State(state): State<AppState>,
    headers: HeaderMap,
    Json(body): Json<ABCompareRequestBody>,
) -> Result<Json<ABCompareResponseBody>, ApiError> {
    let user_id = require_user_uuid(&state, &headers)?;
    let pool = state.require_pool()?;

    if body.cases.is_empty() {
        return Err(ApiError::BadRequest("cases cannot be empty".into()));
    }
    let cases = body.cases.clone();

    let config = body
        .config
        .map_or_else(ABTestConfig::default, |c| ABTestConfig {
            min_token_reduction_pct: c.min_token_reduction_pct,
            max_quality_drop: c.max_quality_drop,
            min_quality_score: c.min_quality_score,
            significance_threshold: c.significance_threshold,
        });

    let mut comparisons = Vec::with_capacity(cases.len());
    for case in &cases {
        let baseline_quality = fetch_quality_metrics(pool, case.baseline_job_id).await?;
        let baseline_tokens = fetch_token_metrics(pool, case.baseline_job_id).await?;
        let optimized_quality = fetch_quality_metrics(pool, case.optimized_job_id).await?;
        let optimized_tokens = fetch_token_metrics(pool, case.optimized_job_id).await?;

        let baseline = ABTestResult {
            test_case_id: case.test_case_id.clone(),
            variant: ABVariant::Baseline,
            quality: baseline_quality,
            tokens: baseline_tokens,
            timestamp: chrono::Utc::now(),
            metadata: json!({
                "jobId": case.baseline_job_id,
            }),
        };
        let optimized = ABTestResult {
            test_case_id: case.test_case_id.clone(),
            variant: ABVariant::Optimized,
            quality: optimized_quality,
            tokens: optimized_tokens,
            timestamp: chrono::Utc::now(),
            metadata: json!({
                "jobId": case.optimized_job_id,
            }),
        };
        comparisons.push(compare_variants(&baseline, &optimized, &config));
    }

    let summary = aggregate_comparisons(comparisons);
    let persist = body.persist.unwrap_or(false);
    let run_id = if persist {
        let run_id: Uuid = sqlx::query_scalar(
            r#"
            INSERT INTO app_benchmark_ab_compare_run (id, owner_user_id, name, config, summary)
            VALUES ($1, $2, $3, $4::jsonb, $5::jsonb)
            RETURNING id
            "#,
        )
        .bind(Uuid::new_v4())
        .bind(user_id)
        .bind(
            body.name
                .as_ref()
                .map(|s| s.trim())
                .filter(|s| !s.is_empty()),
        )
        .bind(json!(&config))
        .bind(json!({
            "totalCases": summary.total_cases,
            "passedCases": summary.passed_cases,
            "failedCases": summary.failed_cases,
            "avgTokenReductionPct": summary.avg_token_reduction_pct,
            "avgQualityDiff": summary.avg_quality_diff,
            "qualityRegressions": summary.quality_regressions,
            "passed": summary.passed,
        }))
        .fetch_one(pool)
        .await
        .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

        for c in &summary.comparisons {
            let comparison_json = json!({
                "testCaseId": c.test_case_id,
                "qualityRegression": c.quality_regression,
                "tokenReductionPct": c.token_reduction_pct,
                "qualityScoreDiff": c.quality_score_diff,
                "pValue": c.p_value,
                "passed": c.passed,
                "failureReasons": c.failure_reasons,
            });
            let baseline_job_id = c
                .baseline
                .metadata
                .get("jobId")
                .and_then(|v| v.as_str())
                .and_then(|s| Uuid::parse_str(s).ok())
                .unwrap_or(Uuid::nil());
            let optimized_job_id = c
                .optimized
                .metadata
                .get("jobId")
                .and_then(|v| v.as_str())
                .and_then(|s| Uuid::parse_str(s).ok())
                .unwrap_or(Uuid::nil());
            let _case_id: Uuid = sqlx::query_scalar(
                r#"
                INSERT INTO app_benchmark_ab_compare_case
                    (id, run_id, test_case_id, baseline_job_id, optimized_job_id, comparison)
                VALUES ($1, $2, $3, $4, $5, $6::jsonb)
                RETURNING id
                "#,
            )
            .bind(Uuid::new_v4())
            .bind(run_id)
            .bind(&c.test_case_id)
            .bind(baseline_job_id)
            .bind(optimized_job_id)
            .bind(comparison_json)
            .fetch_one(pool)
            .await
            .map_err(|e| ApiError::DatabaseError(e.to_string()))?;
        }

        // Also store per-variant A/B results for audit trail (L.3 table)
        for idx in 0..cases.len() {
            if let Some(comp) = summary.comparisons.get(idx) {
                let _ =
                    crate::publish::ab_testing::store_ab_test_result(pool, &comp.baseline).await;
                let _ =
                    crate::publish::ab_testing::store_ab_test_result(pool, &comp.optimized).await;
            }
        }

        Some(run_id)
    } else {
        None
    };

    Ok(Json(ABCompareResponseBody {
        run_id,
        total_cases: summary.total_cases,
        passed_cases: summary.passed_cases,
        failed_cases: summary.failed_cases,
        avg_token_reduction_pct: summary.avg_token_reduction_pct,
        avg_quality_diff: summary.avg_quality_diff,
        quality_regressions: summary.quality_regressions,
        passed: summary.passed,
        comparisons: summary
            .comparisons
            .into_iter()
            .map(|c| ABComparisonLite {
                test_case_id: c.test_case_id,
                quality_regression: c.quality_regression,
                token_reduction_pct: c.token_reduction_pct,
                quality_score_diff: c.quality_score_diff,
                p_value: c.p_value,
                passed: c.passed,
                failure_reasons: c.failure_reasons,
            })
            .collect(),
    }))
}

#[utoipa::path(
    get,
    path = "/api/v1/benchmark/ab/runs",
    responses(
        (status = 200, description = "A/B 对比运行列表", body = Vec<ABCompareRunRow>),
        (status = 401, description = "Unauthorized"),
    ),
    tag = "benchmark",
    security(("bearerAuth" = []))
)]
pub async fn list_ab_compare_runs(
    State(state): State<AppState>,
    headers: HeaderMap,
) -> Result<Json<Vec<ABCompareRunRow>>, ApiError> {
    let user_id = require_user_uuid(&state, &headers)?;
    let pool = state.require_pool()?;
    let rows: Vec<ABCompareRunRow> = sqlx::query_as(
        r#"
        SELECT id, name, created_at, config, summary
        FROM app_benchmark_ab_compare_run
        WHERE owner_user_id = $1
        ORDER BY created_at DESC
        LIMIT 50
        "#,
    )
    .bind(user_id)
    .fetch_all(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;
    Ok(Json(rows))
}

#[utoipa::path(
    get,
    path = "/api/v1/benchmark/ab/runs/{id}",
    params(("id" = Uuid, Path, description = "A/B compare run id")),
    responses(
        (status = 200, description = "A/B 对比运行详情", body = ABCompareRunDetail),
        (status = 401, description = "Unauthorized"),
        (status = 404, description = "Not found"),
    ),
    tag = "benchmark",
    security(("bearerAuth" = []))
)]
pub async fn get_ab_compare_run(
    State(state): State<AppState>,
    headers: HeaderMap,
    Path(id): Path<Uuid>,
) -> Result<Json<ABCompareRunDetail>, ApiError> {
    let user_id = require_user_uuid(&state, &headers)?;
    let pool = state.require_pool()?;
    let run: Option<ABCompareRunRow> = sqlx::query_as(
        r#"
        SELECT id, name, created_at, config, summary
        FROM app_benchmark_ab_compare_run
        WHERE id = $1 AND owner_user_id = $2
        "#,
    )
    .bind(id)
    .bind(user_id)
    .fetch_optional(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;
    let run = run.ok_or(ApiError::NotFound)?;
    let cases: Vec<ABCompareCasePersisted> = sqlx::query_as(
        r#"
        SELECT id, test_case_id, baseline_job_id, optimized_job_id, comparison, created_at
        FROM app_benchmark_ab_compare_case
        WHERE run_id = $1
        ORDER BY created_at ASC
        "#,
    )
    .bind(id)
    .fetch_all(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;
    Ok(Json(ABCompareRunDetail { run, cases }))
}
