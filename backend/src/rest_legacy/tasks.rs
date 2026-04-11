//! 遗留任务接口（Electron 任务中心）作为 `POST /api/v1/tasks/*`。
//!
//! 映射到 `app_project` / `app_generation_job`（在形状对齐处）；`task-details` 接受 `taskId` 作为 **UUID 字符串**（`app_generation_job.id`）或单调**整数**（`app_generation_job.legacy_task_id`）以兼容遗留任务中心。

use axum::{
    extract::{Json, State},
    http::HeaderMap,
    routing::post,
    Json as JsonResponse, Router,
};
use serde::{Deserialize, Serialize};
use serde_json::Value;
use uuid::Uuid;

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
    /// **`taskId`**: UUID string → load by **`app_generation_job.id`**; positive integer → load by **`legacy_task_id`**.
    task_id: Value,
}

fn normalize_project_filter(project_id: Option<i32>) -> Option<String> {
    project_id
        .filter(|id| *id > 0)
        .map(|id| id.to_string())
        .filter(|s| !s.is_empty())
}

fn compute_page_offset(page: i32, limit: i32) -> i64 {
    i64::from(page - 1) * i64::from(limit)
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

async fn fetch_task_detail_row_by_legacy_task_id(
    pool: &sqlx::PgPool,
    uid: uuid::Uuid,
    legacy_task_id: i64,
) -> Result<JobRow, ApiError> {
    sqlx::query_as::<_, JobRow>(
        r#"
        SELECT legacy_task_id, id, owner_user_id, kind, status, payload, result, error_message, idempotency_key, claimed_by, created_at, updated_at
        FROM app_generation_job
        WHERE owner_user_id = $1 AND legacy_task_id = $2
        "#,
    )
    .bind(uid)
    .bind(legacy_task_id)
    .fetch_optional(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?
    .ok_or(ApiError::NotFound)
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
    let project_key = normalize_project_filter(body.project_id);

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

    let offset = compute_page_offset(body.page, body.limit);
    let rows = sqlx::query_as::<_, JobRow>(
        r#"
        SELECT legacy_task_id, id, owner_user_id, kind, status, payload, result, error_message, idempotency_key, claimed_by, created_at, updated_at
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
    .bind(offset)
    .bind(body.limit as i64)
    .fetch_all(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    Ok(JsonResponse(LegacyGetTaskApiResponse { data: rows, total }))
}

async fn post_task_details(
    State(state): State<AppState>,
    headers: HeaderMap,
    Json(body): Json<TaskDetailsBody>,
) -> Result<JsonResponse<JobRow>, ApiError> {
    let uid = require_user_uuid(&state, &headers)?;

    match body.task_id {
        Value::Number(n) => {
            let legacy = n.as_i64().ok_or_else(|| {
                ApiError::BadRequest("taskId integer out of supported range".into())
            })?;
            if legacy <= 0 {
                return Err(ApiError::BadRequest("taskId must be positive".into()));
            }
            let pool = state
                .pool
                .as_ref()
                .ok_or_else(|| ApiError::DatabaseError("DATABASE_URL not configured".into()))?;
            let row = fetch_task_detail_row_by_legacy_task_id(pool, uid, legacy).await?;
            Ok(JsonResponse(row))
        }
        Value::String(s) => {
            let task_id = s.trim();
            if let Ok(legacy_task_id) = task_id.parse::<i64>() {
                if legacy_task_id <= 0 {
                    return Err(ApiError::BadRequest("taskId must be positive".into()));
                }
                let pool = state
                    .pool
                    .as_ref()
                    .ok_or_else(|| ApiError::DatabaseError("DATABASE_URL not configured".into()))?;
                let row =
                    fetch_task_detail_row_by_legacy_task_id(pool, uid, legacy_task_id).await?;
                return Ok(JsonResponse(row));
            }
            let id = Uuid::parse_str(task_id).map_err(|_| {
                ApiError::BadRequest("taskId string must be a UUID or a positive integer".into())
            })?;
            let pool = state
                .pool
                .as_ref()
                .ok_or_else(|| ApiError::DatabaseError("DATABASE_URL not configured".into()))?;
            let row = sqlx::query_as::<_, JobRow>(
                r#"
                SELECT legacy_task_id, id, owner_user_id, kind, status, payload, result, error_message, idempotency_key, claimed_by, created_at, updated_at
                FROM app_generation_job
                WHERE id = $1 AND owner_user_id = $2
                "#,
            )
            .bind(id)
            .bind(uid)
            .fetch_optional(pool)
            .await
            .map_err(|e| ApiError::DatabaseError(e.to_string()))?
            .ok_or(ApiError::NotFound)?;
            Ok(JsonResponse(row))
        }
        _ => Err(ApiError::BadRequest(
            "taskId must be a UUID string, a numeric string, or a positive integer".into(),
        )),
    }
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

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn legacy_empty_body_rejects_unknown_fields() {
        let err = serde_json::from_str::<LegacyEmptyBody>(r#"{"extra":1}"#);
        assert!(err.is_err());
    }

    #[test]
    fn legacy_empty_body_accepts_empty() {
        let b: LegacyEmptyBody = serde_json::from_str(r#"{}"#).unwrap();
        let _ = b;
    }

    #[test]
    fn get_task_api_body_rejects_unknown_fields() {
        let err = serde_json::from_str::<GetTaskApiBody>(r#"{"page":1,"limit":20,"extra":1}"#);
        assert!(err.is_err());
    }

    #[test]
    fn get_task_api_body_accepts_minimal() {
        let b: GetTaskApiBody = serde_json::from_str(r#"{"page":1,"limit":20}"#).unwrap();
        assert_eq!(b.page, 1);
        assert_eq!(b.limit, 20);
        assert_eq!(b.state, None);
        assert_eq!(b.task_class, None);
        assert_eq!(b.project_id, None);
    }

    #[test]
    fn get_task_api_body_accepts_full() {
        let b: GetTaskApiBody = serde_json::from_str(
            r#"{"page":2,"limit":50,"state":"running","taskClass":"image.generate","projectId":5}"#,
        )
        .unwrap();
        assert_eq!(b.page, 2);
        assert_eq!(b.limit, 50);
        assert_eq!(b.state, Some("running".to_string()));
        assert_eq!(b.task_class, Some("image.generate".to_string()));
        assert_eq!(b.project_id, Some(5));
    }

    #[test]
    fn task_details_body_rejects_unknown_fields() {
        let err = serde_json::from_str::<TaskDetailsBody>(
            r#"{"taskId":"550e8400-e29b-41d4-a716-446655440000","extra":1}"#,
        );
        assert!(err.is_err());
    }

    #[test]
    fn task_details_body_accepts_uuid_string() {
        let b: TaskDetailsBody =
            serde_json::from_str(r#"{"taskId":"550e8400-e29b-41d4-a716-446655440000"}"#).unwrap();
        match b.task_id {
            Value::String(s) => assert_eq!(s, "550e8400-e29b-41d4-a716-446655440000"),
            _ => panic!("Expected string"),
        }
    }

    #[test]
    fn task_details_body_accepts_integer() {
        let b: TaskDetailsBody = serde_json::from_str(r#"{"taskId":123}"#).unwrap();
        match b.task_id {
            Value::Number(n) => assert_eq!(n.as_i64(), Some(123)),
            _ => panic!("Expected number"),
        }
    }

    #[test]
    fn task_details_body_accepts_numeric_string() {
        let b: TaskDetailsBody = serde_json::from_str(r#"{"taskId":"123"}"#).unwrap();
        match b.task_id {
            Value::String(s) => assert_eq!(s, "123"),
            _ => panic!("Expected string"),
        }
    }

    #[test]
    fn trim_opt_returns_none_for_none() {
        assert_eq!(trim_opt(None), None);
    }

    #[test]
    fn trim_opt_returns_none_for_empty() {
        assert_eq!(trim_opt(Some("".to_string())), None);
        assert_eq!(trim_opt(Some("   ".to_string())), None);
    }

    #[test]
    fn trim_opt_returns_trimmed() {
        assert_eq!(
            trim_opt(Some("  hello  ".to_string())),
            Some("hello".to_string())
        );
        assert_eq!(trim_opt(Some("test".to_string())), Some("test".to_string()));
    }

    #[test]
    fn normalize_project_filter_returns_none_for_none_or_non_positive() {
        assert_eq!(normalize_project_filter(None), None);
        assert_eq!(normalize_project_filter(Some(0)), None);
        assert_eq!(normalize_project_filter(Some(-1)), None);
    }

    #[test]
    fn normalize_project_filter_returns_text_for_positive() {
        assert_eq!(normalize_project_filter(Some(7)), Some("7".to_string()));
    }

    #[test]
    fn compute_page_offset_handles_normal_and_large_values() {
        assert_eq!(compute_page_offset(1, 10), 0);
        assert_eq!(compute_page_offset(3, 10), 20);
        assert_eq!(compute_page_offset(i32::MAX, 100), 214748364600);
    }

    #[test]
    fn legacy_task_project_item_serialize() {
        let item = LegacyTaskProjectItem {
            id: 1,
            name: "Test Project".to_string(),
        };
        let json = serde_json::to_string(&item).unwrap();
        assert!(json.contains("\"id\":1"));
        assert!(json.contains("\"name\":\"Test Project\""));
    }

    #[test]
    fn legacy_get_project_response_serialize() {
        let resp = LegacyGetProjectResponse { data: vec![] };
        let json = serde_json::to_string(&resp).unwrap();
        assert!(json.contains("\"data\":[]"));
    }

    #[test]
    fn task_class_row_serialize() {
        let row = TaskClassRow {
            task_class: "image.generate".to_string(),
        };
        let json = serde_json::to_string(&row).unwrap();
        assert!(json.contains("\"taskClass\":\"image.generate\""));
    }

    #[test]
    fn legacy_get_task_categories_response_serialize() {
        let resp = LegacyGetTaskCategoriesResponse { data: vec![] };
        let json = serde_json::to_string(&resp).unwrap();
        assert!(json.contains("\"data\":[]"));
    }

    #[test]
    fn legacy_get_task_api_response_serialize() {
        let resp = LegacyGetTaskApiResponse {
            data: vec![],
            total: 0,
        };
        let json = serde_json::to_string(&resp).unwrap();
        assert!(json.contains("\"data\":[]"));
        assert!(json.contains("\"total\":0"));
    }
}
