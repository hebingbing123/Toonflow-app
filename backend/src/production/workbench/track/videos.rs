use axum::{
    extract::{Json, State},
    http::HeaderMap,
    Json as JsonResponse,
};
use serde::{Deserialize, Serialize};

use crate::error::ApiError;
use crate::production::workbench::video_prompt_memory::{
    build_rejected_video_negative_memory, build_selected_video_memory,
    clear_rejected_video_negative_memory, clear_selected_video_memory, extract_key_value,
    persist_rejected_video_negative_memory, persist_selected_video_memory,
    refresh_project_video_style_memory, refresh_script_video_style_memory, StoryboardPromptSeedRow,
};
use crate::scope::http::require_authenticated_user;
use crate::scope::http::require_owned_numeric_script_scope_row;
use crate::state::AppState;

use super::common::validate_positive_id;

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
pub(in crate::production) struct DeleteVideoBody {
    project_id: i32,
    script_id: i32,
    storyboard_id: i32,
}

#[derive(Debug, Serialize)]
#[serde(rename_all = "camelCase")]
pub(in crate::production) struct DeleteVideoResponse {
    storyboard_id: i32,
    negative_memory: Option<WorkbenchVideoMemoryFeedback>,
    message: &'static str,
}

#[derive(Debug, Serialize)]
#[serde(rename_all = "camelCase")]
pub(in crate::production) struct WorkbenchVideoMemoryFeedback {
    kind: &'static str,
    scope: &'static str,
    subject: Option<String>,
    style: Option<String>,
    note: Option<String>,
    avoid: Option<String>,
    risk_tags: Vec<String>,
    rejection_count: Option<u32>,
    char_count: usize,
}

fn selected_video_memory_feedback(content: &str) -> Option<WorkbenchVideoMemoryFeedback> {
    let subject = extract_key_value(content, "subject");
    let style = extract_key_value(content, "style");
    let note = extract_key_value(content, "note");
    if subject.is_none() && style.is_none() && note.is_none() {
        return None;
    }
    Some(WorkbenchVideoMemoryFeedback {
        kind: "selected",
        scope: "user-project-script",
        subject,
        style,
        note,
        avoid: None,
        risk_tags: Vec::new(),
        rejection_count: None,
        char_count: content.chars().count(),
    })
}

fn rejected_video_memory_feedback(content: &str) -> Option<WorkbenchVideoMemoryFeedback> {
    let avoid = extract_key_value(content, "avoid");
    if avoid.is_none() {
        return None;
    }
    let subject = extract_key_value(content, "subject");
    let risk_tags = extract_key_value(content, "riskTags")
        .map(|value| {
            value
                .split(['/', ',', '，', ';', '；'])
                .map(str::trim)
                .filter(|tag| !tag.is_empty())
                .map(str::to_string)
                .collect::<Vec<_>>()
        })
        .unwrap_or_default();
    let rejection_count = extract_key_value(content, "rejectionCount")
        .and_then(|value| value.parse::<u32>().ok())
        .filter(|count| *count > 0);
    Some(WorkbenchVideoMemoryFeedback {
        kind: "rejected",
        scope: "user-project-script",
        subject,
        style: None,
        note: None,
        avoid,
        risk_tags,
        rejection_count,
        char_count: content.chars().count(),
    })
}

#[utoipa::path(
    post,
    path = "/api/v1/production/workbench/delete-video",
    operation_id = "postProductionWorkbenchDeleteVideoV1",
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
pub(in crate::production) async fn post_workbench_delete_video(
    State(state): State<AppState>,
    headers: HeaderMap,
    Json(body): Json<DeleteVideoBody>,
) -> Result<JsonResponse<DeleteVideoResponse>, ApiError> {
    validate_positive_id("storyboardId", body.storyboard_id)?;
    let user_id = require_authenticated_user(&state, &headers)?;
    let (pool, scope_row) =
        require_owned_numeric_script_scope_row(&state, &headers, body.project_id, body.script_id)
            .await?;

    let updated = sqlx::query(
        r#"
        UPDATE app_storyboard
        SET file_path = NULL, state = NULL, updated_at = NOW()
        WHERE script_id = $1
          AND numeric_id = $2
        "#,
    )
    .bind(scope_row.script_id)
    .bind(body.storyboard_id)
    .execute(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    if updated.rows_affected() == 0 {
        return Err(ApiError::NotFound);
    }

    let prompt_seed = sqlx::query_as::<_, StoryboardPromptSeedRow>(
        r#"
        SELECT prompt, video_desc, duration
        FROM app_storyboard
        WHERE script_id = $1
          AND numeric_id = $2
        "#,
    )
    .bind(scope_row.script_id)
    .bind(body.storyboard_id)
    .fetch_optional(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;
    let mut negative_memory = None;
    if let Some(prompt_seed) = prompt_seed {
        if let Some(memory_content) =
            build_rejected_video_negative_memory(body.storyboard_id, &prompt_seed)
        {
            negative_memory = rejected_video_memory_feedback(&memory_content);
            persist_rejected_video_negative_memory(
                pool,
                user_id,
                body.project_id,
                body.script_id,
                &memory_content,
            )
            .await?;
        }
    }
    clear_selected_video_memory(
        pool,
        user_id,
        body.project_id,
        body.script_id,
        body.storyboard_id,
    )
    .await?;
    refresh_script_video_style_memory(pool, user_id, body.project_id, body.script_id).await?;
    refresh_project_video_style_memory(pool, user_id, body.project_id).await?;

    Ok(JsonResponse(DeleteVideoResponse {
        storyboard_id: body.storyboard_id,
        negative_memory,
        message: "Video deleted from storyboard",
    }))
}

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
pub(in crate::production) struct SelectVideoBody {
    project_id: i32,
    script_id: i32,
    storyboard_id: i32,
    video_url: String,
}

#[derive(Debug, Serialize)]
#[serde(rename_all = "camelCase")]
pub(in crate::production) struct SelectVideoResponse {
    storyboard_id: i32,
    video_url: String,
    selected_memory: Option<WorkbenchVideoMemoryFeedback>,
    message: &'static str,
}

#[utoipa::path(
    post,
    path = "/api/v1/production/workbench/select-video",
    operation_id = "postProductionWorkbenchSelectVideoV1",
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
pub(in crate::production) async fn post_workbench_select_video(
    State(state): State<AppState>,
    headers: HeaderMap,
    Json(body): Json<SelectVideoBody>,
) -> Result<JsonResponse<SelectVideoResponse>, ApiError> {
    validate_positive_id("storyboardId", body.storyboard_id)?;
    if body.video_url.trim().is_empty() {
        return Err(ApiError::BadRequest("videoUrl must not be empty".into()));
    }
    let user_id = require_authenticated_user(&state, &headers)?;

    let (pool, scope_row) =
        require_owned_numeric_script_scope_row(&state, &headers, body.project_id, body.script_id)
            .await?;

    let updated = sqlx::query(
        r#"
        UPDATE app_storyboard
        SET file_path = $3, state = '已完成', updated_at = NOW()
        WHERE script_id = $1
          AND numeric_id = $2
        "#,
    )
    .bind(scope_row.script_id)
    .bind(body.storyboard_id)
    .bind(body.video_url.trim())
    .execute(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    if updated.rows_affected() == 0 {
        return Err(ApiError::NotFound);
    }

    let prompt_seed = sqlx::query_as::<_, StoryboardPromptSeedRow>(
        r#"
        SELECT prompt, video_desc, duration
        FROM app_storyboard
        WHERE script_id = $1
          AND numeric_id = $2
        "#,
    )
    .bind(scope_row.script_id)
    .bind(body.storyboard_id)
    .fetch_optional(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;
    clear_rejected_video_negative_memory(
        pool,
        user_id,
        body.project_id,
        body.script_id,
        body.storyboard_id,
    )
    .await?;
    let mut selected_memory = None;
    if let Some(prompt_seed) = prompt_seed {
        if let Some(memory_content) = build_selected_video_memory(body.storyboard_id, &prompt_seed)
        {
            selected_memory = selected_video_memory_feedback(&memory_content);
            persist_selected_video_memory(
                pool,
                user_id,
                body.project_id,
                body.script_id,
                &memory_content,
            )
            .await?;
            refresh_script_video_style_memory(pool, user_id, body.project_id, body.script_id)
                .await?;
            refresh_project_video_style_memory(pool, user_id, body.project_id).await?;
        }
    }

    Ok(JsonResponse(SelectVideoResponse {
        storyboard_id: body.storyboard_id,
        video_url: body.video_url.trim().to_string(),
        selected_memory,
        message: "Video selected for storyboard",
    }))
}
