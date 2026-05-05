use serde::{Deserialize, Serialize};
use sqlx::FromRow;

#[allow(dead_code)]
#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
pub(in crate::production) struct StoryboardIdListBody {
    pub(in crate::production) project_id: i32,
    pub(in crate::production) script_id: i32,
    pub(in crate::production) ids: Vec<i32>,
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
}

#[derive(Debug, Serialize)]
#[serde(rename_all = "camelCase")]
pub(crate) struct ProductionGetProductionDataResponse {
    pub(crate) data: Vec<ProductionStoryboardItem>,
}

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
pub(in crate::production) struct ExportImageShotRef {
    pub(in crate::production) id: String,
}

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
pub(in crate::production) struct ExportImageBody {
    pub(in crate::production) project_id: i32,
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
    pub(super) project_id: i32,
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
        assert_eq!(b.project_id, 9);
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
        assert_eq!(b.project_id, 7);
        assert_eq!(b.script_id, 2);
        assert_eq!(b.shot_id.len(), 2);
        assert_eq!(b.shot_id[0].id, "1");
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
        };
        let json = serde_json::to_string(&item).unwrap();
        assert!(json.contains("\"id\":1"));
        assert!(json.contains("\"scriptId\":2"));
        assert!(json.contains("\"prompt\":\"test prompt\""));
        assert!(json.contains("\"videoDesc\":\"narration\""));
    }

    #[test]
    fn production_get_production_data_response_serialize() {
        let resp = ProductionGetProductionDataResponse { data: vec![] };
        let json = serde_json::to_string(&resp).unwrap();
        assert!(json.contains("\"data\":[]"));
    }
}
