use axum::extract::{Json, State};
use axum::http::HeaderMap;

use crate::auth::require_user_uuid;
use crate::error::ApiError;
use crate::state::AppState;

use super::storage::{load_studio_ui_prefs, save_studio_ui_prefs};
use super::types::{normalize_pinned_project_ids, PutStudioUiPrefsBody, StudioUiPrefsResponse};

#[utoipa::path(
    get,
    path = "/api/v1/settings/studio-ui/prefs",
    operation_id = "getStudioUiPrefsV1",
    tag = "settings",
    responses(
        (status = 200, description = "OK", body = StudioUiPrefsResponse),
        (status = 401, description = "Unauthorized", body = crate::error::ErrorBody),
        (status = 503, description = "Unavailable", body = crate::error::ErrorBody)
    ),
    security(("bearerAuth" = []))
)]
pub(crate) async fn get_studio_ui_prefs(
    State(state): State<AppState>,
    headers: HeaderMap,
) -> Result<Json<StudioUiPrefsResponse>, ApiError> {
    let uid = require_user_uuid(&state, &headers)?;
    let pool = state.require_pool()?;
    Ok(Json(load_studio_ui_prefs(pool, uid).await?))
}

#[utoipa::path(
    put,
    path = "/api/v1/settings/studio-ui/prefs",
    operation_id = "putStudioUiPrefsV1",
    tag = "settings",
    request_body = PutStudioUiPrefsBody,
    responses(
        (status = 200, description = "OK", body = StudioUiPrefsResponse),
        (status = 400, description = "Bad request", body = crate::error::ErrorBody),
        (status = 401, description = "Unauthorized", body = crate::error::ErrorBody),
        (status = 503, description = "Unavailable", body = crate::error::ErrorBody)
    ),
    security(("bearerAuth" = []))
)]
pub(crate) async fn put_studio_ui_prefs(
    State(state): State<AppState>,
    headers: HeaderMap,
    Json(body): Json<PutStudioUiPrefsBody>,
) -> Result<Json<StudioUiPrefsResponse>, ApiError> {
    let uid = require_user_uuid(&state, &headers)?;
    let pool = state.require_pool()?;
    let pinned_project_ids =
        normalize_pinned_project_ids(body.pinned_project_ids).map_err(ApiError::BadRequest)?;
    let prefs = StudioUiPrefsResponse { pinned_project_ids };
    save_studio_ui_prefs(pool, uid, &prefs).await?;
    Ok(Json(prefs))
}
