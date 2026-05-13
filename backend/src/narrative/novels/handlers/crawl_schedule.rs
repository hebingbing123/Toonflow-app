use axum::{
    extract::{Json, Path, State},
    http::HeaderMap,
    Json as JsonResponse,
};
use chrono::{DateTime, Utc};
use serde::{Deserialize, Serialize};
use serde_json::json;
use utoipa::ToSchema;
use uuid::Uuid;

use crate::auth::require_user_uuid;
use crate::error::{bad_request_i18n, validate_enum, ApiError};
use crate::jobs::{
    billing_workspace::resolve_billing_workspace_id, enqueue_generation_job, hydrate_job_row,
    merge_client_request_id_from_http_headers, JobRow, JOB_KIND_NOVEL_CRAWL_IMPORT_BATCH,
};
use crate::metering::quota;
use crate::projects::routes::common::{
    require_project_workspace_member_scope, require_project_write_scope,
};
use crate::state::AppState;

#[derive(Debug, Deserialize, Serialize, ToSchema)]
#[serde(deny_unknown_fields)]
pub struct NovelCrawlScheduleCreateBody {
    pub urls: Vec<String>,
    /// Unix epoch milliseconds; omitted or <=0 means run immediately.
    #[serde(default)]
    pub run_at_ms: Option<i64>,
    /// When set (>0), worker auto-enqueues the next run.
    #[serde(default)]
    pub repeat_interval_ms: Option<i64>,
    pub intake_status: String,
    #[serde(default)]
    pub intake_note: Option<String>,
    /// Optional project numeric id to enable task-center filtering (`/api/v1/jobs/page?project_id=...`).
    #[serde(default)]
    pub project_numeric_id: Option<i32>,
    /// Optional idempotency key: same user + same key returns the existing schedule job.
    #[serde(default)]
    pub idempotency_key: Option<String>,
}

#[derive(Debug, Serialize, ToSchema)]
pub struct NovelCrawlScheduleRow {
    pub numeric_task_id: i64,
    pub id: Uuid,
    pub kind: String,
    pub status: String,
    pub payload: serde_json::Value,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub error_message: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub error_details: Option<serde_json::Value>,
    pub created_at: DateTime<Utc>,
    pub updated_at: DateTime<Utc>,
}

fn schedule_row_from_job(mut row: JobRow) -> NovelCrawlScheduleRow {
    hydrate_job_row(&mut row);
    NovelCrawlScheduleRow {
        numeric_task_id: row.numeric_task_id,
        id: row.id,
        kind: row.kind,
        status: row.status,
        payload: row.payload,
        error_message: row.error_message,
        error_details: row.error_details,
        created_at: row.created_at,
        updated_at: row.updated_at,
    }
}

fn validate_intake_status(value: &str) -> Result<(), ApiError> {
    validate_enum(
        value,
        &["draft", "pending_review", "admitted", "rejected"],
        "intake_status",
    )
}

fn normalize_urls(urls: &[String]) -> Vec<String> {
    urls.iter()
        .map(|s| s.trim().to_string())
        .filter(|s| !s.is_empty())
        .collect()
}

#[utoipa::path(
    post,
    path = "/api/v1/projects/{project_id}/novels/crawl-schedules",
    operation_id = "postProjectNovelCrawlScheduleCreateByProjectIdV1",
    tag = "novels",
    params(
        ("project_id" = Uuid, Path, description = "Project UUID")
    ),
    request_body = NovelCrawlScheduleCreateBody,
    responses(
        (status = 200, description = "OK", body = NovelCrawlScheduleRow),
        (status = 400, description = "Bad request", body = crate::error::ErrorBody),
        (status = 401, description = "Unauthorized", body = crate::error::ErrorBody),
        (status = 404, description = "Not found", body = crate::error::ErrorBody),
        (status = 503, description = "Unavailable", body = crate::error::ErrorBody)
    ),
    security(("bearerAuth" = []))
)]
pub(crate) async fn post_novel_crawl_schedule_create(
    State(state): State<AppState>,
    headers: HeaderMap,
    Path(project_id): Path<Uuid>,
    Json(body): Json<NovelCrawlScheduleCreateBody>,
) -> Result<JsonResponse<NovelCrawlScheduleRow>, ApiError> {
    let uid = require_user_uuid(&state, &headers)?;
    let pool = state.require_pool()?;
    require_project_write_scope(&state, uid, project_id).await?;

    let urls = normalize_urls(&body.urls);
    if urls.is_empty() {
        return Err(bad_request_i18n("urls must not be empty", "urls 不能为空"));
    }
    if urls.len() > 50 {
        return Err(bad_request_i18n(
            "urls too many (max 50)",
            "urls 过多（最多 50 个）",
        ));
    }
    validate_intake_status(body.intake_status.trim())?;

    let run_at_ms = body.run_at_ms.unwrap_or(0);
    let run_at_ms = if run_at_ms <= 0 {
        chrono::Utc::now().timestamp_millis()
    } else {
        run_at_ms
    };

    let repeat_interval_ms = body.repeat_interval_ms.filter(|v| *v > 0);

    let mut payload = json!({
        "project_id": project_id.to_string(),
        "project_numeric_id": body.project_numeric_id,
        "urls": urls,
        "intake_status": body.intake_status.trim(),
        "intake_note": body.intake_note,
        "run_at_ms": run_at_ms,
        "repeat_interval_ms": repeat_interval_ms,
        "job_sub_kind": "novel.crawl.schedule"
    });
    merge_client_request_id_from_http_headers(&headers, &mut payload);

    let idem = body
        .idempotency_key
        .as_deref()
        .map(str::trim)
        .filter(|s| !s.is_empty())
        .map(|s| s.chars().take(200).collect::<String>());

    // Resolve workspace_id for billing attribution (Task 2.1)
    // Get the project's workspace_id for project-based jobs
    let project_workspace_id: Uuid = sqlx::query_scalar(
        r#"
        SELECT p.workspace_id
        FROM app_project p
        WHERE p.id = $1
          AND p.archived_at IS NULL
        "#,
    )
    .bind(project_id)
    .fetch_one(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    let billing_workspace_id =
        resolve_billing_workspace_id(pool, uid, Some(project_workspace_id)).await?;

    // Check quota with effective billing context (Task 3.3)
    quota::check_daily_job_quota_with_context(
        pool,
        uid,
        billing_workspace_id,
        &state.billing_config,
    )
    .await?;

    let row = if let Some(key) = idem.as_deref() {
        let insert = sqlx::query_as::<_, JobRow>(
            r#"
            INSERT INTO app_generation_job (owner_user_id, kind, payload, status, idempotency_key, workspace_id)
            VALUES ($1, $2, $3, 'queued', $4, $5)
            RETURNING numeric_task_id, id, owner_user_id, kind, status, payload, result, error_message, error_details, idempotency_key, claimed_by, created_at, updated_at
            "#,
        )
        .bind(uid)
        .bind(JOB_KIND_NOVEL_CRAWL_IMPORT_BATCH)
        .bind(payload)
        .bind(key)
        .bind(billing_workspace_id)
        .fetch_one(pool)
        .await;

        match insert {
            Ok(row) => row,
            Err(e) if e.as_database_error().and_then(|db| db.code()).is_some_and(|c| c == "23505") => {
                sqlx::query_as::<_, JobRow>(
                    r#"
                    SELECT numeric_task_id, id, owner_user_id, kind, status, payload, result, error_message, error_details, idempotency_key, claimed_by, created_at, updated_at
                    FROM app_generation_job
                    WHERE owner_user_id = $1 AND idempotency_key = $2
                    "#,
                )
                .bind(uid)
                .bind(key)
                .fetch_optional(pool)
                .await
                .map_err(|e| ApiError::DatabaseError(e.to_string()))?
                .ok_or_else(|| ApiError::DatabaseError("idempotency conflict but row not found".into()))?
            }
            Err(e) => return Err(ApiError::DatabaseError(e.to_string())),
        }
    } else {
        enqueue_generation_job(
            pool,
            uid,
            JOB_KIND_NOVEL_CRAWL_IMPORT_BATCH,
            payload,
            Some(&headers),
            &state.billing_config,
        )
        .await?
    };

    Ok(JsonResponse(schedule_row_from_job(row)))
}

#[utoipa::path(
    get,
    path = "/api/v1/projects/{project_id}/novels/crawl-schedules",
    operation_id = "getProjectNovelCrawlSchedulesByProjectIdV1",
    tag = "novels",
    params(
        ("project_id" = Uuid, Path, description = "Project UUID")
    ),
    responses(
        (status = 200, description = "OK", body = [NovelCrawlScheduleRow]),
        (status = 400, description = "Bad request", body = crate::error::ErrorBody),
        (status = 401, description = "Unauthorized", body = crate::error::ErrorBody),
        (status = 404, description = "Not found", body = crate::error::ErrorBody),
        (status = 503, description = "Unavailable", body = crate::error::ErrorBody)
    ),
    security(("bearerAuth" = []))
)]
pub(crate) async fn list_novel_crawl_schedules(
    State(state): State<AppState>,
    headers: HeaderMap,
    Path(project_id): Path<Uuid>,
) -> Result<JsonResponse<Vec<NovelCrawlScheduleRow>>, ApiError> {
    let uid = require_user_uuid(&state, &headers)?;
    let pool = state.require_pool()?;
    require_project_workspace_member_scope(&state, uid, project_id).await?;

    let rows = sqlx::query_as::<_, JobRow>(
        r#"
        SELECT numeric_task_id, id, owner_user_id, kind, status, payload, result, error_message, error_details, idempotency_key, claimed_by, created_at, updated_at
        FROM app_generation_job
        WHERE kind = $1
          AND payload->>'project_id' = $2
        ORDER BY created_at DESC
        LIMIT 100
        "#,
    )
    .bind(JOB_KIND_NOVEL_CRAWL_IMPORT_BATCH)
    .bind(project_id.to_string())
    .fetch_all(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;
    Ok(JsonResponse(
        rows.into_iter().map(schedule_row_from_job).collect(),
    ))
}
