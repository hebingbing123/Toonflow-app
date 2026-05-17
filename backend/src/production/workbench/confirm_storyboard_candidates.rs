//! Confirm storyboard candidate review (**`metadata.shortVideo.candidateStatus`**).

use axum::extract::{Json, State};
use axum::http::HeaderMap;
use axum::Json as JsonResponse;
use serde::{Deserialize, Serialize};
use uuid::Uuid;

use crate::error::ApiError;
use crate::scope::http::require_script_write_scope_ref;
use crate::state::AppState;

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
pub(in crate::production) struct ConfirmStoryboardCandidatesBody {
    #[serde(default)]
    pub project_id: Option<i32>,
    #[serde(default)]
    pub project_uuid: Option<Uuid>,
    pub script_id: i32,
    pub storyboard_numeric_ids: Vec<i32>,
}

#[derive(Debug, Serialize)]
#[serde(rename_all = "camelCase")]
pub(in crate::production) struct ConfirmStoryboardCandidatesResponse {
    pub updated_count: u64,
}

#[utoipa::path(
    post,
    path = "/api/v1/production/workbench/confirm-storyboard-candidates",
    operation_id = "postProductionWorkbenchConfirmStoryboardCandidatesV1",
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
pub(in crate::production) async fn post_workbench_confirm_storyboard_candidates(
    State(state): State<AppState>,
    headers: HeaderMap,
    Json(body): Json<ConfirmStoryboardCandidatesBody>,
) -> Result<JsonResponse<ConfirmStoryboardCandidatesResponse>, ApiError> {
    let ids: Vec<i32> = body
        .storyboard_numeric_ids
        .into_iter()
        .filter(|id| *id > 0)
        .collect();
    if ids.is_empty() {
        return Err(crate::error::bad_request_i18n(
            "storyboardNumericIds must not be empty",
            "storyboardNumericIds 不能为空",
        ));
    }
    let (_user_id, pool, scope_row) = require_script_write_scope_ref(
        &state,
        &headers,
        body.project_id,
        body.project_uuid,
        body.script_id,
    )
    .await?;
    let result = sqlx::query(
        r#"
        UPDATE app_storyboard sb
        SET metadata = jsonb_set(
              jsonb_set(
                COALESCE(sb.metadata, '{}'::jsonb),
                '{shortVideo}',
                COALESCE(sb.metadata->'shortVideo', '{}'::jsonb),
                true
              ),
              '{shortVideo,candidateStatus}',
              '"confirmed"'::jsonb,
              true
            ),
            updated_at = NOW()
        FROM app_script sc
        WHERE sb.script_id = sc.id
          AND sc.project_id = $1
          AND sc.numeric_id = $2
          AND sb.numeric_id = ANY($3::int4[])
        "#,
    )
    .bind(scope_row.project_id)
    .bind(body.script_id)
    .bind(&ids)
    .execute(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;
    Ok(JsonResponse(ConfirmStoryboardCandidatesResponse {
        updated_count: result.rows_affected(),
    }))
}
