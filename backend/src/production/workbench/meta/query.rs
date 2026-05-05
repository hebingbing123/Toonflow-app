use axum::{
    extract::{Json, State},
    http::HeaderMap,
    Json as JsonResponse,
};
use serde::{Deserialize, Serialize};
use std::collections::BTreeSet;

use crate::error::ApiError;
use crate::jobs::{JobRow, JOB_KIND_VIDEO_GENERATE};
use crate::production::VideoItem;
use crate::scope::http::require_owned_numeric_script_scope_ids;
use crate::state::AppState;

/// Server-side rollup for MP-W4 / J3: persisted vs in-flight video generation for a script scope.
#[derive(Debug, Serialize)]
#[serde(rename_all = "camelCase")]
pub(in crate::production) struct VideoBatchWritebackSummary {
    pub schema_version: i32,
    pub script_storyboard_count: i64,
    pub storyboard_numeric_ids_with_persisted_video: Vec<i32>,
    pub storyboard_numeric_ids_with_in_flight_generation: Vec<i32>,
    pub storyboard_numeric_ids_pending_writeback: Vec<i32>,
    pub in_flight_generation_job_count: i64,
}

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
pub(in crate::production) struct GetGenerateDataBody {
    project_id: i32,
    script_id: i32,
}

#[derive(Debug, Serialize)]
#[serde(rename_all = "camelCase")]
pub(in crate::production) struct GetGenerateDataResponse {
    project_id: i32,
    script_id: i32,
    generated_videos: Vec<VideoItem>,
    generating_jobs: Vec<JobRow>,
    video_writeback_summary: VideoBatchWritebackSummary,
}

#[utoipa::path(
    post,
    path = "/api/v1/production/workbench/get-generate-data",
    operation_id = "postProductionWorkbenchGetGenerateDataV1",
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
pub(in crate::production) async fn post_workbench_get_generate_data(
    State(state): State<AppState>,
    headers: HeaderMap,
    Json(body): Json<GetGenerateDataBody>,
) -> Result<JsonResponse<GetGenerateDataResponse>, ApiError> {
    const GEN_JOB_SCOPE_FILTER: &str = r#"
        j.owner_user_id = $1
        AND j.kind = $2
        AND j.status IN ('queued', 'running')
        AND (j.payload->>'project_numeric_id') ~ '^[0-9]+$'
        AND (j.payload->>'project_numeric_id')::int = $3
        AND (j.payload->>'script_id') ~ '^[0-9]+$'
        AND (j.payload->>'script_id')::int = $4
    "#;

    let (uid, pool, script_id) =
        require_owned_numeric_script_scope_ids(&state, &headers, body.project_id, body.script_id)
            .await?;

    let generated_videos = sqlx::query_as::<_, VideoItem>(
        r#"
        SELECT
          sb.numeric_id AS id,
          sc.numeric_id AS script_id,
          sb.prompt,
          sb.file_path AS video_url,
          sb.duration,
          sb.state,
          sb.track_id,
          sb.created_at
        FROM app_storyboard sb
        INNER JOIN app_script sc ON sc.id = sb.script_id
        WHERE sb.script_id = $1
          AND sb.file_path IS NOT NULL
          AND (sb.file_path LIKE '%.mp4' OR sb.file_path LIKE '%.mov' OR sb.file_path LIKE '%.webm')
        ORDER BY sb.created_at DESC
        "#,
    )
    .bind(script_id)
    .fetch_all(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    let generating_jobs_sql = format!(
        r#"
        SELECT numeric_task_id, id, owner_user_id, kind, status, payload, result, error_message, error_details, idempotency_key, claimed_by, created_at, updated_at
        FROM app_generation_job j
        WHERE {}
        ORDER BY j.created_at DESC
        LIMIT 50
        "#,
        GEN_JOB_SCOPE_FILTER,
    );

    let generating_jobs = sqlx::query_as::<_, JobRow>(&generating_jobs_sql)
        .bind(uid)
        .bind(JOB_KIND_VIDEO_GENERATE)
        .bind(body.project_id)
        .bind(body.script_id)
        .fetch_all(pool)
        .await
        .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    let script_storyboard_count: i64 = sqlx::query_scalar(
        r#"SELECT COUNT(*)::bigint FROM app_storyboard sb WHERE sb.script_id = $1"#,
    )
    .bind(script_id)
    .fetch_one(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    let in_flight_generation_job_count: i64 = {
        let count_sql = format!(
            r#"SELECT COUNT(*)::bigint FROM app_generation_job j WHERE {}"#,
            GEN_JOB_SCOPE_FILTER,
        );
        sqlx::query_scalar(&count_sql)
            .bind(uid)
            .bind(JOB_KIND_VIDEO_GENERATE)
            .bind(body.project_id)
            .bind(body.script_id)
            .fetch_one(pool)
            .await
            .map_err(|e| ApiError::DatabaseError(e.to_string()))?
    };

    let in_flight_storyboards_sql = format!(
        r#"
        SELECT DISTINCT (j.payload->>'storyboard_numeric_id')::int AS sb_id
        FROM app_generation_job j
        WHERE {}
          AND j.payload ? 'storyboard_numeric_id'
          AND (j.payload->>'storyboard_numeric_id') ~ '^[0-9]+$'
        ORDER BY sb_id ASC
        "#,
        GEN_JOB_SCOPE_FILTER,
    );

    let storyboard_numeric_ids_with_in_flight_generation: Vec<i32> =
        sqlx::query_scalar::<_, i32>(&in_flight_storyboards_sql)
            .bind(uid)
            .bind(JOB_KIND_VIDEO_GENERATE)
            .bind(body.project_id)
            .bind(body.script_id)
            .fetch_all(pool)
            .await
            .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    let persisted_storyboards: BTreeSet<i32> = generated_videos.iter().map(|v| v.id).collect();
    let storyboard_numeric_ids_with_persisted_video: Vec<i32> =
        persisted_storyboards.iter().copied().collect();

    let storyboard_numeric_ids_pending_writeback: Vec<i32> =
        storyboard_numeric_ids_with_in_flight_generation
            .iter()
            .copied()
            .filter(|id| !persisted_storyboards.contains(id))
            .collect();

    Ok(JsonResponse(GetGenerateDataResponse {
        project_id: body.project_id,
        script_id: body.script_id,
        generated_videos,
        generating_jobs,
        video_writeback_summary: VideoBatchWritebackSummary {
            schema_version: 1,
            script_storyboard_count,
            storyboard_numeric_ids_with_persisted_video,
            storyboard_numeric_ids_with_in_flight_generation,
            storyboard_numeric_ids_pending_writeback,
            in_flight_generation_job_count,
        },
    }))
}
