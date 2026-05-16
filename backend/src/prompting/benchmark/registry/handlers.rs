//! 基线样本注册表 HTTP 处理器。

use axum::{
    extract::{Path, Query, State},
    http::HeaderMap,
    Json,
};
use sqlx::{Postgres, QueryBuilder};
use uuid::Uuid;

use crate::auth::require_user_uuid;
use crate::error::{bad_request_i18n, ApiError};
use crate::state::AppState;

use super::types::{
    BenchmarkCase, CreateBenchmarkCaseBody, ListBenchmarkCasesQuery, PromoteFromQualityReviewBody,
    UpdateBenchmarkCaseBody,
};

/// POST /api/v1/benchmark/cases - 创建基线样本
#[utoipa::path(
    post,
    path = "/api/v1/benchmark/cases",
    operation_id = "createBenchmarkCaseV1",
    tag = "benchmark",
    request_body(content = CreateBenchmarkCaseBody, content_type = "application/json"),
    responses(
        (status = 200, description = "OK", body = BenchmarkCase),
        (status = 400, description = "Bad request", body = crate::error::ErrorBody),
        (status = 401, description = "Unauthorized", body = crate::error::ErrorBody),
        (status = 503, description = "Unavailable", body = crate::error::ErrorBody)
    ),
    security(("bearerAuth" = []))
)]
pub(crate) async fn create_benchmark_case(
    State(state): State<AppState>,
    headers: HeaderMap,
    Json(body): Json<CreateBenchmarkCaseBody>,
) -> Result<Json<BenchmarkCase>, ApiError> {
    let user_id = require_user_uuid(&state, &headers)?;
    validate_create_body(&body)?;
    let pool = state.require_pool()?;

    // 检查重复样本（需求 1.6）
    check_duplicate_case(pool, user_id, body.project_id, body.script_id, &body.stage).await?;

    let issue_tags = serde_json::to_value(body.issue_tags.unwrap_or_default()).map_err(|e| {
        bad_request_i18n(
            &format!("Invalid issue_tags: {}", e),
            &format!("无效的 issue_tags：{}", e),
        )
    })?;

    let weight = body.weight.unwrap_or(1);

    let case = sqlx::query_as::<_, BenchmarkCase>(
        r#"
        INSERT INTO app_benchmark_case (
            owner_user_id, project_id, script_id, stage, case_type,
            issue_tags, weight, source_kind, source_ref, summary
        ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10)
        RETURNING *
        "#,
    )
    .bind(user_id)
    .bind(body.project_id)
    .bind(body.script_id)
    .bind(&body.stage)
    .bind(&body.case_type)
    .bind(issue_tags)
    .bind(weight)
    .bind(&body.source_kind)
    .bind(&body.source_ref)
    .bind(&body.summary)
    .fetch_one(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    Ok(Json(case))
}

/// GET /api/v1/benchmark/cases - 列出基线样本
#[utoipa::path(
    get,
    path = "/api/v1/benchmark/cases",
    operation_id = "listBenchmarkCasesV1",
    tag = "benchmark",
    params(ListBenchmarkCasesQuery),
    responses(
        (status = 200, description = "OK", body = Vec<BenchmarkCase>),
        (status = 400, description = "Bad request", body = crate::error::ErrorBody),
        (status = 401, description = "Unauthorized", body = crate::error::ErrorBody),
        (status = 503, description = "Unavailable", body = crate::error::ErrorBody)
    ),
    security(("bearerAuth" = []))
)]
pub(crate) async fn list_benchmark_cases(
    State(state): State<AppState>,
    headers: HeaderMap,
    Query(query): Query<ListBenchmarkCasesQuery>,
) -> Result<Json<Vec<BenchmarkCase>>, ApiError> {
    let user_id = require_user_uuid(&state, &headers)?;
    validate_list_query(&query)?;
    let pool = state.require_pool()?;

    let limit = query.limit.unwrap_or(100).clamp(1, 500);
    let offset = query.offset.unwrap_or(0).max(0);

    let mut qb =
        QueryBuilder::<Postgres>::new("SELECT * FROM app_benchmark_case WHERE owner_user_id = ");
    qb.push_bind(user_id);

    if let Some(project_id) = query.project_id {
        qb.push(" AND project_id = ");
        qb.push_bind(project_id);
    }
    if let Some(script_id) = query.script_id {
        qb.push(" AND script_id = ");
        qb.push_bind(script_id);
    }
    if let Some(stage) = &query.stage {
        qb.push(" AND stage = ");
        qb.push_bind(stage);
    }
    if let Some(case_type) = &query.case_type {
        qb.push(" AND case_type = ");
        qb.push_bind(case_type);
    }
    if let Some(source_kind) = &query.source_kind {
        qb.push(" AND source_kind = ");
        qb.push_bind(source_kind);
    }

    qb.push(" ORDER BY weight DESC, created_at DESC LIMIT ");
    qb.push_bind(limit);
    qb.push(" OFFSET ");
    qb.push_bind(offset);

    let cases = qb
        .build_query_as::<BenchmarkCase>()
        .fetch_all(pool)
        .await
        .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    Ok(Json(cases))
}

/// PATCH /api/v1/benchmark/cases/:id - 更新基线样本
#[utoipa::path(
    patch,
    path = "/api/v1/benchmark/cases/{id}",
    operation_id = "updateBenchmarkCaseV1",
    tag = "benchmark",
    params(
        ("id" = Uuid, Path, description = "Benchmark case ID")
    ),
    request_body(content = UpdateBenchmarkCaseBody, content_type = "application/json"),
    responses(
        (status = 200, description = "OK", body = BenchmarkCase),
        (status = 400, description = "Bad request", body = crate::error::ErrorBody),
        (status = 401, description = "Unauthorized", body = crate::error::ErrorBody),
        (status = 404, description = "Not found", body = crate::error::ErrorBody),
        (status = 503, description = "Unavailable", body = crate::error::ErrorBody)
    ),
    security(("bearerAuth" = []))
)]
pub(crate) async fn update_benchmark_case(
    State(state): State<AppState>,
    headers: HeaderMap,
    Path(id): Path<Uuid>,
    Json(body): Json<UpdateBenchmarkCaseBody>,
) -> Result<Json<BenchmarkCase>, ApiError> {
    let user_id = require_user_uuid(&state, &headers)?;
    validate_update_body(&body)?;
    let pool = state.require_pool()?;

    // 验证所有权
    let _existing = sqlx::query_as::<_, BenchmarkCase>(
        "SELECT * FROM app_benchmark_case WHERE id = $1 AND owner_user_id = $2",
    )
    .bind(id)
    .bind(user_id)
    .fetch_optional(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?
    .ok_or(ApiError::NotFound)?;

    let mut qb = QueryBuilder::<Postgres>::new("UPDATE app_benchmark_case SET updated_at = NOW()");

    if let Some(stage) = &body.stage {
        qb.push(", stage = ");
        qb.push_bind(stage);
    }
    if let Some(case_type) = &body.case_type {
        qb.push(", case_type = ");
        qb.push_bind(case_type);
    }
    if let Some(issue_tags) = &body.issue_tags {
        let tags_json = serde_json::to_value(issue_tags).map_err(|e| {
            bad_request_i18n(
                &format!("Invalid issue_tags: {}", e),
                &format!("无效的 issue_tags：{}", e),
            )
        })?;
        qb.push(", issue_tags = ");
        qb.push_bind(tags_json);
    }
    if let Some(weight) = body.weight {
        qb.push(", weight = ");
        qb.push_bind(weight);
    }
    if let Some(summary) = &body.summary {
        qb.push(", summary = ");
        qb.push_bind(summary);
    }
    if let Some(last_verified_at) = body.last_verified_at {
        qb.push(", last_verified_at = ");
        qb.push_bind(last_verified_at);
    }

    qb.push(" WHERE id = ");
    qb.push_bind(id);
    qb.push(" AND owner_user_id = ");
    qb.push_bind(user_id);
    qb.push(" RETURNING *");

    let updated = qb
        .build_query_as::<BenchmarkCase>()
        .fetch_one(pool)
        .await
        .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    Ok(Json(updated))
}

/// POST /api/v1/benchmark/cases/promote-from-review - 从质量评审提升为基线样本
#[utoipa::path(
    post,
    path = "/api/v1/benchmark/cases/promote-from-review",
    operation_id = "promoteFromQualityReviewV1",
    tag = "benchmark",
    request_body(content = PromoteFromQualityReviewBody, content_type = "application/json"),
    responses(
        (status = 200, description = "OK", body = BenchmarkCase),
        (status = 400, description = "Bad request", body = crate::error::ErrorBody),
        (status = 401, description = "Unauthorized", body = crate::error::ErrorBody),
        (status = 404, description = "Not found", body = crate::error::ErrorBody),
        (status = 503, description = "Unavailable", body = crate::error::ErrorBody)
    ),
    security(("bearerAuth" = []))
)]
pub(crate) async fn promote_from_quality_review(
    State(state): State<AppState>,
    headers: HeaderMap,
    Json(body): Json<PromoteFromQualityReviewBody>,
) -> Result<Json<BenchmarkCase>, ApiError> {
    let user_id = require_user_uuid(&state, &headers)?;
    validate_promote_body(&body)?;
    let pool = state.require_pool()?;

    // 获取质量评审记录
    let review = sqlx::query_as::<
        _,
        (
            Option<i32>,
            Option<i32>,
            Option<String>,
            String,
            Option<String>,
        ),
    >(
        r#"
        SELECT project_id, script_id, stage, target_type, target_id
        FROM app_quality_review
        WHERE id = $1 AND user_id = $2
        "#,
    )
    .bind(body.quality_review_id)
    .bind(user_id)
    .fetch_optional(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?
    .ok_or(ApiError::NotFound)?;

    let project_id = review.0.ok_or_else(|| {
        bad_request_i18n(
            "Quality review missing project_id",
            "质量评审缺少 project_id",
        )
    })?;

    let stage = review
        .2
        .ok_or_else(|| bad_request_i18n("Quality review missing stage", "质量评审缺少 stage"))?;

    let script_id = review.1;

    // 检查重复样本（需求 1.6）
    check_duplicate_case(pool, user_id, project_id, script_id, &stage).await?;

    let issue_tags = serde_json::to_value(body.issue_tags.unwrap_or_default()).map_err(|e| {
        bad_request_i18n(
            &format!("Invalid issue_tags: {}", e),
            &format!("无效的 issue_tags：{}", e),
        )
    })?;

    let weight = body.weight.unwrap_or(1);
    let source_ref = body.quality_review_id.to_string();

    let case = sqlx::query_as::<_, BenchmarkCase>(
        r#"
        INSERT INTO app_benchmark_case (
            owner_user_id, project_id, script_id, stage, case_type,
            issue_tags, weight, source_kind, source_ref, summary
        ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10)
        RETURNING *
        "#,
    )
    .bind(user_id)
    .bind(project_id)
    .bind(script_id)
    .bind(&stage)
    .bind(&body.case_type)
    .bind(issue_tags)
    .bind(weight)
    .bind("quality_review")
    .bind(&source_ref)
    .bind(&body.summary)
    .fetch_one(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    Ok(Json(case))
}

// ============================================================
// 验证辅助函数
// ============================================================

fn validate_create_body(body: &CreateBenchmarkCaseBody) -> Result<(), ApiError> {
    validate_stage(&body.stage)?;
    validate_case_type(&body.case_type)?;
    validate_source_kind(&body.source_kind)?;

    if body.summary.trim().is_empty() {
        return Err(bad_request_i18n(
            "summary cannot be empty",
            "summary 不能为空",
        ));
    }

    if let Some(weight) = body.weight {
        if !(1..=100).contains(&weight) {
            return Err(bad_request_i18n(
                "weight must be between 1 and 100",
                "weight 必须在 1 到 100 之间",
            ));
        }
    }

    Ok(())
}

fn validate_list_query(query: &ListBenchmarkCasesQuery) -> Result<(), ApiError> {
    if let Some(stage) = &query.stage {
        validate_stage(stage)?;
    }
    if let Some(case_type) = &query.case_type {
        validate_case_type(case_type)?;
    }
    if let Some(source_kind) = &query.source_kind {
        validate_source_kind(source_kind)?;
    }
    Ok(())
}

fn validate_update_body(body: &UpdateBenchmarkCaseBody) -> Result<(), ApiError> {
    if let Some(stage) = &body.stage {
        validate_stage(stage)?;
    }
    if let Some(case_type) = &body.case_type {
        validate_case_type(case_type)?;
    }
    if let Some(summary) = &body.summary {
        if summary.trim().is_empty() {
            return Err(bad_request_i18n(
                "summary cannot be empty",
                "summary 不能为空",
            ));
        }
    }
    if let Some(weight) = body.weight {
        if !(1..=100).contains(&weight) {
            return Err(bad_request_i18n(
                "weight must be between 1 and 100",
                "weight 必须在 1 到 100 之间",
            ));
        }
    }
    Ok(())
}

fn validate_promote_body(body: &PromoteFromQualityReviewBody) -> Result<(), ApiError> {
    validate_case_type(&body.case_type)?;

    if body.summary.trim().is_empty() {
        return Err(bad_request_i18n(
            "summary cannot be empty",
            "summary 不能为空",
        ));
    }

    if let Some(weight) = body.weight {
        if !(1..=100).contains(&weight) {
            return Err(bad_request_i18n(
                "weight must be between 1 and 100",
                "weight 必须在 1 到 100 之间",
            ));
        }
    }

    Ok(())
}

pub(super) fn validate_stage(stage: &str) -> Result<(), ApiError> {
    const VALID_STAGES: &[&str] = &[
        "story_skeleton",
        "adaptation_strategy",
        "director_planning",
        "storyboard_table",
        "storyboard_panel",
        "video_prompt",
    ];

    if !VALID_STAGES.contains(&stage) {
        return Err(bad_request_i18n(
            &format!(
                "Invalid stage '{}'. Must be one of: {}",
                stage,
                VALID_STAGES.join(", ")
            ),
            &format!(
                "无效的 stage '{}'。必须是以下之一：{}",
                stage,
                VALID_STAGES.join("、")
            ),
        ));
    }

    Ok(())
}

pub(super) fn validate_case_type(case_type: &str) -> Result<(), ApiError> {
    const VALID_TYPES: &[&str] = &["golden", "bad_case", "regression_guard"];

    if !VALID_TYPES.contains(&case_type) {
        return Err(bad_request_i18n(
            &format!(
                "Invalid case_type '{}'. Must be one of: {}",
                case_type,
                VALID_TYPES.join(", ")
            ),
            &format!(
                "无效的 case_type '{}'。必须是以下之一：{}",
                case_type,
                VALID_TYPES.join("、")
            ),
        ));
    }

    Ok(())
}

pub(super) fn validate_source_kind(source_kind: &str) -> Result<(), ApiError> {
    const VALID_SOURCES: &[&str] = &[
        "quality_review",
        "job_failure",
        "patch_attribution",
        "manual",
    ];

    if !VALID_SOURCES.contains(&source_kind) {
        return Err(bad_request_i18n(
            &format!(
                "Invalid source_kind '{}'. Must be one of: {}",
                source_kind,
                VALID_SOURCES.join(", ")
            ),
            &format!(
                "无效的 source_kind '{}'。必须是以下之一：{}",
                source_kind,
                VALID_SOURCES.join("、")
            ),
        ));
    }

    Ok(())
}

pub(super) fn benchmark_case_scope_key(
    owner_user_id: Uuid,
    project_id: i32,
    script_id: Option<i32>,
    stage: &str,
) -> String {
    format!(
        "{}:{}:{}:{}",
        owner_user_id,
        project_id,
        script_id
            .map(|value| value.to_string())
            .unwrap_or_else(|| "none".to_string()),
        stage
    )
}

/// 检查重复样本（需求 1.6）
async fn check_duplicate_case(
    pool: &sqlx::PgPool,
    user_id: Uuid,
    project_id: i32,
    script_id: Option<i32>,
    stage: &str,
) -> Result<(), ApiError> {
    let scope_key = benchmark_case_scope_key(user_id, project_id, script_id, stage);
    let count = sqlx::query_scalar::<_, i64>(
        r#"
        SELECT COUNT(*)
        FROM app_benchmark_case
        WHERE owner_user_id = $1
          AND project_id = $2
          AND (script_id = $3 OR (script_id IS NULL AND $3 IS NULL))
          AND stage = $4
        "#,
    )
    .bind(user_id)
    .bind(project_id)
    .bind(script_id)
    .bind(stage)
    .fetch_one(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    if count > 0 {
        return Err(bad_request_i18n(
            &format!(
                "Duplicate benchmark case detected for scope {}. Consider updating existing case instead.",
                scope_key
            ),
            &format!("检测到 scope {} 下存在重复 benchmark case，请考虑更新已有样本。", scope_key),
        ));
    }

    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;
    use proptest::prelude::*;

    #[test]
    fn test_validate_stage() {
        assert!(validate_stage("story_skeleton").is_ok());
        assert!(validate_stage("video_prompt").is_ok());
        assert!(validate_stage("invalid_stage").is_err());
    }

    #[test]
    fn test_validate_case_type() {
        assert!(validate_case_type("golden").is_ok());
        assert!(validate_case_type("bad_case").is_ok());
        assert!(validate_case_type("regression_guard").is_ok());
        assert!(validate_case_type("invalid_type").is_err());
    }

    #[test]
    fn test_validate_source_kind() {
        assert!(validate_source_kind("quality_review").is_ok());
        assert!(validate_source_kind("manual").is_ok());
        assert!(validate_source_kind("invalid_source").is_err());
    }

    proptest! {
        #[test]
        fn prop_benchmark_cases_are_isolated_by_scope(
            project_id_a in 1i32..1000,
            project_id_b in 1001i32..2000,
            script_id in proptest::option::of(1i32..1000),
            stage in prop_oneof![
                Just("story_skeleton".to_string()),
                Just("storyboard_table".to_string()),
                Just("video_prompt".to_string()),
            ],
        ) {
            let owner = Uuid::from_u128(7);
            let key_a = benchmark_case_scope_key(owner, project_id_a, script_id, &stage);
            let key_b = benchmark_case_scope_key(owner, project_id_b, script_id, &stage);
            prop_assert_ne!(key_a, key_b);
        }
    }
}
