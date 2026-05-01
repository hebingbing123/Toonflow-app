//! 实验运行与变体快照 HTTP 处理器。

use axum::{
    extract::{Path, Query, State},
    http::{HeaderMap, StatusCode},
    response::{IntoResponse, Response},
    Json,
};
use serde_json::json;
use uuid::Uuid;

use crate::{auth::require_user_uuid, error::ApiError, state::AppState};

use super::{
    types::{
        CreateExperimentBody, ExperimentDetail, ExperimentRun, ExperimentVariant,
        ListExperimentsQuery,
    },
    validation::{validate_experiment_dependencies, validate_sample_tier, validate_stage_scope},
};

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
