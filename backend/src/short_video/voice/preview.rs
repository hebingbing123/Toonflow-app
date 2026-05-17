//! Synchronous short TTS preview (F.2).

use crate::llm::openai::LlmConfig;
use crate::state::AppState;

use super::resolve::{resolve_voice_config, VoiceResolveInput};
use super::scene::SceneVoiceContext;
use super::synthesize::synthesize_speech;

const MAX_PREVIEW_CHARS: usize = 400;

pub struct VoicePreviewInput<'a> {
    pub project_voice_profile: Option<&'a str>,
    pub character_voice_config: Option<&'a serde_json::Value>,
    pub text: &'a str,
    pub explicit_voice: Option<&'a str>,
    pub explicit_emotion: Option<&'a str>,
    pub explicit_speed: Option<f32>,
    pub explicit_provider: Option<&'a str>,
}

pub async fn run_voice_preview(
    state: &AppState,
    openai_cfg: &LlmConfig,
    input: VoicePreviewInput<'_>,
) -> Result<Vec<u8>, String> {
    let trimmed = input.text.trim();
    if trimmed.is_empty() {
        return Err("text is required".into());
    }
    if trimmed.chars().count() > MAX_PREVIEW_CHARS {
        return Err(format!(
            "preview text exceeds {MAX_PREVIEW_CHARS} characters"
        ));
    }
    let cfg = resolve_voice_config(VoiceResolveInput {
        project_voice_profile: input.project_voice_profile,
        character_voice_config: input.character_voice_config,
        explicit_voice: input.explicit_voice,
        explicit_emotion: input.explicit_emotion,
        explicit_speed: input.explicit_speed,
        explicit_provider: input.explicit_provider,
        scene: SceneVoiceContext::default(),
    });
    let result = synthesize_speech(openai_cfg, &state.http_client, trimmed, &cfg, None).await?;
    Ok(result.audio)
}
