use axum::{
    extract::{Json, State},
    http::HeaderMap,
    Json as JsonResponse,
};
use serde_json::json;
use sqlx::PgPool;

use crate::auth::require_user_uuid;
use crate::error::ApiError;
use crate::jobs::{
    JobRow, JOB_KIND_ASSET_GENERATE_BATCH, JOB_KIND_ASSET_GENERATE_IMAGE,
    JOB_KIND_ASSET_POLISH_BATCH, JOB_KIND_ASSET_POLISH_PROMPT,
};
use crate::state::AppState;

use super::super::types::CancelGenerateBody;

pub(crate) async fn post_cancel_generate(
    State(state): State<AppState>,
    headers: HeaderMap,
    Json(body): Json<CancelGenerateBody>,
) -> Result<JsonResponse<serde_json::Value>, ApiError> {
    let uid = require_user_uuid(&state, &headers)?;
    if body.id <= 0 {
        return Err(ApiError::BadRequest("id must be positive".into()));
    }

    let pool: &PgPool = state
        .pool
        .as_ref()
        .ok_or_else(|| ApiError::DatabaseError("DATABASE_URL not configured".into()))?;

    let _ = sqlx::query(
        r#"
        UPDATE app_asset_image ai
        SET state = '生成失败',
            metadata = COALESCE(ai.metadata, '{}'::jsonb)
              || jsonb_build_object('cancelled', true, 'cancel_source', 'workbench.assets-generate.cancel-generate')
        FROM app_asset a
        INNER JOIN app_project p ON p.id = a.project_id
        WHERE ai.asset_id = a.id
          AND p.owner_user_id = $1
          AND ai.numeric_image_id = $2
        "#,
    )
    .bind(uid)
    .bind(body.id)
    .execute(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    let cancelled_jobs = sqlx::query_as::<_, JobRow>(
        r#"
        WITH target_assets AS (
            SELECT a.numeric_id
            FROM app_asset_image ai
            INNER JOIN app_asset a ON a.id = ai.asset_id
            INNER JOIN app_project p ON p.id = a.project_id
            WHERE p.owner_user_id = $1
              AND ai.numeric_image_id = $2
        ),
        cancelled AS (
            UPDATE app_generation_job j
            SET status = 'cancelled',
                result = COALESCE(j.result, '{}'::jsonb)
                  || jsonb_build_object(
                    'cancelled', true,
                    'cancel_source', 'workbench.assets-generate.cancel-generate',
                    'cancel_numeric_image_id', $2
                  ),
                updated_at = NOW()
            WHERE j.owner_user_id = $1
              AND j.status IN ('queued', 'running')
              AND j.kind IN ($3, $4, $5, $6)
              AND EXISTS (
                SELECT 1
                FROM target_assets t
                WHERE (
                  (j.payload ? 'asset_numeric_id')
                  AND (j.payload->>'asset_numeric_id') ~ '^[0-9]+$'
                  AND (j.payload->>'asset_numeric_id')::int = t.numeric_id
                ) OR EXISTS (
                  SELECT 1
                  FROM jsonb_array_elements(COALESCE(j.payload->'items', '[]'::jsonb)) it
                  WHERE (it ? 'asset_numeric_id')
                    AND (it->>'asset_numeric_id') ~ '^[0-9]+$'
                    AND (it->>'asset_numeric_id')::int = t.numeric_id
                )
              )
            RETURNING j.numeric_task_id, j.id, j.owner_user_id, j.kind, j.status, j.payload, j.result, j.error_message, j.idempotency_key, j.claimed_by, j.created_at, j.updated_at
        )
        SELECT * FROM cancelled
        "#,
    )
    .bind(uid)
    .bind(body.id)
    .bind(JOB_KIND_ASSET_GENERATE_IMAGE)
    .bind(JOB_KIND_ASSET_POLISH_PROMPT)
    .bind(JOB_KIND_ASSET_GENERATE_BATCH)
    .bind(JOB_KIND_ASSET_POLISH_BATCH)
    .fetch_all(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    for row in cancelled_jobs {
        let text = crate::jobs::envelope_generation_job_updated(&row);
        state.notify.broadcast_to_user(uid, text).await;
    }

    Ok(JsonResponse(json!({ "message": "取消成功" })))
}
