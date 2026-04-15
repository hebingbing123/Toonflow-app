use axum::{
    extract::{Json, State},
    http::HeaderMap,
    Json as JsonResponse,
};
use serde::{Deserialize, Serialize};

use super::common::{require_pool, require_positive_project_script, resolve_owned_script_id};
use crate::auth::require_user_uuid;
use crate::error::ApiError;
use crate::narrative::storyboards::ADV_LOCK_STORYBOARD_NUMERIC_ID;
use crate::state::AppState;

async fn insert_storyboard_row(
    tx: &mut sqlx::Transaction<'_, sqlx::Postgres>,
    script_uuid: uuid::Uuid,
    numeric_script_id: i32,
    numeric_id: i32,
    prompt: &str,
    duration: i32,
) -> Result<(), ApiError> {
    sqlx::query(
        r#"
        INSERT INTO app_storyboard (
            script_id, numeric_id, numeric_script_id, prompt, duration,
            state, sb_index, created_at, updated_at
        )
        VALUES ($1, $2, $3, $4, $5, '草稿', $6, NOW(), NOW())
        "#,
    )
    .bind(script_uuid)
    .bind(numeric_id)
    .bind(numeric_script_id)
    .bind(prompt)
    .bind(duration)
    .bind(numeric_id)
    .execute(&mut **tx)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;
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

#[utoipa::path(
    post,
    path = "/api/v1/production/storyboard/add",
    operation_id = "postProductionStoryboardAddV1",
    tag = "production",
    request_body(content = serde_json::Value, content_type = "application/json"),
    responses(
        (status = 200, description = "OK", body = serde_json::Value),
        (status = 400, description = "Bad request", body = crate::error::ErrorBody),
        (status = 401, description = "Unauthorized", body = crate::error::ErrorBody),
        (status = 403, description = "Forbidden", body = crate::error::ErrorBody),
        (status = 404, description = "Not found", body = crate::error::ErrorBody),
        (status = 409, description = "Conflict", body = crate::error::ErrorBody),
        (status = 500, description = "Server error", body = crate::error::ErrorBody),
        (status = 503, description = "Unavailable", body = crate::error::ErrorBody)
    ),
    security(("bearerAuth" = []))
)]
pub(in crate::production) async fn post_storyboard_add(
    State(state): State<AppState>,
    headers: HeaderMap,
    Json(body): Json<AddStoryboardBody>,
) -> Result<JsonResponse<AddStoryboardResponse>, ApiError> {
    let uid = require_user_uuid(&state, &headers)?;
    require_positive_project_script(body.project_id, body.script_id)?;
    if body.prompt.trim().is_empty() {
        return Err(ApiError::BadRequest("prompt must not be empty".into()));
    }

    let pool = require_pool(&state)?;
    let script_uuid = resolve_owned_script_id(pool, uid, body.project_id, body.script_id).await?;

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

    insert_storyboard_row(
        &mut tx,
        script_uuid,
        body.script_id,
        next_id,
        body.prompt.trim(),
        body.duration.unwrap_or(5),
    )
    .await?;

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

#[utoipa::path(
    post,
    path = "/api/v1/production/storyboard/batch-add-info",
    operation_id = "postProductionStoryboardBatchAddInfoV1",
    tag = "production",
    request_body(content = serde_json::Value, content_type = "application/json"),
    responses(
        (status = 200, description = "OK", body = serde_json::Value),
        (status = 400, description = "Bad request", body = crate::error::ErrorBody),
        (status = 401, description = "Unauthorized", body = crate::error::ErrorBody),
        (status = 403, description = "Forbidden", body = crate::error::ErrorBody),
        (status = 404, description = "Not found", body = crate::error::ErrorBody),
        (status = 409, description = "Conflict", body = crate::error::ErrorBody),
        (status = 500, description = "Server error", body = crate::error::ErrorBody),
        (status = 503, description = "Unavailable", body = crate::error::ErrorBody)
    ),
    security(("bearerAuth" = []))
)]
pub(in crate::production) async fn post_storyboard_batch_add_info(
    State(state): State<AppState>,
    headers: HeaderMap,
    Json(body): Json<BatchAddInfoBody>,
) -> Result<JsonResponse<BatchAddInfoResponse>, ApiError> {
    let uid = require_user_uuid(&state, &headers)?;
    require_positive_project_script(body.project_id, body.script_id)?;
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

    let pool = require_pool(&state)?;
    let script_uuid = resolve_owned_script_id(pool, uid, body.project_id, body.script_id).await?;

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
        insert_storyboard_row(
            &mut tx,
            script_uuid,
            body.script_id,
            next_id,
            sb.prompt.trim(),
            sb.duration.unwrap_or(5),
        )
        .await?;

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
