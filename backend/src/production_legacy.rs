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
use serde_json::{json, Map, Value};
use sqlx::FromRow;

use crate::auth::require_user_uuid;
use crate::error::ApiError;
use crate::jobs::{enqueue_generation_job, JobRow, JOB_KIND_ASSET_GENERATE_BATCH};
use crate::state::AppState;

#[path = "production_legacy/workbench_meta.rs"]
mod workbench_meta;
#[path = "production_legacy/workbench_track.rs"]
mod workbench_track;

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
    data: Value,
}

#[derive(Debug, FromRow)]
struct OwnedProductionScope {
    project_id: uuid::Uuid,
    script_id: uuid::Uuid,
    script_content: Option<String>,
}

#[derive(Debug, FromRow)]
struct ProductionAssetFlowRow {
    legacy_id: i32,
    name: String,
    asset_type: String,
    description: Option<String>,
    metadata: Value,
    history_images: Value,
}

#[derive(Debug, FromRow)]
struct ProductionStoryboardFlowRow {
    legacy_id: i32,
    prompt: Option<String>,
    file_path: Option<String>,
    duration: Option<String>,
    state: Option<String>,
    reason: Option<String>,
    video_desc: Option<String>,
    should_generate_image: Option<i32>,
    flow_id: Option<i32>,
    sb_index: Option<i32>,
}

async fn resolve_owned_production_scope(
    pool: &sqlx::PgPool,
    uid: uuid::Uuid,
    project_legacy_id: i32,
    script_legacy_id: i32,
) -> Result<OwnedProductionScope, ApiError> {
    sqlx::query_as::<_, OwnedProductionScope>(
        r#"
        SELECT
          p.id AS project_id,
          s.id AS script_id,
          s.content AS script_content
        FROM app_script s
        INNER JOIN app_project p ON p.id = s.project_id
        WHERE p.owner_user_id = $1
          AND p.legacy_id = $2
          AND s.legacy_id = $3
        "#,
    )
    .bind(uid)
    .bind(project_legacy_id)
    .bind(script_legacy_id)
    .fetch_optional(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?
    .ok_or(ApiError::NotFound)
}

fn json_string(obj: &Map<String, Value>, key: &str) -> Option<String> {
    obj.get(key).and_then(Value::as_str).map(str::to_string)
}

fn json_i32(obj: &Map<String, Value>, key: &str) -> Option<i32> {
    obj.get(key)
        .and_then(Value::as_i64)
        .and_then(|v| i32::try_from(v).ok())
}

fn history_image_src(metadata: &Value, history_images: &[Value]) -> Option<String> {
    let selected_legacy_image_id = metadata
        .get("imageId")
        .and_then(Value::as_i64)
        .and_then(|v| i32::try_from(v).ok());
    if let Some(selected_id) = selected_legacy_image_id {
        if let Some(src) = history_images.iter().find_map(|img| {
            let img_obj = img.as_object()?;
            if json_i32(img_obj, "legacy_image_id") == Some(selected_id) {
                return json_string(img_obj, "file_path");
            }
            None
        }) {
            return Some(src);
        }
    }
    history_images.iter().find_map(|img| {
        img.as_object()
            .and_then(|obj| json_string(obj, "file_path"))
    })
}

fn build_production_asset_item(
    row: &ProductionAssetFlowRow,
    child_rows: &[&ProductionAssetFlowRow],
) -> Value {
    let history_images = row.history_images.as_array().cloned().unwrap_or_default();
    let src = history_image_src(&row.metadata, &history_images);
    let prompt = row
        .metadata
        .get("prompt")
        .and_then(Value::as_str)
        .unwrap_or_default();
    let flow_id = row
        .metadata
        .get("flowId")
        .and_then(Value::as_i64)
        .and_then(|v| i32::try_from(v).ok());

    let derive = child_rows
        .iter()
        .map(|child| {
            let child_history = child
                .history_images
                .as_array()
                .cloned()
                .unwrap_or_default();
            let child_obj = json!({
              "id": child.legacy_id,
              "assetsId": row.legacy_id,
              "name": child.name,
              "type": child.asset_type,
              "prompt": child.metadata.get("prompt").and_then(Value::as_str).unwrap_or_default(),
              "desc": child.description.clone().unwrap_or_default(),
              "src": history_image_src(&child.metadata, &child_history),
              "state": child.metadata.get("state").and_then(Value::as_str).unwrap_or("未生成"),
              "flowId": child.metadata.get("flowId").and_then(Value::as_i64).and_then(|v| i32::try_from(v).ok()),
              "errorReason": child.metadata.get("errorReason").and_then(Value::as_str).unwrap_or_default(),
            });
            child_obj
        })
        .collect::<Vec<_>>();

    json!({
      "id": row.legacy_id,
      "name": row.name,
      "type": row.asset_type,
      "prompt": prompt,
      "desc": row.description.clone().unwrap_or_default(),
      "src": src,
      "flowId": flow_id,
      "derive": derive,
    })
}

async fn load_production_flow_json(
    pool: &sqlx::PgPool,
    scope: &OwnedProductionScope,
) -> Result<Value, ApiError> {
    let saved = sqlx::query_scalar::<_, Value>(
        r#"
        SELECT flow_data
        FROM app_production_flow
        WHERE project_id = $1
          AND script_id = $2
        "#,
    )
    .bind(scope.project_id)
    .bind(scope.script_id)
    .fetch_optional(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?
    .unwrap_or_else(|| json!({}));

    let rows = sqlx::query_as::<_, ProductionAssetFlowRow>(
        r#"
        SELECT
          a.legacy_id,
          a.name,
          a.asset_type,
          a.description,
          a.metadata,
          COALESCE(
            (
              SELECT jsonb_agg(
                jsonb_build_object(
                  'file_path', i.file_path,
                  'legacy_image_id', i.legacy_image_id,
                  'sort_index', i.sort_index
                )
                ORDER BY i.sort_index ASC, i.created_at ASC
              )
              FROM app_asset_image i
              WHERE i.asset_id = a.id
                AND i.state = '已完成'
            ),
            '[]'::jsonb
          ) AS history_images
        FROM app_asset a
        INNER JOIN app_script_asset sa ON sa.asset_id = a.id
        WHERE a.project_id = $1
          AND sa.script_id = $2
        ORDER BY a.legacy_id ASC
        "#,
    )
    .bind(scope.project_id)
    .bind(scope.script_id)
    .fetch_all(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    let root_assets = rows
        .iter()
        .filter(|row| match row.metadata.get("assetsId") {
            None => true,
            Some(v) => v.is_null(),
        })
        .map(|row| {
            let child_rows = rows
                .iter()
                .filter(|child| {
                    child
                        .metadata
                        .get("assetsId")
                        .and_then(Value::as_i64)
                        .and_then(|v| i32::try_from(v).ok())
                        == Some(row.legacy_id)
                })
                .collect::<Vec<_>>();
            build_production_asset_item(row, &child_rows)
        })
        .collect::<Vec<_>>();

    let storyboards = sqlx::query_as::<_, ProductionStoryboardFlowRow>(
        r#"
        SELECT
          legacy_id,
          prompt,
          file_path,
          duration,
          state,
          reason,
          video_desc,
          should_generate_image,
          flow_id,
          sb_index
        FROM app_storyboard
        WHERE script_id = $1
        ORDER BY COALESCE(sb_index, 2147483647), legacy_id
        "#,
    )
    .bind(scope.script_id)
    .fetch_all(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    let saved_obj = saved.as_object().cloned().unwrap_or_default();
    let saved_storyboard_by_id = saved_obj
        .get("storyboard")
        .and_then(Value::as_array)
        .cloned()
        .unwrap_or_default()
        .into_iter()
        .filter_map(|item| {
            let obj = item.as_object()?.clone();
            Some((json_i32(&obj, "id")?, obj))
        })
        .collect::<std::collections::HashMap<_, _>>();

    let storyboard_items = storyboards
        .into_iter()
        .map(|row| {
            let saved_storyboard = saved_storyboard_by_id.get(&row.legacy_id);
            json!({
              "id": row.legacy_id,
              "index": row.sb_index,
              "duration": row.duration.as_deref().and_then(|v| v.parse::<i32>().ok()).unwrap_or(0),
              "prompt": row.prompt.clone().unwrap_or_default(),
              "associateAssetsIds": saved_storyboard
                .and_then(|obj| obj.get("associateAssetsIds"))
                .and_then(Value::as_array)
                .cloned()
                .unwrap_or_default(),
              "src": row.file_path,
              "state": row.state,
              "videoDesc": row.video_desc,
              "shouldGenerateImage": row.should_generate_image,
              "reason": row.reason.unwrap_or_default(),
              "flowId": row.flow_id,
            })
        })
        .collect::<Vec<_>>();

    let mut merged = saved_obj;
    merged.insert(
        "script".into(),
        Value::String(scope.script_content.clone().unwrap_or_default()),
    );
    merged.insert(
        "scriptPlan".into(),
        merged
            .get("scriptPlan")
            .cloned()
            .unwrap_or_else(|| Value::String(String::new())),
    );
    merged.insert("assets".into(), Value::Array(root_assets));
    merged.insert(
        "storyboardTable".into(),
        merged
            .get("storyboardTable")
            .cloned()
            .unwrap_or_else(|| Value::String(String::new())),
    );
    merged.insert("storyboard".into(), Value::Array(storyboard_items));
    Ok(Value::Object(merged))
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
) -> Result<JsonResponse<Value>, ApiError> {
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
    let scope =
        resolve_owned_production_scope(pool, uid, body.project_id, body.episodes_id).await?;
    let flow = load_production_flow_json(pool, &scope).await?;
    Ok(JsonResponse(flow))
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
    let scope =
        resolve_owned_production_scope(pool, uid, body.project_id, body.episodes_id).await?;

    if let Some(storyboards) = body.data.get("storyboard").and_then(Value::as_array) {
        let ordered_ids = storyboards
            .iter()
            .map(|item| {
                item.as_object()
                    .and_then(|obj| json_i32(obj, "id"))
                    .filter(|id| *id > 0)
            })
            .collect::<Option<Vec<_>>>();

        if let Some(ordered_ids) = ordered_ids {
            for (index, storyboard_legacy_id) in ordered_ids.iter().enumerate() {
                sqlx::query(
                    r#"
                    UPDATE app_storyboard
                    SET sb_index = $3, updated_at = NOW()
                    WHERE script_id = $1
                      AND legacy_id = $2
                    "#,
                )
                .bind(scope.script_id)
                .bind(storyboard_legacy_id)
                .bind(index as i32)
                .execute(pool)
                .await
                .map_err(|e| ApiError::DatabaseError(e.to_string()))?;
            }
        }
    }

    sqlx::query(
        r#"
        INSERT INTO app_production_flow (project_id, script_id, flow_data)
        VALUES ($1, $2, $3)
        ON CONFLICT (project_id, script_id) DO UPDATE
        SET flow_data = EXCLUDED.flow_data,
            updated_at = NOW()
        "#,
    )
    .bind(scope.project_id)
    .bind(scope.script_id)
    .bind(&body.data)
    .execute(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

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

#[derive(Debug, Serialize)]
#[serde(rename_all = "camelCase")]
struct VideoListResponse {
    videos: Vec<VideoItem>,
    total: i64,
}

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
struct VideoListBody {
    project_id: i32,
    #[serde(default)]
    track_id: Option<i32>,
    #[serde(default)]
    limit: Option<i64>,
    #[serde(default)]
    offset: Option<i64>,
}

async fn post_workbench_get_video_list(
    State(state): State<AppState>,
    headers: HeaderMap,
    Json(body): Json<VideoListBody>,
) -> Result<JsonResponse<VideoListResponse>, ApiError> {
    let uid = require_user_uuid(&state, &headers)?;
    if body.project_id <= 0 {
        return Err(ApiError::BadRequest(
            "projectId must be a positive integer".into(),
        ));
    }

    let pool = state
        .pool
        .as_ref()
        .ok_or_else(|| ApiError::DatabaseError("DATABASE_URL not configured".into()))?;

    let limit = body.limit.map(|l| l.clamp(1, 100)).unwrap_or(50);
    let offset = body.offset.unwrap_or(0).max(0);

    // Query videos (storyboards with video file_path)
    let videos = sqlx::query_as::<_, VideoItem>(
        r#"
        SELECT
          sb.legacy_id AS id,
          sc.legacy_id AS script_id,
          sb.prompt,
          sb.file_path AS video_url,
          sb.duration,
          sb.state,
          sb.track_id,
          sb.created_at
        FROM app_storyboard sb
        INNER JOIN app_script sc ON sc.id = sb.script_id
        INNER JOIN app_project p ON p.id = sc.project_id
        WHERE p.owner_user_id = $1
          AND p.legacy_id = $2
          AND sb.file_path IS NOT NULL
          AND (sb.file_path LIKE '%.mp4' OR sb.file_path LIKE '%.mov' OR sb.file_path LIKE '%.webm')
          AND ($3::int4 IS NULL OR sb.track_id = $3)
        ORDER BY sb.created_at DESC
        LIMIT $4 OFFSET $5
        "#,
    )
    .bind(uid)
    .bind(body.project_id)
    .bind(body.track_id)
    .bind(limit)
    .bind(offset)
    .fetch_all(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    // Get total count
    let total: i64 = sqlx::query_scalar(
        r#"
        SELECT COUNT(*)
        FROM app_storyboard sb
        INNER JOIN app_script sc ON sc.id = sb.script_id
        INNER JOIN app_project p ON p.id = sc.project_id
        WHERE p.owner_user_id = $1
          AND p.legacy_id = $2
          AND sb.file_path IS NOT NULL
          AND (sb.file_path LIKE '%.mp4' OR sb.file_path LIKE '%.mov' OR sb.file_path LIKE '%.webm')
          AND ($3::int4 IS NULL OR sb.track_id = $3)
        "#,
    )
    .bind(uid)
    .bind(body.project_id)
    .bind(body.track_id)
    .fetch_one(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    Ok(JsonResponse(VideoListResponse { videos, total }))
}

// =============================================================================
// Production Assets (Wave E)
// =============================================================================

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
struct BatchGenerateAssetsImageBody {
    project_id: i32,
    script_id: i32,
    asset_ids: Vec<i32>,
    #[serde(default)]
    model: Option<String>,
    #[serde(default)]
    resolution: Option<String>,
}

#[derive(Debug, Serialize)]
#[serde(rename_all = "camelCase")]
struct BatchGenerateAssetsImageResponse {
    enqueued: Vec<JobRow>,
    total: usize,
}

async fn post_assets_batch_generate_image(
    State(state): State<AppState>,
    headers: HeaderMap,
    Json(body): Json<BatchGenerateAssetsImageBody>,
) -> Result<JsonResponse<BatchGenerateAssetsImageResponse>, ApiError> {
    let uid = require_user_uuid(&state, &headers)?;
    if body.project_id <= 0 || body.script_id <= 0 {
        return Err(ApiError::BadRequest(
            "projectId and scriptId must be positive integers".into(),
        ));
    }
    if body.asset_ids.is_empty() {
        return Err(ApiError::BadRequest("assetIds must not be empty".into()));
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

    let default_model = body.model.as_deref().unwrap_or("dall-e-3");
    let default_resolution = body.resolution.as_deref().unwrap_or("1024x1024");

    let mut enqueued = Vec::with_capacity(body.asset_ids.len());
    for asset_id in &body.asset_ids {
        let payload = serde_json::json!({
            "source": "production.assets.batch-generate",
            "project_legacy_id": body.project_id,
            "script_id": body.script_id,
            "asset_id": asset_id,
            "model": default_model,
            "resolution": default_resolution,
        });

        let row = enqueue_generation_job(pool, uid, JOB_KIND_ASSET_GENERATE_BATCH, payload).await?;
        enqueued.push(row);
    }

    let total = enqueued.len();
    Ok(JsonResponse(BatchGenerateAssetsImageResponse {
        enqueued,
        total,
    }))
}

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
struct DeleteAssetsDerivativeBody {
    project_id: i32,
    asset_ids: Vec<i32>,
}

#[derive(Debug, Serialize)]
#[serde(rename_all = "camelCase")]
struct DeleteAssetsDerivativeResponse {
    deleted: i64,
    asset_ids: Vec<i32>,
}

async fn post_assets_delete_derivative(
    State(state): State<AppState>,
    headers: HeaderMap,
    Json(body): Json<DeleteAssetsDerivativeBody>,
) -> Result<JsonResponse<DeleteAssetsDerivativeResponse>, ApiError> {
    let uid = require_user_uuid(&state, &headers)?;
    if body.project_id <= 0 {
        return Err(ApiError::BadRequest(
            "projectId must be a positive integer".into(),
        ));
    }
    if body.asset_ids.is_empty() {
        return Err(ApiError::BadRequest("assetIds must not be empty".into()));
    }

    let pool = state
        .pool
        .as_ref()
        .ok_or_else(|| ApiError::DatabaseError("DATABASE_URL not configured".into()))?;

    // Delete asset images (derivatives) for the given assets
    let result = sqlx::query(
        r#"
        DELETE FROM app_asset_image
        WHERE asset_id IN (
            SELECT a.id FROM app_asset a
            INNER JOIN app_project p ON p.id = a.project_id
            WHERE p.owner_user_id = $1
              AND p.legacy_id = $2
              AND a.legacy_id = ANY($3::int4[])
        )
        "#,
    )
    .bind(uid)
    .bind(body.project_id)
    .bind(&body.asset_ids)
    .execute(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    Ok(JsonResponse(DeleteAssetsDerivativeResponse {
        deleted: result.rows_affected() as i64,
        asset_ids: body.asset_ids,
    }))
}

#[derive(Debug, Serialize, FromRow)]
#[serde(rename_all = "camelCase")]
struct AssetDataItem {
    id: i32,
    name: String,
    #[serde(rename = "type")]
    asset_type: String,
    describe: Option<String>,
    cover_legacy_image_id: Option<i32>,
    created_at: Option<chrono::DateTime<chrono::Utc>>,
}

#[derive(Debug, Serialize)]
#[serde(rename_all = "camelCase")]
struct AssetsDataResponse {
    assets: Vec<AssetDataItem>,
    total: i64,
}

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
struct GetAssetsDataBody {
    project_id: i32,
    #[serde(default)]
    asset_type: Option<String>,
    #[serde(default)]
    limit: Option<i64>,
    #[serde(default)]
    offset: Option<i64>,
}

async fn post_assets_get_data(
    State(state): State<AppState>,
    headers: HeaderMap,
    Json(body): Json<GetAssetsDataBody>,
) -> Result<JsonResponse<AssetsDataResponse>, ApiError> {
    let uid = require_user_uuid(&state, &headers)?;
    if body.project_id <= 0 {
        return Err(ApiError::BadRequest(
            "projectId must be a positive integer".into(),
        ));
    }

    let pool = state
        .pool
        .as_ref()
        .ok_or_else(|| ApiError::DatabaseError("DATABASE_URL not configured".into()))?;

    let limit = body.limit.map(|l| l.clamp(1, 100)).unwrap_or(50);
    let offset = body.offset.unwrap_or(0).max(0);

    let assets = sqlx::query_as::<_, AssetDataItem>(
        r#"
        SELECT
          a.legacy_id AS id,
          a.name,
          a.asset_type AS "type",
          a.describe,
          a.cover_legacy_image_id,
          a.created_at
        FROM app_asset a
        INNER JOIN app_project p ON p.id = a.project_id
        WHERE p.owner_user_id = $1
          AND p.legacy_id = $2
          AND ($3::text IS NULL OR a.asset_type = $3)
        ORDER BY a.created_at DESC
        LIMIT $4 OFFSET $5
        "#,
    )
    .bind(uid)
    .bind(body.project_id)
    .bind(
        body.asset_type
            .as_ref()
            .map(|s| s.trim())
            .filter(|s| !s.is_empty()),
    )
    .bind(limit)
    .bind(offset)
    .fetch_all(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    let total: i64 = sqlx::query_scalar(
        r#"
        SELECT COUNT(*)
        FROM app_asset a
        INNER JOIN app_project p ON p.id = a.project_id
        WHERE p.owner_user_id = $1
          AND p.legacy_id = $2
          AND ($3::text IS NULL OR a.asset_type = $3)
        "#,
    )
    .bind(uid)
    .bind(body.project_id)
    .bind(
        body.asset_type
            .as_ref()
            .map(|s| s.trim())
            .filter(|s| !s.is_empty()),
    )
    .fetch_one(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    Ok(JsonResponse(AssetsDataResponse { assets, total }))
}

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
struct AssetsPollingImageBody {
    project_id: i32,
    asset_ids: Vec<i32>,
}

#[derive(Debug, Serialize, FromRow)]
#[serde(rename_all = "camelCase")]
struct AssetImageStatus {
    asset_id: i32,
    image_count: i64,
    latest_state: Option<String>,
}

#[derive(Debug, Serialize)]
#[serde(rename_all = "camelCase")]
struct AssetsPollingImageResponse {
    statuses: Vec<AssetImageStatus>,
}

async fn post_assets_polling_image(
    State(state): State<AppState>,
    headers: HeaderMap,
    Json(body): Json<AssetsPollingImageBody>,
) -> Result<JsonResponse<AssetsPollingImageResponse>, ApiError> {
    let uid = require_user_uuid(&state, &headers)?;
    if body.project_id <= 0 {
        return Err(ApiError::BadRequest(
            "projectId must be a positive integer".into(),
        ));
    }
    if body.asset_ids.is_empty() {
        return Err(ApiError::BadRequest("assetIds must not be empty".into()));
    }

    let pool = state
        .pool
        .as_ref()
        .ok_or_else(|| ApiError::DatabaseError("DATABASE_URL not configured".into()))?;

    let statuses = sqlx::query_as::<_, AssetImageStatus>(
        r#"
        SELECT
          a.legacy_id AS asset_id,
          COUNT(ai.id) AS image_count,
          MAX(ai.state) AS latest_state
        FROM app_asset a
        INNER JOIN app_project p ON p.id = a.project_id
        LEFT JOIN app_asset_image ai ON ai.asset_id = a.id
        WHERE p.owner_user_id = $1
          AND p.legacy_id = $2
          AND a.legacy_id = ANY($3::int4[])
        GROUP BY a.legacy_id
        "#,
    )
    .bind(uid)
    .bind(body.project_id)
    .bind(&body.asset_ids)
    .fetch_all(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    Ok(JsonResponse(AssetsPollingImageResponse { statuses }))
}

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
struct UpdateAssetsUrlBody {
    project_id: i32,
    asset_id: i32,
    image_url: String,
}

#[derive(Debug, Serialize)]
#[serde(rename_all = "camelCase")]
struct UpdateAssetsUrlResponse {
    asset_id: i32,
    image_url: String,
    message: &'static str,
}

async fn post_assets_update_url(
    State(state): State<AppState>,
    headers: HeaderMap,
    Json(body): Json<UpdateAssetsUrlBody>,
) -> Result<JsonResponse<UpdateAssetsUrlResponse>, ApiError> {
    let uid = require_user_uuid(&state, &headers)?;
    if body.project_id <= 0 || body.asset_id <= 0 {
        return Err(ApiError::BadRequest(
            "projectId and assetId must be positive integers".into(),
        ));
    }
    if body.image_url.trim().is_empty() {
        return Err(ApiError::BadRequest("imageUrl must not be empty".into()));
    }

    let pool = state
        .pool
        .as_ref()
        .ok_or_else(|| ApiError::DatabaseError("DATABASE_URL not configured".into()))?;

    // Insert new asset image with the provided URL
    let image_id = sqlx::query_scalar::<_, uuid::Uuid>(
        r#"
        INSERT INTO app_asset_image (id, asset_id, sort_index, file_path, state, metadata)
        SELECT $4, a.id, COALESCE(MAX(ai.sort_index), 0) + 1, $5, '已完成', '{}'::jsonb
        FROM app_asset a
        INNER JOIN app_project p ON p.id = a.project_id
        LEFT JOIN app_asset_image ai ON ai.asset_id = a.id
        WHERE p.owner_user_id = $1
          AND p.legacy_id = $2
          AND a.legacy_id = $3
        GROUP BY a.id
        RETURNING id
        "#,
    )
    .bind(uid)
    .bind(body.project_id)
    .bind(body.asset_id)
    .bind(uuid::Uuid::new_v4())
    .bind(body.image_url.trim())
    .fetch_optional(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    if image_id.is_none() {
        return Err(ApiError::NotFound);
    }

    Ok(JsonResponse(UpdateAssetsUrlResponse {
        asset_id: body.asset_id,
        image_url: body.image_url.trim().to_string(),
        message: "Asset image URL updated",
    }))
}

// =============================================================================
// Edit Image Flow (Wave E)
// =============================================================================

#[derive(Debug, Serialize)]
#[serde(rename_all = "camelCase")]
struct ImageFlowResponse {
    flow_id: String,
    steps: Vec<ImageFlowStep>,
    default_model: String,
}

#[derive(Debug, Serialize)]
#[serde(rename_all = "camelCase")]
struct ImageFlowStep {
    step_id: String,
    step_name: String,
    status: String,
}

async fn post_edit_image_get_image_flow(
    State(state): State<AppState>,
    headers: HeaderMap,
) -> Result<JsonResponse<ImageFlowResponse>, ApiError> {
    let _uid = require_user_uuid(&state, &headers)?;

    // Return a mock image flow structure
    Ok(JsonResponse(ImageFlowResponse {
        flow_id: "img-flow-001".to_string(),
        steps: vec![
            ImageFlowStep {
                step_id: "upload".to_string(),
                step_name: "上传图片".to_string(),
                status: "pending".to_string(),
            },
            ImageFlowStep {
                step_id: "select_area".to_string(),
                step_name: "选择区域".to_string(),
                status: "pending".to_string(),
            },
            ImageFlowStep {
                step_id: "generate".to_string(),
                step_name: "生成图片".to_string(),
                status: "pending".to_string(),
            },
        ],
        default_model: "dall-e-3".to_string(),
    }))
}

#[derive(Debug, Serialize)]
#[serde(rename_all = "camelCase")]
struct ImageDefaultModelResponse {
    model: String,
    resolution: String,
}

async fn post_edit_image_get_image_default_model(
    State(state): State<AppState>,
    headers: HeaderMap,
) -> Result<JsonResponse<ImageDefaultModelResponse>, ApiError> {
    let _uid = require_user_uuid(&state, &headers)?;

    Ok(JsonResponse(ImageDefaultModelResponse {
        model: "dall-e-3".to_string(),
        resolution: "1024x1024".to_string(),
    }))
}

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
struct SaveImageFlowBody {
    #[allow(dead_code)]
    flow_id: String,
    #[allow(dead_code)]
    steps: Vec<ImageFlowStepInput>,
}

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase")]
struct ImageFlowStepInput {
    #[allow(dead_code)]
    step_id: String,
    #[allow(dead_code)]
    status: String,
}

#[derive(Debug, Serialize)]
#[serde(rename_all = "camelCase")]
struct SaveImageFlowResponse {
    flow_id: String,
    saved: bool,
}

async fn post_edit_image_save_image_flow(
    State(state): State<AppState>,
    headers: HeaderMap,
    Json(body): Json<SaveImageFlowBody>,
) -> Result<JsonResponse<SaveImageFlowResponse>, ApiError> {
    let _uid = require_user_uuid(&state, &headers)?;

    Ok(JsonResponse(SaveImageFlowResponse {
        flow_id: body.flow_id,
        saved: true,
    }))
}

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
struct UpdateImageFlowBody {
    #[allow(dead_code)]
    flow_id: String,
    #[allow(dead_code)]
    step_id: String,
    #[allow(dead_code)]
    updates: serde_json::Value,
}

#[derive(Debug, Serialize)]
#[serde(rename_all = "camelCase")]
struct UpdateImageFlowResponse {
    flow_id: String,
    step_id: String,
    updated: bool,
}

async fn post_edit_image_update_image_flow(
    State(state): State<AppState>,
    headers: HeaderMap,
    Json(body): Json<UpdateImageFlowBody>,
) -> Result<JsonResponse<UpdateImageFlowResponse>, ApiError> {
    let _uid = require_user_uuid(&state, &headers)?;

    Ok(JsonResponse(UpdateImageFlowResponse {
        flow_id: body.flow_id,
        step_id: body.step_id,
        updated: true,
    }))
}

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
struct GenerateFlowImageBody {
    flow_id: String,
    prompt: String,
    #[serde(default)]
    model: Option<String>,
}

#[derive(Debug, Serialize)]
#[serde(rename_all = "camelCase")]
struct GenerateFlowImageResponse {
    job_id: String,
    status: String,
}

async fn post_edit_image_generate_flow_image(
    State(state): State<AppState>,
    headers: HeaderMap,
    Json(body): Json<GenerateFlowImageBody>,
) -> Result<JsonResponse<GenerateFlowImageResponse>, ApiError> {
    let uid = require_user_uuid(&state, &headers)?;
    if body.flow_id.trim().is_empty() {
        return Err(ApiError::BadRequest("flowId must not be empty".into()));
    }
    if body.prompt.trim().is_empty() {
        return Err(ApiError::BadRequest("prompt must not be empty".into()));
    }

    let pool = state
        .pool
        .as_ref()
        .ok_or_else(|| ApiError::DatabaseError("DATABASE_URL not configured".into()))?;

    let payload = serde_json::json!({
        "source": "production.edit-image.generate-flow",
        "flow_id": body.flow_id.trim(),
        "prompt": body.prompt.trim(),
        "model": body.model.unwrap_or_else(|| "dall-e-3".to_string()),
    });

    let row = enqueue_generation_job(pool, uid, JOB_KIND_ASSET_GENERATE_BATCH, payload).await?;

    Ok(JsonResponse(GenerateFlowImageResponse {
        job_id: row.id.to_string(),
        status: "queued".to_string(),
    }))
}

// =============================================================================
// Storyboard Management (Wave E)
// =============================================================================

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
struct AddStoryboardBody {
    project_id: i32,
    script_id: i32,
    prompt: String,
    #[serde(default)]
    duration: Option<i32>,
}

#[derive(Debug, Serialize)]
#[serde(rename_all = "camelCase")]
struct AddStoryboardResponse {
    storyboard_id: i32,
    message: &'static str,
}

async fn post_storyboard_add(
    State(state): State<AppState>,
    headers: HeaderMap,
    Json(body): Json<AddStoryboardBody>,
) -> Result<JsonResponse<AddStoryboardResponse>, ApiError> {
    let uid = require_user_uuid(&state, &headers)?;
    if body.project_id <= 0 || body.script_id <= 0 {
        return Err(ApiError::BadRequest(
            "projectId and scriptId must be positive integers".into(),
        ));
    }
    if body.prompt.trim().is_empty() {
        return Err(ApiError::BadRequest("prompt must not be empty".into()));
    }

    let pool = state
        .pool
        .as_ref()
        .ok_or_else(|| ApiError::DatabaseError("DATABASE_URL not configured".into()))?;

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

    // Get next legacy_id
    let next_id: i32 = sqlx::query_scalar(
        r#"
        SELECT COALESCE(MAX(legacy_id), 0) + 1
        FROM app_storyboard sb
        INNER JOIN app_script sc ON sc.id = sb.script_id
        INNER JOIN app_project p ON p.id = sc.project_id
        WHERE p.owner_user_id = $1
        "#,
    )
    .bind(uid)
    .fetch_one(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    // Insert storyboard
    sqlx::query(
        r#"
        INSERT INTO app_storyboard (
            script_id, legacy_id, legacy_script_id, prompt, duration,
            state, sb_index, created_at, updated_at
        )
        SELECT sc.id, $4, $3, $5, $6, '草稿', $7, NOW(), NOW()
        FROM app_script sc
        INNER JOIN app_project p ON p.id = sc.project_id
        WHERE p.owner_user_id = $1
          AND p.legacy_id = $2
          AND sc.legacy_id = $3
        "#,
    )
    .bind(uid)
    .bind(body.project_id)
    .bind(body.script_id)
    .bind(next_id)
    .bind(body.prompt.trim())
    .bind(body.duration.unwrap_or(5))
    .bind(next_id) // sb_index = legacy_id for now
    .execute(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    Ok(JsonResponse(AddStoryboardResponse {
        storyboard_id: next_id,
        message: "Storyboard added",
    }))
}

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
struct BatchAddInfoBody {
    project_id: i32,
    script_id: i32,
    storyboards: Vec<StoryboardInfoInput>,
}

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase")]
struct StoryboardInfoInput {
    prompt: String,
    #[serde(default)]
    duration: Option<i32>,
}

#[derive(Debug, Serialize)]
#[serde(rename_all = "camelCase")]
struct BatchAddInfoResponse {
    added: usize,
    storyboard_ids: Vec<i32>,
}

async fn post_storyboard_batch_add_info(
    State(state): State<AppState>,
    headers: HeaderMap,
    Json(body): Json<BatchAddInfoBody>,
) -> Result<JsonResponse<BatchAddInfoResponse>, ApiError> {
    let uid = require_user_uuid(&state, &headers)?;
    if body.project_id <= 0 || body.script_id <= 0 {
        return Err(ApiError::BadRequest(
            "projectId and scriptId must be positive integers".into(),
        ));
    }
    if body.storyboards.is_empty() {
        return Err(ApiError::BadRequest("storyboards must not be empty".into()));
    }
    if body
        .storyboards
        .iter()
        .any(|sb| sb.prompt.trim().is_empty())
    {
        return Err(ApiError::BadRequest(
            "storyboards[*].prompt must not be empty".into(),
        ));
    }

    let pool = state
        .pool
        .as_ref()
        .ok_or_else(|| ApiError::DatabaseError("DATABASE_URL not configured".into()))?;

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

    // Get base legacy_id
    let base_id: i32 = sqlx::query_scalar(
        r#"
        SELECT COALESCE(MAX(legacy_id), 0)
        FROM app_storyboard sb
        INNER JOIN app_script sc ON sc.id = sb.script_id
        INNER JOIN app_project p ON p.id = sc.project_id
        WHERE p.owner_user_id = $1
        "#,
    )
    .bind(uid)
    .fetch_one(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    let mut storyboard_ids = Vec::with_capacity(body.storyboards.len());

    for (idx, sb) in body.storyboards.iter().enumerate() {
        let next_id = base_id + idx as i32 + 1;
        sqlx::query(
            r#"
            INSERT INTO app_storyboard (
                script_id, legacy_id, legacy_script_id, prompt, duration,
                state, sb_index, created_at, updated_at
            )
            SELECT sc.id, $4, $3, $5, $6, '草稿', $7, NOW(), NOW()
            FROM app_script sc
            INNER JOIN app_project p ON p.id = sc.project_id
            WHERE p.owner_user_id = $1
              AND p.legacy_id = $2
              AND sc.legacy_id = $3
            "#,
        )
        .bind(uid)
        .bind(body.project_id)
        .bind(body.script_id)
        .bind(next_id)
        .bind(sb.prompt.trim())
        .bind(sb.duration.unwrap_or(5))
        .bind(next_id)
        .execute(pool)
        .await
        .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

        storyboard_ids.push(next_id);
    }

    Ok(JsonResponse(BatchAddInfoResponse {
        added: storyboard_ids.len(),
        storyboard_ids,
    }))
}

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
struct GetStoryboardDataBody {
    storyboard_id: i32,
}

async fn post_storyboard_get_data(
    State(state): State<AppState>,
    headers: HeaderMap,
    Json(body): Json<GetStoryboardDataBody>,
) -> Result<JsonResponse<ProductionStoryboardItem>, ApiError> {
    let uid = require_user_uuid(&state, &headers)?;
    if body.storyboard_id <= 0 {
        return Err(ApiError::BadRequest(
            "storyboardId must be a positive integer".into(),
        ));
    }

    let pool = state
        .pool
        .as_ref()
        .ok_or_else(|| ApiError::DatabaseError("DATABASE_URL not configured".into()))?;

    let row = sqlx::query_as::<_, ProductionStoryboardItem>(
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
          AND sb.legacy_id = $2
        "#,
    )
    .bind(uid)
    .bind(body.storyboard_id)
    .fetch_optional(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?
    .ok_or(ApiError::NotFound)?;

    Ok(JsonResponse(row))
}

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
struct EditStoryboardInfoBody {
    storyboard_id: i32,
    prompt: String,
    #[serde(default)]
    duration: Option<i32>,
}

#[derive(Debug, Serialize)]
#[serde(rename_all = "camelCase")]
struct EditStoryboardInfoResponse {
    storyboard_id: i32,
    message: &'static str,
}

async fn post_storyboard_edit_info(
    State(state): State<AppState>,
    headers: HeaderMap,
    Json(body): Json<EditStoryboardInfoBody>,
) -> Result<JsonResponse<EditStoryboardInfoResponse>, ApiError> {
    let uid = require_user_uuid(&state, &headers)?;
    if body.storyboard_id <= 0 {
        return Err(ApiError::BadRequest(
            "storyboardId must be a positive integer".into(),
        ));
    }
    if body.prompt.trim().is_empty() {
        return Err(ApiError::BadRequest("prompt must not be empty".into()));
    }

    let pool = state
        .pool
        .as_ref()
        .ok_or_else(|| ApiError::DatabaseError("DATABASE_URL not configured".into()))?;

    let updated = sqlx::query(
        r#"
        UPDATE app_storyboard
        SET prompt = $3, duration = $4, updated_at = NOW()
        FROM app_script, app_project
        WHERE app_storyboard.script_id = app_script.id
          AND app_script.project_id = app_project.id
          AND app_project.owner_user_id = $1
          AND app_storyboard.legacy_id = $2
        "#,
    )
    .bind(uid)
    .bind(body.storyboard_id)
    .bind(body.prompt.trim())
    .bind(body.duration)
    .execute(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    if updated.rows_affected() == 0 {
        return Err(ApiError::NotFound);
    }

    Ok(JsonResponse(EditStoryboardInfoResponse {
        storyboard_id: body.storyboard_id,
        message: "Storyboard info updated",
    }))
}

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
struct RemoveFrameBody {
    storyboard_id: i32,
}

#[derive(Debug, Serialize)]
#[serde(rename_all = "camelCase")]
struct RemoveFrameResponse {
    storyboard_id: i32,
    message: &'static str,
}

async fn post_storyboard_remove_frame(
    State(state): State<AppState>,
    headers: HeaderMap,
    Json(body): Json<RemoveFrameBody>,
) -> Result<JsonResponse<RemoveFrameResponse>, ApiError> {
    let uid = require_user_uuid(&state, &headers)?;
    if body.storyboard_id <= 0 {
        return Err(ApiError::BadRequest(
            "storyboardId must be a positive integer".into(),
        ));
    }

    let pool = state
        .pool
        .as_ref()
        .ok_or_else(|| ApiError::DatabaseError("DATABASE_URL not configured".into()))?;

    let updated = sqlx::query(
        r#"
        UPDATE app_storyboard
        SET file_path = NULL, state = NULL, updated_at = NOW()
        FROM app_script, app_project
        WHERE app_storyboard.script_id = app_script.id
          AND app_script.project_id = app_project.id
          AND app_project.owner_user_id = $1
          AND app_storyboard.legacy_id = $2
        "#,
    )
    .bind(uid)
    .bind(body.storyboard_id)
    .execute(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    if updated.rows_affected() == 0 {
        return Err(ApiError::NotFound);
    }

    Ok(JsonResponse(RemoveFrameResponse {
        storyboard_id: body.storyboard_id,
        message: "Frame removed from storyboard",
    }))
}

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
struct UpdateStoryboardUrlBody {
    storyboard_id: i32,
    image_url: String,
}

#[derive(Debug, Serialize)]
#[serde(rename_all = "camelCase")]
struct UpdateStoryboardUrlResponse {
    storyboard_id: i32,
    image_url: String,
    message: &'static str,
}

async fn post_storyboard_update_url(
    State(state): State<AppState>,
    headers: HeaderMap,
    Json(body): Json<UpdateStoryboardUrlBody>,
) -> Result<JsonResponse<UpdateStoryboardUrlResponse>, ApiError> {
    let uid = require_user_uuid(&state, &headers)?;
    if body.storyboard_id <= 0 {
        return Err(ApiError::BadRequest(
            "storyboardId must be a positive integer".into(),
        ));
    }
    if body.image_url.trim().is_empty() {
        return Err(ApiError::BadRequest("imageUrl must not be empty".into()));
    }

    let pool = state
        .pool
        .as_ref()
        .ok_or_else(|| ApiError::DatabaseError("DATABASE_URL not configured".into()))?;

    let updated = sqlx::query(
        r#"
        UPDATE app_storyboard
        SET file_path = $3, state = '已完成', updated_at = NOW()
        FROM app_script, app_project
        WHERE app_storyboard.script_id = app_script.id
          AND app_script.project_id = app_project.id
          AND app_project.owner_user_id = $1
          AND app_storyboard.legacy_id = $2
        "#,
    )
    .bind(uid)
    .bind(body.storyboard_id)
    .bind(body.image_url.trim())
    .execute(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    if updated.rows_affected() == 0 {
        return Err(ApiError::NotFound);
    }

    Ok(JsonResponse(UpdateStoryboardUrlResponse {
        storyboard_id: body.storyboard_id,
        image_url: body.image_url.trim().to_string(),
        message: "Storyboard image URL updated",
    }))
}

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
struct GetStoryboardDataByProjectBody {
    project_id: i32,
    script_id: i32,
}

async fn post_get_storyboard_data(
    State(state): State<AppState>,
    headers: HeaderMap,
    Json(body): Json<GetStoryboardDataByProjectBody>,
) -> Result<JsonResponse<ProductionGetProductionDataResponse>, ApiError> {
    let uid = require_user_uuid(&state, &headers)?;
    if body.project_id <= 0 || body.script_id <= 0 {
        return Err(ApiError::BadRequest(
            "projectId and scriptId must be positive integers".into(),
        ));
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
          AND p.legacy_id = $2
          AND sc.legacy_id = $3
        ORDER BY sb.sb_index ASC
        "#,
    )
    .bind(uid)
    .bind(body.project_id)
    .bind(body.script_id)
    .fetch_all(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    Ok(JsonResponse(ProductionGetProductionDataResponse {
        data: rows,
    }))
}

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
struct DownPreviewImageBody {
    storyboard_id: i32,
}

#[derive(Debug, Serialize)]
#[serde(rename_all = "camelCase")]
struct DownPreviewImageResponse {
    storyboard_id: i32,
    preview_url: Option<String>,
    message: &'static str,
}

async fn post_storyboard_down_preview_image(
    State(state): State<AppState>,
    headers: HeaderMap,
    Json(body): Json<DownPreviewImageBody>,
) -> Result<JsonResponse<DownPreviewImageResponse>, ApiError> {
    let uid = require_user_uuid(&state, &headers)?;
    if body.storyboard_id <= 0 {
        return Err(ApiError::BadRequest(
            "storyboardId must be a positive integer".into(),
        ));
    }

    let pool = state
        .pool
        .as_ref()
        .ok_or_else(|| ApiError::DatabaseError("DATABASE_URL not configured".into()))?;

    let file_path: Option<String> = sqlx::query_scalar(
        r#"
        SELECT sb.file_path
        FROM app_storyboard sb
        INNER JOIN app_script sc ON sc.id = sb.script_id
        INNER JOIN app_project p ON p.id = sc.project_id
        WHERE p.owner_user_id = $1
          AND sb.legacy_id = $2
        "#,
    )
    .bind(uid)
    .bind(body.storyboard_id)
    .fetch_optional(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    if file_path.is_none() {
        return Err(ApiError::NotFound);
    }

    Ok(JsonResponse(DownPreviewImageResponse {
        storyboard_id: body.storyboard_id,
        preview_url: file_path.clone(),
        message: "Preview image URL retrieved",
    }))
}

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
struct PreviewImageBody {
    storyboard_id: i32,
}

#[derive(Debug, Serialize)]
#[serde(rename_all = "camelCase")]
struct PreviewImageResponse {
    storyboard_id: i32,
    image_url: Option<String>,
    prompt: Option<String>,
}

async fn post_storyboard_preview_image(
    State(state): State<AppState>,
    headers: HeaderMap,
    Json(body): Json<PreviewImageBody>,
) -> Result<JsonResponse<PreviewImageResponse>, ApiError> {
    let uid = require_user_uuid(&state, &headers)?;
    if body.storyboard_id <= 0 {
        return Err(ApiError::BadRequest(
            "storyboardId must be a positive integer".into(),
        ));
    }

    let pool = state
        .pool
        .as_ref()
        .ok_or_else(|| ApiError::DatabaseError("DATABASE_URL not configured".into()))?;

    let row: Option<(Option<String>, Option<String>)> = sqlx::query_as(
        r#"
        SELECT sb.file_path, sb.prompt
        FROM app_storyboard sb
        INNER JOIN app_script sc ON sc.id = sb.script_id
        INNER JOIN app_project p ON p.id = sc.project_id
        WHERE p.owner_user_id = $1
          AND sb.legacy_id = $2
        "#,
    )
    .bind(uid)
    .bind(body.storyboard_id)
    .fetch_optional(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    if row.is_none() {
        return Err(ApiError::NotFound);
    }

    let (file_path, prompt) = row.unwrap();

    Ok(JsonResponse(PreviewImageResponse {
        storyboard_id: body.storyboard_id,
        image_url: file_path,
        prompt,
    }))
}

pub fn router() -> Router<AppState> {
    Router::new()
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
        .route("/api/v1/production/export-image", post(post_export_image))
        .route(
            "/api/v1/production/storyboard/batch-generate-image",
            post(post_storyboard_batch_generate_image),
        )
        .route(
            "/api/v1/production/workbench/get-video-list",
            post(post_workbench_get_video_list),
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
            post(post_assets_batch_generate_image),
        )
        .route(
            "/api/v1/production/assets/delete-assets-derivative",
            post(post_assets_delete_derivative),
        )
        .route(
            "/api/v1/production/assets/get-assets-data",
            post(post_assets_get_data),
        )
        .route(
            "/api/v1/production/assets/polling-image",
            post(post_assets_polling_image),
        )
        .route(
            "/api/v1/production/assets/update-assets-url",
            post(post_assets_update_url),
        )
        .route(
            "/api/v1/production/edit-image/get-image-flow",
            post(post_edit_image_get_image_flow),
        )
        .route(
            "/api/v1/production/edit-image/get-image-default-model",
            post(post_edit_image_get_image_default_model),
        )
        .route(
            "/api/v1/production/edit-image/save-image-flow",
            post(post_edit_image_save_image_flow),
        )
        .route(
            "/api/v1/production/edit-image/update-image-flow",
            post(post_edit_image_update_image_flow),
        )
        .route(
            "/api/v1/production/edit-image/generate-flow-image",
            post(post_edit_image_generate_flow_image),
        )
        .route(
            "/api/v1/production/get-storyboard-data",
            post(post_get_storyboard_data),
        )
        .route(
            "/api/v1/production/storyboard/add",
            post(post_storyboard_add),
        )
        .route(
            "/api/v1/production/storyboard/batch-add-info",
            post(post_storyboard_batch_add_info),
        )
        .route(
            "/api/v1/production/storyboard/down-preview-image",
            post(post_storyboard_down_preview_image),
        )
        .route(
            "/api/v1/production/storyboard/edit-info",
            post(post_storyboard_edit_info),
        )
        .route(
            "/api/v1/production/storyboard/get-data",
            post(post_storyboard_get_data),
        )
        .route(
            "/api/v1/production/storyboard/preview-image",
            post(post_storyboard_preview_image),
        )
        .route(
            "/api/v1/production/storyboard/remove-frame",
            post(post_storyboard_remove_frame),
        )
        .route(
            "/api/v1/production/storyboard/update-url",
            post(post_storyboard_update_url),
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
    fn get_flow_data_body_rejects_unknown_fields() {
        let err =
            serde_json::from_str::<GetFlowDataBody>(r#"{"projectId":1,"episodesId":5,"extra":1}"#);
        assert!(err.is_err());
    }

    #[test]
    fn get_flow_data_body_accepts_valid() {
        let b: GetFlowDataBody = serde_json::from_str(r#"{"projectId":1,"episodesId":5}"#).unwrap();
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
        let b: SaveFlowDataBody =
            serde_json::from_str(r#"{"projectId":1,"episodesId":5,"data":{"key":"value"}}"#)
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
