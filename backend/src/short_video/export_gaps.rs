//! Shared export-gap evaluation for **`GET …/short-video-export-check`** and **`GET …/short-video-assembly`**.

use uuid::Uuid;

/// Row fields required to evaluate per-shot export gaps (D1/D2 aligned).
#[derive(Debug, Clone)]
pub struct ExportGapRowInput {
    pub storyboard_id: Uuid,
    pub storyboard_numeric_id: i32,
    pub script_numeric_id: i32,
    pub sb_index: Option<i32>,
    pub file_path: Option<String>,
    pub duration: Option<String>,
    pub state: Option<String>,
    pub prompt: Option<String>,
    pub video_desc: Option<String>,
    pub voiceover_state: Option<String>,
    pub voiceover_audio_url: Option<String>,
    pub voiceover_error: Option<String>,
    pub candidate_status: Option<String>,
}

#[derive(Debug, Clone)]
pub struct ExportGapIssue {
    pub severity: &'static str,
    pub code: &'static str,
    pub detail: String,
}

/// Per-shot export gap facets (same semantics as **`storyboard_gaps`** on export-check).
#[derive(Debug, Clone, Default, serde::Serialize)]
pub struct ShotExportGapFacets {
    pub gap_codes: Vec<String>,
    pub has_blocking: bool,
    pub missing_selected_video: bool,
    pub missing_subtitle: bool,
    pub missing_voiceover: bool,
    pub duration_anomaly: bool,
}

#[must_use]
pub fn evaluate_export_gap_issues(row: &ExportGapRowInput) -> Vec<ExportGapIssue> {
    let mut out = Vec::new();
    let media_kind = assembly_selected_media_kind(row.file_path.as_deref());
    let subtitle_src = crate::production::resolve_shot_script_source(
        row.video_desc.as_deref(),
        row.prompt.as_deref(),
    );
    let vo_script_ready = crate::production::resolve_shot_voiceover_ready(
        row.video_desc.as_deref(),
        row.prompt.as_deref(),
    );
    let vo_asset_ready = row.voiceover_state.as_deref() == Some("completed")
        && row
            .voiceover_audio_url
            .as_deref()
            .is_some_and(|u| !u.trim().is_empty());

    if row.candidate_status.as_deref().map(str::trim) == Some("pending") {
        out.push(ExportGapIssue {
            severity: "blocking",
            code: "candidate_pending",
            detail: "Storyboard shortVideo.candidateStatus is pending; confirm before export."
                .into(),
        });
    }

    match media_kind {
        "none" => {
            out.push(ExportGapIssue {
                severity: "blocking",
                code: "missing_selected_media",
                detail: "No file_path / selected media for this storyboard.".into(),
            });
        }
        "video" => {}
        _ => {
            out.push(ExportGapIssue {
                severity: "blocking",
                code: "selected_media_not_video",
                detail: "Video export expects an mp4/mov/webm/mkv current selection; found image or other URL.".into(),
            });
        }
    }

    if subtitle_src == "placeholder" {
        out.push(ExportGapIssue {
            severity: "blocking",
            code: "subtitle_placeholder",
            detail: "No subtitle/narration text (video_desc empty and prompt empty).".into(),
        });
    }

    let vo_failed = row.voiceover_state.as_deref() == Some("failed")
        || row
            .voiceover_error
            .as_deref()
            .is_some_and(|e| !e.trim().is_empty());
    if vo_failed {
        out.push(ExportGapIssue {
            severity: "warning",
            code: "voiceover_failed",
            detail: "Voiceover pipeline reported failure or error metadata.".into(),
        });
    }

    if vo_script_ready && !vo_asset_ready && !vo_failed {
        out.push(ExportGapIssue {
            severity: "warning",
            code: "voiceover_audio_missing",
            detail: "Narration text exists but completed voiceover audio URL is absent.".into(),
        });
    }

    if let Some(code) = crate::production::export_duration_warning_code(row.duration.as_deref()) {
        let detail = match code {
            "duration_not_explicit" => {
                "Duration field empty; exporter defaults timeline to 5s.".to_string()
            }
            "duration_unparsable" => format!(
                "Duration {:?} is not a positive integer seconds value.",
                row.duration.as_deref().unwrap_or("")
            ),
            _ => "Duration anomaly.".to_string(),
        };
        out.push(ExportGapIssue {
            severity: "warning",
            code,
            detail,
        });
    }

    if media_kind == "video" {
        let st = row.state.as_deref().map(str::trim).unwrap_or("");
        if st != "已完成" {
            out.push(ExportGapIssue {
                severity: "warning",
                code: "completion_uncertain",
                detail: format!(
                    "Video selected but storyboard state is {:?}, not 已完成.",
                    row.state.as_deref().unwrap_or("")
                ),
            });
        }
    }

    out
}

#[must_use]
pub fn gap_facet_flags(codes: &[String]) -> (bool, bool, bool, bool) {
    let missing_selected_video = codes.iter().any(|c| {
        matches!(
            c.as_str(),
            "missing_selected_media" | "selected_media_not_video" | "candidate_pending"
        )
    });
    let missing_subtitle = codes
        .iter()
        .any(|c| matches!(c.as_str(), "subtitle_placeholder" | "subtitle_empty"));
    let missing_voiceover = codes.iter().any(|c| {
        matches!(
            c.as_str(),
            "voiceover_audio_missing" | "voiceover_failed" | "voiceover_not_ready"
        )
    });
    let duration_anomaly = codes.iter().any(|c| {
        matches!(
            c.as_str(),
            "duration_not_explicit" | "duration_unparsable" | "duration_not_set"
        )
    });
    (
        missing_selected_video,
        missing_subtitle,
        missing_voiceover,
        duration_anomaly,
    )
}

#[must_use]
pub fn shot_export_gap_facets(row: &ExportGapRowInput) -> ShotExportGapFacets {
    let issues = evaluate_export_gap_issues(row);
    let mut gap_codes = Vec::new();
    let mut has_blocking = false;
    for issue in &issues {
        if !gap_codes.iter().any(|c| c == issue.code) {
            gap_codes.push(issue.code.to_string());
        }
        if issue.severity == "blocking" {
            has_blocking = true;
        }
    }
    let (mv, ms, mvo, da) = gap_facet_flags(&gap_codes);
    ShotExportGapFacets {
        gap_codes,
        has_blocking,
        missing_selected_video: mv,
        missing_subtitle: ms,
        missing_voiceover: mvo,
        duration_anomaly: da,
    }
}

#[must_use]
fn assembly_selected_media_kind(url: Option<&str>) -> &'static str {
    let Some(raw) = url.map(str::trim).filter(|s| !s.is_empty()) else {
        return "none";
    };
    let path = raw
        .split('?')
        .next()
        .unwrap_or(raw)
        .split('#')
        .next()
        .unwrap_or(raw);
    let lower = path.to_ascii_lowercase();
    if lower.ends_with(".mp4")
        || lower.ends_with(".mov")
        || lower.ends_with(".webm")
        || lower.ends_with(".mkv")
    {
        return "video";
    }
    if lower.ends_with(".png")
        || lower.ends_with(".jpg")
        || lower.ends_with(".jpeg")
        || lower.ends_with(".webp")
    {
        return "image";
    }
    "other"
}

#[cfg(test)]
mod tests {
    use super::*;
    use uuid::Uuid;

    fn sample_row(
        file_path: Option<&str>,
        video_desc: Option<&str>,
        prompt: Option<&str>,
    ) -> ExportGapRowInput {
        ExportGapRowInput {
            storyboard_id: Uuid::nil(),
            storyboard_numeric_id: 1,
            script_numeric_id: 9,
            sb_index: Some(1),
            file_path: file_path.map(str::to_string),
            duration: Some("5".into()),
            state: Some("已完成".into()),
            prompt: prompt.map(str::to_string),
            video_desc: video_desc.map(str::to_string),
            voiceover_state: None,
            voiceover_audio_url: None,
            voiceover_error: None,
            candidate_status: None,
        }
    }

    #[test]
    fn facets_match_export_check_blocking_combo() {
        let facets = shot_export_gap_facets(&sample_row(None, None, None));
        assert!(facets.has_blocking);
        assert!(facets.missing_selected_video);
        assert!(facets.missing_subtitle);
        assert!(facets
            .gap_codes
            .contains(&"missing_selected_media".to_string()));
    }

    #[test]
    fn gap_facet_flags_aggregate_codes() {
        let codes = vec![
            "missing_selected_media".to_string(),
            "subtitle_placeholder".to_string(),
        ];
        let (mv, ms, mvo, da) = gap_facet_flags(&codes);
        assert!(mv);
        assert!(ms);
        assert!(!mvo);
        assert!(!da);
    }
}
