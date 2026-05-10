use axum::{
    extract::{Path, Query, State},
    http::HeaderMap,
    Json,
};
use serde::{Deserialize, Serialize};
use serde_json::{json, Value};
use utoipa::{IntoParams, ToSchema};
use uuid::Uuid;

use crate::{
    auth::require_user_uuid,
    error::ApiError,
    jobs::{enqueue_generation_job, JOB_KIND_VOICEOVER_GENERATE},
    projects::routes::common::require_project_write_scope,
    short_video::defaults::resolve_tts_voice,
    state::AppState,
};

#[derive(Debug, Clone, Serialize, Deserialize, ToSchema)]
pub struct TtsGenerateRequest {
    pub project_id: Uuid,
    pub shot_id: Uuid,
    pub text: String,
    pub provider: String,
    pub voice_id: String,
    pub emotion: Option<String>,
    pub speed: Option<f32>,
}

#[derive(Debug, Clone, Serialize, Deserialize, ToSchema)]
pub struct TtsGenerateResponse {
    pub task_id: Uuid,
    pub status: String,
    pub audio_url: Option<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize, ToSchema, sqlx::FromRow)]
pub struct TtsTaskResponse {
    pub task_id: Uuid,
    pub project_id: Uuid,
    pub shot_id: Option<Uuid>,
    pub status: String,
    pub audio_url: Option<String>,
    pub error: Option<String>,
    pub created_at: chrono::DateTime<chrono::Utc>,
    pub updated_at: chrono::DateTime<chrono::Utc>,
}

#[derive(Debug, Clone, Deserialize, Default, IntoParams, ToSchema)]
#[into_params(parameter_in = Query)]
pub struct TtsTaskListQuery {
    #[serde(default)]
    pub project_id: Option<Uuid>,
    #[serde(default)]
    pub status: Option<String>,
    #[serde(default)]
    pub limit: Option<i64>,
    #[serde(default)]
    pub offset: Option<i64>,
}

#[derive(Debug, Clone, Serialize, Deserialize, ToSchema)]
pub struct TtsBatchGenerateRequest {
    pub project_id: Uuid,
    pub shots: Vec<TtsGenerateRequest>,
}

#[derive(Debug, Clone, Serialize, Deserialize, ToSchema)]
pub struct TtsBatchGenerateResponse {
    pub tasks: Vec<TtsGenerateResponse>,
    pub total: usize,
    pub succeeded: usize,
    pub failed: usize,
}

#[derive(Debug, Clone, Serialize, Deserialize, ToSchema)]
pub struct TtsCancelRequest {
    pub task_id: Uuid,
}

#[derive(Debug, Clone, Serialize, Deserialize, ToSchema)]
pub struct TtsCancelResponse {
    pub task_id: Uuid,
    pub cancelled: bool,
}

#[derive(Debug, Clone, Serialize, Deserialize, ToSchema)]
pub struct TtsRetryRequest {
    pub task_id: Uuid,
    pub provider: Option<String>,
    pub voice_id: Option<String>,
    pub emotion: Option<String>,
    pub speed: Option<f32>,
}

#[derive(Debug, Clone, Serialize, Deserialize, ToSchema)]
pub struct TtsRetryResponse {
    pub previous_task_id: Uuid,
    pub task_id: Uuid,
    pub status: String,
}

/// 生成单个镜头的 TTS 配音
#[utoipa::path(
    post,
    path = "/api/v1/tts/generate",
    request_body = TtsGenerateRequest,
    responses(
        (status = 200, description = "TTS 生成任务已创建", body = TtsGenerateResponse),
        (status = 400, description = "请求参数无效"),
        (status = 401, description = "未授权"),
        (status = 500, description = "服务器错误"),
    ),
    tag = "tts"
)]
pub async fn generate_tts(
    State(state): State<AppState>,
    headers: HeaderMap,
    Json(req): Json<TtsGenerateRequest>,
) -> Result<Json<TtsGenerateResponse>, ApiError> {
    let uid = require_user_uuid(&state, &headers)?;
    let _scope = require_project_write_scope(&state, uid, req.project_id).await?;
    let pool = state
        .pool
        .as_ref()
        .ok_or(ApiError::DatabaseError("Database not configured".into()))?;

    let row: (
        i32,
        i32,
        i32,
        Option<String>,
        Option<String>,
        Option<String>,
    ) = sqlx::query_as::<
        _,
        (
            i32,
            i32,
            i32,
            Option<String>,
            Option<String>,
            Option<String>,
        ),
    >(
        r#"
        SELECT
          p.numeric_id AS project_numeric_id,
          sb.numeric_id AS storyboard_numeric_id,
          s.numeric_id AS script_numeric_id,
          p.voice_profile,
          sb.video_desc,
          sb.prompt
        FROM app_storyboard sb
        JOIN app_script s ON s.id = sb.script_id
        JOIN app_project p ON p.id = s.project_id
        WHERE p.id = $1
          AND sb.id = $2
        "#,
    )
    .bind(req.project_id)
    .bind(req.shot_id)
    .fetch_optional(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?
    .ok_or_else(|| ApiError::BadRequest("shot_id does not belong to project_id".into()))?;

    let (
        project_numeric_id,
        storyboard_numeric_id,
        script_numeric_id,
        voice_profile,
        video_desc,
        prompt,
    ) = row;

    let narration = req.text.trim().to_string();
    let narration = if narration.is_empty() {
        video_desc
            .as_deref()
            .map(str::trim)
            .filter(|value| !value.is_empty())
            .or_else(|| {
                prompt
                    .as_deref()
                    .map(str::trim)
                    .filter(|value| !value.is_empty())
            })
            .unwrap_or_default()
            .to_string()
    } else {
        narration
    };
    if narration.is_empty() {
        return Err(ApiError::BadRequest(
            "text is empty and shot has no prompt fallback".into(),
        ));
    }
    let resolved_voice = resolve_tts_voice(Some(req.voice_id.as_str()), voice_profile.as_deref());

    let speed = req.speed.filter(|value| *value >= 0.25 && *value <= 4.0);
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
    .bind(req.shot_id)
    .bind(json!({
        "state": "queued",
        "voice": resolved_voice,
        "speed": speed,
        "sourceText": narration,
        "provider": req.provider.trim(),
        "emotion": req.emotion.as_deref().map(str::trim).filter(|s| !s.is_empty()),
        "error": null,
        "updatedAt": chrono::Utc::now().to_rfc3339(),
    }))
    .execute(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    let mut payload = json!({
      "project_numeric_id": project_numeric_id,
      "script_numeric_id": script_numeric_id,
      "storyboard_numeric_id": storyboard_numeric_id,
      "voice": resolved_voice,
      "source_text": narration,
      "provider": req.provider.trim(),
    });
    if let Some(speed_value) = speed {
        payload["speed"] = json!(speed_value);
    }
    if let Some(emotion) = req
        .emotion
        .as_deref()
        .map(str::trim)
        .filter(|value| !value.is_empty())
    {
        payload["emotion"] = json!(emotion);
    }

    let job = enqueue_generation_job(
        pool,
        uid,
        JOB_KIND_VOICEOVER_GENERATE,
        payload,
        Some(&headers),
    )
    .await?;

    Ok(Json(TtsGenerateResponse {
        task_id: job.id,
        status: "queued".to_string(),
        audio_url: None,
    }))
}

/// 批量生成 TTS 配音
#[utoipa::path(
    post,
    path = "/api/v1/tts/batch-generate",
    request_body = TtsBatchGenerateRequest,
    responses(
        (status = 200, description = "批量 TTS 生成任务已创建", body = TtsBatchGenerateResponse),
        (status = 400, description = "请求参数无效"),
        (status = 401, description = "未授权"),
        (status = 500, description = "服务器错误"),
    ),
    tag = "tts"
)]
pub async fn batch_generate_tts(
    State(state): State<AppState>,
    headers: HeaderMap,
    Json(req): Json<TtsBatchGenerateRequest>,
) -> Result<Json<TtsBatchGenerateResponse>, ApiError> {
    // Verify authentication and database availability upfront
    let _uid = require_user_uuid(&state, &headers)?;
    let _pool = state
        .pool
        .as_ref()
        .ok_or(ApiError::DatabaseError("Database not configured".into()))?;

    if req.shots.is_empty() {
        return Ok(Json(TtsBatchGenerateResponse {
            tasks: Vec::new(),
            total: 0,
            succeeded: 0,
            failed: 0,
        }));
    }

    let mut tasks = Vec::with_capacity(req.shots.len());
    let mut succeeded = 0usize;
    let mut failed = 0usize;
    for shot in req.shots {
        if shot.project_id != req.project_id {
            failed += 1;
            continue;
        }
        match generate_tts(State(state.clone()), headers.clone(), Json(shot)).await {
            Ok(Json(task)) => {
                succeeded += 1;
                tasks.push(task);
            }
            Err(_) => {
                failed += 1;
            }
        }
    }

    Ok(Json(TtsBatchGenerateResponse {
        total: tasks.len() + failed,
        succeeded,
        failed,
        tasks,
    }))
}

#[utoipa::path(
    get,
    path = "/api/v1/tts/tasks",
    params(TtsTaskListQuery),
    responses(
        (status = 200, description = "TTS 任务列表", body = [TtsTaskResponse]),
        (status = 401, description = "未授权"),
        (status = 500, description = "服务器错误"),
    ),
    tag = "tts"
)]
pub async fn list_tts_tasks(
    State(state): State<AppState>,
    headers: HeaderMap,
    Query(query): Query<TtsTaskListQuery>,
) -> Result<Json<Vec<TtsTaskResponse>>, ApiError> {
    let uid = require_user_uuid(&state, &headers)?;
    let pool = state
        .pool
        .as_ref()
        .ok_or(ApiError::DatabaseError("Database not configured".into()))?;
    let status = query
        .status
        .as_deref()
        .map(str::trim)
        .filter(|value| !value.is_empty());
    let limit = query.limit.unwrap_or(50).clamp(1, 200);
    let offset = query.offset.unwrap_or(0).max(0);

    let rows: Vec<TtsTaskResponse> = sqlx::query_as(
        r#"
        SELECT
          j.id AS task_id,
          p.id AS project_id,
          sb.id AS shot_id,
          j.status,
          CASE
            WHEN jsonb_typeof(j.result) = 'object' THEN NULLIF(j.result->>'audio_url', '')
            ELSE NULL
          END AS audio_url,
          j.error_message AS error,
          j.created_at,
          j.updated_at
        FROM app_generation_job j
        JOIN app_project p
          ON p.owner_user_id = j.owner_user_id
         AND (j.payload->>'project_numeric_id') ~ '^[0-9]+$'
         AND p.numeric_id = (j.payload->>'project_numeric_id')::int
        LEFT JOIN app_script s
          ON s.project_id = p.id
         AND (j.payload->>'script_numeric_id') ~ '^[0-9]+$'
         AND s.numeric_id = (j.payload->>'script_numeric_id')::int
        LEFT JOIN app_storyboard sb
          ON sb.script_id = s.id
         AND (j.payload->>'storyboard_numeric_id') ~ '^[0-9]+$'
         AND sb.numeric_id = (j.payload->>'storyboard_numeric_id')::int
        WHERE j.kind = $1
          AND j.owner_user_id = $2
          AND ($3::uuid IS NULL OR p.id = $3)
          AND ($4::text IS NULL OR j.status = $4)
        ORDER BY j.created_at DESC
        LIMIT $5
        OFFSET $6
        "#,
    )
    .bind(JOB_KIND_VOICEOVER_GENERATE)
    .bind(uid)
    .bind(query.project_id)
    .bind(status)
    .bind(limit)
    .bind(offset)
    .fetch_all(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;
    Ok(Json(rows))
}

#[utoipa::path(
    get,
    path = "/api/v1/tts/tasks/{task_id}",
    params(
        ("task_id" = Uuid, Path, description = "TTS task id")
    ),
    responses(
        (status = 200, description = "TTS 任务详情", body = TtsTaskResponse),
        (status = 401, description = "未授权"),
        (status = 404, description = "任务不存在"),
        (status = 500, description = "服务器错误"),
    ),
    tag = "tts"
)]
pub async fn get_tts_task(
    State(state): State<AppState>,
    headers: HeaderMap,
    Path(task_id): Path<Uuid>,
) -> Result<Json<TtsTaskResponse>, ApiError> {
    let uid = require_user_uuid(&state, &headers)?;
    let pool = state
        .pool
        .as_ref()
        .ok_or(ApiError::DatabaseError("Database not configured".into()))?;

    let row: Option<TtsTaskResponse> = sqlx::query_as(
        r#"
        SELECT
          j.id AS task_id,
          p.id AS project_id,
          sb.id AS shot_id,
          j.status,
          CASE
            WHEN jsonb_typeof(j.result) = 'object' THEN NULLIF(j.result->>'audio_url', '')
            ELSE NULL
          END AS audio_url,
          j.error_message AS error,
          j.created_at,
          j.updated_at
        FROM app_generation_job j
        JOIN app_project p
          ON p.owner_user_id = j.owner_user_id
         AND (j.payload->>'project_numeric_id') ~ '^[0-9]+$'
         AND p.numeric_id = (j.payload->>'project_numeric_id')::int
        LEFT JOIN app_script s
          ON s.project_id = p.id
         AND (j.payload->>'script_numeric_id') ~ '^[0-9]+$'
         AND s.numeric_id = (j.payload->>'script_numeric_id')::int
        LEFT JOIN app_storyboard sb
          ON sb.script_id = s.id
         AND (j.payload->>'storyboard_numeric_id') ~ '^[0-9]+$'
         AND sb.numeric_id = (j.payload->>'storyboard_numeric_id')::int
        WHERE j.kind = $1
          AND j.owner_user_id = $2
          AND j.id = $3
        "#,
    )
    .bind(JOB_KIND_VOICEOVER_GENERATE)
    .bind(uid)
    .bind(task_id)
    .fetch_optional(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;
    Ok(Json(row.ok_or(ApiError::NotFound)?))
}

#[utoipa::path(
    post,
    path = "/api/v1/tts/cancel",
    request_body = TtsCancelRequest,
    responses(
        (status = 200, description = "TTS 任务取消结果", body = TtsCancelResponse),
        (status = 400, description = "请求参数无效"),
        (status = 401, description = "未授权"),
        (status = 404, description = "任务不存在"),
        (status = 500, description = "服务器错误"),
    ),
    tag = "tts"
)]
pub async fn cancel_tts_task(
    State(state): State<AppState>,
    headers: HeaderMap,
    Json(req): Json<TtsCancelRequest>,
) -> Result<Json<TtsCancelResponse>, ApiError> {
    let uid = require_user_uuid(&state, &headers)?;
    let pool = state
        .pool
        .as_ref()
        .ok_or(ApiError::DatabaseError("Database not configured".into()))?;
    let updated: Option<Uuid> = sqlx::query_scalar(
        r#"
        UPDATE app_generation_job
        SET status = 'cancelled', updated_at = NOW()
        WHERE id = $1
          AND kind = $2
          AND owner_user_id = $3
          AND status IN ('queued', 'running')
        RETURNING id
        "#,
    )
    .bind(req.task_id)
    .bind(JOB_KIND_VOICEOVER_GENERATE)
    .bind(uid)
    .fetch_optional(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;
    Ok(Json(TtsCancelResponse {
        task_id: req.task_id,
        cancelled: updated.is_some(),
    }))
}

#[utoipa::path(
    post,
    path = "/api/v1/tts/retry",
    request_body = TtsRetryRequest,
    responses(
        (status = 200, description = "TTS 任务重试已入队", body = TtsRetryResponse),
        (status = 400, description = "请求参数无效"),
        (status = 401, description = "未授权"),
        (status = 404, description = "任务不存在"),
        (status = 500, description = "服务器错误"),
    ),
    tag = "tts"
)]
pub async fn retry_tts_task(
    State(state): State<AppState>,
    headers: HeaderMap,
    Json(req): Json<TtsRetryRequest>,
) -> Result<Json<TtsRetryResponse>, ApiError> {
    let uid = require_user_uuid(&state, &headers)?;
    let pool = state
        .pool
        .as_ref()
        .ok_or(ApiError::DatabaseError("Database not configured".into()))?;

    let base: Option<(Value, Uuid, Option<Uuid>, Option<String>)> = sqlx::query_as(
        r#"
        SELECT
          j.payload,
          p.id AS project_id,
          sb.id AS shot_id,
          p.voice_profile
        FROM app_generation_job j
        JOIN app_project p
          ON p.owner_user_id = j.owner_user_id
         AND (j.payload->>'project_numeric_id') ~ '^[0-9]+$'
         AND p.numeric_id = (j.payload->>'project_numeric_id')::int
        LEFT JOIN app_script s
          ON s.project_id = p.id
         AND (j.payload->>'script_numeric_id') ~ '^[0-9]+$'
         AND s.numeric_id = (j.payload->>'script_numeric_id')::int
        LEFT JOIN app_storyboard sb
          ON sb.script_id = s.id
         AND (j.payload->>'storyboard_numeric_id') ~ '^[0-9]+$'
         AND sb.numeric_id = (j.payload->>'storyboard_numeric_id')::int
        WHERE j.id = $1
          AND j.kind = $2
          AND j.owner_user_id = $3
          AND j.status IN ('failed', 'cancelled')
        "#,
    )
    .bind(req.task_id)
    .bind(JOB_KIND_VOICEOVER_GENERATE)
    .bind(uid)
    .fetch_optional(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;
    let (payload, _project_id, shot_id, voice_profile) = base.ok_or(ApiError::NotFound)?;
    let shot_id =
        shot_id.ok_or_else(|| ApiError::BadRequest("task has no resolvable storyboard".into()))?;

    let project_numeric_id = payload
        .get("project_numeric_id")
        .and_then(Value::as_i64)
        .ok_or_else(|| ApiError::BadRequest("task payload missing project_numeric_id".into()))?
        as i32;
    let script_numeric_id = payload
        .get("script_numeric_id")
        .and_then(Value::as_i64)
        .ok_or_else(|| ApiError::BadRequest("task payload missing script_numeric_id".into()))?
        as i32;
    let storyboard_numeric_id = payload
        .get("storyboard_numeric_id")
        .and_then(Value::as_i64)
        .ok_or_else(|| ApiError::BadRequest("task payload missing storyboard_numeric_id".into()))?
        as i32;

    let source_text = payload
        .get("source_text")
        .and_then(Value::as_str)
        .map(str::trim)
        .filter(|v| !v.is_empty())
        .ok_or_else(|| ApiError::BadRequest("task payload missing source_text".into()))?
        .to_string();
    let provider = req
        .provider
        .as_deref()
        .map(str::trim)
        .filter(|v| !v.is_empty())
        .or_else(|| {
            payload
                .get("provider")
                .and_then(Value::as_str)
                .map(str::trim)
                .filter(|v| !v.is_empty())
        })
        .unwrap_or("openai");
    let requested_voice = req
        .voice_id
        .as_deref()
        .map(str::trim)
        .filter(|v| !v.is_empty())
        .or_else(|| {
            payload
                .get("voice")
                .and_then(Value::as_str)
                .map(str::trim)
                .filter(|v| !v.is_empty())
        });
    let resolved_voice = resolve_tts_voice(requested_voice, voice_profile.as_deref());
    let speed = req
        .speed
        .or_else(|| {
            payload
                .get("speed")
                .and_then(Value::as_f64)
                .map(|v| v as f32)
        })
        .filter(|value| *value >= 0.25 && *value <= 4.0);
    let emotion = req
        .emotion
        .as_deref()
        .map(str::trim)
        .filter(|v| !v.is_empty())
        .or_else(|| {
            payload
                .get("emotion")
                .and_then(Value::as_str)
                .map(str::trim)
                .filter(|v| !v.is_empty())
        });

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
    .bind(shot_id)
    .bind(json!({
        "state": "queued",
        "voice": resolved_voice,
        "speed": speed,
        "sourceText": source_text,
        "provider": provider,
        "emotion": emotion,
        "error": null,
        "updatedAt": chrono::Utc::now().to_rfc3339(),
    }))
    .execute(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    let mut new_payload = json!({
      "project_numeric_id": project_numeric_id,
      "script_numeric_id": script_numeric_id,
      "storyboard_numeric_id": storyboard_numeric_id,
      "voice": resolved_voice,
      "source_text": source_text,
      "provider": provider,
      "retry_of_task_id": req.task_id,
    });
    if let Some(speed_value) = speed {
        new_payload["speed"] = json!(speed_value);
    }
    if let Some(emotion_value) = emotion {
        new_payload["emotion"] = json!(emotion_value);
    }

    let job = enqueue_generation_job(
        pool,
        uid,
        JOB_KIND_VOICEOVER_GENERATE,
        new_payload,
        Some(&headers),
    )
    .await?;

    Ok(Json(TtsRetryResponse {
        previous_task_id: req.task_id,
        task_id: job.id,
        status: "queued".to_string(),
    }))
}
