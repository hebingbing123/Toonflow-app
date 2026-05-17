//! Swappable voice-clone providers (mock default; Azure/ElevenLabs stubs).

mod azure;
mod mock;
mod store;

pub use azure::AzureVoiceCloneProvider;
pub use mock::MockVoiceCloneProvider;
pub use store::{append_cloned_voice, mock_openai_voice_for_clone_id};

use std::sync::Arc;

use crate::error::ApiError;

#[derive(Debug, Clone)]
pub struct ClonedVoiceRef {
    pub custom_voice_id: String,
    pub provider: String,
    pub display_name: String,
    pub locale: Option<String>,
}

pub trait VoiceCloneProvider: Send + Sync {
    fn provider_name(&self) -> &'static str;

    fn clone_sample(
        &self,
        audio_bytes: &[u8],
        display_name: &str,
        locale: Option<&str>,
    ) -> Result<ClonedVoiceRef, ApiError>;
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum VoiceCloneProviderKind {
    Mock,
    Azure,
    ElevenLabs,
}

impl VoiceCloneProviderKind {
    pub fn from_env() -> Self {
        match std::env::var("TOONFLOW_VOICE_CLONE_PROVIDER")
            .unwrap_or_else(|_| "mock".into())
            .trim()
            .to_ascii_lowercase()
            .as_str()
        {
            "azure" | "microsoft" => Self::Azure,
            "elevenlabs" | "11labs" => Self::ElevenLabs,
            _ => Self::Mock,
        }
    }
}

pub fn voice_clone_provider_from_env() -> Arc<dyn VoiceCloneProvider> {
    match VoiceCloneProviderKind::from_env() {
        VoiceCloneProviderKind::Mock => Arc::new(MockVoiceCloneProvider),
        VoiceCloneProviderKind::Azure => Arc::new(AzureVoiceCloneProvider),
        VoiceCloneProviderKind::ElevenLabs => Arc::new(AzureVoiceCloneProvider),
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn mock_provider_is_deterministic() {
        let p = MockVoiceCloneProvider;
        let a = p
            .clone_sample(b"wav", "Hero", Some("zh-CN"))
            .expect("clone");
        let b = p
            .clone_sample(b"wav", "Hero", Some("zh-CN"))
            .expect("clone");
        assert_eq!(a.custom_voice_id, b.custom_voice_id);
        assert!(a.custom_voice_id.starts_with("mock-"));
    }
}
