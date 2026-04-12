//! 危险操作模块。
//!
//! 遗留 `POST /api/other/deleteAllData` 和 `GET /api/setting/dbConfig/clearData` 擦除/重建**本地 SQLite**。
//! SaaS：`POST` 端点仅接受 `{}`；需要 **JWT**；响应 **501** — 无批量擦除（使用 Supabase 操作/账户删除流程）。

use axum::{
    extract::{Json, State},
    http::HeaderMap,
    response::Response,
    routing::post,
    Router,
};
use serde::Deserialize;

use crate::auth::require_user_uuid;
use crate::error::ApiError;
use crate::state::AppState;

#[derive(Debug, Deserialize)]
#[serde(deny_unknown_fields)]
pub(crate) struct EmptyDangerBody {}

fn wipe_not_supported() -> ApiError {
    ApiError::NotImplemented(
        "bulk database wipe is not supported on this API; use hosted Postgres operations or product-level account deletion"
            .into(),
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

pub fn router() -> Router<AppState> {
    Router::new()
        .route(
            "/api/v1/settings/danger/delete-all-data",
            post(post_delete_all_data),
        )
        .route(
            "/api/v1/settings/danger/clear-database",
            post(post_clear_database),
        )
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn empty_danger_body_rejects_unknown_fields() {
        let err = serde_json::from_str::<EmptyDangerBody>(r#"{"extra":1}"#);
        assert!(err.is_err());
    }

    #[test]
    fn empty_danger_body_accepts_empty() {
        let b: EmptyDangerBody = serde_json::from_str(r#"{}"#).unwrap();
        // EmptyDangerBody has no fields, so just parsing successfully is the test
        let _ = b;
    }

    #[test]
    fn wipe_not_supported_returns_not_implemented() {
        let err = wipe_not_supported();
        assert!(matches!(err, ApiError::NotImplemented(_)));
    }
}
