use axum::{
    extract::{Query, State},
    http::HeaderMap,
    Json,
};
use sqlx::{Postgres, QueryBuilder};

use crate::auth::require_user_uuid;
use crate::error::ApiError;
use crate::state::AppState;

use super::super::types::{ListQualityReviewsQuery, QualityReview};
use super::super::validate::validate_list_reviews_query;

/// GET /api/v1/quality/reviews - 列出自己的质量评估
#[utoipa::path(
    get,
    path = "/api/v1/quality/reviews",
    operation_id = "listQualityReviewsV1",
    tag = "quality",
    params(ListQualityReviewsQuery),
    responses(
        (status = 200, description = "OK", body = serde_json::Value),
        (status = 400, description = "Bad request", body = crate::error::ErrorBody),
        (status = 401, description = "Unauthorized", body = crate::error::ErrorBody),
        (status = 503, description = "Unavailable", body = crate::error::ErrorBody)
    ),
    security(("bearerAuth" = []))
)]
pub(crate) async fn list_reviews(
    State(state): State<AppState>,
    headers: HeaderMap,
    Query(query): Query<ListQualityReviewsQuery>,
) -> Result<Json<Vec<QualityReview>>, ApiError> {
    let user_id = require_user_uuid(&state, &headers)?;
    validate_list_reviews_query(&query)?;
    let pool = state.require_pool()?;

    let limit = query.limit.unwrap_or(100).clamp(1, 500);
    let offset = query.offset.unwrap_or(0).max(0);

    let mut qb = QueryBuilder::<Postgres>::new("SELECT * FROM app_quality_review WHERE user_id = ");
    qb.push_bind(user_id);
    if let Some(project_id) = query.project_id {
        qb.push(" AND project_id = ");
        qb.push_bind(project_id);
    }
    if let Some(script_id) = query.script_id {
        qb.push(" AND script_id = ");
        qb.push_bind(script_id);
    }
    if let Some(target_type) = &query.target_type {
        qb.push(" AND target_type = ");
        qb.push_bind(target_type);
    }
    if let Some(target_id) = &query.target_id {
        qb.push(" AND target_id = ");
        qb.push_bind(target_id);
    }
    if let Some(job_id) = query.job_id {
        qb.push(" AND job_id = ");
        qb.push_bind(job_id);
    }
    if let Some(source) = &query.source {
        qb.push(" AND source = ");
        qb.push_bind(source);
    }
    if let Some(is_bad_case) = query.is_bad_case {
        qb.push(" AND is_bad_case = ");
        qb.push_bind(is_bad_case);
    }
    if let Some(memory_delivery_priority_applied) = query.memory_delivery_priority_applied {
        qb.push(" AND memory_delivery_priority_applied = ");
        qb.push_bind(memory_delivery_priority_applied);
    }
    // 按阶段和评分等级过滤（需求 6.6）
    if let Some(stage) = &query.stage {
        qb.push(" AND stage = ");
        qb.push_bind(stage);
    }
    if let Some(grade) = &query.grade {
        qb.push(" AND grade = ");
        qb.push_bind(grade);
    }
    // 按下一步动作过滤（需求 I.4）
    if let Some(next_action) = &query.next_action {
        qb.push(" AND next_action = ");
        qb.push_bind(next_action);
    }
    if let Some(suggested_action) = &query.suggested_action {
        qb.push(" AND suggested_action = ");
        qb.push_bind(suggested_action);
    }
    qb.push(" ORDER BY created_at DESC LIMIT ");
    qb.push_bind(limit);
    qb.push(" OFFSET ");
    qb.push_bind(offset);

    let reviews = qb
        .build_query_as::<QualityReview>()
        .fetch_all(pool)
        .await
        .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    Ok(Json(reviews))
}
