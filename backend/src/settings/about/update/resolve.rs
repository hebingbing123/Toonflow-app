use chrono::Utc;
use std::cmp::Ordering;

use super::constants::{ENV_UPDATE_LATEST_VERSION, ENV_UPDATE_TIME, PKG_VERSION};
use super::types::{CheckUpdateResponse, CheckUpdateSource, ReleaseVersion};

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

pub(in crate::settings::about) fn resolve_check_update_response(
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
