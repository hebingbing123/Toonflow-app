//! Legacy **`POST /api/other/deleteAllData`** and **`GET /api/setting/dbConfig/clearData`** wiped/rebuilt **local SQLite**.
//! SaaS: **`POST`** endpoints accept **`{}`** only; **JWT** required; response **501** — no bulk wipe (use Supabase ops / account deletion flows).

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
struct EmptyDangerBody {}

fn wipe_not_supported() -> ApiError {
    ApiError::NotImplemented(
        "bulk database wipe is not supported on this API; use hosted Postgres operations or product-level account deletion"
            .into(),
    )
}

async fn post_delete_all_data(
    State(state): State<AppState>,
    headers: HeaderMap,
    Json(_body): Json<EmptyDangerBody>,
) -> Result<Response, ApiError> {
    let _ = require_user_uuid(&state, &headers)?;
    Err(wipe_not_supported())
}

async fn post_clear_database(
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
