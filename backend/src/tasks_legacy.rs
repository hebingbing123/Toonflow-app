//! Legacy **`/api/task/*`** (Electron task center) as **`POST /api/v1/tasks/*`**.
//! Maps to **`app_project`** / **`app_generation_job`** where shapes align; **`task-details`** stays **501** (numeric **`o_tasks.id`** has no UUID mapping).

use axum::{
    extract::{Json, State},
    http::HeaderMap,
    routing::post,
    Json as JsonResponse, Router,
};
use serde::{Deserialize, Serialize};

use crate::auth::require_user_uuid;
use crate::error::ApiError;
use crate::jobs::JobRow;
use crate::state::AppState;

#[derive(Debug, Deserialize, Default)]
#[serde(deny_unknown_fields)]
struct LegacyEmptyBody {}

#[derive(Debug, Serialize)]
struct LegacyTaskProjectItem {
    id: i32,
    name: String,
}

#[derive(Debug, Serialize)]
struct LegacyGetProjectResponse {
    data: Vec<LegacyTaskProjectItem>,
}

#[derive(Debug, Serialize)]
struct TaskClassRow {
    #[serde(rename = "taskClass")]
    task_class: String,
}

#[derive(Debug, Serialize)]
struct LegacyGetTaskCategoriesResponse {
    data: Vec<TaskClassRow>,
}

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
struct GetTaskApiBody {
    #[serde(default)]
    state: Option<String>,
    #[serde(default)]
    task_class: Option<String>,
    #[serde(default)]
    project_id: Option<i32>,
    page: i32,
    limit: i32,
}

#[derive(Debug, Serialize)]
struct LegacyGetTaskApiResponse {
    data: Vec<JobRow>,
    total: i64,
}

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
struct TaskDetailsBody {
    /// Legacy **`o_tasks.id`**; SaaS jobs use UUID (**`501`** until a mapping exists).
    #[allow(dead_code)]
    task_id: i32,
}

fn trim_opt(s: Option<String>) -> Option<String> {
    s.and_then(|v| {
        let t = v.trim();
        if t.is_empty() {
            None
        } else {
            Some(t.to_owned())
        }
    })
}

fn task_details_not_implemented() -> ApiError {
    ApiError::NotImplemented(
        "legacy numeric taskId does not map to app_generation_job UUID ids; use GET /api/v1/jobs/{id}"
            .into(),
    )
}

async fn post_get_project(
    State(state): State<AppState>,
    headers: HeaderMap,
    Json(_body): Json<LegacyEmptyBody>,
) -> Result<JsonResponse<LegacyGetProjectResponse>, ApiError> {
    let uid = require_user_uuid(&state, &headers)?;
    let pool = state
        .pool
        .as_ref()
        .ok_or_else(|| ApiError::DatabaseError("DATABASE_URL not configured".into()))?;

    let rows: Vec<(i32, Option<String>)> = sqlx::query_as(
        r#"
        SELECT legacy_id, name
        FROM app_project
        WHERE owner_user_id = $1
        ORDER BY create_time_ms DESC NULLS LAST, legacy_id DESC
        "#,
    )
    .bind(uid)
    .fetch_all(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    let data = rows
        .into_iter()
        .filter_map(|(legacy_id, name)| {
            let n = name?;
            let t = n.trim();
            if t.is_empty() {
                None
            } else {
                Some(LegacyTaskProjectItem {
                    id: legacy_id,
                    name: t.to_owned(),
                })
            }
        })
        .collect();

    Ok(JsonResponse(LegacyGetProjectResponse { data }))
}

async fn post_get_task_categories(
    State(state): State<AppState>,
    headers: HeaderMap,
    Json(_body): Json<LegacyEmptyBody>,
) -> Result<JsonResponse<LegacyGetTaskCategoriesResponse>, ApiError> {
    let uid = require_user_uuid(&state, &headers)?;
    let pool = state
        .pool
        .as_ref()
        .ok_or_else(|| ApiError::DatabaseError("DATABASE_URL not configured".into()))?;

    let kinds: Vec<String> = sqlx::query_scalar(
        r#"
        SELECT DISTINCT kind
        FROM app_generation_job
        WHERE owner_user_id = $1 AND kind <> ''
        ORDER BY kind ASC
        "#,
    )
    .bind(uid)
    .fetch_all(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    let data = kinds
        .into_iter()
        .map(|task_class| TaskClassRow { task_class })
        .collect();

    Ok(JsonResponse(LegacyGetTaskCategoriesResponse { data }))
}

async fn post_get_task_api(
    State(state): State<AppState>,
    headers: HeaderMap,
    Json(body): Json<GetTaskApiBody>,
) -> Result<JsonResponse<LegacyGetTaskApiResponse>, ApiError> {
    let uid = require_user_uuid(&state, &headers)?;
    if body.page < 1 {
        return Err(ApiError::BadRequest("page must be >= 1".into()));
    }
    if body.limit < 1 || body.limit > 100 {
        return Err(ApiError::BadRequest(
            "limit must be between 1 and 100".into(),
        ));
    }

    let pool = state
        .pool
        .as_ref()
        .ok_or_else(|| ApiError::DatabaseError("DATABASE_URL not configured".into()))?;

    let kind = trim_opt(body.task_class);
    let status = trim_opt(body.state);
    let project_key = body
        .project_id
        .map(|n| n.to_string())
        .filter(|s| !s.is_empty());

    let total: i64 = sqlx::query_scalar(
        r#"
        SELECT COUNT(*)::bigint
        FROM app_generation_job
        WHERE owner_user_id = $1
          AND ($2::text IS NULL OR kind = $2)
          AND ($3::text IS NULL OR status = $3)
          AND ($4::text IS NULL OR payload->>'project_legacy_id' = $4)
        "#,
    )
    .bind(uid)
    .bind(kind.as_deref())
    .bind(status.as_deref())
    .bind(project_key.as_deref())
    .fetch_one(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    let offset = (body.page - 1) * body.limit;
    let rows = sqlx::query_as::<_, JobRow>(
        r#"
        SELECT id, owner_user_id, kind, status, payload, result, error_message, idempotency_key, claimed_by, created_at, updated_at
        FROM app_generation_job
        WHERE owner_user_id = $1
          AND ($2::text IS NULL OR kind = $2)
          AND ($3::text IS NULL OR status = $3)
          AND ($4::text IS NULL OR payload->>'project_legacy_id' = $4)
        ORDER BY created_at DESC
        OFFSET $5
        LIMIT $6
        "#,
    )
    .bind(uid)
    .bind(kind.as_deref())
    .bind(status.as_deref())
    .bind(project_key.as_deref())
    .bind(offset as i64)
    .bind(body.limit as i64)
    .fetch_all(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    Ok(JsonResponse(LegacyGetTaskApiResponse { data: rows, total }))
}

async fn post_task_details(
    State(state): State<AppState>,
    headers: HeaderMap,
    Json(_body): Json<TaskDetailsBody>,
) -> Result<JsonResponse<JobRow>, ApiError> {
    let _ = require_user_uuid(&state, &headers)?;
    Err(task_details_not_implemented())
}

pub fn router() -> Router<AppState> {
    Router::new()
        .route("/api/v1/tasks/get-project", post(post_get_project))
        .route(
            "/api/v1/tasks/get-task-categories",
            post(post_get_task_categories),
        )
        .route("/api/v1/tasks/get-task-api", post(post_get_task_api))
        .route("/api/v1/tasks/task-details", post(post_task_details))
}
