use axum::{
    extract::{Json, State},
    http::HeaderMap,
    Json as JsonResponse,
};
use serde::{Deserialize, Serialize};
use serde_json::json;

use crate::error::ApiError;
use crate::jobs::{enqueue_generation_job, JobRow, JOB_KIND_VOICEOVER_GENERATE};
use crate::production::workbench::storyboard_ops::require_owned_normalized_storyboards_scope;
use crate::scope::http::require_owned_numeric_storyboard_scope;
use crate::short_video::defaults::resolve_tts_voice;
use crate::state::AppState;

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
pub(in crate::production) struct WorkbenchGenerateVoiceoverBody {
    pub(crate) project_id: i32,
    pub(crate) script_id: i32,
    pub(crate) storyboard_ids: Vec<i32>,
    #[serde(default)]
    pub(crate) voice: Option<String>,
    #[serde(default)]
    pub(crate) speed: Option<f32>,
}

#[derive(Debug, Serialize)]
#[serde(rename_all = "camelCase")]
pub(in crate::production) struct WorkbenchGenerateVoiceoverResponse {
    enqueued: Vec<JobRow>,
    total: usize,
}

struct VoiceoverQueueContext<'a> {
    state: &'a AppState,
    headers: &'a HeaderMap,
    project_id: i32,
    script_id: i32,
    resolved_voice: &'a str,
    speed: Option<f32>,
}

#[utoipa::path(
    post,
    path = "/api/v1/production/workbench/generate-voiceover",
    operation_id = "postProductionWorkbenchGenerateVoiceoverV1",
    tag = "production",
    request_body(content = serde_json::Value, content_type = "application/json"),
    responses(
        (status = 200, description = "OK", body = serde_json::Value),
        (status = 400, description = "Bad request", body = crate::error::ErrorBody),
        (status = 401, description = "Unauthorized", body = crate::error::ErrorBody),
        (status = 403, description = "Forbidden", body = crate::error::ErrorBody),
        (status = 404, description = "Not found", body = crate::error::ErrorBody),
        (status = 500, description = "Server error", body = crate::error::ErrorBody),
        (status = 503, description = "Unavailable", body = crate::error::ErrorBody)
    ),
    security(("bearerAuth" = []))
)]
pub(in crate::production) async fn post_workbench_generate_voiceover(
    State(state): State<AppState>,
    headers: HeaderMap,
    Json(body): Json<WorkbenchGenerateVoiceoverBody>,
) -> Result<JsonResponse<WorkbenchGenerateVoiceoverResponse>, ApiError> {
    let (uid, pool, script_uuid, storyboard_ids) = require_owned_normalized_storyboards_scope(
        &state,
        &headers,
        body.project_id,
        body.script_id,
        &body.storyboard_ids,
    )
    .await?;

    let proj_defaults: Option<(Option<String>, Option<String>, Option<String>)> = sqlx::query_as(
        r#"
        SELECT voice_profile, subtitle_style, bgm_strategy
        FROM app_project
        WHERE owner_user_id = $1 AND numeric_id = $2
        "#,
    )
    .bind(uid)
    .bind(body.project_id)
    .fetch_optional(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    let (voice_profile, _subtitle_style, _bgm_strategy) =
        proj_defaults.unwrap_or((None, None, None));
    let resolved_voice = resolve_tts_voice(body.voice.as_deref(), voice_profile.as_deref());
    let queue_ctx = VoiceoverQueueContext {
        state: &state,
        headers: &headers,
        project_id: body.project_id,
        script_id: body.script_id,
        resolved_voice: resolved_voice.as_str(),
        speed: body.speed,
    };

    let rows: Vec<(i32, Option<String>, Option<String>)> = sqlx::query_as(
        r#"
        SELECT numeric_id, video_desc, prompt
        FROM app_storyboard
        WHERE script_id = $1
          AND numeric_id = ANY($2::int4[])
        ORDER BY array_position($2::int4[], numeric_id)
        "#,
    )
    .bind(script_uuid)
    .bind(&storyboard_ids)
    .fetch_all(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    let mut enqueued = Vec::with_capacity(rows.len());
    for (storyboard_id, video_desc, prompt) in rows {
        let narration = video_desc
            .as_deref()
            .map(str::trim)
            .filter(|value| !value.is_empty())
            .or_else(|| {
                prompt
                    .as_deref()
                    .map(str::trim)
                    .filter(|value| !value.is_empty())
            })
            .ok_or_else(|| {
                ApiError::BadRequest(format!(
                    "storyboard {} has neither narration text nor prompt fallback",
                    storyboard_id
                ))
            })?;

        mark_storyboard_voiceover_queued(pool, &queue_ctx, storyboard_id, narration).await?;

        let mut payload = json!({
            "project_numeric_id": body.project_id,
            "script_numeric_id": body.script_id,
            "storyboard_numeric_id": storyboard_id,
            "voice": resolved_voice.as_str(),
        });
        if let Some(speed) = body.speed.filter(|value| *value >= 0.25 && *value <= 4.0) {
            payload["speed"] = json!(speed);
        }
        let row = enqueue_generation_job(pool, uid, JOB_KIND_VOICEOVER_GENERATE, payload).await?;
        enqueued.push(row);
    }

    Ok(JsonResponse(WorkbenchGenerateVoiceoverResponse {
        total: enqueued.len(),
        enqueued,
    }))
}

async fn mark_storyboard_voiceover_queued(
    pool: &sqlx::PgPool,
    ctx: &VoiceoverQueueContext<'_>,
    storyboard_id: i32,
    narration: &str,
) -> Result<(), ApiError> {
    let (_pool, storyboard_uuid) = require_owned_numeric_storyboard_scope(
        ctx.state,
        ctx.headers,
        ctx.project_id,
        ctx.script_id,
        storyboard_id,
    )
    .await?;
    sqlx::query(
        r#"
        UPDATE app_storyboard
        SET metadata = jsonb_set(
              COALESCE(metadata, '{}'::jsonb),
              '{voiceover}',
              $2::jsonb,
              true
            ),
            updated_at = NOW()
        WHERE id = $1
        "#,
    )
    .bind(storyboard_uuid)
    .bind(json!({
        "state": "queued",
        "voice": ctx.resolved_voice,
        "speed": ctx.speed,
        "sourceText": narration,
        "error": null,
        "updatedAt": chrono::Utc::now().to_rfc3339(),
    }))
    .execute(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;
    Ok(())
}
