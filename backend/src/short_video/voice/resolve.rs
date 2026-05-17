//! Resolve effective voice synthesis plan from project / character / request overrides.

use super::config::{
    merge_voice_config, parse_voice_json_value, parse_voice_profile, VoiceProfileConfig,
};
use super::emotion::VoiceEmotion;
use super::scene::SceneVoiceContext;

#[derive(Debug, Clone)]
pub struct VoiceResolveInput<'a> {
    pub project_voice_profile: Option<&'a str>,
    pub character_voice_config: Option<&'a serde_json::Value>,
    pub explicit_voice: Option<&'a str>,
    pub explicit_emotion: Option<&'a str>,
    pub explicit_speed: Option<f32>,
    pub explicit_provider: Option<&'a str>,
    pub scene: SceneVoiceContext,
}

pub fn resolve_voice_config(input: VoiceResolveInput<'_>) -> VoiceProfileConfig {
    let project_cfg = parse_voice_profile(input.project_voice_profile);
    let character_cfg = input.character_voice_config.map(parse_voice_json_value);
    let mut cfg = merge_voice_config(
        project_cfg,
        character_cfg,
        input.explicit_voice,
        input.explicit_emotion,
        input.explicit_speed,
        input.explicit_provider,
    );
    if cfg.emotion.is_none() {
        let inferred = input.scene.infer_emotion();
        if inferred != VoiceEmotion::Neutral {
            cfg.emotion = Some(inferred.as_id().to_string());
            if cfg.style.is_none() {
                cfg.style = inferred.azure_style().map(str::to_string);
            }
        }
    }
    cfg
}

/// Legacy helper: OpenAI-compatible voice name string.
pub fn resolve_tts_voice_name(cfg: &VoiceProfileConfig) -> String {
    cfg.voice.clone()
}
