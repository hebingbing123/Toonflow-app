use sqlx::PgPool;

use super::types::{
    ProductionStoryboardItem, StoryboardLastWritebackSummary, StoryboardMediaSlotsSummary,
};
use crate::short_video::candidate_videos::{
    fetch_storyboard_candidate_job_video_urls, merge_candidate_video_urls,
    parse_candidate_urls_from_metadata,
};

const CANDIDATE_VIDEO_SOURCES_HINT: &str =
    "workbench.getVideoList; workbench.generateData.generatingJobs; production candidate asset APIs";

impl StoryboardMediaSlotsSummary {
    #[inline]
    fn build_from_legacy_url(
        raw: Option<&str>,
    ) -> (Option<String>, Option<String>, Option<String>) {
        let Some(trimmed) = raw.map(|s| s.trim()).filter(|s| !s.is_empty()) else {
            return (None, None, None);
        };
        let without_query = trimmed.split_once('?').map(|(b, _)| b).unwrap_or(trimmed);
        let pathish = without_query
            .split_once('#')
            .map(|(b, _)| b)
            .unwrap_or(without_query);
        let ext = pathish
            .rsplit_once('.')
            .map(|(_, e)| e.to_ascii_lowercase());
        match ext.as_deref() {
            Some("mp4") | Some("mov") | Some("webm") | Some("m4v") | Some("mkv") | Some("avi") => {
                (None, Some(trimmed.to_string()), None)
            }
            Some("png") | Some("jpg") | Some("jpeg") | Some("gif") | Some("webp") | Some("bmp")
            | Some("svg") | Some("tif") | Some("tiff") | Some("avif") | Some("heic") => {
                (Some(trimmed.to_string()), None, None)
            }
            _ => (None, None, Some(trimmed.to_string())),
        }
    }

    fn last_writeback_from_row(
        row: &ProductionStoryboardItem,
    ) -> Option<StoryboardLastWritebackSummary> {
        let status = row
            .short_video_writeback_status
            .as_deref()
            .map(str::trim)
            .filter(|s| !s.is_empty())?;
        Some(StoryboardLastWritebackSummary {
            status: status.to_string(),
            at: row
                .short_video_writeback_at
                .as_deref()
                .map(str::trim)
                .filter(|s| !s.is_empty())
                .map(str::to_string),
            error_code: row
                .short_video_writeback_error_code
                .as_deref()
                .map(str::trim)
                .filter(|s| !s.is_empty())
                .map(str::to_string),
        })
    }

    #[inline]
    pub(crate) fn from_row(row: &ProductionStoryboardItem) -> Self {
        let (reference_or_preview_frame_url, current_video_url, legacy_ambiguous_media_url) =
            Self::build_from_legacy_url(row.file_path.as_deref());
        let export_artifact_url = row
            .short_video_export_artifact_url
            .as_deref()
            .map(str::trim)
            .filter(|s| !s.is_empty())
            .map(str::to_string);
        Self {
            schema_version: 1,
            current_video_url,
            reference_or_preview_frame_url,
            legacy_ambiguous_media_url,
            voiceover_audio_url: row.voiceover_audio_url.clone(),
            voiceover_state: row.voiceover_state.clone(),
            export_artifact_url,
            last_writeback: Self::last_writeback_from_row(row),
            candidate_video_sources_hint: CANDIDATE_VIDEO_SOURCES_HINT,
            candidate_video_urls: Vec::new(),
        }
    }

    fn candidate_urls_for_row(row: &ProductionStoryboardItem, job_urls: &[String]) -> Vec<String> {
        let meta_urls = parse_candidate_urls_from_metadata(row.short_video_metadata.as_ref());
        let current = row.file_path.as_deref().filter(|u| {
            StoryboardMediaSlotsSummary::build_from_legacy_url(Some(u))
                .1
                .is_some()
        });
        merge_candidate_video_urls(meta_urls, job_urls.to_vec(), current)
    }
}

#[inline]
pub(crate) fn hydrate_production_storyboard_items(rows: &mut [ProductionStoryboardItem]) {
    for row in rows.iter_mut() {
        row.media_slots = Some(StoryboardMediaSlotsSummary::from_row(row));
    }
}

pub(crate) async fn hydrate_production_storyboard_candidate_urls(
    pool: &PgPool,
    project_numeric_id: i32,
    rows: &mut [ProductionStoryboardItem],
) -> Result<(), crate::error::ApiError> {
    if rows.is_empty() {
        return Ok(());
    }
    let ids: Vec<i32> = rows.iter().map(|r| r.id).collect();
    let job_map = fetch_storyboard_candidate_job_video_urls(pool, project_numeric_id, &ids).await?;
    for row in rows.iter_mut() {
        let job_urls = job_map.get(&row.id).cloned().unwrap_or_default();
        let urls = StoryboardMediaSlotsSummary::candidate_urls_for_row(row, &job_urls);
        if let Some(slots) = row.media_slots.as_mut() {
            slots.candidate_video_urls = urls;
        }
    }
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::hydrate_production_storyboard_items;

    use crate::production::workbench::storyboard_ops::types::{
        ProductionStoryboardItem, StoryboardMediaSlotsSummary,
    };

    #[inline]
    fn row_with_url(url: Option<String>) -> ProductionStoryboardItem {
        ProductionStoryboardItem {
            id: 99,
            script_id: Some(8),
            prompt: None,
            video_desc: None,
            file_path: url,
            duration: None,
            state: None,
            track_id: None,
            flow_id: None,
            sb_index: None,
            voiceover_state: Some("ready".into()),
            voiceover_audio_url: Some("https://x/a.mp3".into()),
            voiceover_error: None,
            live_action_reference_shot_urls: Vec::new(),
            live_action_performance_notes: None,
            short_video_writeback_status: Some("incomplete".into()),
            short_video_writeback_at: Some("2026-05-16T12:00:00Z".into()),
            short_video_writeback_error_code: Some(
                "video_generate_writeback_no_row_matched".into(),
            ),
            short_video_export_artifact_url: None,
            character_id: None,
            short_video_metadata: None,
            media_slots: None,
        }
    }

    #[test]
    fn mp4_legacy_url_maps_to_current_video_slot() {
        let row = row_with_url(Some("https://cdn/item.mp4?t=1".to_string()));
        let slots = StoryboardMediaSlotsSummary::from_row(&row);
        assert_eq!(
            slots.current_video_url.as_deref(),
            Some("https://cdn/item.mp4?t=1")
        );
        assert!(slots.reference_or_preview_frame_url.is_none());
        assert!(slots.legacy_ambiguous_media_url.is_none());
    }

    #[test]
    fn png_legacy_url_maps_to_reference_slot() {
        let slots = StoryboardMediaSlotsSummary::from_row(&row_with_url(Some("frame.PNG".into())));
        assert_eq!(
            slots.reference_or_preview_frame_url.as_deref(),
            Some("frame.PNG")
        );
        assert!(slots.current_video_url.is_none());
    }

    #[test]
    fn unknown_suffix_keeps_ambiguous_slot() {
        let slots =
            StoryboardMediaSlotsSummary::from_row(&row_with_url(Some("https://nocdn/key".into())));
        assert_eq!(
            slots.legacy_ambiguous_media_url.as_deref(),
            Some("https://nocdn/key")
        );
    }

    #[test]
    fn hydrate_writes_media_slots_into_row() {
        let mut rows = vec![row_with_url(None)];
        hydrate_production_storyboard_items(&mut rows);
        assert!(rows[0].media_slots.as_ref().is_some());
        assert_eq!(rows[0].media_slots.as_ref().unwrap().schema_version, 1);
        let last = rows[0]
            .media_slots
            .as_ref()
            .unwrap()
            .last_writeback
            .as_ref()
            .unwrap();
        assert_eq!(last.status, "incomplete");
        assert_eq!(
            last.error_code.as_deref(),
            Some("video_generate_writeback_no_row_matched")
        );
    }
}
