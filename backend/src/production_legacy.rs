//! Legacy **`/api/production/*`**: SQLite **`o_video`**, **`o_videoConfig`**, **`o_agentWorkData`** (production flow), OSS paths.
//! SaaS: six routes use **strict** serde bodies; all other legacy **`POST`** paths share **`post_production_legacy_json_stub`**
//! (**JSON object** only, then **501**) until video pipeline + storage exist.

use axum::{
    extract::{Json, State},
    http::{HeaderMap, StatusCode},
    response::{IntoResponse, Response},
    routing::post,
    Json as JsonResponse, Router,
};
use serde::{Deserialize, Serialize};
use serde_json::Value;
use sqlx::FromRow;

use crate::auth::require_user_uuid;
use crate::error::ApiError;
use crate::state::AppState;

fn not_implemented() -> ApiError {
    ApiError::NotImplemented(
        "production workbench / video pipeline is not implemented; use storyboard REST and generation jobs when wired"
            .into(),
    )
}

fn require_json_object(body: &Value) -> Result<(), ApiError> {
    if body.as_object().is_none() {
        return Err(ApiError::BadRequest("body must be a JSON object".into()));
    }
    Ok(())
}

async fn post_production_legacy_json_stub(
    State(state): State<AppState>,
    headers: HeaderMap,
    Json(body): Json<Value>,
) -> Result<Response, ApiError> {
    let _ = require_user_uuid(&state, &headers)?;
    require_json_object(&body)?;
    Err(not_implemented())
}

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
struct GetFlowDataBody {
    project_id: i32,
    episodes_id: i32,
}

#[allow(dead_code)]
#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
struct SaveFlowDataBody {
    project_id: i32,
    episodes_id: i32,
    data: serde_json::Value,
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

async fn post_get_flow_data(
    State(state): State<AppState>,
    headers: HeaderMap,
    Json(body): Json<GetFlowDataBody>,
) -> Result<Response, ApiError> {
    let uid = require_user_uuid(&state, &headers)?;
    if body.project_id <= 0 || body.episodes_id <= 0 {
        return Err(ApiError::BadRequest(
            "projectId and episodesId must be positive integers".into(),
        ));
    }

    let pool = state
        .pool
        .as_ref()
        .ok_or_else(|| ApiError::DatabaseError("DATABASE_URL not configured".into()))?;

    // Minimal "flow" poll: verify the project exists and user owns at least one storyboard.
    // (Real episode/flow JSON pipeline will be added later.)
    let owned_count = sqlx::query_scalar::<_, i64>(
        r#"
        SELECT COUNT(*)
        FROM app_storyboard sb
        INNER JOIN app_script sc ON sc.id = sb.script_id
        INNER JOIN app_project p ON p.id = sc.project_id
        WHERE p.owner_user_id = $1
          AND p.legacy_id = $2
        "#,
    )
    .bind(uid)
    .bind(body.project_id)
    .fetch_one(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    if owned_count == 0 {
        return Err(ApiError::NotFound);
    }

    Ok(StatusCode::OK.into_response())
}

async fn post_save_flow_data(
    State(state): State<AppState>,
    headers: HeaderMap,
    Json(body): Json<SaveFlowDataBody>,
) -> Result<Response, ApiError> {
    let uid = require_user_uuid(&state, &headers)?;
    if body.project_id <= 0 || body.episodes_id <= 0 {
        return Err(ApiError::BadRequest(
            "projectId and episodesId must be positive integers".into(),
        ));
    }
    if body.data.as_object().is_none() {
        return Err(ApiError::BadRequest("data must be a JSON object".into()));
    }

    let pool = state
        .pool
        .as_ref()
        .ok_or_else(|| ApiError::DatabaseError("DATABASE_URL not configured".into()))?;

    // Minimal save: verify user owns the project (has at least one storyboard).
    let owned_count = sqlx::query_scalar::<_, i64>(
        r#"
        SELECT COUNT(*)
        FROM app_storyboard sb
        INNER JOIN app_script sc ON sc.id = sb.script_id
        INNER JOIN app_project p ON p.id = sc.project_id
        WHERE p.owner_user_id = $1
          AND p.legacy_id = $2
        "#,
    )
    .bind(uid)
    .bind(body.project_id)
    .fetch_one(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    if owned_count == 0 {
        return Err(ApiError::NotFound);
    }

    Ok(StatusCode::OK.into_response())
}

async fn post_workbench_generate_video(
    State(state): State<AppState>,
    headers: HeaderMap,
    Json(body): Json<WorkbenchGenerateVideoBody>,
) -> Result<Response, ApiError> {
    let uid = require_user_uuid(&state, &headers)?;
    if body.project_id <= 0 || body.script_id <= 0 || body.track_id <= 0 {
        return Err(ApiError::BadRequest(
            "projectId/scriptId/trackId must be positive integers".into(),
        ));
    }

    let pool = state
        .pool
        .as_ref()
        .ok_or_else(|| ApiError::DatabaseError("DATABASE_URL not configured".into()))?;

    // Minimal "enqueue": verify the project + script belong to the current user.
    // Real video-generation pipeline will come later.
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

    Ok(StatusCode::OK.into_response())
}

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

const LEGACY_JSON_STUB_PATHS: &[&str] = &[
    "/api/v1/production/assets/batch-generate-assets-image",
    "/api/v1/production/assets/delete-assets-derivative",
    "/api/v1/production/assets/get-assets-data",
    "/api/v1/production/assets/polling-image",
    "/api/v1/production/assets/update-assets-url",
    "/api/v1/production/edit-image/generate-flow-image",
    "/api/v1/production/edit-image/get-image-default-model",
    "/api/v1/production/edit-image/get-image-flow",
    "/api/v1/production/edit-image/save-image-flow",
    "/api/v1/production/edit-image/update-image-flow",
    "/api/v1/production/get-storyboard-data",
    "/api/v1/production/storyboard/add",
    "/api/v1/production/storyboard/batch-add-info",
    "/api/v1/production/storyboard/batch-generate-image",
    "/api/v1/production/storyboard/down-preview-image",
    "/api/v1/production/storyboard/edit-info",
    "/api/v1/production/storyboard/get-data",
    "/api/v1/production/storyboard/preview-image",
    "/api/v1/production/storyboard/remove-frame",
    "/api/v1/production/storyboard/update-url",
    "/api/v1/production/workbench/add-track",
    "/api/v1/production/workbench/delete-track",
    "/api/v1/production/workbench/delete-video",
    "/api/v1/production/workbench/generate-video-prompt",
    "/api/v1/production/workbench/get-generate-data",
    "/api/v1/production/workbench/get-video-list",
    "/api/v1/production/workbench/get-video-model-detail",
    "/api/v1/production/workbench/select-video",
];

pub fn router() -> Router<AppState> {
    let mut r = Router::new()
        .route(
            "/api/v1/production/get-production-data",
            post(post_get_production_data),
        )
        .route("/api/v1/production/get-flow-data", post(post_get_flow_data))
        .route(
            "/api/v1/production/save-flow-data",
            post(post_save_flow_data),
        )
        .route(
            "/api/v1/production/workbench/generate-video",
            post(post_workbench_generate_video),
        )
        .route(
            "/api/v1/production/storyboard/polling-image",
            post(post_storyboard_polling_image),
        )
        .route("/api/v1/production/export-image", post(post_export_image));
    for path in LEGACY_JSON_STUB_PATHS {
        r = r.route(path, post(post_production_legacy_json_stub));
    }
    r
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn storyboard_id_list_body_rejects_unknown_fields() {
        let err =
            serde_json::from_str::<StoryboardIdListBody>(r#"{"ids":[1,2],"extra":1}"#);
        assert!(err.is_err());
    }

    #[test]
    fn storyboard_id_list_body_accepts_valid() {
        let b: StoryboardIdListBody =
            serde_json::from_str(r#"{"ids":[1,2,3]}"#).unwrap();
        assert_eq!(b.ids, vec![1, 2, 3]);
    }

    #[test]
    fn get_flow_data_body_rejects_unknown_fields() {
        let err = serde_json::from_str::<GetFlowDataBody>(
            r#"{"projectId":1,"episodesId":5,"extra":1}"#,
        );
        assert!(err.is_err());
    }

    #[test]
    fn get_flow_data_body_accepts_valid() {
        let b: GetFlowDataBody =
            serde_json::from_str(r#"{"projectId":1,"episodesId":5}"#).unwrap();
        assert_eq!(b.project_id, 1);
        assert_eq!(b.episodes_id, 5);
    }

    #[test]
    fn save_flow_data_body_rejects_unknown_fields() {
        let err = serde_json::from_str::<SaveFlowDataBody>(
            r#"{"projectId":1,"episodesId":5,"data":{},"extra":1}"#,
        );
        assert!(err.is_err());
    }

    #[test]
    fn save_flow_data_body_accepts_valid() {
        let b: SaveFlowDataBody = serde_json::from_str(
            r#"{"projectId":1,"episodesId":5,"data":{"key":"value"}}"#,
        )
        .unwrap();
        assert_eq!(b.project_id, 1);
        assert_eq!(b.episodes_id, 5);
        assert!(b.data.is_object());
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
        let err =
            serde_json::from_str::<ExportImageShotRef>(r#"{"id":"1","extra":1}"#);
        assert!(err.is_err());
    }

    #[test]
    fn export_image_shot_ref_accepts_valid() {
        let b: ExportImageShotRef =
            serde_json::from_str(r#"{"id":"123"}"#).unwrap();
        assert_eq!(b.id, "123");
    }

    #[test]
    fn export_image_body_rejects_unknown_fields() {
        let err = serde_json::from_str::<ExportImageBody>(
            r#"{"shotId":[{"id":"1"}],"extra":1}"#,
        );
        assert!(err.is_err());
    }

    #[test]
    fn export_image_body_accepts_valid() {
        let b: ExportImageBody = serde_json::from_str(
            r#"{"shotId":[{"id":"1"},{"id":"2"}]}"#,
        )
        .unwrap();
        assert_eq!(b.shot_id.len(), 2);
        assert_eq!(b.shot_id[0].id, "1");
    }

    #[test]
    fn require_json_object_rejects_non_object() {
        assert!(require_json_object(&Value::Null).is_err());
        assert!(require_json_object(&Value::Array(vec![])).is_err());
        assert!(require_json_object(&Value::String("test".to_string())).is_err());
        assert!(require_json_object(&Value::Number(42.into())).is_err());
        assert!(require_json_object(&Value::Bool(true)).is_err());
    }

    #[test]
    fn require_json_object_accepts_object() {
        assert!(require_json_object(&Value::Object(serde_json::Map::new())).is_ok());
    }

    #[test]
    fn not_implemented_returns_error() {
        let err = not_implemented();
        assert!(matches!(err, ApiError::NotImplemented(_)));
    }

    #[test]
    fn legacy_json_stub_paths_is_not_empty() {
        assert!(!LEGACY_JSON_STUB_PATHS.is_empty());
        // Verify all paths start with expected prefix
        for path in LEGACY_JSON_STUB_PATHS {
            assert!(path.starts_with("/api/v1/production/"));
        }
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
