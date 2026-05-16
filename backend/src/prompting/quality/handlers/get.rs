use axum::{
    extract::{Path, State},
    http::HeaderMap,
    Json,
};
use uuid::Uuid;

use crate::auth::require_user_uuid;
use crate::error::ApiError;
use crate::state::AppState;

use super::super::types::QualityReview;

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
