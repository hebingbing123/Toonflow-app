//! 模型列表与详情查询。

use axum::{
    extract::{Query, State},
    http::HeaderMap,
    Json,
};

use crate::auth::require_user_uuid;
use crate::error::ApiError;
use crate::state::AppState;

use super::super::query::{list_filtered, lookup_detail, normalize_filter};
use super::super::types::{DetailQuery, ListQuery, ModelDetailResponse, ModelListEntry};

#[utoipa::path(
    get,
    path = "/api/v1/models",
    operation_id = "listModelsV1",
    tag = "models",
    params(
        ("type" = Option<String>, Query, description = "Filter: text, image, video, or all (default all)")
    ),
    responses(
        (status = 200, description = "OK", body = serde_json::Value),
        (status = 400, description = "Bad request", body = crate::error::ErrorBody),
        (status = 401, description = "Unauthorized", body = crate::error::ErrorBody),
        (status = 503, description = "Unavailable", body = crate::error::ErrorBody)
    ),
    security(("bearerAuth" = []))
)]
pub(crate) async fn list_models(
    State(state): State<AppState>,
    headers: HeaderMap,
    Query(q): Query<ListQuery>,
) -> Result<Json<Vec<ModelListEntry>>, ApiError> {
    let _user = require_user_uuid(&state, &headers)?;
    let filter = normalize_filter(q.filter)?;
    let include_pricing = q.include_pricing.unwrap_or(false);
    Ok(Json(list_filtered(&filter, include_pricing)))
}

#[utoipa::path(
    get,
    path = "/api/v1/models/detail",
    operation_id = "modelDetailV1",
    tag = "models",
    params(
        ("model_id" = String, Query, description = "Composite id `{vendor_id}:{model_name}`")
    ),
    responses(
        (status = 200, description = "OK", body = serde_json::Value),
        (status = 400, description = "Bad request", body = crate::error::ErrorBody),
        (status = 401, description = "Unauthorized", body = crate::error::ErrorBody),
        (status = 404, description = "Not found", body = crate::error::ErrorBody),
        (status = 503, description = "Unavailable", body = crate::error::ErrorBody)
    ),
    security(("bearerAuth" = []))
)]
pub(crate) async fn model_detail(
    State(state): State<AppState>,
    headers: HeaderMap,
    Query(q): Query<DetailQuery>,
) -> Result<Json<ModelDetailResponse>, ApiError> {
    let _user = require_user_uuid(&state, &headers)?;
    if q.model_id.trim().is_empty() {
        return Err(ApiError::BadRequest("model_id is required".into()));
    }
    let include_pricing = q.include_pricing.unwrap_or(false);
    lookup_detail(q.model_id.trim(), include_pricing)
        .map(Json)
        .ok_or(ApiError::NotFound)
}
