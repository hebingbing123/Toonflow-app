//! 关于模块：遗留 `/api/setting/about/checkUpdate`（远程 `update.json`）和 `downloadApp`（本地安装程序/zip 应用）。
//!
//! SaaS Rust API 不获取桌面清单。相反，`check-update` 可以读取环境驱动的发布清单并与服务器 crate 版本比较；
//! 如果未设置，它安全地回退到 `needUpdate: false` 并返回当前版本。
//! `download-app` 验证 `url` 然后返回 **200** 策略响应 — Flutter 应用使用平台商店/安装程序，不使用此遗留端点。

use axum::{routing::post, Router};

use crate::state::AppState;

mod download;
mod update;

#[allow(unused_imports)]
pub(crate) use download::__path_post_download_app;
pub(crate) use download::post_download_app;
#[allow(unused_imports)]
pub(crate) use update::__path_post_check_update;
pub(crate) use update::post_check_update;

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
    use chrono::Utc;

    use super::download::{DownloadAppAcceptedResponse, DownloadAppBody};
    use super::update::constants::{
        ENV_UPDATE_ATOMGIT_URL, ENV_UPDATE_GITEE_URL, ENV_UPDATE_GITHUB_URL,
        ENV_UPDATE_LATEST_VERSION, ENV_UPDATE_OPENFLOW_URL, ENV_UPDATE_TIME, PKG_VERSION,
    };
    use super::update::resolve::resolve_check_update_response;
    use super::update::types::{CheckUpdateBody, CheckUpdateSource, ReleaseVersion};
    use super::SETTINGS_ABOUT_ENV_TEST_MUTEX;

    fn env_lock() -> tokio::sync::MutexGuard<'static, ()> {
        SETTINGS_ABOUT_ENV_TEST_MUTEX
            .get_or_init(|| tokio::sync::Mutex::new(()))
            .blocking_lock()
    }

    fn clear_update_env() {
        std::env::remove_var(ENV_UPDATE_LATEST_VERSION);
        std::env::remove_var(ENV_UPDATE_TIME);
        std::env::remove_var(ENV_UPDATE_OPENFLOW_URL);
        std::env::remove_var(ENV_UPDATE_GITHUB_URL);
        std::env::remove_var(ENV_UPDATE_GITEE_URL);
        std::env::remove_var(ENV_UPDATE_ATOMGIT_URL);
    }

    #[test]
    fn check_update_body_rejects_unknown_fields() {
        let err = serde_json::from_str::<CheckUpdateBody>(r#"{"source":"openflow","extra":1}"#);
        assert!(err.is_err());
    }

    #[test]
    fn check_update_body_accepts_valid_source() {
        let b: CheckUpdateBody = serde_json::from_str(r#"{"source":"openflow"}"#).unwrap();
        matches!(b.source, CheckUpdateSource::Openflow);
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
        let resp = resolve_check_update_response(CheckUpdateSource::Openflow, now);
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
        std::env::set_var(ENV_UPDATE_GITHUB_URL, "https://example.com/openflow.zip");
        let resp = resolve_check_update_response(CheckUpdateSource::Github, Utc::now());
        assert!(resp.need_update);
        assert!(!resp.reinstall);
        let parsed = chrono::DateTime::parse_from_rfc3339(&resp.time).expect("valid rfc3339");
        assert_eq!(parsed.to_utc().to_rfc3339(), "2026-04-08T08:30:00+00:00");
        assert_eq!(
            resp.url.as_deref(),
            Some("https://example.com/openflow.zip")
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
        let resp = resolve_check_update_response(CheckUpdateSource::Openflow, Utc::now());
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
        let resp = resolve_check_update_response(CheckUpdateSource::Openflow, now);
        assert_eq!(resp.time, now.to_rfc3339());
        clear_update_env();
    }
}
