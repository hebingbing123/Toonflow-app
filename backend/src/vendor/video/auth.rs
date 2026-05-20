//! Resolve per-provider credentials (Bearer, Kling JWT, Tencent TC3).

use crate::vendor::kling_jwt::kling_bearer_token;
use crate::vendor::tencent_tc3::TencentTc3Config;

use super::endpoint::VideoApiRouting;
use super::VideoProvider;

/// User or env credentials for a single video job.
#[derive(Debug, Clone)]
pub struct VideoProviderCredentials {
    pub api_key: Option<String>,
    pub api_secret: Option<String>,
}

impl VideoProviderCredentials {
    pub fn from_key_only(key: impl Into<String>) -> Self {
        Self {
            api_key: Some(key.into()),
            api_secret: None,
        }
    }
}

/// Resolved auth material passed into provider HTTP calls.
#[derive(Debug, Clone)]
pub enum VideoProviderAuth {
    Bearer(String),
    TencentTc3(TencentTc3Config),
}

impl VideoProviderAuth {
    pub(crate) fn bearer_token(&self) -> anyhow::Result<&str> {
        match self {
            Self::Bearer(t) => Ok(t.as_str()),
            Self::TencentTc3(_) => Err(anyhow::anyhow!("expected Bearer auth")),
        }
    }

    pub(crate) fn tencent_tc3(&self) -> anyhow::Result<&TencentTc3Config> {
        match self {
            Self::TencentTc3(c) => Ok(c),
            Self::Bearer(_) => Err(anyhow::anyhow!("expected Tencent TC3 auth")),
        }
    }
}

pub fn resolve_video_auth(
    provider: VideoProvider,
    creds: Option<&VideoProviderCredentials>,
    api_base: &str,
    routing: VideoApiRouting,
) -> anyhow::Result<VideoProviderAuth> {
    if routing == VideoApiRouting::OpenAiCompatible {
        return resolve_bearer(provider, creds);
    }
    match provider {
        VideoProvider::Hunyuan => resolve_hunyuan_tc3(creds, api_base),
        VideoProvider::Kling => resolve_kling_bearer(creds),
        _ => resolve_bearer(provider, creds),
    }
}

fn resolve_bearer(
    provider: VideoProvider,
    creds: Option<&VideoProviderCredentials>,
) -> anyhow::Result<VideoProviderAuth> {
    if let Some(key) = creds
        .and_then(|c| c.api_key.as_deref())
        .map(str::trim)
        .filter(|s| !s.is_empty())
    {
        return Ok(VideoProviderAuth::Bearer(key.to_string()));
    }
    let env_key = match provider {
        VideoProvider::Pika => std::env::var("FAL_KEY")
            .ok()
            .filter(|s| !s.trim().is_empty())
            .or_else(|| std::env::var(provider.api_key_env_var()).ok()),
        _ => std::env::var(provider.api_key_env_var()).ok(),
    }
    .filter(|s| !s.trim().is_empty())
    .ok_or_else(|| {
        anyhow::anyhow!(
            "{} API key not configured (Settings credential or {})",
            provider.name(),
            provider.api_key_env_var()
        )
    })?;
    Ok(VideoProviderAuth::Bearer(env_key))
}

fn resolve_kling_bearer(
    creds: Option<&VideoProviderCredentials>,
) -> anyhow::Result<VideoProviderAuth> {
    let (ak, sk) = kling_access_secret_pair(creds)?;
    let token = kling_bearer_token(&ak, &sk).map_err(anyhow::Error::msg)?;
    Ok(VideoProviderAuth::Bearer(token))
}

fn kling_access_secret_pair(
    creds: Option<&VideoProviderCredentials>,
) -> anyhow::Result<(String, String)> {
    if let Some(c) = creds {
        if let (Some(ak), Some(sk)) = (
            c.api_key
                .as_deref()
                .map(str::trim)
                .filter(|s| !s.is_empty()),
            c.api_secret
                .as_deref()
                .map(str::trim)
                .filter(|s| !s.is_empty()),
        ) {
            return Ok((ak.to_string(), sk.to_string()));
        }
    }
    let ak = std::env::var("KLING_ACCESS_KEY")
        .ok()
        .filter(|s| !s.trim().is_empty())
        .or_else(|| std::env::var("KLING_API_KEY").ok())
        .filter(|s| !s.trim().is_empty());
    let sk = std::env::var("KLING_SECRET_KEY")
        .ok()
        .filter(|s| !s.trim().is_empty());
    match (ak, sk) {
        (Some(ak), Some(sk)) => Ok((ak, sk)),
        _ => Err(anyhow::anyhow!(
            "Kling requires Access Key + Secret Key in Settings (API Key + API Secret) or KLING_ACCESS_KEY + KLING_SECRET_KEY"
        )),
    }
}

fn resolve_hunyuan_tc3(
    creds: Option<&VideoProviderCredentials>,
    api_base: &str,
) -> anyhow::Result<VideoProviderAuth> {
    let (id, key) = hunyuan_secret_pair(creds)?;
    Ok(VideoProviderAuth::TencentTc3(
        TencentTc3Config::from_keys_and_base(&id, &key, api_base),
    ))
}

fn hunyuan_secret_pair(
    creds: Option<&VideoProviderCredentials>,
) -> anyhow::Result<(String, String)> {
    if let Some(c) = creds {
        if let (Some(id), Some(key)) = (
            c.api_key
                .as_deref()
                .map(str::trim)
                .filter(|s| !s.is_empty()),
            c.api_secret
                .as_deref()
                .map(str::trim)
                .filter(|s| !s.is_empty()),
        ) {
            return Ok((id.to_string(), key.to_string()));
        }
    }
    let id = std::env::var("TENCENT_SECRET_ID")
        .ok()
        .filter(|s| !s.trim().is_empty())
        .or_else(|| std::env::var("HUNYUAN_SECRET_ID").ok())
        .filter(|s| !s.trim().is_empty());
    let key = std::env::var("TENCENT_SECRET_KEY")
        .ok()
        .filter(|s| !s.trim().is_empty())
        .or_else(|| std::env::var("HUNYUAN_SECRET_KEY").ok())
        .filter(|s| !s.trim().is_empty());
    match (id, key) {
        (Some(id), Some(key)) => Ok((id, key)),
        _ => Err(anyhow::anyhow!(
            "Hunyuan video requires Tencent SecretId + SecretKey in Settings or TENCENT_SECRET_ID + TENCENT_SECRET_KEY"
        )),
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn resolve_bearer_from_override() {
        let creds = VideoProviderCredentials::from_key_only("user-key");
        let auth = resolve_video_auth(
            VideoProvider::Doubao,
            Some(&creds),
            "https://ark.cn-beijing.volces.com",
            VideoApiRouting::NativeVendor,
        )
        .unwrap();
        match auth {
            VideoProviderAuth::Bearer(k) => assert_eq!(k, "user-key"),
            _ => panic!("expected bearer"),
        }
    }

    #[test]
    fn kling_jwt_from_stored_pair() {
        let creds = VideoProviderCredentials {
            api_key: Some("ak_x".into()),
            api_secret: Some("sk_y".into()),
        };
        let auth = resolve_video_auth(
            VideoProvider::Kling,
            Some(&creds),
            "https://api.klingai.com",
            VideoApiRouting::NativeVendor,
        )
        .unwrap();
        match auth {
            VideoProviderAuth::Bearer(t) => assert_eq!(t.matches('.').count(), 2),
            _ => panic!("expected jwt bearer"),
        }
    }
}
