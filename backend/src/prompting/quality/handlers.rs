//! 质量审查 HTTP 处理器。

use axum::{
    extract::{Path, Query, State},
    http::HeaderMap,
    Json,
};
use sqlx::{Postgres, QueryBuilder};
use uuid::Uuid;

use crate::auth::require_user_uuid;
use crate::error::ApiError;
use crate::state::AppState;

use super::types::{
    CreateQualityReviewBody, ListQualityReviewsQuery, QualityReview, QualityStatsResponse,
    StagePassRateItem,
};
use super::validate::{validate_create_review_body, validate_list_reviews_query};

/// POST /api/v1/quality/reviews - 创建质量评估
#[utoipa::path(
    post,
    path = "/api/v1/quality/reviews",
    operation_id = "createQualityReviewV1",
    tag = "quality",
    request_body(content = serde_json::Value, content_type = "application/json"),
    responses(
        (status = 200, description = "OK", body = serde_json::Value),
        (status = 400, description = "Bad request", body = crate::error::ErrorBody),
        (status = 401, description = "Unauthorized", body = crate::error::ErrorBody),
        (status = 503, description = "Unavailable", body = crate::error::ErrorBody)
    ),
    security(("bearerAuth" = []))
)]
pub(crate) async fn create_review(
    State(state): State<AppState>,
    headers: HeaderMap,
    Json(body): Json<CreateQualityReviewBody>,
) -> Result<Json<QualityReview>, ApiError> {
    let user_id = require_user_uuid(&state, &headers)?;
    validate_create_review_body(&body)?;
    let pool = state.require_pool()?;

    let source = body.source.as_deref().unwrap_or("manual");
    let is_bad_case = body.is_bad_case.unwrap_or(false);

    let review = sqlx::query_as::<_, QualityReview>(
        r#"
        INSERT INTO app_quality_review (
            user_id, project_id, script_id, job_id, target_type, target_id,
            source, plot_coherence, character_consistency, dialogue_naturalness,
            pacing, faithfulness, visual_quality, overall_score, passed,
            comments, skill_version, model_name, model_params,
            is_bad_case, bad_case_category
        ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, $15, $16, $17, $18, $19, $20, $21)
        RETURNING *
        "#,
    )
    .bind(user_id)
    .bind(body.project_id)
    .bind(body.script_id)
    .bind(body.job_id)
    .bind(&body.target_type)
    .bind(&body.target_id)
    .bind(source)
    .bind(body.plot_coherence)
    .bind(body.character_consistency)
    .bind(body.dialogue_naturalness)
    .bind(body.pacing)
    .bind(body.faithfulness)
    .bind(body.visual_quality)
    .bind(body.overall_score)
    .bind(body.passed)
    .bind(&body.comments)
    .bind(&body.skill_version)
    .bind(&body.model_name)
    .bind(&body.model_params)
    .bind(is_bad_case)
    .bind(&body.bad_case_category)
    .fetch_one(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    Ok(Json(review))
}

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
    if let Some(is_bad_case) = query.is_bad_case {
        qb.push(" AND is_bad_case = ");
        qb.push_bind(is_bad_case);
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

/// GET /api/v1/quality/reviews/{id} - 获取单个质量评估
#[utoipa::path(
    get,
    path = "/api/v1/quality/reviews/{id}",
    operation_id = "getQualityReviewV1",
    tag = "quality",
    params(
        ("id" = uuid::Uuid, Path, description = "Review id")
    ),
    responses(
        (status = 200, description = "OK", body = serde_json::Value),
        (status = 401, description = "Unauthorized", body = crate::error::ErrorBody),
        (status = 404, description = "Not found", body = crate::error::ErrorBody),
        (status = 503, description = "Unavailable", body = crate::error::ErrorBody)
    ),
    security(("bearerAuth" = []))
)]
pub(crate) async fn get_review(
    State(state): State<AppState>,
    headers: HeaderMap,
    Path(id): Path<Uuid>,
) -> Result<Json<QualityReview>, ApiError> {
    let user_id = require_user_uuid(&state, &headers)?;
    let pool = state.require_pool()?;

    let review = sqlx::query_as::<_, QualityReview>(
        "SELECT * FROM app_quality_review WHERE id = $1 AND user_id = $2",
    )
    .bind(id)
    .bind(user_id)
    .fetch_optional(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?
    .ok_or(ApiError::NotFound)?;

    Ok(Json(review))
}

/// GET /api/v1/quality/stats - 获取质量统计
#[utoipa::path(
    get,
    path = "/api/v1/quality/stats",
    operation_id = "getQualityStatsV1",
    tag = "quality",
    responses(
        (status = 200, description = "OK", body = serde_json::Value),
        (status = 401, description = "Unauthorized", body = crate::error::ErrorBody),
        (status = 503, description = "Unavailable", body = crate::error::ErrorBody)
    ),
    security(("bearerAuth" = []))
)]
pub(crate) async fn get_stats(
    State(state): State<AppState>,
    headers: HeaderMap,
) -> Result<Json<Vec<QualityStatsResponse>>, ApiError> {
    let user_id = require_user_uuid(&state, &headers)?;
    let pool = state.require_pool()?;

    let stats = sqlx::query_as::<_, QualityStatsResponse>(
        r#"
        SELECT
            target_type,
            COUNT(*) as total_reviews,
            COUNT(*) FILTER (WHERE passed = true) as passed_count,
            COUNT(*) FILTER (WHERE passed = false) as failed_count,
            COUNT(*) FILTER (WHERE is_bad_case = true) as bad_case_count,
            ROUND(COUNT(*) FILTER (WHERE passed = true) * 100.0 / NULLIF(COUNT(*), 0), 2) as pass_rate_percent,
            COALESCE(AVG(overall_score), 0) as avg_overall_score
        FROM app_quality_review
        WHERE user_id = $1
        GROUP BY target_type
        "#,
    )
    .bind(user_id)
    .fetch_all(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    Ok(Json(stats))
}

/// GET /api/v1/quality/stage-pass-rate - 分环节通过率（按日期聚合）
#[utoipa::path(
    get,
    path = "/api/v1/quality/stage-pass-rate",
    operation_id = "getQualityStagePassRateV1",
    tag = "quality",
    responses(
        (status = 200, description = "OK", body = serde_json::Value),
        (status = 401, description = "Unauthorized", body = crate::error::ErrorBody),
        (status = 503, description = "Unavailable", body = crate::error::ErrorBody)
    ),
    security(("bearerAuth" = []))
)]
pub(crate) async fn get_stage_pass_rate(
    State(state): State<AppState>,
    headers: HeaderMap,
) -> Result<Json<Vec<StagePassRateItem>>, ApiError> {
    let user_id = require_user_uuid(&state, &headers)?;
    let pool = state.require_pool()?;

    let items = sqlx::query_as::<_, StagePassRateItem>(
        r#"
        SELECT
            target_type,
            DATE_TRUNC('day', created_at) as review_date,
            COUNT(*) as total_reviews,
            COUNT(*) FILTER (WHERE passed = true) as passed_count,
            COUNT(*) FILTER (WHERE is_bad_case = true) as bad_case_count,
            ROUND(COUNT(*) FILTER (WHERE passed = true) * 100.0 / NULLIF(COUNT(*), 0), 2) as pass_rate_percent,
            AVG(overall_score) as avg_score
        FROM app_quality_review
        WHERE user_id = $1
        GROUP BY target_type, DATE_TRUNC('day', created_at)
        ORDER BY review_date DESC
        "#,
    )
    .bind(user_id)
    .fetch_all(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    Ok(Json(items))
}
