use axum::{
    extract::{Json, State},
    http::HeaderMap,
    Json as JsonResponse,
};
use serde::{Deserialize, Serialize};

use super::storyboard_ops::{ProductionGetProductionDataResponse, ProductionStoryboardItem};
use crate::auth::require_user_uuid;
use crate::error::ApiError;
use crate::narrative::storyboards::ADV_LOCK_STORYBOARD_NUMERIC_ID;
use crate::scope;
use crate::state::AppState;

fn require_positive_scope_ids(
    project_id: i32,
    script_id: i32,
    storyboard_id: i32,
) -> Result<(), ApiError> {
    if project_id <= 0 || script_id <= 0 || storyboard_id <= 0 {
        return Err(ApiError::BadRequest(
            "projectId, scriptId, and storyboardId must be positive integers".into(),
        ));
    }
    Ok(())
}

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
pub(in crate::production) struct AddStoryboardBody {
    project_id: i32,
    script_id: i32,
    prompt: String,
    #[serde(default)]
    duration: Option<i32>,
}

#[derive(Debug, Serialize)]
#[serde(rename_all = "camelCase")]
pub(in crate::production) struct AddStoryboardResponse {
    storyboard_id: i32,
    message: &'static str,
}

pub(in crate::production) async fn post_storyboard_add(
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

    let scope_row = scope::owned_script_scope(pool, uid, body.project_id, body.script_id)
        .await
        .map_err(|e| e.into_api_error())?;

    let mut tx = pool
        .begin()
        .await
        .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    sqlx::query("SELECT pg_advisory_xact_lock($1)")
        .bind(ADV_LOCK_STORYBOARD_NUMERIC_ID)
        .execute(&mut *tx)
        .await
        .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    let next_id: i32 = sqlx::query_scalar(
        r#"
        SELECT COALESCE(MAX(numeric_id), 0) + 1
        FROM app_storyboard
        "#,
    )
    .fetch_one(&mut *tx)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    sqlx::query(
        r#"
        INSERT INTO app_storyboard (
            script_id, numeric_id, numeric_script_id, prompt, duration,
            state, sb_index, created_at, updated_at
        )
        VALUES ($1, $2, $3, $4, $5, '草稿', $6, NOW(), NOW())
        "#,
    )
    .bind(scope_row.script_id)
    .bind(next_id)
    .bind(body.script_id)
    .bind(body.prompt.trim())
    .bind(body.duration.unwrap_or(5))
    .bind(next_id)
    .execute(&mut *tx)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    tx.commit()
        .await
        .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    Ok(JsonResponse(AddStoryboardResponse {
        storyboard_id: next_id,
        message: "Storyboard added",
    }))
}

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
pub(in crate::production) struct BatchAddInfoBody {
    project_id: i32,
    script_id: i32,
    storyboards: Vec<StoryboardInfoInput>,
}

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase")]
pub(in crate::production) struct StoryboardInfoInput {
    prompt: String,
    #[serde(default)]
    duration: Option<i32>,
}

#[derive(Debug, Serialize)]
#[serde(rename_all = "camelCase")]
pub(in crate::production) struct BatchAddInfoResponse {
    added: usize,
    storyboard_ids: Vec<i32>,
}

pub(in crate::production) async fn post_storyboard_batch_add_info(
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

    let scope_row = scope::owned_script_scope(pool, uid, body.project_id, body.script_id)
        .await
        .map_err(|e| e.into_api_error())?;

    let mut tx = pool
        .begin()
        .await
        .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    sqlx::query("SELECT pg_advisory_xact_lock($1)")
        .bind(ADV_LOCK_STORYBOARD_NUMERIC_ID)
        .execute(&mut *tx)
        .await
        .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    let base_id: i32 =
        sqlx::query_scalar(r#"SELECT COALESCE(MAX(numeric_id), 0) FROM app_storyboard"#)
            .fetch_one(&mut *tx)
            .await
            .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    let mut storyboard_ids = Vec::with_capacity(body.storyboards.len());

    for (idx, sb) in body.storyboards.iter().enumerate() {
        let next_id = base_id + idx as i32 + 1;
        sqlx::query(
            r#"
            INSERT INTO app_storyboard (
                script_id, numeric_id, numeric_script_id, prompt, duration,
                state, sb_index, created_at, updated_at
            )
            VALUES ($1, $2, $3, $4, $5, '草稿', $6, NOW(), NOW())
            "#,
        )
        .bind(scope_row.script_id)
        .bind(next_id)
        .bind(body.script_id)
        .bind(sb.prompt.trim())
        .bind(sb.duration.unwrap_or(5))
        .bind(next_id)
        .execute(&mut *tx)
        .await
        .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

        storyboard_ids.push(next_id);
    }

    tx.commit()
        .await
        .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    Ok(JsonResponse(BatchAddInfoResponse {
        added: storyboard_ids.len(),
        storyboard_ids,
    }))
}

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
pub(in crate::production) struct GetStoryboardDataBody {
    project_id: i32,
    script_id: i32,
    storyboard_id: i32,
}

pub(in crate::production) async fn post_storyboard_get_data(
    State(state): State<AppState>,
    headers: HeaderMap,
    Json(body): Json<GetStoryboardDataBody>,
) -> Result<JsonResponse<ProductionStoryboardItem>, ApiError> {
    let uid = require_user_uuid(&state, &headers)?;
    require_positive_scope_ids(body.project_id, body.script_id, body.storyboard_id)?;

    let pool = state
        .pool
        .as_ref()
        .ok_or_else(|| ApiError::DatabaseError("DATABASE_URL not configured".into()))?;

    let sb = scope::owned_storyboard_in_script_scope(
        pool,
        uid,
        body.project_id,
        body.script_id,
        body.storyboard_id,
    )
    .await
    .map_err(|e| e.into_api_error())?;

    let row = sqlx::query_as::<_, ProductionStoryboardItem>(
        r#"
        SELECT
          sb.numeric_id AS id,
          sb.numeric_script_id AS script_id,
          sb.prompt,
          sb.file_path AS url,
          sb.duration,
          sb.state,
          sb.track_id,
          sb.flow_id,
          sb.sb_index
        FROM app_storyboard sb
        WHERE sb.id = $1
        "#,
    )
    .bind(sb.storyboard_id)
    .fetch_optional(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?
    .ok_or(ApiError::NotFound)?;

    Ok(JsonResponse(row))
}

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
pub(in crate::production) struct EditStoryboardInfoBody {
    project_id: i32,
    script_id: i32,
    storyboard_id: i32,
    prompt: String,
    #[serde(default)]
    duration: Option<i32>,
}

#[derive(Debug, Serialize)]
#[serde(rename_all = "camelCase")]
pub(in crate::production) struct EditStoryboardInfoResponse {
    storyboard_id: i32,
    message: &'static str,
}

pub(in crate::production) async fn post_storyboard_edit_info(
    State(state): State<AppState>,
    headers: HeaderMap,
    Json(body): Json<EditStoryboardInfoBody>,
) -> Result<JsonResponse<EditStoryboardInfoResponse>, ApiError> {
    let uid = require_user_uuid(&state, &headers)?;
    require_positive_scope_ids(body.project_id, body.script_id, body.storyboard_id)?;
    if body.prompt.trim().is_empty() {
        return Err(ApiError::BadRequest("prompt must not be empty".into()));
    }

    let pool = state
        .pool
        .as_ref()
        .ok_or_else(|| ApiError::DatabaseError("DATABASE_URL not configured".into()))?;

    let sb = scope::owned_storyboard_in_script_scope(
        pool,
        uid,
        body.project_id,
        body.script_id,
        body.storyboard_id,
    )
    .await
    .map_err(|e| e.into_api_error())?;

    let updated = sqlx::query(
        r#"
        UPDATE app_storyboard
        SET prompt = $2, duration = $3, updated_at = NOW()
        WHERE id = $1
        "#,
    )
    .bind(sb.storyboard_id)
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
pub(in crate::production) struct RemoveFrameBody {
    project_id: i32,
    script_id: i32,
    storyboard_id: i32,
}

#[derive(Debug, Serialize)]
#[serde(rename_all = "camelCase")]
pub(in crate::production) struct RemoveFrameResponse {
    storyboard_id: i32,
    message: &'static str,
}

pub(in crate::production) async fn post_storyboard_remove_frame(
    State(state): State<AppState>,
    headers: HeaderMap,
    Json(body): Json<RemoveFrameBody>,
) -> Result<JsonResponse<RemoveFrameResponse>, ApiError> {
    let uid = require_user_uuid(&state, &headers)?;
    require_positive_scope_ids(body.project_id, body.script_id, body.storyboard_id)?;

    let pool = state
        .pool
        .as_ref()
        .ok_or_else(|| ApiError::DatabaseError("DATABASE_URL not configured".into()))?;

    let sb = scope::owned_storyboard_in_script_scope(
        pool,
        uid,
        body.project_id,
        body.script_id,
        body.storyboard_id,
    )
    .await
    .map_err(|e| e.into_api_error())?;

    let updated = sqlx::query(
        r#"
        UPDATE app_storyboard
        SET file_path = NULL, state = NULL, updated_at = NOW()
        WHERE id = $1
        "#,
    )
    .bind(sb.storyboard_id)
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
pub(in crate::production) struct UpdateStoryboardUrlBody {
    project_id: i32,
    script_id: i32,
    storyboard_id: i32,
    image_url: String,
}

#[derive(Debug, Serialize)]
#[serde(rename_all = "camelCase")]
pub(in crate::production) struct UpdateStoryboardUrlResponse {
    storyboard_id: i32,
    image_url: String,
    message: &'static str,
}

pub(in crate::production) async fn post_storyboard_update_url(
    State(state): State<AppState>,
    headers: HeaderMap,
    Json(body): Json<UpdateStoryboardUrlBody>,
) -> Result<JsonResponse<UpdateStoryboardUrlResponse>, ApiError> {
    let uid = require_user_uuid(&state, &headers)?;
    require_positive_scope_ids(body.project_id, body.script_id, body.storyboard_id)?;
    if body.image_url.trim().is_empty() {
        return Err(ApiError::BadRequest("imageUrl must not be empty".into()));
    }

    let pool = state
        .pool
        .as_ref()
        .ok_or_else(|| ApiError::DatabaseError("DATABASE_URL not configured".into()))?;

    let sb = scope::owned_storyboard_in_script_scope(
        pool,
        uid,
        body.project_id,
        body.script_id,
        body.storyboard_id,
    )
    .await
    .map_err(|e| e.into_api_error())?;

    let updated = sqlx::query(
        r#"
        UPDATE app_storyboard
        SET file_path = $2, state = '已完成', updated_at = NOW()
        WHERE id = $1
        "#,
    )
    .bind(sb.storyboard_id)
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
pub(in crate::production) struct GetStoryboardDataByProjectBody {
    project_id: i32,
    script_id: i32,
}

pub(in crate::production) async fn post_get_storyboard_data(
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

    let scope_row = scope::owned_script_scope(pool, uid, body.project_id, body.script_id)
        .await
        .map_err(|e| e.into_api_error())?;

    let rows = sqlx::query_as::<_, ProductionStoryboardItem>(
        r#"
        SELECT
          sb.numeric_id AS id,
          sb.numeric_script_id AS script_id,
          sb.prompt,
          sb.file_path AS url,
          sb.duration,
          sb.state,
          sb.track_id,
          sb.flow_id,
          sb.sb_index
        FROM app_storyboard sb
        WHERE sb.script_id = $1
        ORDER BY sb.sb_index ASC
        "#,
    )
    .bind(scope_row.script_id)
    .fetch_all(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    Ok(JsonResponse(ProductionGetProductionDataResponse {
        data: rows,
    }))
}

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
pub(in crate::production) struct DownPreviewImageBody {
    project_id: i32,
    script_id: i32,
    storyboard_id: i32,
}

#[derive(Debug, Serialize)]
#[serde(rename_all = "camelCase")]
pub(in crate::production) struct DownPreviewImageResponse {
    storyboard_id: i32,
    preview_url: Option<String>,
    message: &'static str,
}

pub(in crate::production) async fn post_storyboard_down_preview_image(
    State(state): State<AppState>,
    headers: HeaderMap,
    Json(body): Json<DownPreviewImageBody>,
) -> Result<JsonResponse<DownPreviewImageResponse>, ApiError> {
    let uid = require_user_uuid(&state, &headers)?;
    require_positive_scope_ids(body.project_id, body.script_id, body.storyboard_id)?;

    let pool = state
        .pool
        .as_ref()
        .ok_or_else(|| ApiError::DatabaseError("DATABASE_URL not configured".into()))?;

    let sb = scope::owned_storyboard_in_script_scope(
        pool,
        uid,
        body.project_id,
        body.script_id,
        body.storyboard_id,
    )
    .await
    .map_err(|e| e.into_api_error())?;

    let file_path: Option<String> =
        sqlx::query_scalar(r#"SELECT file_path FROM app_storyboard WHERE id = $1"#)
            .bind(sb.storyboard_id)
            .fetch_one(pool)
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
pub(in crate::production) struct PreviewImageBody {
    project_id: i32,
    script_id: i32,
    storyboard_id: i32,
}

#[derive(Debug, Serialize)]
#[serde(rename_all = "camelCase")]
pub(in crate::production) struct PreviewImageResponse {
    storyboard_id: i32,
    image_url: Option<String>,
    prompt: Option<String>,
}

pub(in crate::production) async fn post_storyboard_preview_image(
    State(state): State<AppState>,
    headers: HeaderMap,
    Json(body): Json<PreviewImageBody>,
) -> Result<JsonResponse<PreviewImageResponse>, ApiError> {
    let uid = require_user_uuid(&state, &headers)?;
    require_positive_scope_ids(body.project_id, body.script_id, body.storyboard_id)?;

    let pool = state
        .pool
        .as_ref()
        .ok_or_else(|| ApiError::DatabaseError("DATABASE_URL not configured".into()))?;

    let sb = scope::owned_storyboard_in_script_scope(
        pool,
        uid,
        body.project_id,
        body.script_id,
        body.storyboard_id,
    )
    .await
    .map_err(|e| e.into_api_error())?;

    let (file_path, prompt): (Option<String>, Option<String>) =
        sqlx::query_as(r#"SELECT file_path, prompt FROM app_storyboard WHERE id = $1"#)
            .bind(sb.storyboard_id)
            .fetch_one(pool)
            .await
            .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    Ok(JsonResponse(PreviewImageResponse {
        storyboard_id: body.storyboard_id,
        image_url: file_path,
        prompt,
    }))
}
