//! 关于模块：遗留 `/api/setting/about/checkUpdate`（远程 `update.json`）和 `downloadApp`（本地安装程序/zip 应用）。
//!
//! SaaS Rust API 不获取桌面清单。相反，`check-update` 可以读取环境驱动的发布清单并与服务器 crate 版本比较；
//! 如果未设置，它安全地回退到 `needUpdate: false` 并返回当前版本。
//! `download-app` 验证 `url` 然后返回 **200** 策略响应 — Flutter 应用使用平台商店/安装程序，不使用此遗留端点。

use axum::{
    extract::{Json, State},
    http::HeaderMap,
    routing::post,
    Router,
};
use chrono::Utc;
use serde::{Deserialize, Serialize};
use std::cmp::Ordering;

use crate::auth::require_user_uuid;
use crate::error::ApiError;
use crate::state::AppState;

const PKG_VERSION: &str = env!("CARGO_PKG_VERSION");
const ENV_UPDATE_LATEST_VERSION: &str = "TOONFLOW_UPDATE_LATEST_VERSION";
const ENV_UPDATE_TIME: &str = "TOONFLOW_UPDATE_TIME";
const ENV_UPDATE_TOONFLOW_URL: &str = "TOONFLOW_UPDATE_TOONFLOW_URL";
const ENV_UPDATE_GITHUB_URL: &str = "TOONFLOW_UPDATE_GITHUB_URL";
const ENV_UPDATE_GITEE_URL: &str = "TOONFLOW_UPDATE_GITEE_URL";
const ENV_UPDATE_ATOMGIT_URL: &str = "TOONFLOW_UPDATE_ATOMGIT_URL";

#[derive(Debug, Deserialize)]
#[serde(rename_all = "lowercase")]
enum CheckUpdateSource {
    Toonflow,
    Github,
    Gitee,
    Atomgit,
}

impl CheckUpdateSource {
    fn url_env_key(&self) -> &'static str {
        match self {
            Self::Toonflow => ENV_UPDATE_TOONFLOW_URL,
            Self::Github => ENV_UPDATE_GITHUB_URL,
            Self::Gitee => ENV_UPDATE_GITEE_URL,
            Self::Atomgit => ENV_UPDATE_ATOMGIT_URL,
        }
    }
}

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
pub(crate) struct CheckUpdateBody {
    source: CheckUpdateSource,
}

#[derive(Debug, Serialize)]
#[serde(rename_all = "camelCase")]
pub(crate) struct CheckUpdateResponse {
    pub need_update: bool,
    pub latest_version: String,
    pub reinstall: bool,
    /// RFC3339 timestamp; stub uses **now** (Electron client used remote manifest **`time`**).
    pub time: String,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub url: Option<String>,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, PartialOrd, Ord)]
struct ReleaseVersion {
    major: u64,
    minor: u64,
    patch: u64,
}

impl ReleaseVersion {
    fn parse(raw: &str) -> Option<Self> {
        let trimmed = raw.trim();
        let core = trimmed.split_once('-').map(|(v, _)| v).unwrap_or(trimmed);
        let mut parts = core.split('.');
        let major = parts.next()?.parse().ok()?;
        let minor = parts.next()?.parse().ok()?;
        let patch = parts.next()?.parse().ok()?;
        if parts.next().is_some() {
            return None;
        }
        Some(Self {
            major,
            minor,
            patch,
        })
    }
}

fn configured_update_url(source: CheckUpdateSource) -> Option<String> {
    let raw = std::env::var(source.url_env_key()).ok()?;
    let trimmed = raw.trim();
    if trimmed.is_empty() {
        return None;
    }
    let parsed = reqwest::Url::parse(trimmed).ok()?;
    match parsed.scheme() {
        "http" | "https" => Some(trimmed.to_string()),
        _ => None,
    }
}

fn resolved_update_time(now: chrono::DateTime<Utc>) -> String {
    let raw = std::env::var(ENV_UPDATE_TIME).ok();
    let Some(raw) = raw else {
        return now.to_rfc3339();
    };
    let trimmed = raw.trim();
    if trimmed.is_empty() {
        return now.to_rfc3339();
    }
    chrono::DateTime::parse_from_rfc3339(trimmed)
        .map(|dt| dt.with_timezone(&Utc).to_rfc3339())
        .unwrap_or_else(|_| now.to_rfc3339())
}

fn resolve_check_update_response(
    source: CheckUpdateSource,
    now: chrono::DateTime<Utc>,
) -> CheckUpdateResponse {
    let latest_version = std::env::var(ENV_UPDATE_LATEST_VERSION)
        .ok()
        .map(|v| v.trim().to_string())
        .filter(|v| !v.is_empty())
        .unwrap_or_else(|| PKG_VERSION.to_string());
    let time = resolved_update_time(now);

    let Some(current) = ReleaseVersion::parse(PKG_VERSION) else {
        return CheckUpdateResponse {
            need_update: false,
            latest_version,
            reinstall: false,
            time,
            url: None,
        };
    };
    let Some(latest) = ReleaseVersion::parse(&latest_version) else {
        return CheckUpdateResponse {
            need_update: false,
            latest_version: PKG_VERSION.to_string(),
            reinstall: false,
            time,
            url: None,
        };
    };

    match latest.cmp(&current) {
        Ordering::Greater => CheckUpdateResponse {
            need_update: true,
            latest_version,
            reinstall: latest.major > current.major || latest.minor > current.minor,
            time,
            url: configured_update_url(source),
        },
        _ => CheckUpdateResponse {
            need_update: false,
            latest_version,
            reinstall: false,
            time,
            url: None,
        },
    }
}

#[utoipa::path(
    post,
    path = "/api/v1/settings/about/check-update",
    operation_id = "postAboutCheckUpdateV1",
    tag = "settings",
    request_body(content = serde_json::Value, content_type = "application/json"),
    responses(
        (status = 200, description = "OK", body = serde_json::Value),
        (status = 400, description = "Bad request", body = crate::error::ErrorBody),
        (status = 401, description = "Unauthorized", body = crate::error::ErrorBody),
        (status = 503, description = "Unavailable", body = crate::error::ErrorBody)
    ),
    security(("bearerAuth" = []))
)]
pub(crate) async fn post_check_update(
    State(state): State<AppState>,
    headers: HeaderMap,
    Json(body): Json<CheckUpdateBody>,
) -> Result<Json<CheckUpdateResponse>, ApiError> {
    let _ = require_user_uuid(&state, &headers)?;
    Ok(Json(resolve_check_update_response(body.source, Utc::now())))
}

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
pub(crate) struct DownloadAppBody {
    url: String,
    reinstall: bool,
}

#[derive(Debug, Serialize)]
#[serde(rename_all = "camelCase")]
pub(crate) struct DownloadAppAcceptedResponse {
    message: &'static str,
}

#[utoipa::path(
    post,
    path = "/api/v1/settings/about/download-app",
    operation_id = "postAboutDownloadAppV1",
    tag = "settings",
    request_body(content = serde_json::Value, content_type = "application/json"),
    responses(
        (status = 200, description = "OK", body = serde_json::Value),
        (status = 400, description = "Bad request", body = crate::error::ErrorBody),
        (status = 401, description = "Unauthorized", body = crate::error::ErrorBody),
        (status = 503, description = "Unavailable", body = crate::error::ErrorBody)
    ),
    security(("bearerAuth" = []))
)]
pub(crate) async fn post_download_app(
    State(state): State<AppState>,
    headers: HeaderMap,
    Json(body): Json<DownloadAppBody>,
) -> Result<Json<DownloadAppAcceptedResponse>, ApiError> {
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
    Ok(Json(DownloadAppAcceptedResponse {
        message: "Flutter 版本不通过此接口执行安装；请使用平台商店、分发页或浏览器打开下载链接",
    }))
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
static SETTINGS_ABOUT_ENV_TEST_MUTEX: std::sync::OnceLock<tokio::sync::Mutex<()>> =
    std::sync::OnceLock::new();

#[cfg(test)]
pub(crate) async fn env_test_lock() -> tokio::sync::MutexGuard<'static, ()> {
    SETTINGS_ABOUT_ENV_TEST_MUTEX
        .get_or_init(|| tokio::sync::Mutex::new(()))
        .lock()
        .await
}

#[cfg(test)]
mod tests {
    use super::*;

    fn env_lock() -> tokio::sync::MutexGuard<'static, ()> {
        SETTINGS_ABOUT_ENV_TEST_MUTEX
            .get_or_init(|| tokio::sync::Mutex::new(()))
            .blocking_lock()
    }

    fn clear_update_env() {
        std::env::remove_var(ENV_UPDATE_LATEST_VERSION);
        std::env::remove_var(ENV_UPDATE_TIME);
        std::env::remove_var(ENV_UPDATE_TOONFLOW_URL);
        std::env::remove_var(ENV_UPDATE_GITHUB_URL);
        std::env::remove_var(ENV_UPDATE_GITEE_URL);
        std::env::remove_var(ENV_UPDATE_ATOMGIT_URL);
    }

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

    #[test]
    fn download_app_response_has_message() {
        let resp = DownloadAppAcceptedResponse {
            message: "Flutter 版本不通过此接口执行安装；请使用平台商店、分发页或浏览器打开下载链接",
        };
        assert!(resp.message.contains("Flutter"));
    }

    #[test]
    fn release_version_parse_accepts_semver_like_string() {
        let version = ReleaseVersion::parse("1.2.3-beta.1").expect("parse version");
        assert_eq!(version.major, 1);
        assert_eq!(version.minor, 2);
        assert_eq!(version.patch, 3);
    }

    #[test]
    fn check_update_response_defaults_to_current_version_without_env() {
        let _guard = env_lock();
        clear_update_env();
        let now = Utc::now();
        let resp = resolve_check_update_response(CheckUpdateSource::Toonflow, now);
        assert!(!resp.need_update);
        assert_eq!(resp.latest_version, PKG_VERSION);
        assert!(!resp.reinstall);
        assert!(resp.url.is_none());
    }

    #[test]
    fn check_update_response_uses_patch_update_with_source_url() {
        let _guard = env_lock();
        clear_update_env();
        let current = ReleaseVersion::parse(PKG_VERSION).expect("pkg version");
        std::env::set_var(
            ENV_UPDATE_LATEST_VERSION,
            format!("{}.{}.{}", current.major, current.minor, current.patch + 1),
        );
        std::env::set_var(ENV_UPDATE_TIME, "2026-04-08T08:30:00Z");
        std::env::set_var(ENV_UPDATE_GITHUB_URL, "https://example.com/toonflow.zip");
        let resp = resolve_check_update_response(CheckUpdateSource::Github, Utc::now());
        assert!(resp.need_update);
        assert!(!resp.reinstall);
        let parsed = chrono::DateTime::parse_from_rfc3339(&resp.time).expect("valid rfc3339");
        assert_eq!(parsed.to_utc().to_rfc3339(), "2026-04-08T08:30:00+00:00");
        assert_eq!(
            resp.url.as_deref(),
            Some("https://example.com/toonflow.zip")
        );
        clear_update_env();
    }

    #[test]
    fn check_update_response_uses_reinstall_for_minor_update() {
        let _guard = env_lock();
        clear_update_env();
        let current = ReleaseVersion::parse(PKG_VERSION).expect("pkg version");
        std::env::set_var(
            ENV_UPDATE_LATEST_VERSION,
            format!("{}.{}.0", current.major, current.minor + 1),
        );
        let resp = resolve_check_update_response(CheckUpdateSource::Toonflow, Utc::now());
        assert!(resp.need_update);
        assert!(resp.reinstall);
        assert!(resp.url.is_none());
        clear_update_env();
    }

    #[test]
    fn check_update_response_ignores_invalid_latest_version() {
        let _guard = env_lock();
        clear_update_env();
        std::env::set_var(ENV_UPDATE_LATEST_VERSION, "not-a-version");
        let resp = resolve_check_update_response(CheckUpdateSource::Atomgit, Utc::now());
        assert!(!resp.need_update);
        assert_eq!(resp.latest_version, PKG_VERSION);
        clear_update_env();
    }

    #[test]
    fn check_update_response_ignores_invalid_time() {
        let _guard = env_lock();
        clear_update_env();
        std::env::set_var(ENV_UPDATE_TIME, "invalid-time");
        let now = Utc::now();
        let resp = resolve_check_update_response(CheckUpdateSource::Toonflow, now);
        assert_eq!(resp.time, now.to_rfc3339());
        clear_update_env();
    }
}
