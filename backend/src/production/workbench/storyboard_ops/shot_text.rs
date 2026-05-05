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

/// Timeline duration seconds aligned with ZIP export (**positive integer**, fallback **5**).
#[must_use]
pub(crate) fn parse_storyboard_duration_seconds(value: Option<&str>) -> i32 {
    value
        .and_then(|raw| raw.trim().parse::<i32>().ok())
        .filter(|duration| *duration > 0)
        .unwrap_or(5)
}

/// Export-check warning: absent/unparsable duration strings (exporter still defaults).
#[must_use]
pub(crate) fn export_duration_warning_code(raw: Option<&str>) -> Option<&'static str> {
    match raw.map(str::trim) {
        None | Some("") => Some("duration_not_explicit"),
        Some(s) => {
            if s.parse::<i32>().ok().filter(|d| *d > 0).is_some() {
                None
            } else {
                Some("duration_unparsable")
            }
        }
    }
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

    #[test]
    fn parse_storyboard_duration_seconds_handles_blank_and_positive() {
        assert_eq!(parse_storyboard_duration_seconds(None), 5);
        assert_eq!(parse_storyboard_duration_seconds(Some("")), 5);
        assert_eq!(parse_storyboard_duration_seconds(Some("12")), 12);
        assert_eq!(parse_storyboard_duration_seconds(Some("0")), 5);
    }

    #[test]
    fn export_duration_warning_codes() {
        assert_eq!(
            export_duration_warning_code(None),
            Some("duration_not_explicit")
        );
        assert_eq!(
            export_duration_warning_code(Some("")),
            Some("duration_not_explicit")
        );
        assert_eq!(export_duration_warning_code(Some("10")), None);
        assert_eq!(
            export_duration_warning_code(Some("oops")),
            Some("duration_unparsable")
        );
    }
}
