//! 分镜编辑、删帧、更新图片 URL。

use axum::{
    extract::{Json, State},
    http::HeaderMap,
    Json as JsonResponse,
};

use super::super::common::{
    normalize_storyboard_image_url, normalize_storyboard_prompt, remove_storyboard_frame,
    update_live_action_reference, update_storyboard_character_id, update_storyboard_duration,
    update_storyboard_image_url, update_storyboard_info, validate_storyboard_duration,
};
use super::types::{
    EditStoryboardInfoBody, EditStoryboardInfoResponse, RemoveFrameBody, RemoveFrameResponse,
    UpdateStoryboardCharacterBody, UpdateStoryboardCharacterResponse, UpdateStoryboardDurationBody,
    UpdateStoryboardDurationResponse, UpdateStoryboardLiveActionReferenceBody,
    UpdateStoryboardLiveActionReferenceResponse, UpdateStoryboardUrlBody,
    UpdateStoryboardUrlResponse,
};
use crate::error::{bad_request_i18n, validate_positive, ApiError};
use crate::scope::http::{require_script_write_scope_ref, require_storyboard_write_scope_ref};
use crate::state::AppState;
use uuid::Uuid;

#[utoipa::path(
    post,
    path = "/api/v1/production/storyboard/edit-info",
    operation_id = "postProductionStoryboardEditInfoV1",
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
pub(in crate::production) async fn post_storyboard_edit_info(
    State(state): State<AppState>,
    headers: HeaderMap,
    Json(body): Json<EditStoryboardInfoBody>,
) -> Result<JsonResponse<EditStoryboardInfoResponse>, ApiError> {
    let prompt = normalize_storyboard_prompt(&body.prompt)?;
    let duration = validate_storyboard_duration(body.duration)?;

    let (pool, sb_uuid) = require_storyboard_write_scope_ref(
        &state,
        &headers,
        body.project_id,
        body.project_uuid,
        body.script_id,
        body.storyboard_id,
    )
    .await?;
    update_storyboard_info(pool, sb_uuid, &prompt, duration).await?;

    Ok(JsonResponse(EditStoryboardInfoResponse {
        storyboard_id: body.storyboard_id,
        message: "Storyboard info updated",
    }))
}

#[utoipa::path(
    post,
    path = "/api/v1/production/storyboard/remove-frame",
    operation_id = "postProductionStoryboardRemoveFrameV1",
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
pub(in crate::production) async fn post_storyboard_remove_frame(
    State(state): State<AppState>,
    headers: HeaderMap,
    Json(body): Json<RemoveFrameBody>,
) -> Result<JsonResponse<RemoveFrameResponse>, ApiError> {
    let (pool, sb_uuid) = require_storyboard_write_scope_ref(
        &state,
        &headers,
        body.project_id,
        body.project_uuid,
        body.script_id,
        body.storyboard_id,
    )
    .await?;
    remove_storyboard_frame(pool, sb_uuid).await?;

    Ok(JsonResponse(RemoveFrameResponse {
        storyboard_id: body.storyboard_id,
        message: "Frame removed from storyboard",
    }))
}

#[utoipa::path(
    post,
    path = "/api/v1/production/storyboard/update-url",
    operation_id = "postProductionStoryboardUpdateUrlV1",
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
pub(in crate::production) async fn post_storyboard_update_url(
    State(state): State<AppState>,
    headers: HeaderMap,
    Json(body): Json<UpdateStoryboardUrlBody>,
) -> Result<JsonResponse<UpdateStoryboardUrlResponse>, ApiError> {
    let image_url = normalize_storyboard_image_url(&body.image_url)?;

    let (pool, sb_uuid) = require_storyboard_write_scope_ref(
        &state,
        &headers,
        body.project_id,
        body.project_uuid,
        body.script_id,
        body.storyboard_id,
    )
    .await?;
    update_storyboard_image_url(pool, sb_uuid, &image_url).await?;

    Ok(JsonResponse(UpdateStoryboardUrlResponse {
        storyboard_id: body.storyboard_id,
        image_url,
        message: "Storyboard image URL updated",
    }))
}

#[utoipa::path(
    post,
    path = "/api/v1/production/storyboard/update-live-action-reference",
    operation_id = "postProductionStoryboardUpdateLiveActionReferenceV1",
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
pub(in crate::production) async fn post_storyboard_update_live_action_reference(
    State(state): State<AppState>,
    headers: HeaderMap,
    Json(body): Json<UpdateStoryboardLiveActionReferenceBody>,
) -> Result<JsonResponse<UpdateStoryboardLiveActionReferenceResponse>, ApiError> {
    let reference_shot_urls = body
        .reference_shot_urls
        .into_iter()
        .map(|value| value.trim().to_string())
        .filter(|value| !value.is_empty())
        .collect::<Vec<_>>();
    if reference_shot_urls.len() > 6 {
        return Err(bad_request_i18n(
            "referenceShotUrls must contain at most 6 items",
            "referenceShotUrls 最多只能包含 6 项",
        ));
    }
    if reference_shot_urls
        .iter()
        .any(|value| !(value.starts_with("http://") || value.starts_with("https://")))
    {
        return Err(bad_request_i18n(
            "referenceShotUrls must use http(s) URLs",
            "referenceShotUrls 必须使用 http(s) URL",
        ));
    }
    let performance_notes = body
        .performance_notes
        .as_deref()
        .map(str::trim)
        .filter(|value| !value.is_empty())
        .map(str::to_string);
    if performance_notes
        .as_ref()
        .is_some_and(|value| value.chars().count() > 280)
    {
        return Err(bad_request_i18n(
            "performanceNotes must be 280 chars or fewer",
            "performanceNotes 必须不超过 280 个字符",
        ));
    }

    let (pool, sb_uuid) = require_storyboard_write_scope_ref(
        &state,
        &headers,
        body.project_id,
        body.project_uuid,
        body.script_id,
        body.storyboard_id,
    )
    .await?;
    update_live_action_reference(
        pool,
        sb_uuid,
        &reference_shot_urls,
        performance_notes.as_deref(),
    )
    .await?;

    Ok(JsonResponse(UpdateStoryboardLiveActionReferenceResponse {
        storyboard_id: body.storyboard_id,
        reference_shot_urls,
        performance_notes,
        message: "Storyboard live-action reference updated",
    }))
}

#[utoipa::path(
    post,
    path = "/api/v1/production/storyboard/update-duration",
    operation_id = "postProductionStoryboardUpdateDurationV1",
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
pub(in crate::production) async fn post_storyboard_update_duration(
    State(state): State<AppState>,
    headers: HeaderMap,
    Json(body): Json<UpdateStoryboardDurationBody>,
) -> Result<JsonResponse<UpdateStoryboardDurationResponse>, ApiError> {
    validate_positive(body.duration, "duration")?;

    let (pool, sb_uuid) = require_storyboard_write_scope_ref(
        &state,
        &headers,
        body.project_id,
        body.project_uuid,
        body.script_id,
        body.storyboard_id,
    )
    .await?;
    update_storyboard_duration(pool, sb_uuid, body.duration).await?;

    Ok(JsonResponse(UpdateStoryboardDurationResponse {
        storyboard_id: body.storyboard_id,
        duration: body.duration,
        message: "Storyboard duration updated",
    }))
}

async fn ensure_character_in_project(
    pool: &sqlx::PgPool,
    project_id: Uuid,
    character_id: Uuid,
) -> Result<(), ApiError> {
    let exists: bool = sqlx::query_scalar(
        r#"
        SELECT EXISTS(
          SELECT 1 FROM app_project_character
          WHERE id = $1 AND project_id = $2
        )
        "#,
    )
    .bind(character_id)
    .bind(project_id)
    .fetch_one(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;
    if exists {
        Ok(())
    } else {
        Err(ApiError::BadRequest(
            "character_id does not belong to this project".into(),
        ))
    }
}

#[utoipa::path(
    post,
    path = "/api/v1/production/storyboard/set-character",
    operation_id = "postProductionStoryboardSetCharacterV1",
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
pub(in crate::production) async fn post_storyboard_set_character(
    State(state): State<AppState>,
    headers: HeaderMap,
    Json(body): Json<UpdateStoryboardCharacterBody>,
) -> Result<JsonResponse<UpdateStoryboardCharacterResponse>, ApiError> {
    let (_, pool, scope_row) = require_script_write_scope_ref(
        &state,
        &headers,
        body.project_id,
        body.project_uuid,
        body.script_id,
    )
    .await?;
    let (_, sb_uuid) = require_storyboard_write_scope_ref(
        &state,
        &headers,
        body.project_id,
        body.project_uuid,
        body.script_id,
        body.storyboard_id,
    )
    .await?;

    let character_id = body.character_id;

    if let Some(cid) = character_id {
        ensure_character_in_project(pool, scope_row.project_id, cid).await?;
    }

    update_storyboard_character_id(pool, sb_uuid, character_id).await?;

    Ok(JsonResponse(UpdateStoryboardCharacterResponse {
        storyboard_id: body.storyboard_id,
        character_id,
        message: "Storyboard character assignment updated",
    }))
}
