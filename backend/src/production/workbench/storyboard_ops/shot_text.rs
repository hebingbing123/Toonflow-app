//! Subtitle / voiceover script hints shared by ZIP export and **`GET …/short-video-assembly`** (D1).

/// Aligns with export manifest **`subtitle_source`**.
#[must_use]
pub(crate) fn resolve_shot_script_source(
    subtitle_text: Option<&str>,
    prompt: Option<&str>,
) -> &'static str {
    if subtitle_text
        .map(str::trim)
        .filter(|value| !value.is_empty())
        .is_some()
    {
        return "explicit_narration";
    }
    if prompt
        .map(str::trim)
        .filter(|value| !value.is_empty())
        .is_some()
    {
        return "prompt_fallback";
    }
    "placeholder"
}

/// Whether there is non-placeholder narration text for TTS / VO pipelines (export parity).
#[must_use]
pub(crate) fn resolve_shot_voiceover_ready(
    subtitle_text: Option<&str>,
    prompt: Option<&str>,
) -> bool {
    matches!(
        resolve_shot_script_source(subtitle_text, prompt),
        "explicit_narration" | "prompt_fallback"
    )
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn script_source_prefers_video_desc_then_prompt() {
        assert_eq!(
            resolve_shot_script_source(Some("  hello "), None),
            "explicit_narration"
        );
        assert_eq!(
            resolve_shot_script_source(None, Some("p")),
            "prompt_fallback"
        );
        assert_eq!(resolve_shot_script_source(None, None), "placeholder");
    }

    #[test]
    fn voiceover_ready_matches_non_placeholder_sources() {
        assert!(resolve_shot_voiceover_ready(Some("x"), None));
        assert!(resolve_shot_voiceover_ready(None, Some("y")));
        assert!(!resolve_shot_voiceover_ready(None, None));
    }
}
