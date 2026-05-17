//! Project-level vs per-job overrides for narration / export defaults (**D7**).

#[cfg_attr(not(test), allow(dead_code))]
pub(crate) const DEFAULT_TTS_VOICE: &str = crate::short_video::voice::config::DEFAULT_OPENAI_VOICE;
pub(crate) use crate::short_video::voice::{
    resolve_tts_voice_name, resolve_voice_config, VoiceResolveInput,
};

/// **`explicit_voice`** (per enqueue payload / UI) wins; then **`project_voice_profile`**; else default.
#[must_use]
pub(crate) fn resolve_tts_voice(
    explicit_voice: Option<&str>,
    project_voice_profile: Option<&str>,
) -> String {
    let cfg = resolve_voice_config(VoiceResolveInput {
        project_voice_profile,
        character_voice_config: None,
        explicit_voice,
        explicit_emotion: None,
        explicit_speed: None,
        explicit_provider: None,
        scene: Default::default(),
    });
    resolve_tts_voice_name(&cfg)
}

#[cfg(test)]
mod tests {
    use super::{resolve_tts_voice, DEFAULT_TTS_VOICE};

    #[test]
    fn explicit_trumps_project() {
        assert_eq!(
            resolve_tts_voice(Some("echo"), Some("alloy")),
            "echo".to_string()
        );
    }

    #[test]
    fn project_profile_used_when_explicit_blank() {
        assert_eq!(
            resolve_tts_voice(Some("   "), Some(" nova ")),
            "nova".to_string()
        );
    }

    #[test]
    fn falls_back_to_default_voice() {
        assert_eq!(resolve_tts_voice(None, None), DEFAULT_TTS_VOICE.to_string());
    }
}
