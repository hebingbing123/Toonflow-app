use axum::{
    extract::{Json, State},
    http::HeaderMap,
    response::Response,
};

use crate::auth::require_user_uuid;
use crate::error::helpers::not_implemented_i18n;
use crate::error::ApiError;
use crate::state::AppState;

use super::types::EmptyDangerBody;

pub(super) fn wipe_not_supported() -> ApiError {
    not_implemented_i18n(
        "bulk database wipe is not supported on this API; use hosted Postgres operations or product-level account deletion",
        "此 API 不支持批量数据库清除；请使用托管 Postgres 操作或产品级账户删除",
    )
}

#[utoipa::path(
    post,
    path = "/api/v1/settings/danger/delete-all-data",
    operation_id = "postSettingsDangerDeleteAllDataV1",
    tag = "settings",
    request_body(content = serde_json::Value, content_type = "application/json"),
    responses(
        (status = 400, description = "Bad request", body = crate::error::ErrorBody),
        (status = 401, description = "Unauthorized", body = crate::error::ErrorBody),
        (status = 501, description = "Not implemented", body = crate::error::ErrorBody),
        (status = 503, description = "Unavailable", body = crate::error::ErrorBody)
    ),
    security(("bearerAuth" = []))
)]
pub(crate) async fn post_delete_all_data(
    State(state): State<AppState>,
    headers: HeaderMap,
    Json(_body): Json<EmptyDangerBody>,
) -> Result<Response, ApiError> {
    let _ = require_user_uuid(&state, &headers)?;
    Err(wipe_not_supported())
}

#[utoipa::path(
    post,
    path = "/api/v1/settings/danger/clear-database",
    operation_id = "postSettingsDangerClearDatabaseV1",
    tag = "settings",
    request_body(content = serde_json::Value, content_type = "application/json"),
    responses(
        (status = 400, description = "Bad request", body = crate::error::ErrorBody),
        (status = 401, description = "Unauthorized", body = crate::error::ErrorBody),
        (status = 501, description = "Not implemented", body = crate::error::ErrorBody),
        (status = 503, description = "Unavailable", body = crate::error::ErrorBody)
    ),
    security(("bearerAuth" = []))
)]
pub(crate) async fn post_clear_database(
    State(state): State<AppState>,
    headers: HeaderMap,
    Json(_body): Json<EmptyDangerBody>,
) -> Result<Response, ApiError> {
    let _ = require_user_uuid(&state, &headers)?;
    Err(wipe_not_supported())
}
