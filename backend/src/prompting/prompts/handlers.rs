//! 提示词模板 HTTP 处理器。

use axum::{
    extract::{Path, State},
    http::HeaderMap,
    Json,
};

use crate::auth::require_user_uuid;
use crate::error::ApiError;
use crate::state::AppState;

use super::defaults::DEFAULT_SLOTS;
use super::merge::{merge_slot, slot_by_numeric_id};
use super::types::{PatchPromptBody, PromptTemplateJson, UserPromptRow};

#[utoipa::path(
    get,
    path = "/api/v1/prompts",
    operation_id = "listPromptsV1",
    tag = "prompts",
    responses(
        (status = 200, description = "OK", body = serde_json::Value),
        (status = 401, description = "Unauthorized", body = crate::error::ErrorBody),
        (status = 503, description = "Unavailable", body = crate::error::ErrorBody)
    ),
    security(("bearerAuth" = []))
)]
pub(crate) async fn list_prompts(
    State(state): State<AppState>,
    headers: HeaderMap,
) -> Result<Json<Vec<PromptTemplateJson>>, ApiError> {
    let uid = require_user_uuid(&state, &headers)?;
    let pool = state.require_pool()?;

    let rows: Vec<UserPromptRow> = sqlx::query_as(
        r#"
        SELECT numeric_id, name, kind, body
        FROM app_user_prompt
        WHERE owner_user_id = $1
        ORDER BY numeric_id
        "#,
    )
    .bind(uid)
    .fetch_all(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    let mut out = Vec::with_capacity(DEFAULT_SLOTS.len());
    for def in &DEFAULT_SLOTS {
        let merged = rows.iter().find(|r| r.numeric_id == def.numeric_id);
        out.push(merge_slot(def, merged));
    }

    Ok(Json(out))
}

#[utoipa::path(
    get,
    path = "/api/v1/prompts/{numeric_id}",
    operation_id = "getPromptByNumericIdV1",
    tag = "prompts",
    params(
        ("numeric_id" = i32, Path, description = "Prompt slot id (1–3)")
    ),
    responses(
        (status = 200, description = "OK", body = serde_json::Value),
        (status = 401, description = "Unauthorized", body = crate::error::ErrorBody),
        (status = 404, description = "Not found", body = crate::error::ErrorBody),
        (status = 503, description = "Unavailable", body = crate::error::ErrorBody)
    ),
    security(("bearerAuth" = []))
)]
pub(crate) async fn get_prompt(
    State(state): State<AppState>,
    headers: HeaderMap,
    Path(numeric_id): Path<i32>,
) -> Result<Json<PromptTemplateJson>, ApiError> {
    let uid = require_user_uuid(&state, &headers)?;
    let def = slot_by_numeric_id(numeric_id).ok_or(ApiError::NotFound)?;
    let pool = state.require_pool()?;

    let row: Option<UserPromptRow> = sqlx::query_as(
        r#"
        SELECT numeric_id, name, kind, body
        FROM app_user_prompt
        WHERE owner_user_id = $1 AND numeric_id = $2
        "#,
    )
    .bind(uid)
    .bind(numeric_id)
    .fetch_optional(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    Ok(Json(merge_slot(def, row.as_ref())))
}

#[utoipa::path(
    patch,
    path = "/api/v1/prompts/{numeric_id}",
    operation_id = "patchPromptByNumericIdV1",
    tag = "prompts",
    params(
        ("numeric_id" = i32, Path, description = "Prompt slot id (1–3)")
    ),
    request_body(content = serde_json::Value, content_type = "application/json"),
    responses(
        (status = 200, description = "OK", body = serde_json::Value),
        (status = 400, description = "Bad request", body = crate::error::ErrorBody),
        (status = 401, description = "Unauthorized", body = crate::error::ErrorBody),
        (status = 404, description = "Not found", body = crate::error::ErrorBody),
        (status = 503, description = "Unavailable", body = crate::error::ErrorBody)
    ),
    security(("bearerAuth" = []))
)]
pub(crate) async fn patch_prompt(
    State(state): State<AppState>,
    headers: HeaderMap,
    Path(numeric_id): Path<i32>,
    Json(body): Json<PatchPromptBody>,
) -> Result<Json<PromptTemplateJson>, ApiError> {
    let uid = require_user_uuid(&state, &headers)?;
    let def = slot_by_numeric_id(numeric_id).ok_or(ApiError::NotFound)?;
    let pool = state.require_pool()?;

    sqlx::query(
        r#"
        INSERT INTO app_user_prompt (owner_user_id, numeric_id, name, kind, body, updated_at)
        VALUES ($1, $2, $3, $4, $5, NOW())
        ON CONFLICT (owner_user_id, numeric_id) DO UPDATE SET
          body = EXCLUDED.body,
          updated_at = NOW()
        "#,
    )
    .bind(uid)
    .bind(def.numeric_id)
    .bind(def.name)
    .bind(def.kind)
    .bind(&body.data)
    .execute(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    Ok(Json(PromptTemplateJson {
        id: def.numeric_id,
        name: def.name.to_string(),
        prompt_type: def.kind.to_string(),
        data: body.data,
    }))
}
