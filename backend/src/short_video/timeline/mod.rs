//! Persisted short-video timeline tracks (**NLE M1–M3**).

mod document;
pub mod revisions;
mod subtitle_style;
pub mod templates;
pub use templates::{apply_template, is_known_template};
mod validate;
pub mod waveform;

pub use document::{
    ProjectTimelineDocument, TimelineBgmTrack, TimelineSubtitleCue, TimelineTracks,
    TimelineTransition, TimelineTransitionType, TimelineVideoClip, TimelineVoiceoverClip,
    TIMELINE_SCHEMA_VERSION, TIMELINE_SCHEMA_VERSION_V1,
};
pub use revisions::{
    list_timeline_revisions, load_revision_document, upsert_timeline_with_revision,
};
pub use subtitle_style::burn_in_style_from_project;
pub use validate::{validate_schema_version, validate_tracks, MAX_CROSSFADE_MS};
pub use waveform::mock_waveform_peaks_for_voiceover;

use chrono::{DateTime, Utc};
use sqlx::PgPool;
use uuid::Uuid;

use crate::error::ApiError;
use crate::short_video::assembly_query::{assembly_selected_media_kind, AssemblyFlatRow};

#[derive(Debug, sqlx::FromRow)]
pub(crate) struct TimelineRow {
    pub(crate) schema_version: i32,
    pub(crate) timeline_json: serde_json::Value,
    pub(crate) updated_at: DateTime<Utc>,
    pub(crate) revision: i32,
}

pub(crate) async fn load_timeline_row(
    pool: &PgPool,
    project_id: Uuid,
) -> Result<Option<TimelineRow>, ApiError> {
    sqlx::query_as(
        r#"
        SELECT schema_version, timeline_json, updated_at, revision
        FROM app_project_timeline
        WHERE project_id = $1
        "#,
    )
    .bind(project_id)
    .fetch_optional(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))
}

pub(crate) fn parse_timeline_document(
    schema_version: i32,
    timeline_json: &serde_json::Value,
) -> ProjectTimelineDocument {
    if let Ok(mut doc) = serde_json::from_value::<ProjectTimelineDocument>(timeline_json.clone()) {
        normalize_document(&mut doc, schema_version);
        return doc;
    }
    ProjectTimelineDocument {
        schema_version: schema_version.max(TIMELINE_SCHEMA_VERSION_V1),
        tracks: TimelineTracks::default(),
    }
}

fn normalize_document(doc: &mut ProjectTimelineDocument, row_schema: i32) {
    doc.schema_version = doc.schema_version.max(row_schema);
    pad_transitions_for_video(&mut doc.tracks);
}

/// Ensure `transitions.len() == video.len().saturating_sub(1)` with cut defaults.
pub fn pad_transitions_for_video(tracks: &mut TimelineTracks) {
    let need = tracks.video.len().saturating_sub(1);
    if tracks.transitions.len() > need {
        tracks.transitions.truncate(need);
    }
    while tracks.transitions.len() < need {
        tracks.transitions.push(TimelineTransition {
            transition_type: TimelineTransitionType::Cut,
            duration_ms: 0,
        });
    }
}

/// Legacy upsert without revision history — prefer [`upsert_timeline_with_revision`].
#[allow(dead_code)]
pub(crate) async fn upsert_timeline_document(
    pool: &PgPool,
    project_id: Uuid,
    doc: &ProjectTimelineDocument,
    created_by: Uuid,
) -> Result<(DateTime<Utc>, i32), ApiError> {
    upsert_timeline_with_revision(pool, project_id, doc, created_by, None).await
}

#[must_use]
pub fn default_out_ms_from_duration(duration: Option<&str>) -> i64 {
    i64::from(parse_duration_seconds(duration)) * 1000
}

#[must_use]
pub fn parse_duration_seconds(raw: Option<&str>) -> i32 {
    let Some(text) = raw.map(str::trim).filter(|s| !s.is_empty()) else {
        return 5;
    };
    let digits: String = text.chars().filter(|c| c.is_ascii_digit()).collect();
    digits.parse::<i32>().ok().filter(|v| *v > 0).unwrap_or(5)
}

#[must_use]
pub fn default_tracks_from_assembly(
    rows: &[AssemblyFlatRow],
    bgm_strategy: Option<&str>,
) -> TimelineTracks {
    let mut video = Vec::new();
    for row in rows {
        let Some(url) = row
            .file_path
            .as_deref()
            .map(str::trim)
            .filter(|s| !s.is_empty())
        else {
            continue;
        };
        if assembly_selected_media_kind(Some(url)) != "video" {
            continue;
        }
        let out_ms = default_out_ms_from_duration(row.duration.as_deref());
        video.push(TimelineVideoClip {
            storyboard_numeric_id: row.storyboard_numeric_id,
            source_url: url.to_string(),
            in_ms: 0,
            out_ms,
            effect_preset_id: None,
        });
    }
    let bgm = bgm_strategy
        .map(|s| s.trim())
        .filter(|s| !s.is_empty())
        .map(|strategy| TimelineBgmTrack {
            enabled: false,
            asset_url: None,
            bgm_strategy: Some(strategy.to_string()),
            volume: 0.35,
        });
    let mut tracks = TimelineTracks {
        video,
        bgm,
        ..TimelineTracks::default()
    };
    pad_transitions_for_video(&mut tracks);
    tracks
}

#[must_use]
pub fn merge_tracks(
    defaults: TimelineTracks,
    persisted: &ProjectTimelineDocument,
) -> TimelineTracks {
    let mut by_id: std::collections::HashMap<i32, TimelineVideoClip> = defaults
        .video
        .into_iter()
        .map(|c| (c.storyboard_numeric_id, c))
        .collect();
    for clip in &persisted.tracks.video {
        if let Some(slot) = by_id.get_mut(&clip.storyboard_numeric_id) {
            slot.in_ms = clip.in_ms.max(0);
            slot.out_ms = clip.out_ms.max(slot.in_ms);
            if !clip.source_url.trim().is_empty() {
                slot.source_url = clip.source_url.clone();
            }
            if clip.effect_preset_id.is_some() {
                slot.effect_preset_id = clip.effect_preset_id.clone();
            }
        } else if !clip.source_url.trim().is_empty() && clip.out_ms > clip.in_ms {
            by_id.insert(clip.storyboard_numeric_id, clip.clone());
        }
    }
    let mut video: Vec<TimelineVideoClip> = by_id.into_values().collect();
    video.sort_by_key(|c| c.storyboard_numeric_id);

    let bgm = persisted.tracks.bgm.clone().or(defaults.bgm);
    let subtitles = if persisted.tracks.subtitles.is_empty() {
        defaults.subtitles
    } else {
        persisted.tracks.subtitles.clone()
    };
    let transitions = if persisted.tracks.transitions.is_empty() {
        defaults.transitions
    } else {
        persisted.tracks.transitions.clone()
    };
    let voiceover = if persisted.tracks.voiceover.is_empty() {
        defaults.voiceover
    } else {
        persisted.tracks.voiceover.clone()
    };
    let template_id = persisted
        .tracks
        .template_id
        .clone()
        .or(defaults.template_id);

    let mut tracks = TimelineTracks {
        video,
        bgm,
        subtitles,
        transitions,
        voiceover,
        template_id,
    };
    pad_transitions_for_video(&mut tracks);
    tracks
}

#[must_use]
pub fn clip_for_storyboard(
    tracks: &TimelineTracks,
    storyboard_numeric_id: i32,
) -> Option<&TimelineVideoClip> {
    tracks
        .video
        .iter()
        .find(|c| c.storyboard_numeric_id == storyboard_numeric_id)
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::short_video::timeline::document::TIMELINE_SCHEMA_VERSION_V3;
    use uuid::Uuid;

    fn sample_row(numeric_id: i32, url: Option<&str>, duration: Option<&str>) -> AssemblyFlatRow {
        AssemblyFlatRow {
            storyboard_id: Uuid::nil(),
            storyboard_numeric_id: numeric_id,
            script_numeric_id: 1,
            script_name: None,
            sb_index: Some(numeric_id),
            file_path: url.map(str::to_string),
            duration: duration.map(str::to_string),
            state: None,
            track_id: None,
            prompt: None,
            video_desc: None,
            voiceover_state: None,
            voiceover_audio_url: None,
            voiceover_error: None,
            candidate_status: None,
        }
    }

    #[test]
    fn timeline_json_roundtrip_v3() {
        let doc = ProjectTimelineDocument {
            schema_version: TIMELINE_SCHEMA_VERSION_V3,
            tracks: TimelineTracks {
                video: vec![TimelineVideoClip {
                    storyboard_numeric_id: 7,
                    source_url: "https://example.com/a.mp4".into(),
                    in_ms: 100,
                    out_ms: 4500,
                    effect_preset_id: Some("vivid".into()),
                }],
                bgm: Some(TimelineBgmTrack {
                    enabled: true,
                    asset_url: None,
                    bgm_strategy: Some("calm".into()),
                    volume: 0.5,
                }),
                subtitles: vec![TimelineSubtitleCue {
                    storyboard_numeric_id: Some(7),
                    start_ms: 0,
                    end_ms: 4400,
                    text: "hello".into(),
                    style_id: None,
                }],
                transitions: vec![],
                voiceover: vec![],
                template_id: None,
            },
        };
        let json = serde_json::to_value(&doc).expect("serialize");
        let back: ProjectTimelineDocument = serde_json::from_value(json).expect("deserialize");
        assert_eq!(doc, back);
    }

    #[test]
    fn merge_persisted_trim_overrides_default() {
        let defaults = default_tracks_from_assembly(
            &[sample_row(1, Some("https://x/v.mp4"), Some("8s"))],
            Some("upbeat"),
        );
        assert_eq!(defaults.video[0].out_ms, 8000);
        let persisted = ProjectTimelineDocument {
            schema_version: 1,
            tracks: TimelineTracks {
                video: vec![TimelineVideoClip {
                    storyboard_numeric_id: 1,
                    source_url: "https://x/v.mp4".into(),
                    in_ms: 500,
                    out_ms: 3000,
                    effect_preset_id: None,
                }],
                bgm: None,
                ..TimelineTracks::default()
            },
        };
        let merged = merge_tracks(defaults, &persisted);
        assert_eq!(merged.video[0].in_ms, 500);
        assert_eq!(merged.video[0].out_ms, 3000);
    }

    #[test]
    fn pad_transitions_inserts_cuts() {
        let mut tracks = TimelineTracks {
            video: vec![
                TimelineVideoClip {
                    storyboard_numeric_id: 1,
                    source_url: "a".into(),
                    in_ms: 0,
                    out_ms: 1000,
                    effect_preset_id: None,
                },
                TimelineVideoClip {
                    storyboard_numeric_id: 2,
                    source_url: "b".into(),
                    in_ms: 0,
                    out_ms: 1000,
                    effect_preset_id: None,
                },
            ],
            ..TimelineTracks::default()
        };
        pad_transitions_for_video(&mut tracks);
        assert_eq!(tracks.transitions.len(), 1);
        assert_eq!(
            tracks.transitions[0].transition_type,
            TimelineTransitionType::Cut
        );
    }
}
