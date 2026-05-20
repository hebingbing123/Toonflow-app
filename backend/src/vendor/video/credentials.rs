//! Resolve video provider API keys and per-vendor API base URLs.

use sqlx::PgPool;
use uuid::Uuid;

use crate::settings::vendors::load_user_vendor_config;
use crate::state::VendorConfig;

use crate::vendor::user_credentials::{load_stored_vendor_api_key, load_stored_vendor_credentials};

use super::auth::VideoProviderCredentials;
use super::endpoint::{video_vendor_id_candidates, VideoProviderCall};

use super::VideoProvider;

#[allow(dead_code)] // used by PG contract tests (`--ignored`) and external callers
pub async fn load_video_provider_api_key(
    pool: &PgPool,
    owner_user_id: Uuid,
    provider: VideoProvider,
    catalog_model_id: Option<&str>,
) -> Result<Option<String>, String> {
    let candidates = video_vendor_id_candidates(provider, catalog_model_id);
    load_stored_vendor_api_key(pool, owner_user_id, &candidates).await
}

pub async fn load_video_provider_credentials(
    pool: &PgPool,
    owner_user_id: Uuid,
    provider: VideoProvider,
    catalog_model_id: Option<&str>,
) -> Result<Option<VideoProviderCredentials>, String> {
    let candidates = video_vendor_id_candidates(provider, catalog_model_id);
    let stored = load_stored_vendor_credentials(pool, owner_user_id, &candidates).await?;
    Ok(stored.map(|s| VideoProviderCredentials {
        api_key: s.api_key.or(s.api_token),
        api_secret: s.api_secret,
    }))
}

/// Load stored credentials + Settings vendor config and build [`VideoProviderCall`].
pub async fn load_video_provider_call(
    pool: &PgPool,
    owner_user_id: Uuid,
    provider: VideoProvider,
    catalog_model_id: Option<&str>,
) -> Result<(Option<VideoProviderCredentials>, VideoProviderCall), String> {
    let credentials =
        load_video_provider_credentials(pool, owner_user_id, provider, catalog_model_id).await?;
    let vendor_config = load_user_vendor_config(pool, owner_user_id).await.ok();
    let call = VideoProviderCall::build(
        provider,
        credentials.as_ref(),
        catalog_model_id,
        vendor_config.as_ref(),
    )
    .map_err(|e| e.to_string())?;
    Ok((credentials, call))
}

/// Build call when credentials are already loaded (avoids double DB read in workers).
#[allow(dead_code)] // reserved for worker/external integration path
pub async fn build_video_provider_call(
    pool: &PgPool,
    owner_user_id: Uuid,
    provider: VideoProvider,
    catalog_model_id: Option<&str>,
    credentials: Option<&VideoProviderCredentials>,
) -> Result<VideoProviderCall, String> {
    let vendor_config = load_user_vendor_config(pool, owner_user_id).await.ok();
    VideoProviderCall::build(
        provider,
        credentials,
        catalog_model_id,
        vendor_config.as_ref(),
    )
    .map_err(|e| e.to_string())
}

#[allow(dead_code)] // reserved for callsites with preloaded config + credentials
pub fn build_video_provider_call_with_config(
    provider: VideoProvider,
    catalog_model_id: Option<&str>,
    vendor_config: Option<&VendorConfig>,
    credentials: Option<&VideoProviderCredentials>,
) -> Result<VideoProviderCall, String> {
    VideoProviderCall::build(provider, credentials, catalog_model_id, vendor_config)
        .map_err(|e| e.to_string())
}

pub use super::endpoint::resolve_video_api_base;

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn video_vendor_candidates_from_catalog_composite_id() {
        let ids =
            video_vendor_id_candidates(VideoProvider::Doubao, Some("20:doubao-seedance-1-0-pro"));
        assert!(ids.iter().any(|v| v == "20"));
        assert!(ids.iter().any(|v| v == "18"));
    }

    #[test]
    fn video_vendor_candidates_include_provider_defaults() {
        let ids = video_vendor_id_candidates(VideoProvider::Kling, None);
        assert!(ids.iter().any(|v| v == "4"));
    }

    #[test]
    fn video_vendor_candidates_hunyuan_video_vendor() {
        let ids = video_vendor_id_candidates(VideoProvider::Hunyuan, Some("21:hunyuan-video"));
        assert!(ids.iter().any(|v| v == "21"));
        assert!(ids.iter().any(|v| v == "19"));
    }
}
