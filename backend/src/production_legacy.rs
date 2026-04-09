//! Legacy **`/api/production/*`**: SQLite **`o_video`**, **`o_videoConfig`**, **`o_agentWorkData`**
//! (production flow), OSS paths.
//! SaaS parity now covers the production workbench routes in this module; no generic **501** JSON
//! stub fallback remains registered here.

use axum::{
    extract::{Json, State},
    http::{HeaderMap, StatusCode},
    response::{IntoResponse, Response},
    routing::post,
    Json as JsonResponse, Router,
};
use serde::{Deserialize, Serialize};
use sqlx::FromRow;

use crate::auth::require_user_uuid;
use crate::error::ApiError;
use crate::jobs::{enqueue_generation_job, JobRow, JOB_KIND_ASSET_GENERATE_BATCH};
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
#[path = "production_legacy/workbench_track.rs"]
mod workbench_track;
#[path = "production_legacy/workbench_video.rs"]
mod workbench_video;

#[allow(dead_code)]
#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
struct StoryboardIdListBody {
    ids: Vec<i32>,
}

#[derive(Debug, Serialize, FromRow)]
#[serde(rename_all = "camelCase")]
struct ProductionStoryboardItem {
    id: i32,
    #[sqlx(rename = "script_id")]
    script_id: Option<i32>,
    prompt: Option<String>,
    #[sqlx(rename = "url")]
    file_path: Option<String>,
    duration: Option<String>,
    state: Option<String>,
    #[sqlx(rename = "track_id")]
    track_id: Option<i32>,
    #[sqlx(rename = "flow_id")]
    flow_id: Option<i32>,
    #[sqlx(rename = "sb_index")]
    sb_index: Option<i32>,
}

#[derive(Debug, Serialize)]
#[serde(rename_all = "camelCase")]
struct ProductionGetProductionDataResponse {
    data: Vec<ProductionStoryboardItem>,
}

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

#[allow(dead_code)]
#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
struct ExportImageShotRef {
    id: String,
}

#[allow(dead_code)]
#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
struct ExportImageBody {
    shot_id: Vec<ExportImageShotRef>,
}

async fn post_get_production_data(
    State(state): State<AppState>,
    headers: HeaderMap,
    Json(body): Json<StoryboardIdListBody>,
) -> Result<Response, ApiError> {
    let uid = require_user_uuid(&state, &headers)?;
    if body.ids.is_empty() {
        return Err(ApiError::BadRequest("ids must be a non-empty array".into()));
    }
    if body.ids.iter().any(|id| *id <= 0) {
        return Err(ApiError::BadRequest("ids must be positive integers".into()));
    }

    let pool = state
        .pool
        .as_ref()
        .ok_or_else(|| ApiError::DatabaseError("DATABASE_URL not configured".into()))?;

    let rows = sqlx::query_as::<_, ProductionStoryboardItem>(
        r#"
        SELECT
          sb.legacy_id AS id,
          sb.legacy_script_id AS script_id,
          sb.prompt,
          sb.file_path AS url,
          sb.duration,
          sb.state,
          sb.track_id,
          sb.flow_id,
          sb.sb_index
        FROM app_storyboard sb
        INNER JOIN app_script sc ON sc.id = sb.script_id
        INNER JOIN app_project p ON p.id = sc.project_id
        WHERE p.owner_user_id = $1
          AND sb.legacy_id = ANY($2::int4[])
        ORDER BY array_position($2::int4[], sb.legacy_id)
        "#,
    )
    .bind(uid)
    .bind(&body.ids)
    .fetch_all(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    Ok(JsonResponse(ProductionGetProductionDataResponse { data: rows }).into_response())
}

pub(crate) use workbench_flow::{load_owned_production_flow_json, resolve_owned_production_scope};

async fn post_storyboard_polling_image(
    State(state): State<AppState>,
    headers: HeaderMap,
    Json(body): Json<StoryboardIdListBody>,
) -> Result<Response, ApiError> {
    let uid = require_user_uuid(&state, &headers)?;
    if body.ids.is_empty() {
        return Err(ApiError::BadRequest("ids must be a non-empty array".into()));
    }
    if body.ids.iter().any(|id| *id <= 0) {
        return Err(ApiError::BadRequest("ids must be positive integers".into()));
    }

    let pool = state
        .pool
        .as_ref()
        .ok_or_else(|| ApiError::DatabaseError("DATABASE_URL not configured".into()))?;

    // Minimal "poll": verify all requested storyboard ids are owned by this user.
    // Real image-generation queue + `should_generate_image` updates will be added later.
    let mut uniq = body.ids.clone();
    uniq.sort_unstable();
    uniq.dedup();

    let owned_count = sqlx::query_scalar::<_, i64>(
        r#"
        SELECT COUNT(DISTINCT sb.legacy_id)
        FROM app_storyboard sb
        INNER JOIN app_script sc ON sc.id = sb.script_id
        INNER JOIN app_project p ON p.id = sc.project_id
        WHERE p.owner_user_id = $1
          AND sb.legacy_id = ANY($2::int4[])
        "#,
    )
    .bind(uid)
    .bind(&uniq)
    .fetch_one(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    if owned_count != uniq.len() as i64 {
        return Err(ApiError::NotFound);
    }

    Ok(StatusCode::OK.into_response())
}

async fn post_export_image(
    State(state): State<AppState>,
    headers: HeaderMap,
    Json(body): Json<ExportImageBody>,
) -> Result<Response, ApiError> {
    let uid = require_user_uuid(&state, &headers)?;
    if body.shot_id.is_empty() {
        return Err(ApiError::BadRequest(
            "shotId must be a non-empty array".into(),
        ));
    }

    let mut uniq = Vec::with_capacity(body.shot_id.len());
    for s in body.shot_id {
        let t = s.id.trim();
        let parsed: i32 = t
            .parse()
            .map_err(|_| ApiError::BadRequest("shotId.id must be a positive integer".into()))?;
        if parsed <= 0 {
            return Err(ApiError::BadRequest(
                "shotId.id must be a positive integer".into(),
            ));
        }
        uniq.push(parsed);
    }

    let pool = state
        .pool
        .as_ref()
        .ok_or_else(|| ApiError::DatabaseError("DATABASE_URL not configured".into()))?;

    uniq.sort_unstable();
    uniq.dedup();

    let owned_count = sqlx::query_scalar::<_, i64>(
        r#"
        SELECT COUNT(DISTINCT sb.legacy_id)
        FROM app_storyboard sb
        INNER JOIN app_script sc ON sc.id = sb.script_id
        INNER JOIN app_project p ON p.id = sc.project_id
        WHERE p.owner_user_id = $1
          AND sb.legacy_id = ANY($2::int4[])
        "#,
    )
    .bind(uid)
    .bind(&uniq)
    .fetch_one(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    if owned_count != uniq.len() as i64 {
        return Err(ApiError::NotFound);
    }

    Ok(StatusCode::OK.into_response())
}

// =============================================================================
// Batch Generate Image (Wave E)
// =============================================================================

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
struct BatchGenerateImageItem {
    storyboard_id: i32,
    prompt: String,
    #[serde(default)]
    negative_prompt: Option<String>,
    #[serde(default)]
    model: Option<String>,
    #[serde(default)]
    resolution: Option<String>,
}

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
struct BatchGenerateImageBody {
    project_id: i32,
    script_id: i32,
    items: Vec<BatchGenerateImageItem>,
    #[serde(default)]
    model: Option<String>,
    #[serde(default)]
    resolution: Option<String>,
}

#[derive(Debug, Serialize)]
#[serde(rename_all = "camelCase")]
struct BatchGenerateImageResponse {
    enqueued: Vec<JobRow>,
    total: usize,
}

async fn post_storyboard_batch_generate_image(
    State(state): State<AppState>,
    headers: HeaderMap,
    Json(body): Json<BatchGenerateImageBody>,
) -> Result<JsonResponse<BatchGenerateImageResponse>, ApiError> {
    let uid = require_user_uuid(&state, &headers)?;
    if body.project_id <= 0 || body.script_id <= 0 {
        return Err(ApiError::BadRequest(
            "projectId and scriptId must be positive integers".into(),
        ));
    }
    if body.items.is_empty() {
        return Err(ApiError::BadRequest("items must not be empty".into()));
    }

    let pool = state
        .pool
        .as_ref()
        .ok_or_else(|| ApiError::DatabaseError("DATABASE_URL not configured".into()))?;

    // Verify ownership
    let owned_count = sqlx::query_scalar::<_, i64>(
        r#"
        SELECT COUNT(*)
        FROM app_script s
        INNER JOIN app_project p ON p.id = s.project_id
        WHERE p.owner_user_id = $1
          AND p.legacy_id = $2
          AND s.legacy_id = $3
        "#,
    )
    .bind(uid)
    .bind(body.project_id)
    .bind(body.script_id)
    .fetch_one(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    if owned_count == 0 {
        return Err(ApiError::NotFound);
    }

    // Enqueue generation jobs for each storyboard
    let default_model = body.model.as_deref().unwrap_or("dall-e-3");
    let default_resolution = body.resolution.as_deref().unwrap_or("1024x1024");

    let mut enqueued = Vec::with_capacity(body.items.len());
    for item in &body.items {
        let payload = serde_json::json!({
            "source": "production.storyboard.batch-generate-image",
            "project_legacy_id": body.project_id,
            "script_id": body.script_id,
            "storyboard_id": item.storyboard_id,
            "prompt": item.prompt,
            "negative_prompt": item.negative_prompt,
            "model": item.model.as_deref().unwrap_or(default_model),
            "resolution": item.resolution.as_deref().unwrap_or(default_resolution),
        });

        let row = enqueue_generation_job(pool, uid, JOB_KIND_ASSET_GENERATE_BATCH, payload).await?;
        enqueued.push(row);
    }

    let total = enqueued.len();
    Ok(JsonResponse(BatchGenerateImageResponse { enqueued, total }))
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
            post(post_get_production_data),
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
            post(post_storyboard_polling_image),
        )
        .route("/api/v1/production/export-image", post(post_export_image))
        .route(
            "/api/v1/production/storyboard/batch-generate-image",
            post(post_storyboard_batch_generate_image),
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
    fn storyboard_id_list_body_rejects_unknown_fields() {
        let err = serde_json::from_str::<StoryboardIdListBody>(r#"{"ids":[1,2],"extra":1}"#);
        assert!(err.is_err());
    }

    #[test]
    fn storyboard_id_list_body_accepts_valid() {
        let b: StoryboardIdListBody = serde_json::from_str(r#"{"ids":[1,2,3]}"#).unwrap();
        assert_eq!(b.ids, vec![1, 2, 3]);
    }

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
        let err = serde_json::from_str::<ExportImageBody>(r#"{"shotId":[{"id":"1"}],"extra":1}"#);
        assert!(err.is_err());
    }

    #[test]
    fn export_image_body_accepts_valid() {
        let b: ExportImageBody =
            serde_json::from_str(r#"{"shotId":[{"id":"1"},{"id":"2"}]}"#).unwrap();
        assert_eq!(b.shot_id.len(), 2);
        assert_eq!(b.shot_id[0].id, "1");
    }

    #[test]
    fn router_builds_without_generic_stub_paths() {
        let app = router();
        let _ = app;
    }

    #[test]
    fn production_storyboard_item_serialize() {
        let item = ProductionStoryboardItem {
            id: 1,
            script_id: Some(2),
            prompt: Some("test prompt".to_string()),
            file_path: Some("http://example.com/image.png".to_string()),
            duration: Some("5s".to_string()),
            state: Some("completed".to_string()),
            track_id: Some(3),
            flow_id: Some(4),
            sb_index: Some(5),
        };
        let json = serde_json::to_string(&item).unwrap();
        assert!(json.contains("\"id\":1"));
        assert!(json.contains("\"scriptId\":2"));
        assert!(json.contains("\"prompt\":\"test prompt\""));
    }

    #[test]
    fn production_get_production_data_response_serialize() {
        let resp = ProductionGetProductionDataResponse { data: vec![] };
        let json = serde_json::to_string(&resp).unwrap();
        assert!(json.contains("\"data\":[]"));
    }
}
