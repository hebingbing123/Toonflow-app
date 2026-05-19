//! Dispatch TTS synthesis to OpenAI-compatible or Azure SSML backends.

use reqwest::Client;

use crate::llm::azure::{
    azure_speech_bytes, load_azure_credentials_from_env, AzureSpeechCredentials,
};
use crate::llm::openai::{audio_speech_bytes, LlmConfig};

use super::config::{VoiceProfileConfig, VoiceProvider};
use super::emotion::VoiceEmotion;
use super::ssml::build_azure_ssml;

pub struct SynthesisResult {
    pub audio: Vec<u8>,
    pub provider: VoiceProvider,
    pub model: String,
}

pub async fn synthesize_speech(
    openai_cfg: &LlmConfig,
    client: &Client,
    text: &str,
    cfg: &VoiceProfileConfig,
    azure_creds: Option<&AzureSpeechCredentials>,
) -> Result<SynthesisResult, String> {
    let mut effective = cfg.clone();
    if let Some(clone_id) = cfg
        .clone_voice_id
        .as_deref()
        .map(str::trim)
        .filter(|s| !s.is_empty())
    {
        let mock_clone = clone_id.starts_with("mock-")
            || std::env::var("OPENFLOW_VOICE_CLONE_PROVIDER")
                .unwrap_or_else(|_| "mock".into())
                .trim()
                .eq_ignore_ascii_case("mock");
        if mock_clone {
            effective.provider = VoiceProvider::Openai;
            effective.voice = super::clone::mock_openai_voice_for_clone_id(clone_id).to_string();
        } else {
            return Err(
                "voice clone provider is not configured for synthesis; set OPENFLOW_VOICE_CLONE_PROVIDER=mock or use preset voices"
                    .into(),
            );
        }
    }

    match effective.provider {
        VoiceProvider::Azure => {
            let creds = azure_creds
                .cloned()
                .or_else(load_azure_credentials_from_env)
                .ok_or_else(|| {
                    "Azure TTS requires AZURE_SPEECH_KEY and AZURE_SPEECH_REGION (or vendor credentials)"
                        .to_string()
                })?;
            let ssml = build_azure_ssml(text, &effective);
            let audio =
                azure_speech_bytes(client, &creds, &ssml, "audio-16khz-128kbitrate-mono-mp3")
                    .await?;
            Ok(SynthesisResult {
                audio,
                provider: VoiceProvider::Azure,
                model: "azure-neural".into(),
            })
        }
        VoiceProvider::Openai => {
            let emotion = effective
                .emotion
                .as_deref()
                .map(VoiceEmotion::parse)
                .unwrap_or(VoiceEmotion::Neutral);
            let base_speed = effective.speed.unwrap_or(1.0);
            let speed = (base_speed * emotion.openai_speed_multiplier()).clamp(0.25, 4.0);
            let audio =
                audio_speech_bytes(openai_cfg, client, text, &effective.voice, speed, "mp3")
                    .await?;
            Ok(SynthesisResult {
                audio,
                provider: VoiceProvider::Openai,
                model: openai_cfg.model.clone(),
            })
        }
    }
}
