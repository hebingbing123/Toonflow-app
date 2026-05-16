//! Project-level vs per-job overrides for narration / export defaults (**D7**).

/// OpenAI-compatible speech **`voice`** when neither explicit nor project profile is set.
pub(crate) const DEFAULT_TTS_VOICE: &str = "alloy";

/// **`explicit_voice`** (per enqueue payload / UI) wins; then **`project_voice_profile`**; else [`DEFAULT_TTS_VOICE`].
#[must_use]
pub(crate) fn resolve_tts_voice(
    explicit_voice: Option<&str>,
    project_voice_profile: Option<&str>,
) -> String {
    if let Some(v) = explicit_voice.map(str::trim).filter(|s| !s.is_empty()) {
        return v.to_string();
    }
    if let Some(v) = project_voice_profile
        .map(str::trim)
        .filter(|s| !s.is_empty())
    {
        return v.to_string();
    }
    DEFAULT_TTS_VOICE.to_string()
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
