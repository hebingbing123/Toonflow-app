use axum::{
    extract::{Json, State},
    http::HeaderMap,
};
use chrono::Utc;
use serde::{Deserialize, Serialize};
use std::cmp::Ordering;

use crate::auth::require_user_uuid;
use crate::error::ApiError;
use crate::state::AppState;

pub(super) const PKG_VERSION: &str = env!("CARGO_PKG_VERSION");
pub(super) const ENV_UPDATE_LATEST_VERSION: &str = "TOONFLOW_UPDATE_LATEST_VERSION";
pub(super) const ENV_UPDATE_TIME: &str = "TOONFLOW_UPDATE_TIME";
pub(super) const ENV_UPDATE_TOONFLOW_URL: &str = "TOONFLOW_UPDATE_TOONFLOW_URL";
pub(super) const ENV_UPDATE_GITHUB_URL: &str = "TOONFLOW_UPDATE_GITHUB_URL";
pub(super) const ENV_UPDATE_GITEE_URL: &str = "TOONFLOW_UPDATE_GITEE_URL";
pub(super) const ENV_UPDATE_ATOMGIT_URL: &str = "TOONFLOW_UPDATE_ATOMGIT_URL";

#[derive(Debug, Deserialize)]
#[serde(rename_all = "lowercase")]
pub(super) enum CheckUpdateSource {
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
    pub(super) source: CheckUpdateSource,
}

#[derive(Debug, Serialize)]
#[serde(rename_all = "camelCase")]
pub(crate) struct CheckUpdateResponse {
    pub need_update: bool,
    pub latest_version: String,
    pub reinstall: bool,
    pub time: String,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub url: Option<String>,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, PartialOrd, Ord)]
pub(super) struct ReleaseVersion {
    pub(super) major: u64,
    pub(super) minor: u64,
    pub(super) patch: u64,
}

impl ReleaseVersion {
    pub(super) fn parse(raw: &str) -> Option<Self> {
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

pub(super) fn resolve_check_update_response(
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
