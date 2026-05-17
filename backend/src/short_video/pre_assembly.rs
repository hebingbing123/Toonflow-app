//! Rough-cut / batch pre-assembly manifest builder (**MP-W6**).

use serde::Serialize;
use uuid::Uuid;

use super::export_gaps::{shot_export_gap_facets, ExportGapRowInput};
use crate::production::{resolve_shot_script_source, resolve_shot_voiceover_ready};

#[derive(Debug, Serialize)]
pub struct PreAssemblyProjectDefaults {
    pub voice_profile: Option<String>,
    pub subtitle_style: Option<String>,
    pub bgm_strategy: Option<String>,
    pub tts_voice: String,
}

#[derive(Debug, Serialize)]
pub struct PreAssemblyManifestShot {
    pub order_index: usize,
    pub script_numeric_id: i32,
    pub storyboard_id: Uuid,
    pub storyboard_numeric_id: i32,
    pub sb_index: Option<i32>,
    pub selected_media_url: Option<String>,
    pub selected_media_kind: String,
    pub duration_seconds: i32,
    pub subtitle_text: Option<String>,
    pub subtitle_source: String,
    pub voiceover_audio_url: Option<String>,
    pub voiceover_script_ready: bool,
    pub voiceover_asset_ready: bool,
    pub gap_codes: Vec<String>,
    pub has_blocking_gap: bool,
    pub placeholder_video: bool,
    pub placeholder_voiceover: bool,
}

#[derive(Debug, Serialize)]
pub struct PreAssemblyManifest {
    pub schema_version: i32,
    pub export_type: &'static str,
    pub project_uuid: Uuid,
    pub shot_count: usize,
    pub blocking_shot_count: usize,
    pub ready_video_count: usize,
    pub ready_voiceover_count: usize,
    pub total_duration_seconds: i64,
    pub project_defaults: PreAssemblyProjectDefaults,
    pub shots: Vec<PreAssemblyManifestShot>,
}

pub struct PreAssemblyBuildInput<'a> {
    pub project_uuid: Uuid,
    pub voice_profile: Option<&'a str>,
    pub subtitle_style: Option<&'a str>,
    pub bgm_strategy: Option<&'a str>,
    pub tts_voice: String,
    pub rows: &'a [ExportGapRowInput],
}

#[must_use]
pub fn build_pre_assembly_manifest(input: PreAssemblyBuildInput<'_>) -> PreAssemblyManifest {
    let mut shots = Vec::with_capacity(input.rows.len());
    let mut blocking_shot_count = 0_usize;
    let mut ready_video_count = 0_usize;
    let mut ready_voiceover_count = 0_usize;
    let mut total_duration_seconds = 0_i64;

    for (order_index, row) in input.rows.iter().enumerate() {
        let gap = shot_export_gap_facets(row);
        let gap_codes = gap.gap_codes;
        let has_blocking_gap = gap.has_blocking;
        if has_blocking_gap {
            blocking_shot_count += 1;
        }

        let media_url = row
            .file_path
            .as_deref()
            .map(str::trim)
            .filter(|s| !s.is_empty())
            .map(str::to_string);
        let media_kind = media_kind_label(media_url.as_deref());
        let placeholder_video = media_kind != "video";
        if !placeholder_video {
            ready_video_count += 1;
        }

        let voiceover_asset_ready = row.voiceover_state.as_deref() == Some("completed")
            && row
                .voiceover_audio_url
                .as_deref()
                .is_some_and(|u| !u.trim().is_empty());
        let placeholder_voiceover = !voiceover_asset_ready;
        if voiceover_asset_ready {
            ready_voiceover_count += 1;
        }

        let duration_seconds = parse_duration_seconds(row.duration.as_deref());
        total_duration_seconds += i64::from(duration_seconds);

        let subtitle_source =
            resolve_shot_script_source(row.video_desc.as_deref(), row.prompt.as_deref())
                .to_string();
        let voiceover_script_ready =
            resolve_shot_voiceover_ready(row.video_desc.as_deref(), row.prompt.as_deref());

        shots.push(PreAssemblyManifestShot {
            order_index,
            script_numeric_id: row.script_numeric_id,
            storyboard_id: row.storyboard_id,
            storyboard_numeric_id: row.storyboard_numeric_id,
            sb_index: row.sb_index,
            selected_media_url: media_url,
            selected_media_kind: media_kind.to_string(),
            duration_seconds,
            subtitle_text: row.video_desc.clone(),
            subtitle_source,
            voiceover_audio_url: row.voiceover_audio_url.clone(),
            voiceover_script_ready,
            voiceover_asset_ready,
            gap_codes,
            has_blocking_gap,
            placeholder_video,
            placeholder_voiceover,
        });
    }

    PreAssemblyManifest {
        schema_version: 1,
        export_type: "short_video_pre_assembly",
        project_uuid: input.project_uuid,
        shot_count: shots.len(),
        blocking_shot_count,
        ready_video_count,
        ready_voiceover_count,
        total_duration_seconds,
        project_defaults: PreAssemblyProjectDefaults {
            voice_profile: input.voice_profile.map(str::to_string),
            subtitle_style: input.subtitle_style.map(str::to_string),
            bgm_strategy: input.bgm_strategy.map(str::to_string),
            tts_voice: input.tts_voice,
        },
        shots,
    }
}

fn media_kind_label(url: Option<&str>) -> &'static str {
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
        "video"
    } else if lower.ends_with(".png")
        || lower.ends_with(".jpg")
        || lower.ends_with(".jpeg")
        || lower.ends_with(".webp")
    {
        "image"
    } else {
        "other"
    }
}

fn parse_duration_seconds(raw: Option<&str>) -> i32 {
    let Some(text) = raw.map(str::trim).filter(|s| !s.is_empty()) else {
        return 5;
    };
    let digits: String = text.chars().filter(|c| c.is_ascii_digit()).collect();
    digits.parse::<i32>().ok().filter(|v| *v > 0).unwrap_or(5)
}

#[cfg(test)]
mod tests {
    use super::*;
    use uuid::Uuid;

    #[test]
    fn manifest_counts_blocking_and_placeholders() {
        let rows = vec![ExportGapRowInput {
            storyboard_id: Uuid::nil(),
            storyboard_numeric_id: 1,
            script_numeric_id: 1,
            sb_index: Some(0),
            file_path: None,
            duration: None,
            state: None,
            prompt: None,
            video_desc: None,
            voiceover_state: None,
            voiceover_audio_url: None,
            voiceover_error: None,
            candidate_status: None,
        }];
        let manifest = build_pre_assembly_manifest(PreAssemblyBuildInput {
            project_uuid: Uuid::nil(),
            voice_profile: None,
            subtitle_style: None,
            bgm_strategy: None,
            tts_voice: "alloy".into(),
            rows: &rows,
        });
        assert_eq!(manifest.shot_count, 1);
        assert_eq!(manifest.blocking_shot_count, 1);
        assert!(manifest.shots[0].placeholder_video);
        assert!(manifest.shots[0].placeholder_voiceover);
    }
}
