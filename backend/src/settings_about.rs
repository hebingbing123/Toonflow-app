//! Legacy **`/api/setting/about/checkUpdate`** (remote **`update.json`**) and **`downloadApp`** (local installer / zip apply).
//! SaaS Rust API does not fetch the desktop manifest: **`check-update`** returns **`needUpdate: false`** with the server crate version.
//! **`download-app`** validates **`url`** then responds **501** — Flutter apps use platform stores/installers, not this legacy endpoint.

use axum::{
    extract::{Json, State},
    http::HeaderMap,
    response::Response,
    routing::post,
    Router,
};
use chrono::Utc;
use serde::{Deserialize, Serialize};

use crate::auth::require_user_uuid;
use crate::error::ApiError;
use crate::state::AppState;

const PKG_VERSION: &str = env!("CARGO_PKG_VERSION");

#[derive(Debug, Deserialize)]
#[serde(rename_all = "lowercase")]
enum CheckUpdateSource {
    Toonflow,
    Github,
    Gitee,
    Atomgit,
}

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
struct CheckUpdateBody {
    source: CheckUpdateSource,
}

#[derive(Debug, Serialize)]
#[serde(rename_all = "camelCase")]
struct CheckUpdateResponse {
    pub need_update: bool,
    pub latest_version: String,
    pub reinstall: bool,
    /// RFC3339 timestamp; stub uses **now** (legacy used remote manifest **`time`**).
    pub time: String,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub url: Option<String>,
}

async fn post_check_update(
    State(state): State<AppState>,
    headers: HeaderMap,
    Json(body): Json<CheckUpdateBody>,
) -> Result<Json<CheckUpdateResponse>, ApiError> {
    let _ = require_user_uuid(&state, &headers)?;
    let _ = body.source;
    Ok(Json(CheckUpdateResponse {
        need_update: false,
        latest_version: PKG_VERSION.to_string(),
        reinstall: false,
        time: Utc::now().to_rfc3339(),
        url: None,
    }))
}

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
struct DownloadAppBody {
    url: String,
    reinstall: bool,
}

async fn post_download_app(
    State(state): State<AppState>,
    headers: HeaderMap,
    Json(body): Json<DownloadAppBody>,
) -> Result<Response, ApiError> {
    let _ = require_user_uuid(&state, &headers)?;
    let u = body.url.trim();
    if u.is_empty() {
        return Err(ApiError::BadRequest("url is required".into()));
    }
    let parsed = reqwest::Url::parse(u).map_err(|_| ApiError::BadRequest("invalid url".into()))?;
    let scheme = parsed.scheme();
    if scheme != "http" && scheme != "https" {
        return Err(ApiError::BadRequest("url must be http or https".into()));
    }
    let _ = body.reinstall;
    Err(ApiError::NotImplemented(
        "legacy download-app not implemented; Flutter apps use platform stores/installers".into(),
    ))
}

pub fn router() -> Router<AppState> {
    Router::new()
        .route(
            "/api/v1/settings/about/check-update",
            post(post_check_update),
        )
        .route(
            "/api/v1/settings/about/download-app",
            post(post_download_app),
        )
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn check_update_body_rejects_unknown_fields() {
        let err = serde_json::from_str::<CheckUpdateBody>(r#"{"source":"toonflow","extra":1}"#);
        assert!(err.is_err());
    }

    #[test]
    fn check_update_body_accepts_valid_source() {
        let b: CheckUpdateBody = serde_json::from_str(r#"{"source":"toonflow"}"#).unwrap();
        matches!(b.source, CheckUpdateSource::Toonflow);
    }

    #[test]
    fn check_update_body_accepts_github_source() {
        let b: CheckUpdateBody = serde_json::from_str(r#"{"source":"github"}"#).unwrap();
        matches!(b.source, CheckUpdateSource::Github);
    }

    #[test]
    fn download_app_body_rejects_unknown_fields() {
        let err = serde_json::from_str::<DownloadAppBody>(
            r#"{"url":"http://example.com","reinstall":true,"extra":1}"#,
        );
        assert!(err.is_err());
    }

    #[test]
    fn download_app_body_accepts_valid() {
        let b: DownloadAppBody =
            serde_json::from_str(r#"{"url":"http://example.com/app.zip","reinstall":false}"#)
                .unwrap();
        assert_eq!(b.url, "http://example.com/app.zip");
        assert!(!b.reinstall);
    }
}
