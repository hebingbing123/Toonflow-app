//! Deterministic mock voice cloning for local / CI.

use sha2::{Digest, Sha256};

use super::{ClonedVoiceRef, VoiceCloneProvider};
use crate::error::{bad_request_i18n, ApiError};

pub struct MockVoiceCloneProvider;

impl MockVoiceCloneProvider {
    fn deterministic_id(audio_bytes: &[u8], display_name: &str, locale: Option<&str>) -> String {
        let mut hasher = Sha256::new();
        hasher.update(audio_bytes);
        hasher.update(display_name.as_bytes());
        if let Some(loc) = locale {
            hasher.update(loc.as_bytes());
        }
        let digest = hasher.finalize();
        format!("mock-{}", hex::encode(&digest[..8]))
    }
}

impl VoiceCloneProvider for MockVoiceCloneProvider {
    fn provider_name(&self) -> &'static str {
        "mock"
    }

    fn clone_sample(
        &self,
        audio_bytes: &[u8],
        display_name: &str,
        locale: Option<&str>,
    ) -> Result<ClonedVoiceRef, ApiError> {
        if audio_bytes.is_empty() {
            return Err(bad_request_i18n("audio sample is empty", "音频样本为空"));
        }
        if display_name.trim().is_empty() {
            return Err(bad_request_i18n(
                "displayName is required",
                "displayName 为必填项",
            ));
        }
        Ok(ClonedVoiceRef {
            custom_voice_id: Self::deterministic_id(audio_bytes, display_name.trim(), locale),
            provider: self.provider_name().to_string(),
            display_name: display_name.trim().to_string(),
            locale: locale
                .map(str::trim)
                .filter(|s| !s.is_empty())
                .map(str::to_string),
        })
    }
}
