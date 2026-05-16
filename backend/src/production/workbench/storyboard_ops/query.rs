use axum::{
    extract::{Json, State},
    http::{HeaderMap, StatusCode},
    response::{IntoResponse, Response},
    Json as JsonResponse,
};

use super::common::{require_owned_normalized_storyboards_access_ref, validate_storyboard_ids};
use super::media_slots::hydrate_production_storyboard_items;
use super::types::{
    ProductionGetProductionDataResponse, ProductionStoryboardItem, StoryboardIdListBody,
};
use crate::error::ApiError;
use crate::scope::http::require_script_read_scope_ref;
use crate::state::AppState;

#[utoipa::path(
    post,
    path = "/api/v1/production/get-production-data",
    operation_id = "postProductionGetProductionDataV1",
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
pub(in crate::production) async fn post_get_production_data(
    State(state): State<AppState>,
    headers: HeaderMap,
    Json(body): Json<StoryboardIdListBody>,
) -> Result<Response, ApiError> {
    validate_storyboard_ids(&body.ids)?;

    let (_uid, pool, scope_row) = require_script_read_scope_ref(
        &state,
        &headers,
        body.project_id,
        body.project_uuid,
        body.script_id,
    )
    .await?;

    let mut rows = sqlx::query_as::<_, ProductionStoryboardItem>(
        r#"
        SELECT
          sb.numeric_id AS id,
          sb.numeric_script_id AS script_id,
          sb.prompt,
          sb.video_desc,
          sb.file_path AS url,
          sb.duration,
          sb.state,
          sb.track_id,
          sb.flow_id,
          sb.sb_index,
          sb.metadata #>> '{voiceover,state}' AS voiceover_state,
          sb.metadata #>> '{voiceover,audioUrl}' AS voiceover_audio_url,
          sb.metadata #>> '{voiceover,error}' AS voiceover_error,
          ARRAY(
            SELECT jsonb_array_elements_text(
              COALESCE(sb.metadata #> '{shortVideo,liveAction,referenceShotUrls}', '[]'::jsonb)
            )
          ) AS live_action_reference_shot_urls,
          sb.metadata #>> '{shortVideo,liveAction,performanceNotes}' AS live_action_performance_notes
        FROM app_storyboard sb
        WHERE sb.script_id = $1
          AND sb.numeric_id = ANY($2::int4[])
        ORDER BY array_position($2::int4[], sb.numeric_id)
        "#,
    )
    .bind(scope_row.script_id)
    .bind(&body.ids)
    .fetch_all(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    hydrate_production_storyboard_items(&mut rows);

    Ok(JsonResponse(ProductionGetProductionDataResponse { data: rows }).into_response())
}

#[utoipa::path(
    post,
    path = "/api/v1/production/storyboard/polling-image",
    operation_id = "postProductionStoryboardPollingImageV1",
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
pub(in crate::production) async fn post_storyboard_polling_image(
    State(state): State<AppState>,
    headers: HeaderMap,
    Json(body): Json<StoryboardIdListBody>,
) -> Result<Response, ApiError> {
    require_owned_normalized_storyboards_access_ref(
        &state,
        &headers,
        body.project_id,
        body.project_uuid,
        body.script_id,
        &body.ids,
    )
    .await?;

    Ok(StatusCode::OK.into_response())
}
