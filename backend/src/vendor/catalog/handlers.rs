//! 静态模型目录 HTTP 处理器。

use axum::{
    extract::{Query, State},
    http::HeaderMap,
    Json,
};

use crate::auth::require_user_uuid;
use crate::error::ApiError;
use crate::state::AppState;

use super::query::{
    default_text_model_composite_id, list_filtered, lookup_detail, normalize_filter,
};
use super::types::{
    DetailQuery, ListQuery, ModelDetailResponse, ModelListEntry, PatchTextModelDefaultBody,
    TextModelDefaultResponse,
};

#[utoipa::path(
    get,
    path = "/api/v1/models/text-default",
    operation_id = "getTextModelDefaultV1",
    tag = "models",
    responses(
        (status = 200, description = "OK", body = serde_json::Value),
        (status = 401, description = "Unauthorized", body = crate::error::ErrorBody),
        (status = 503, description = "Unavailable", body = crate::error::ErrorBody)
    ),
    security(("bearerAuth" = []))
)]
pub(crate) async fn text_model_default(
    State(state): State<AppState>,
    headers: HeaderMap,
) -> Result<Json<TextModelDefaultResponse>, ApiError> {
    let uid = require_user_uuid(&state, &headers)?;

    // Try to load per-user preference from DB.
    let user_pref: Option<String> = if let Some(pool) = state.pool.as_ref() {
        sqlx::query_scalar(
            r#"SELECT preferred_text_model_id FROM app_user_profile WHERE user_id = $1"#,
        )
        .bind(uid)
        .fetch_optional(pool)
        .await
        .map_err(|e| ApiError::DatabaseError(e.to_string()))?
        .flatten()
    } else {
        None
    };

    // Validate the stored preference is still in the catalog; fall back to server default if not.
    let default_model_id = user_pref
        .as_deref()
        .filter(|id| lookup_detail(id).is_some())
        .map(str::to_string)
        .unwrap_or_else(default_text_model_composite_id);

    Ok(Json(TextModelDefaultResponse {
        stub_placeholder: "123",
        default_model_id,
    }))
}

#[utoipa::path(
    patch,
    path = "/api/v1/models/text-default",
    operation_id = "patchTextModelDefaultV1",
    tag = "models",
    request_body(content = serde_json::Value, content_type = "application/json"),
    responses(
        (status = 200, description = "OK", body = serde_json::Value),
        (status = 400, description = "Bad request", body = crate::error::ErrorBody),
        (status = 401, description = "Unauthorized", body = crate::error::ErrorBody),
        (status = 503, description = "Unavailable", body = crate::error::ErrorBody)
    ),
    security(("bearerAuth" = []))
)]
pub(crate) async fn patch_text_model_default(
    State(state): State<AppState>,
    headers: HeaderMap,
    Json(body): Json<PatchTextModelDefaultBody>,
) -> Result<Json<TextModelDefaultResponse>, ApiError> {
    let uid = require_user_uuid(&state, &headers)?;

    // Validate model_id BEFORE touching the pool so bad requests get 400 even without DB.
    if let Some(ref id) = body.model_id {
        let id = id.trim();
        if id.is_empty() {
            return Err(ApiError::BadRequest(
                "model_id must be non-empty or null to reset".into(),
            ));
        }
        if lookup_detail(id).is_none() {
            return Err(ApiError::BadRequest(format!(
                "model_id '{id}' not found in catalog; use GET /api/v1/models/detail to verify"
            )));
        }
    }

    let pool = state.require_pool()?;

    let model_id_to_store = body.model_id.as_deref().map(str::trim).map(str::to_string);

    sqlx::query(
        r#"
        INSERT INTO app_user_profile (user_id, preferred_text_model_id, updated_at)
        VALUES ($1, $2, NOW())
        ON CONFLICT (user_id) DO UPDATE SET
          preferred_text_model_id = EXCLUDED.preferred_text_model_id,
          updated_at = NOW()
        "#,
    )
    .bind(uid)
    .bind(model_id_to_store.as_deref())
    .execute(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    let default_model_id = model_id_to_store
        .as_deref()
        .filter(|id| lookup_detail(id).is_some())
        .map(str::to_string)
        .unwrap_or_else(default_text_model_composite_id);

    Ok(Json(TextModelDefaultResponse {
        stub_placeholder: "123",
        default_model_id,
    }))
}

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
    Ok(Json(list_filtered(&filter)))
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
    lookup_detail(q.model_id.trim())
        .map(Json)
        .ok_or(ApiError::NotFound)
}
