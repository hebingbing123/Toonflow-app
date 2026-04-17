use axum::{
    extract::{Json, State},
    http::HeaderMap,
    Json as JsonResponse,
};
use serde::{Deserialize, Serialize};

use super::common::{
    normalize_storyboard_image_url, normalize_storyboard_prompt, remove_owned_storyboard_frame,
    require_pool, update_owned_storyboard_image_url, update_owned_storyboard_info,
};
use crate::auth::require_user_uuid;
use crate::error::ApiError;
use crate::state::AppState;

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
    let uid = require_user_uuid(&state, &headers)?;
    let prompt = normalize_storyboard_prompt(&body.prompt)?;

    let pool = require_pool(&state)?;
    update_owned_storyboard_info(
        pool,
        uid,
        body.project_id,
        body.script_id,
        body.storyboard_id,
        &prompt,
        body.duration,
    )
    .await?;

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
    let uid = require_user_uuid(&state, &headers)?;

    let pool = require_pool(&state)?;
    remove_owned_storyboard_frame(
        pool,
        uid,
        body.project_id,
        body.script_id,
        body.storyboard_id,
    )
    .await?;

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
    let uid = require_user_uuid(&state, &headers)?;
    let image_url = normalize_storyboard_image_url(&body.image_url)?;

    let pool = require_pool(&state)?;
    update_owned_storyboard_image_url(
        pool,
        uid,
        body.project_id,
        body.script_id,
        body.storyboard_id,
        &image_url,
    )
    .await?;

    Ok(JsonResponse(UpdateStoryboardUrlResponse {
        storyboard_id: body.storyboard_id,
        image_url,
        message: "Storyboard image URL updated",
    }))
}

#[cfg(test)]
mod tests {
    use super::super::common::{normalize_storyboard_image_url, normalize_storyboard_prompt};
    use crate::error::ApiError;

    #[test]
    fn normalize_storyboard_prompt_trims_value() {
        let prompt = normalize_storyboard_prompt("  opening frame  ").unwrap();
        assert_eq!(prompt, "opening frame");
    }

    #[test]
    fn normalize_storyboard_prompt_rejects_blank_value() {
        let err = normalize_storyboard_prompt("   ").unwrap_err();
        assert!(matches!(
            err,
            ApiError::BadRequest(message) if message == "prompt must not be empty"
        ));
    }

    #[test]
    fn normalize_storyboard_image_url_trims_value() {
        let image_url =
            normalize_storyboard_image_url("  https://example.com/frame.png  ").unwrap();
        assert_eq!(image_url, "https://example.com/frame.png");
    }

    #[test]
    fn normalize_storyboard_image_url_rejects_blank_value() {
        let err = normalize_storyboard_image_url(" ").unwrap_err();
        assert!(matches!(
            err,
            ApiError::BadRequest(message) if message == "imageUrl must not be empty"
        ));
    }
}
