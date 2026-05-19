//! Azure / third-party voice clone stub — real HTTP when credentials exist.

use super::{ClonedVoiceRef, VoiceCloneProvider};
use crate::error::ApiError;
use crate::llm::azure::load_azure_credentials_from_env;

pub struct AzureVoiceCloneProvider;

impl VoiceCloneProvider for AzureVoiceCloneProvider {
    fn provider_name(&self) -> &'static str {
        "azure"
    }

    fn clone_sample(
        &self,
        _audio_bytes: &[u8],
        _display_name: &str,
        _locale: Option<&str>,
    ) -> Result<ClonedVoiceRef, ApiError> {
        if load_azure_credentials_from_env().is_none() {
            return Err(ApiError::BadRequestI18n {
                en: "Voice clone provider azure is not configured (set AZURE_SPEECH_KEY and AZURE_SPEECH_REGION)".into(),
                zh: "Azure 声音克隆未配置（请设置 AZURE_SPEECH_KEY 与 AZURE_SPEECH_REGION）".into(),
            });
        }
        Err(ApiError::NotImplementedI18n {
            en: "Azure custom neural voice cloning is not wired yet; use OPENFLOW_VOICE_CLONE_PROVIDER=mock".into(),
            zh: "Azure 自定义神经语音克隆尚未对接；请使用 OPENFLOW_VOICE_CLONE_PROVIDER=mock".into(),
        })
    }
}
