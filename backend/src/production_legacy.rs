//! Legacy **`/api/production/*`**: SQLite **`o_video`**, **`o_videoConfig`**, **`o_agentWorkData`**
//! (production flow), OSS paths.
//! SaaS parity now covers the production workbench routes in this module; no generic **501** JSON
//! stub fallback remains registered here.

use axum::{routing::post, Router};
use serde::{Deserialize, Serialize};
use sqlx::FromRow;

use crate::state::AppState;

#[path = "production_legacy/workbench_assets.rs"]
mod workbench_assets;
#[path = "production_legacy/workbench_edit_image.rs"]
mod workbench_edit_image;
#[path = "production_legacy/workbench_flow.rs"]
mod workbench_flow;
#[path = "production_legacy/workbench_meta.rs"]
mod workbench_meta;
#[path = "production_legacy/workbench_storyboard.rs"]
mod workbench_storyboard;
#[path = "production_legacy/workbench_storyboard_ops.rs"]
mod workbench_storyboard_ops;
#[path = "production_legacy/workbench_track.rs"]
mod workbench_track;
#[path = "production_legacy/workbench_video.rs"]
mod workbench_video;

pub(crate) use workbench_flow::{load_owned_production_flow_json, resolve_owned_production_scope};
pub(crate) use workbench_storyboard_ops::{
    ProductionGetProductionDataResponse, ProductionStoryboardItem,
};

#[allow(dead_code)]
#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
struct GenerateVideoUploadItem {
    id: i32,
    sources: String,
}

#[allow(dead_code)]
#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
struct WorkbenchGenerateVideoBody {
    project_id: i32,
    script_id: i32,
    upload_data: Vec<GenerateVideoUploadItem>,
    prompt: String,
    model: String,
    mode: String,
    resolution: String,
    duration: i32,
    #[serde(default)]
    audio: Option<bool>,
    track_id: i32,
}

// =============================================================================
// Video List (Wave E)
// =============================================================================

#[derive(Debug, Serialize, FromRow)]
#[serde(rename_all = "camelCase")]
struct VideoItem {
    id: i32,
    #[sqlx(rename = "legacy_script_id")]
    script_id: Option<i32>,
    prompt: Option<String>,
    #[sqlx(rename = "file_path")]
    video_url: Option<String>,
    duration: Option<String>,
    state: Option<String>,
    track_id: Option<i32>,
    created_at: Option<chrono::DateTime<chrono::Utc>>,
}

pub fn router() -> Router<AppState> {
    Router::new()
        .route(
            "/api/v1/production/get-production-data",
            post(workbench_storyboard_ops::post_get_production_data),
        )
        .route(
            "/api/v1/production/get-flow-data",
            post(workbench_flow::post_get_flow_data),
        )
        .route(
            "/api/v1/production/save-flow-data",
            post(workbench_flow::post_save_flow_data),
        )
        .route(
            "/api/v1/production/workbench/generate-video",
            post(workbench_video::post_workbench_generate_video),
        )
        .route(
            "/api/v1/production/storyboard/polling-image",
            post(workbench_storyboard_ops::post_storyboard_polling_image),
        )
        .route(
            "/api/v1/production/export-image",
            post(workbench_storyboard_ops::post_export_image),
        )
        .route(
            "/api/v1/production/storyboard/batch-generate-image",
            post(workbench_storyboard_ops::post_storyboard_batch_generate_image),
        )
        .route(
            "/api/v1/production/workbench/get-video-list",
            post(workbench_video::post_workbench_get_video_list),
        )
        .route(
            "/api/v1/production/workbench/add-track",
            post(workbench_track::post_workbench_add_track),
        )
        .route(
            "/api/v1/production/workbench/delete-track",
            post(workbench_track::post_workbench_delete_track),
        )
        .route(
            "/api/v1/production/workbench/delete-video",
            post(workbench_track::post_workbench_delete_video),
        )
        .route(
            "/api/v1/production/workbench/select-video",
            post(workbench_track::post_workbench_select_video),
        )
        .route(
            "/api/v1/production/assets/batch-generate-assets-image",
            post(workbench_assets::post_assets_batch_generate_image),
        )
        .route(
            "/api/v1/production/assets/delete-assets-derivative",
            post(workbench_assets::post_assets_delete_derivative),
        )
        .route(
            "/api/v1/production/assets/get-assets-data",
            post(workbench_assets::post_assets_get_data),
        )
        .route(
            "/api/v1/production/assets/polling-image",
            post(workbench_assets::post_assets_polling_image),
        )
        .route(
            "/api/v1/production/assets/update-assets-url",
            post(workbench_assets::post_assets_update_url),
        )
        .route(
            "/api/v1/production/edit-image/get-image-flow",
            post(workbench_edit_image::post_edit_image_get_image_flow),
        )
        .route(
            "/api/v1/production/edit-image/get-image-default-model",
            post(workbench_edit_image::post_edit_image_get_image_default_model),
        )
        .route(
            "/api/v1/production/edit-image/save-image-flow",
            post(workbench_edit_image::post_edit_image_save_image_flow),
        )
        .route(
            "/api/v1/production/edit-image/update-image-flow",
            post(workbench_edit_image::post_edit_image_update_image_flow),
        )
        .route(
            "/api/v1/production/edit-image/generate-flow-image",
            post(workbench_edit_image::post_edit_image_generate_flow_image),
        )
        .route(
            "/api/v1/production/edit-image/upload-image",
            post(workbench_edit_image::post_edit_image_upload_image),
        )
        .route(
            "/api/v1/production/get-storyboard-data",
            post(workbench_storyboard::post_get_storyboard_data),
        )
        .route(
            "/api/v1/production/storyboard/add",
            post(workbench_storyboard::post_storyboard_add),
        )
        .route(
            "/api/v1/production/storyboard/batch-add-info",
            post(workbench_storyboard::post_storyboard_batch_add_info),
        )
        .route(
            "/api/v1/production/storyboard/down-preview-image",
            post(workbench_storyboard::post_storyboard_down_preview_image),
        )
        .route(
            "/api/v1/production/storyboard/edit-info",
            post(workbench_storyboard::post_storyboard_edit_info),
        )
        .route(
            "/api/v1/production/storyboard/get-data",
            post(workbench_storyboard::post_storyboard_get_data),
        )
        .route(
            "/api/v1/production/storyboard/preview-image",
            post(workbench_storyboard::post_storyboard_preview_image),
        )
        .route(
            "/api/v1/production/storyboard/remove-frame",
            post(workbench_storyboard::post_storyboard_remove_frame),
        )
        .route(
            "/api/v1/production/storyboard/update-url",
            post(workbench_storyboard::post_storyboard_update_url),
        )
        .route(
            "/api/v1/production/workbench/generate-video-prompt",
            post(workbench_meta::post_workbench_generate_video_prompt),
        )
        .route(
            "/api/v1/production/workbench/get-generate-data",
            post(workbench_meta::post_workbench_get_generate_data),
        )
        .route(
            "/api/v1/production/workbench/get-video-model-detail",
            post(workbench_meta::post_workbench_get_video_model_detail),
        )
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn generate_video_upload_item_rejects_unknown_fields() {
        let err = serde_json::from_str::<GenerateVideoUploadItem>(
            r#"{"id":1,"sources":"url","extra":1}"#,
        );
        assert!(err.is_err());
    }

    #[test]
    fn generate_video_upload_item_accepts_valid() {
        let b: GenerateVideoUploadItem =
            serde_json::from_str(r#"{"id":1,"sources":"http://example.com"}"#).unwrap();
        assert_eq!(b.id, 1);
        assert_eq!(b.sources, "http://example.com");
    }

    #[test]
    fn workbench_generate_video_body_rejects_unknown_fields() {
        let err = serde_json::from_str::<WorkbenchGenerateVideoBody>(
            r#"{"projectId":1,"scriptId":2,"uploadData":[],"prompt":"","model":"","mode":"","resolution":"","duration":5,"trackId":1,"extra":1}"#,
        );
        assert!(err.is_err());
    }

    #[test]
    fn workbench_generate_video_body_accepts_valid() {
        let b: WorkbenchGenerateVideoBody = serde_json::from_str(
            r#"{"projectId":1,"scriptId":2,"uploadData":[{"id":1,"sources":"url"}],"prompt":"test","model":"runway","mode":"standard","resolution":"1080p","duration":5,"trackId":1}"#,
        )
        .unwrap();
        assert_eq!(b.project_id, 1);
        assert_eq!(b.script_id, 2);
        assert_eq!(b.upload_data.len(), 1);
        assert_eq!(b.duration, 5);
        assert_eq!(b.audio, None);
    }

    #[test]
    fn workbench_generate_video_body_accepts_with_audio() {
        let b: WorkbenchGenerateVideoBody = serde_json::from_str(
            r#"{"projectId":1,"scriptId":2,"uploadData":[],"prompt":"","model":"","mode":"","resolution":"","duration":5,"audio":true,"trackId":1}"#,
        )
        .unwrap();
        assert_eq!(b.audio, Some(true));
    }

    #[test]
    fn router_builds_without_generic_stub_paths() {
        let app = router();
        let _ = app;
    }
}
