use axum::{
    extract::{Json, State},
    http::HeaderMap,
    Json as JsonResponse,
};
use serde::{Deserialize, Serialize};

use super::common::{
    insert_storyboards_with_next_numeric_ids, require_owned_script_id, require_pool,
    StoryboardInsertDraft,
};
use crate::auth::require_user_uuid;
use crate::error::ApiError;
use crate::state::AppState;

const DEFAULT_STORYBOARD_DURATION: i32 = 5;

fn prepare_storyboard_insert(
    prompt: &str,
    duration: Option<i32>,
) -> Result<StoryboardInsertDraft, ApiError> {
    let prompt = prompt.trim();
    if prompt.is_empty() {
        return Err(ApiError::BadRequest("prompt must not be empty".into()));
    }

    Ok(StoryboardInsertDraft {
        prompt: prompt.to_string(),
        duration: duration.unwrap_or(DEFAULT_STORYBOARD_DURATION),
    })
}

fn prepare_batch_storyboard_inserts(
    storyboards: &[StoryboardInfoInput],
) -> Result<Vec<StoryboardInsertDraft>, ApiError> {
    if storyboards.is_empty() {
        return Err(ApiError::BadRequest("storyboards must not be empty".into()));
    }

    storyboards
        .iter()
        .map(|storyboard| {
            prepare_storyboard_insert(&storyboard.prompt, storyboard.duration)
                .map_err(|_| ApiError::BadRequest("storyboards[*].prompt must not be empty".into()))
        })
        .collect()
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
    let prepared = prepare_storyboard_insert(&body.prompt, body.duration)?;

    let pool = require_pool(&state)?;
    let script_uuid = require_owned_script_id(pool, uid, body.project_id, body.script_id).await?;
    let storyboard_ids =
        insert_storyboards_with_next_numeric_ids(pool, script_uuid, body.script_id, &[prepared])
            .await?;
    let storyboard_id = storyboard_ids
        .into_iter()
        .next()
        .ok_or(ApiError::Internal)?;

    Ok(JsonResponse(AddStoryboardResponse {
        storyboard_id,
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
    let prepared_storyboards = prepare_batch_storyboard_inserts(&body.storyboards)?;

    let pool = require_pool(&state)?;
    let script_uuid = require_owned_script_id(pool, uid, body.project_id, body.script_id).await?;
    let storyboard_ids = insert_storyboards_with_next_numeric_ids(
        pool,
        script_uuid,
        body.script_id,
        &prepared_storyboards,
    )
    .await?;

    Ok(JsonResponse(BatchAddInfoResponse {
        added: storyboard_ids.len(),
        storyboard_ids,
    }))
}

#[cfg(test)]
mod tests {
    use super::{
        prepare_batch_storyboard_inserts, prepare_storyboard_insert, StoryboardInfoInput,
        StoryboardInsertDraft, DEFAULT_STORYBOARD_DURATION,
    };
    use crate::error::ApiError;

    #[test]
    fn prepare_storyboard_insert_trims_prompt_and_defaults_duration() {
        let prepared = prepare_storyboard_insert("  opening shot  ", None).unwrap();
        assert_eq!(
            prepared,
            StoryboardInsertDraft {
                prompt: "opening shot".to_string(),
                duration: DEFAULT_STORYBOARD_DURATION,
            }
        );
    }

    #[test]
    fn prepare_storyboard_insert_rejects_blank_prompt() {
        let err = prepare_storyboard_insert("   ", Some(3)).unwrap_err();
        assert!(matches!(
            err,
            ApiError::BadRequest(message) if message == "prompt must not be empty"
        ));
    }

    #[test]
    fn prepare_batch_storyboard_inserts_rejects_empty_list() {
        let err = prepare_batch_storyboard_inserts(&[]).unwrap_err();
        assert!(matches!(
            err,
            ApiError::BadRequest(message) if message == "storyboards must not be empty"
        ));
    }

    #[test]
    fn prepare_batch_storyboard_inserts_normalizes_each_item() {
        let prepared = prepare_batch_storyboard_inserts(&[
            StoryboardInfoInput {
                prompt: "  first  ".to_string(),
                duration: None,
            },
            StoryboardInfoInput {
                prompt: "second".to_string(),
                duration: Some(8),
            },
        ])
        .unwrap();

        assert_eq!(
            prepared,
            vec![
                StoryboardInsertDraft {
                    prompt: "first".to_string(),
                    duration: DEFAULT_STORYBOARD_DURATION,
                },
                StoryboardInsertDraft {
                    prompt: "second".to_string(),
                    duration: 8,
                },
            ]
        );
    }

    #[test]
    fn prepare_batch_storyboard_inserts_relabels_blank_prompt_error() {
        let err = prepare_batch_storyboard_inserts(&[StoryboardInfoInput {
            prompt: " ".to_string(),
            duration: Some(2),
        }])
        .unwrap_err();

        assert!(matches!(
            err,
            ApiError::BadRequest(message) if message == "storyboards[*].prompt must not be empty"
        ));
    }
}
