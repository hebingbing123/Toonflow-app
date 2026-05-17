use serde::{Deserialize, Serialize};
use sqlx::FromRow;
use uuid::Uuid;

/// Latest video **`file_path`** writeback attempt (**`metadata.shortVideo.lastWriteback`**).
#[derive(Debug, Clone, Serialize)]
#[serde(rename_all = "camelCase")]
pub(crate) struct StoryboardLastWritebackSummary {
    pub(crate) status: String,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub(crate) at: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub(crate) error_code: Option<String>,
}

/// Read-only **`mediaSlots`** on API responses clarifies legacy storyboard **`url`** / DB **`file_path`**
/// (single column) versus voiceover (**`metadata.voiceover`**) versus **candidate/export** aggregates.
#[derive(Debug, Clone, Serialize)]
#[serde(rename_all = "camelCase")]
pub(crate) struct StoryboardMediaSlotsSummary {
    pub(crate) schema_version: i32,
    /// **`url`** when it looks like a video file.
    #[serde(skip_serializing_if = "Option::is_none")]
    pub(crate) current_video_url: Option<String>,
    /// **`url`** when it looks like a static image (**reference frame / preview / keyframe** share this legacy slot until split).
    #[serde(skip_serializing_if = "Option::is_none")]
    pub(crate) reference_or_preview_frame_url: Option<String>,
    /// Non-empty **`url`** with unknown suffix — do not infer image vs video.
    #[serde(skip_serializing_if = "Option::is_none")]
    pub(crate) legacy_ambiguous_media_url: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub(crate) voiceover_audio_url: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub(crate) voiceover_state: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub(crate) export_artifact_url: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub(crate) last_writeback: Option<StoryboardLastWritebackSummary>,
    pub(crate) candidate_video_sources_hint: &'static str,
    /// Explicit candidate clip URLs (metadata **`candidateVideos`** + completed video jobs).
    #[serde(skip_serializing_if = "Vec::is_empty", default)]
    pub(crate) candidate_video_urls: Vec<String>,
}

#[allow(dead_code)]
#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
pub(in crate::production) struct StoryboardIdListBody {
    #[serde(default)]
    pub(in crate::production) project_id: Option<i32>,
    #[serde(default)]
    pub(in crate::production) project_uuid: Option<Uuid>,
    pub(in crate::production) script_id: i32,
    pub(in crate::production) ids: Vec<i32>,
    /// When set and matches server **`data_version`**, response returns **`unchanged: true`** with empty **`data`**.
    #[serde(default)]
    pub(in crate::production) client_data_version: Option<String>,
}

#[derive(Debug, Serialize, FromRow)]
#[serde(rename_all = "camelCase")]
pub(crate) struct ProductionStoryboardItem {
    pub(crate) id: i32,
    #[sqlx(rename = "script_id")]
    pub(crate) script_id: Option<i32>,
    pub(crate) prompt: Option<String>,
    pub(crate) video_desc: Option<String>,
    #[sqlx(rename = "url")]
    pub(crate) file_path: Option<String>,
    pub(crate) duration: Option<String>,
    pub(crate) state: Option<String>,
    #[sqlx(rename = "track_id")]
    pub(crate) track_id: Option<i32>,
    #[sqlx(rename = "flow_id")]
    pub(crate) flow_id: Option<i32>,
    #[sqlx(rename = "sb_index")]
    pub(crate) sb_index: Option<i32>,
    pub(crate) voiceover_state: Option<String>,
    pub(crate) voiceover_audio_url: Option<String>,
    pub(crate) voiceover_error: Option<String>,
    pub(crate) live_action_reference_shot_urls: Vec<String>,
    pub(crate) live_action_performance_notes: Option<String>,
    #[sqlx(rename = "short_video_writeback_status")]
    pub(crate) short_video_writeback_status: Option<String>,
    #[sqlx(rename = "short_video_writeback_at")]
    pub(crate) short_video_writeback_at: Option<String>,
    #[sqlx(rename = "short_video_writeback_error_code")]
    pub(crate) short_video_writeback_error_code: Option<String>,
    #[sqlx(rename = "short_video_export_artifact_url")]
    pub(crate) short_video_export_artifact_url: Option<String>,
    pub(crate) character_id: Option<Uuid>,
    #[serde(skip)]
    #[sqlx(rename = "short_video_metadata")]
    pub(crate) short_video_metadata: Option<serde_json::Value>,
    #[serde(skip_serializing_if = "Option::is_none")]
    #[sqlx(skip)]
    pub(crate) media_slots: Option<StoryboardMediaSlotsSummary>,
}

#[derive(Debug, Serialize)]
#[serde(rename_all = "camelCase")]
pub(crate) struct ProductionGetProductionDataResponse {
    pub(crate) data: Vec<ProductionStoryboardItem>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub(crate) data_version: Option<String>,
    #[serde(default)]
    pub(crate) unchanged: bool,
}

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
pub(in crate::production) struct ExportImageShotRef {
    pub(in crate::production) id: String,
}

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
pub(in crate::production) struct ExportImageBody {
    #[serde(default)]
    pub(in crate::production) project_id: Option<i32>,
    #[serde(default)]
    pub(in crate::production) project_uuid: Option<Uuid>,
    pub(in crate::production) script_id: i32,
    pub(in crate::production) shot_id: Vec<ExportImageShotRef>,
}

#[derive(Debug, FromRow)]
pub(super) struct ExportImageSourceRow {
    pub(super) numeric_id: i32,
    pub(super) file_path: Option<String>,
    pub(super) prompt: Option<String>,
    pub(super) video_desc: Option<String>,
    pub(super) duration: Option<String>,
    pub(super) state: Option<String>,
    pub(super) track_id: Option<i32>,
    pub(super) sb_index: Option<i32>,
    pub(super) voiceover_audio_url: Option<String>,
    pub(super) voiceover_state: Option<String>,
}

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
pub(super) struct BatchGenerateImageItem {
    pub(super) storyboard_id: i32,
    pub(super) prompt: String,
    #[serde(default)]
    pub(super) negative_prompt: Option<String>,
    #[serde(default)]
    pub(super) model: Option<String>,
    #[serde(default)]
    pub(super) resolution: Option<String>,
}

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
pub(in crate::production) struct BatchGenerateImageBody {
    #[serde(default)]
    pub(super) project_id: Option<i32>,
    #[serde(default)]
    pub(super) project_uuid: Option<Uuid>,
    pub(super) script_id: i32,
    pub(super) items: Vec<BatchGenerateImageItem>,
    #[serde(default)]
    pub(super) model: Option<String>,
    #[serde(default)]
    pub(super) resolution: Option<String>,
}

#[derive(Debug, Serialize)]
#[serde(rename_all = "camelCase")]
pub(in crate::production) struct BatchGenerateImageResponse {
    pub(super) enqueued: Vec<crate::jobs::JobRow>,
    pub(super) total: usize,
}

#[cfg(test)]
mod tests {
    use super::{
        ExportImageBody, ExportImageShotRef, ProductionGetProductionDataResponse,
        ProductionStoryboardItem, StoryboardIdListBody,
    };

    #[test]
    fn storyboard_id_list_body_rejects_unknown_fields() {
        let err = serde_json::from_str::<StoryboardIdListBody>(
            r#"{"projectId":1,"scriptId":1,"ids":[1,2],"extra":1}"#,
        );
        assert!(err.is_err());
    }

    #[test]
    fn storyboard_id_list_body_accepts_valid() {
        let b: StoryboardIdListBody =
            serde_json::from_str(r#"{"projectId":9,"scriptId":3,"ids":[1,2,3]}"#).unwrap();
        assert_eq!(b.project_id, Some(9));
        assert_eq!(b.script_id, 3);
        assert_eq!(b.ids, vec![1, 2, 3]);
    }

    #[test]
    fn export_image_shot_ref_rejects_unknown_fields() {
        let err = serde_json::from_str::<ExportImageShotRef>(r#"{"id":"1","extra":1}"#);
        assert!(err.is_err());
    }

    #[test]
    fn export_image_shot_ref_accepts_valid() {
        let b: ExportImageShotRef = serde_json::from_str(r#"{"id":"123"}"#).unwrap();
        assert_eq!(b.id, "123");
    }

    #[test]
    fn export_image_body_rejects_unknown_fields() {
        let err = serde_json::from_str::<ExportImageBody>(
            r#"{"projectId":1,"scriptId":1,"shotId":[{"id":"1"}],"extra":1}"#,
        );
        assert!(err.is_err());
    }

    #[test]
    fn export_image_body_accepts_valid() {
        let b: ExportImageBody = serde_json::from_str(
            r#"{"projectId":7,"scriptId":2,"shotId":[{"id":"1"},{"id":"2"}]}"#,
        )
        .unwrap();
        assert_eq!(b.project_id, Some(7));
        assert_eq!(b.script_id, 2);
        assert_eq!(b.shot_id.len(), 2);
        assert_eq!(b.shot_id[0].id, "1");
    }

    #[test]
    fn export_image_body_accepts_project_uuid() {
        let b: ExportImageBody = serde_json::from_str(
            r#"{"projectUuid":"550e8400-e29b-41d4-a716-446655440000","scriptId":2,"shotId":[{"id":"1"}]}"#,
        )
        .unwrap();
        assert_eq!(b.project_id, None);
        assert_eq!(
            b.project_uuid.map(|id| id.to_string()).as_deref(),
            Some("550e8400-e29b-41d4-a716-446655440000")
        );
    }

    #[test]
    fn batch_generate_image_body_accepts_project_uuid() {
        let b: super::BatchGenerateImageBody = serde_json::from_str(
            r#"{"projectUuid":"550e8400-e29b-41d4-a716-446655440000","scriptId":2,"items":[{"storyboardId":1,"prompt":"hello"}]}"#,
        )
        .unwrap();
        assert_eq!(b.project_id, None);
        assert_eq!(
            b.project_uuid.map(|id| id.to_string()).as_deref(),
            Some("550e8400-e29b-41d4-a716-446655440000")
        );
        assert_eq!(b.items.len(), 1);
    }

    #[test]
    fn production_storyboard_item_serialize() {
        let item = ProductionStoryboardItem {
            id: 1,
            script_id: Some(2),
            prompt: Some("test prompt".to_string()),
            video_desc: Some("narration".to_string()),
            file_path: Some("http://example.com/image.png".to_string()),
            duration: Some("5s".to_string()),
            state: Some("completed".to_string()),
            track_id: Some(3),
            flow_id: Some(4),
            sb_index: Some(5),
            voiceover_state: Some("completed".to_string()),
            voiceover_audio_url: Some("/api/v1/jobs/audio/file".to_string()),
            voiceover_error: None,
            live_action_reference_shot_urls: vec!["https://example.com/shot-1.jpg".into()],
            live_action_performance_notes: Some("自然口播，停顿克制".into()),
            short_video_writeback_status: None,
            short_video_writeback_at: None,
            short_video_writeback_error_code: None,
            short_video_export_artifact_url: None,
            character_id: None,
            short_video_metadata: None,
            media_slots: None,
        };
        let json = serde_json::to_string(&item).unwrap();
        assert!(json.contains("\"id\":1"));
        assert!(json.contains("\"scriptId\":2"));
        assert!(json.contains("\"prompt\":\"test prompt\""));
        assert!(json.contains("\"videoDesc\":\"narration\""));
        assert!(json.contains("\"liveActionReferenceShotUrls\""));
    }

    #[test]
    fn production_get_production_data_response_serialize() {
        let resp = ProductionGetProductionDataResponse {
            data: vec![],
            data_version: None,
            unchanged: false,
        };
        let json = serde_json::to_string(&resp).unwrap();
        assert!(json.contains("\"data\":[]"));
    }
}
