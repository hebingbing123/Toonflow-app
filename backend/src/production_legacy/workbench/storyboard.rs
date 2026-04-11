use axum::{
    extract::{Json, State},
    http::HeaderMap,
    Json as JsonResponse,
};
use serde::{Deserialize, Serialize};

use super::storyboard_ops::{ProductionGetProductionDataResponse, ProductionStoryboardItem};
use crate::auth::require_user_uuid;
use crate::error::ApiError;
use crate::state::AppState;

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
pub(in crate::production_legacy) struct AddStoryboardBody {
    project_id: i32,
    script_id: i32,
    prompt: String,
    #[serde(default)]
    duration: Option<i32>,
}

#[derive(Debug, Serialize)]
#[serde(rename_all = "camelCase")]
pub(in crate::production_legacy) struct AddStoryboardResponse {
    storyboard_id: i32,
    message: &'static str,
}

pub(in crate::production_legacy) async fn post_storyboard_add(
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
pub(in crate::production_legacy) struct BatchAddInfoBody {
    project_id: i32,
    script_id: i32,
    storyboards: Vec<StoryboardInfoInput>,
}

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase")]
pub(in crate::production_legacy) struct StoryboardInfoInput {
    prompt: String,
    #[serde(default)]
    duration: Option<i32>,
}

#[derive(Debug, Serialize)]
#[serde(rename_all = "camelCase")]
pub(in crate::production_legacy) struct BatchAddInfoResponse {
    added: usize,
    storyboard_ids: Vec<i32>,
}

pub(in crate::production_legacy) async fn post_storyboard_batch_add_info(
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
pub(in crate::production_legacy) struct GetStoryboardDataBody {
    storyboard_id: i32,
}

pub(in crate::production_legacy) async fn post_storyboard_get_data(
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
pub(in crate::production_legacy) struct EditStoryboardInfoBody {
    storyboard_id: i32,
    prompt: String,
    #[serde(default)]
    duration: Option<i32>,
}

#[derive(Debug, Serialize)]
#[serde(rename_all = "camelCase")]
pub(in crate::production_legacy) struct EditStoryboardInfoResponse {
    storyboard_id: i32,
    message: &'static str,
}

pub(in crate::production_legacy) async fn post_storyboard_edit_info(
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
pub(in crate::production_legacy) struct RemoveFrameBody {
    storyboard_id: i32,
}

#[derive(Debug, Serialize)]
#[serde(rename_all = "camelCase")]
pub(in crate::production_legacy) struct RemoveFrameResponse {
    storyboard_id: i32,
    message: &'static str,
}

pub(in crate::production_legacy) async fn post_storyboard_remove_frame(
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
pub(in crate::production_legacy) struct UpdateStoryboardUrlBody {
    storyboard_id: i32,
    image_url: String,
}

#[derive(Debug, Serialize)]
#[serde(rename_all = "camelCase")]
pub(in crate::production_legacy) struct UpdateStoryboardUrlResponse {
    storyboard_id: i32,
    image_url: String,
    message: &'static str,
}

pub(in crate::production_legacy) async fn post_storyboard_update_url(
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
pub(in crate::production_legacy) struct GetStoryboardDataByProjectBody {
    project_id: i32,
    script_id: i32,
}

pub(in crate::production_legacy) async fn post_get_storyboard_data(
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
pub(in crate::production_legacy) struct DownPreviewImageBody {
    storyboard_id: i32,
}

#[derive(Debug, Serialize)]
#[serde(rename_all = "camelCase")]
pub(in crate::production_legacy) struct DownPreviewImageResponse {
    storyboard_id: i32,
    preview_url: Option<String>,
    message: &'static str,
}

pub(in crate::production_legacy) async fn post_storyboard_down_preview_image(
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
pub(in crate::production_legacy) struct PreviewImageBody {
    storyboard_id: i32,
}

#[derive(Debug, Serialize)]
#[serde(rename_all = "camelCase")]
pub(in crate::production_legacy) struct PreviewImageResponse {
    storyboard_id: i32,
    image_url: Option<String>,
    prompt: Option<String>,
}

pub(in crate::production_legacy) async fn post_storyboard_preview_image(
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
