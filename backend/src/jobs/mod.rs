//! 任务模块：`/api/v1/jobs` 下的 REST 路由和进程内轮询器。
//!
//! 子模块：
//! - `worker` — 任务工作器（`worker/mod.rs` + `worker/*` 子模块）
//! - `queue` — 任务队列抽象

pub mod queue;
pub mod worker;

use axum::{
    extract::{Path, Query, State},
    http::HeaderMap,
    routing::{get, post},
    Json, Router,
};
use chrono::{DateTime, Utc};
use serde::{Deserialize, Serialize};
use serde_json::json;
use sqlx::{FromRow, PgPool};
use uuid::Uuid;

use crate::auth::require_user_uuid;
use crate::error::ApiError;
use crate::metering::quota;
use crate::metering::usage;
use crate::state::AppState;

/// 生成任务数据库行 (`app_generation_job`)。
///
/// 表示一个异步生成任务的完整状态。
#[derive(Debug, FromRow, Serialize)]
pub struct JobRow {
    /// 遗留任务 ID（用于向后兼容）。
    pub legacy_task_id: i64,
    /// 内部 UUID 主键。
    pub id: Uuid,
    /// 任务所有者的用户 ID。
    pub owner_user_id: Uuid,
    /// 任务类型（如 asset.generate.image）。
    pub kind: String,
    /// 任务状态：queued、running、succeeded、failed、cancelled。
    pub status: String,
    /// 任务输入参数 JSON。
    pub payload: serde_json::Value,
    /// 任务成功结果 JSON。
    pub result: Option<serde_json::Value>,
    /// 失败时的错误消息。
    pub error_message: Option<String>,
    /// 幂等性键（用于重复请求检测）。
    pub idempotency_key: Option<String>,
    /// 认领此任务的 Worker 标识（WORKER_ID 环境变量），仅在 running 状态时设置。
    pub claimed_by: Option<String>,
    /// 任务创建时间。
    pub created_at: DateTime<Utc>,
    /// 任务最后更新时间。
    pub updated_at: DateTime<Utc>,
}

/// 任务列表查询参数。
#[derive(Debug, Deserialize, Default)]
struct ListJobsQuery {
    /// 按类型精确匹配（设置时，修剪后；空值省略）。
    #[serde(default)]
    kind: Option<String>,
    /// 按状态精确匹配（设置时，修剪后；空值省略）。
    #[serde(default)]
    status: Option<String>,
    /// 每页大小（1-100），省略则为 100。
    #[serde(default)]
    limit: Option<i64>,
    /// 要跳过的行数（>= 0），省略则为 0。
    #[serde(default)]
    offset: Option<i64>,
}

/// 创建任务的请求体。
#[derive(Debug, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct CreateJobBody {
    /// 任务类型。
    pub kind: String,
    /// 任务输入参数。
    #[serde(default)]
    pub payload: serde_json::Value,
}

/// 按任务类型汇总的数据库行。
#[derive(Debug, FromRow, Serialize)]
struct JobKindSummaryRow {
    /// 任务类型。
    kind: String,
    /// 该类型的任务数量。
    job_count: i64,
}

/// 按任务状态汇总的数据库行。
#[derive(Debug, FromRow, Serialize)]
struct JobStatusSummaryRow {
    /// 任务状态。
    status: String,
    /// 该状态的任务数量。
    job_count: i64,
}

/// 单图资产生成（遗留 `POST …/assets-generate/generate`）。
///
/// Worker 在 payload 有 `image_base64` 时使用 `images/edits`，否则使用 `images/generations`，
/// 然后插入 `app_asset_image`（`file_path` = 提供商 URL 或 `…/images/{id}/file`，
/// 当设置了 `TOONFLOW_LOCAL_ASSET_IMAGE_DIR` 时）。
pub const JOB_KIND_ASSET_GENERATE_IMAGE: &str = "asset.generate.image";
/// 单条提示词优化（遗留 `POST …/assets-generate/polish-prompt`）。
///
/// Worker 在设置了 `LlmConfig` 时调用聊天补全，否则标记为 `failed`。
pub const JOB_KIND_ASSET_POLISH_PROMPT: &str = "asset.polish.prompt";
/// 批量图片生成（`POST …/assets-generate/batch-generate`）。
///
/// Worker 对每个项目运行一次图片调用（优先在 `image_base64` 存在时使用 `images/edits`，
/// 否则使用 `images/generations`），并在设置了 LLM 键时为每个项目插入 `app_asset_image`
/// （`file_path` 规则与单图相同）。
pub const JOB_KIND_ASSET_GENERATE_BATCH: &str = "asset.generate.batch";
/// 批量提示词优化（`POST …/assets-generate/batch-polish`）。
///
/// Worker 在设置了 `LlmConfig` 时为每个项目运行 `chat_completion_assistant_text`
/// （项目间支持协作取消），否则标记为 `failed`。
pub const JOB_KIND_ASSET_POLISH_BATCH: &str = "asset.polish.batch";
/// 遗留 modelTest 探测（`POST …/settings/vendors/model-test`）。
///
/// Worker 使用存储的凭据（如果存在）或服务器环境回退执行实时的文本/图片/视频提供商探测。
pub const JOB_KIND_SETTINGS_VENDOR_MODEL_TEST: &str = "settings.vendor.model_test";
/// Flutter / 集成探测（`POST /api/v1/jobs`）。
///
/// Worker 休眠约 1 秒后返回 `succeeded` 状态，结果为 `{ ok, probe }`。
pub const JOB_KIND_FLUTTER_PROBE: &str = "flutter.probe";
/// 视频生成（`POST …/production/workbench/generate-video`）。
///
/// Worker 根据分镜项目生成视频。
pub const JOB_KIND_VIDEO_GENERATE: &str = "video.generate";
/// 视频导出（`POST …/production/export-image` 作为视频导出）。
///
/// Worker 导出视频文件。
pub const JOB_KIND_VIDEO_EXPORT: &str = "video.export";

/// Enqueue **`queued`** job after quota check (no HTTP idempotency). Records **`generation_job.created`** usage.
pub async fn enqueue_generation_job(
    pool: &PgPool,
    owner_user_id: Uuid,
    kind: &str,
    payload: serde_json::Value,
) -> Result<JobRow, ApiError> {
    quota::check_daily_job_quota(pool, owner_user_id).await?;
    let row = sqlx::query_as::<_, JobRow>(
        r#"
        INSERT INTO app_generation_job (owner_user_id, kind, payload, status, idempotency_key)
        VALUES ($1, $2, $3, 'queued', NULL)
        RETURNING legacy_task_id, id, owner_user_id, kind, status, payload, result, error_message, idempotency_key, claimed_by, created_at, updated_at
        "#,
    )
    .bind(owner_user_id)
    .bind(kind)
    .bind(payload)
    .fetch_one(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    if let Err(e) =
        usage::record_generation_job_created(pool, owner_user_id, row.id, &row.kind).await
    {
        tracing::warn!(
            error = %e,
            job_id = %row.id,
            "app_usage_event insert failed for generation_job.created (job still created)"
        );
    }

    Ok(row)
}

/// WebSocket envelope (`docs/websocket-events.md`): full job row as `payload`.
pub fn envelope_generation_job_updated(row: &JobRow) -> String {
    let v = json!({
        "type": "generation.job.updated",
        "schema_version": 1,
        "payload": row,
    });
    serde_json::to_string(&v).expect("JobRow serializes to JSON")
}

pub fn router() -> Router<AppState> {
    Router::new()
        .route("/api/v1/jobs/kinds/summary", get(list_job_kind_summaries))
        .route("/api/v1/jobs/kinds", get(list_job_kinds))
        .route(
            "/api/v1/jobs/status/summary",
            get(list_job_status_summaries),
        )
        .route("/api/v1/jobs", get(list_jobs).post(create_job))
        .route("/api/v1/jobs/{id}", get(get_job))
        .route("/api/v1/jobs/{id}/cancel", post(cancel_job))
        .route("/api/v1/jobs/{id}/retry", post(retry_job))
}

fn idempotency_key_header(headers: &HeaderMap) -> Option<String> {
    headers
        .get("idempotency-key")
        .and_then(|v| v.to_str().ok())
        .map(str::trim)
        .filter(|s| !s.is_empty())
        .map(|s| s.chars().take(200).collect())
}

fn is_unique_violation(e: &sqlx::Error) -> bool {
    match e {
        sqlx::Error::Database(db) => db.code().map(|c| c == "23505").unwrap_or(false),
        _ => false,
    }
}

/// Distinct `kind` values for the caller (rough analogue of legacy `getTaskCategories` over `o_tasks.taskClass`).
async fn list_job_kinds(
    State(state): State<AppState>,
    headers: HeaderMap,
) -> Result<Json<Vec<String>>, ApiError> {
    let uid = require_user_uuid(&state, &headers)?;
    let pool = state
        .pool
        .as_ref()
        .ok_or_else(|| ApiError::DatabaseError("DATABASE_URL not configured".into()))?;
    let kinds: Vec<String> = sqlx::query_scalar(
        r#"
        SELECT DISTINCT kind
        FROM app_generation_job
        WHERE owner_user_id = $1
        ORDER BY kind ASC
        "#,
    )
    .bind(uid)
    .fetch_all(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;
    Ok(Json(kinds))
}

async fn list_job_kind_summaries(
    State(state): State<AppState>,
    headers: HeaderMap,
) -> Result<Json<Vec<JobKindSummaryRow>>, ApiError> {
    let uid = require_user_uuid(&state, &headers)?;
    let pool = state
        .pool
        .as_ref()
        .ok_or_else(|| ApiError::DatabaseError("DATABASE_URL not configured".into()))?;
    let rows = sqlx::query_as::<_, JobKindSummaryRow>(
        r#"
        SELECT kind, COUNT(*)::bigint AS job_count
        FROM app_generation_job
        WHERE owner_user_id = $1
        GROUP BY kind
        ORDER BY kind ASC
        "#,
    )
    .bind(uid)
    .fetch_all(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;
    Ok(Json(rows))
}

async fn list_job_status_summaries(
    State(state): State<AppState>,
    headers: HeaderMap,
) -> Result<Json<Vec<JobStatusSummaryRow>>, ApiError> {
    let uid = require_user_uuid(&state, &headers)?;
    let pool = state
        .pool
        .as_ref()
        .ok_or_else(|| ApiError::DatabaseError("DATABASE_URL not configured".into()))?;
    let rows = sqlx::query_as::<_, JobStatusSummaryRow>(
        r#"
        SELECT status, COUNT(*)::bigint AS job_count
        FROM app_generation_job
        WHERE owner_user_id = $1
        GROUP BY status
        ORDER BY status ASC
        "#,
    )
    .bind(uid)
    .fetch_all(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;
    Ok(Json(rows))
}

fn trim_query_opt(s: Option<String>) -> Option<String> {
    s.and_then(|v| {
        let t = v.trim();
        if t.is_empty() {
            None
        } else {
            Some(t.to_owned())
        }
    })
}

fn normalize_job_list_status_filter(raw: Option<String>) -> Result<Option<String>, ApiError> {
    let Some(s) = trim_query_opt(raw) else {
        return Ok(None);
    };
    let s = s.to_ascii_lowercase();
    if matches!(
        s.as_str(),
        "queued" | "running" | "succeeded" | "failed" | "cancelled"
    ) {
        Ok(Some(s))
    } else {
        Err(ApiError::BadRequest(
            "status must be one of: queued, running, succeeded, failed, cancelled".into(),
        ))
    }
}

fn list_jobs_limit_offset(limit: Option<i64>, offset: Option<i64>) -> Result<(i64, i64), ApiError> {
    let limit = match limit {
        None => 100,
        Some(x) if (1..=100).contains(&x) => x,
        Some(_) => {
            return Err(ApiError::BadRequest(
                "limit must be between 1 and 100".into(),
            ));
        }
    };
    let offset = offset.unwrap_or(0);
    if offset < 0 {
        return Err(ApiError::BadRequest(
            "offset must be greater than or equal to 0".into(),
        ));
    }
    Ok((limit, offset))
}

async fn list_jobs(
    State(state): State<AppState>,
    headers: HeaderMap,
    Query(q): Query<ListJobsQuery>,
) -> Result<Json<Vec<JobRow>>, ApiError> {
    let uid = require_user_uuid(&state, &headers)?;
    let kind = trim_query_opt(q.kind);
    let status = normalize_job_list_status_filter(q.status)?;
    let (limit, offset) = list_jobs_limit_offset(q.limit, q.offset)?;
    let pool = state
        .pool
        .as_ref()
        .ok_or_else(|| ApiError::DatabaseError("DATABASE_URL not configured".into()))?;
    let rows = sqlx::query_as::<_, JobRow>(
        r#"
        SELECT legacy_task_id, id, owner_user_id, kind, status, payload, result, error_message, idempotency_key, claimed_by, created_at, updated_at
        FROM app_generation_job
        WHERE owner_user_id = $1
          AND ($2::text IS NULL OR kind = $2)
          AND ($3::text IS NULL OR status = $3)
        ORDER BY created_at DESC
        LIMIT $4 OFFSET $5
        "#,
    )
    .bind(uid)
    .bind(kind)
    .bind(status)
    .bind(limit)
    .bind(offset)
    .fetch_all(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;
    Ok(Json(rows))
}

async fn create_job(
    State(state): State<AppState>,
    headers: HeaderMap,
    Json(body): Json<CreateJobBody>,
) -> Result<Json<JobRow>, ApiError> {
    let uid = require_user_uuid(&state, &headers)?;
    let pool = state
        .pool
        .as_ref()
        .ok_or_else(|| ApiError::DatabaseError("DATABASE_URL not configured".into()))?;
    let kind = body.kind.trim();
    if kind.is_empty() {
        return Err(ApiError::BadRequest("kind must not be empty".into()));
    }

    let idem = idempotency_key_header(&headers);
    if let Some(ref key) = idem {
        if let Some(row) = sqlx::query_as::<_, JobRow>(
            r#"
            SELECT legacy_task_id, id, owner_user_id, kind, status, payload, result, error_message, idempotency_key, claimed_by, created_at, updated_at
            FROM app_generation_job
            WHERE owner_user_id = $1 AND idempotency_key = $2
            "#,
        )
        .bind(uid)
        .bind(key)
        .fetch_optional(pool)
        .await
        .map_err(|e| ApiError::DatabaseError(e.to_string()))?
        {
            return Ok(Json(row));
        }
    }

    // Quota check: idempotent re-submissions (key already seen above) bypass this.
    // New jobs must pass the daily cap before insertion.
    quota::check_daily_job_quota(pool, uid).await?;

    let insert = sqlx::query_as::<_, JobRow>(
        r#"
        INSERT INTO app_generation_job (owner_user_id, kind, payload, status, idempotency_key)
        VALUES ($1, $2, $3, 'queued', $4)
        RETURNING legacy_task_id, id, owner_user_id, kind, status, payload, result, error_message, idempotency_key, claimed_by, created_at, updated_at
        "#,
    )
    .bind(uid)
    .bind(kind)
    .bind(body.payload)
    .bind(idem.clone())
    .fetch_one(pool)
    .await;

    let row = match insert {
        Ok(r) => r,
        Err(e) if is_unique_violation(&e) => {
            let Some(key) = idem.as_ref() else {
                return Err(ApiError::DatabaseError(e.to_string()));
            };
            sqlx::query_as::<_, JobRow>(
                r#"
                SELECT legacy_task_id, id, owner_user_id, kind, status, payload, result, error_message, idempotency_key, claimed_by, created_at, updated_at
                FROM app_generation_job
                WHERE owner_user_id = $1 AND idempotency_key = $2
                "#,
            )
            .bind(uid)
            .bind(key)
            .fetch_optional(pool)
            .await
            .map_err(|e| ApiError::DatabaseError(e.to_string()))?
            .ok_or_else(|| {
                ApiError::DatabaseError("idempotency conflict but row not found".into())
            })?
        }
        Err(e) => return Err(ApiError::DatabaseError(e.to_string())),
    };

    // Best-effort usage event — log on failure, never fail the request.
    if let Err(e) = usage::record_generation_job_created(pool, uid, row.id, &row.kind).await {
        tracing::warn!(
            error = %e,
            job_id = %row.id,
            "app_usage_event insert failed for generation_job.created (job still created)"
        );
    }

    Ok(Json(row))
}

async fn get_job(
    State(state): State<AppState>,
    Path(id): Path<Uuid>,
    headers: HeaderMap,
) -> Result<Json<JobRow>, ApiError> {
    let uid = require_user_uuid(&state, &headers)?;
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
    Ok(Json(row))
}

async fn cancel_job(
    State(state): State<AppState>,
    Path(id): Path<Uuid>,
    headers: HeaderMap,
) -> Result<Json<JobRow>, ApiError> {
    let uid = require_user_uuid(&state, &headers)?;
    let pool = state
        .pool
        .as_ref()
        .ok_or_else(|| ApiError::DatabaseError("DATABASE_URL not configured".into()))?;

    let updated = sqlx::query_as::<_, JobRow>(
        r#"
        UPDATE app_generation_job
        SET status = 'cancelled', updated_at = NOW()
        WHERE id = $1 AND owner_user_id = $2 AND status IN ('queued', 'running')
        RETURNING legacy_task_id, id, owner_user_id, kind, status, payload, result, error_message, idempotency_key, claimed_by, created_at, updated_at
        "#,
    )
    .bind(id)
    .bind(uid)
    .fetch_optional(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    if let Some(row) = updated {
        let text = envelope_generation_job_updated(&row);
        state.notify.broadcast_to_user(uid, text).await;
        return Ok(Json(row));
    }

    let exists: bool = sqlx::query_scalar(
        "SELECT EXISTS(SELECT 1 FROM app_generation_job WHERE id = $1 AND owner_user_id = $2)",
    )
    .bind(id)
    .bind(uid)
    .fetch_one(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    if !exists {
        return Err(ApiError::NotFound);
    }

    Err(ApiError::Conflict(
        "job cannot be cancelled in its current status (not queued or running)".into(),
    ))
}

async fn retry_job(
    State(state): State<AppState>,
    Path(id): Path<Uuid>,
    headers: HeaderMap,
) -> Result<Json<JobRow>, ApiError> {
    let uid = require_user_uuid(&state, &headers)?;
    let pool = state
        .pool
        .as_ref()
        .ok_or_else(|| ApiError::DatabaseError("DATABASE_URL not configured".into()))?;

    let updated = sqlx::query_as::<_, JobRow>(
        r#"
        UPDATE app_generation_job
        SET status = 'queued', error_message = NULL, result = NULL, claimed_by = NULL, updated_at = NOW()
        WHERE id = $1 AND owner_user_id = $2 AND status = 'failed'
        RETURNING legacy_task_id, id, owner_user_id, kind, status, payload, result, error_message, idempotency_key, claimed_by, created_at, updated_at
        "#,
    )
    .bind(id)
    .bind(uid)
    .fetch_optional(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    if let Some(row) = updated {
        let text = envelope_generation_job_updated(&row);
        state.notify.broadcast_to_user(uid, text).await;
        return Ok(Json(row));
    }

    let exists: bool = sqlx::query_scalar(
        "SELECT EXISTS(SELECT 1 FROM app_generation_job WHERE id = $1 AND owner_user_id = $2)",
    )
    .bind(id)
    .bind(uid)
    .fetch_one(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    if !exists {
        return Err(ApiError::NotFound);
    }

    Err(ApiError::Conflict(
        "only failed jobs can be retried (re-queue)".into(),
    ))
}

#[cfg(test)]
mod tests {
    use super::*;
    use axum::http::{HeaderMap, HeaderName, HeaderValue};
    use serde_json::json;

    fn sample_job_row() -> JobRow {
        JobRow {
            legacy_task_id: 1,
            id: Uuid::nil(),
            owner_user_id: Uuid::nil(),
            kind: JOB_KIND_FLUTTER_PROBE.into(),
            status: "queued".into(),
            payload: json!({ "n": 1 }),
            result: None,
            error_message: None,
            idempotency_key: Some("idem-1".into()),
            claimed_by: None,
            created_at: Utc::now(),
            updated_at: Utc::now(),
        }
    }

    #[test]
    fn idempotency_key_header_trims_and_caps_length() {
        let mut h = HeaderMap::new();
        assert!(idempotency_key_header(&h).is_none());

        h.insert(
            HeaderName::from_static("idempotency-key"),
            HeaderValue::from_static("  abc  "),
        );
        assert_eq!(idempotency_key_header(&h).as_deref(), Some("abc"));

        h.insert(
            HeaderName::from_static("idempotency-key"),
            HeaderValue::from_static(""),
        );
        assert!(idempotency_key_header(&h).is_none());

        let long = "x".repeat(250);
        let mut h2 = HeaderMap::new();
        h2.insert(
            HeaderName::from_static("idempotency-key"),
            HeaderValue::from_str(&long).unwrap(),
        );
        let got = idempotency_key_header(&h2).unwrap();
        assert_eq!(got.len(), 200);
        assert!(got.chars().all(|c| c == 'x'));
    }

    #[test]
    fn envelope_generation_job_updated_shape() {
        let text = envelope_generation_job_updated(&sample_job_row());
        let v: serde_json::Value = serde_json::from_str(&text).unwrap();
        assert_eq!(
            v.get("type").and_then(|x| x.as_str()),
            Some("generation.job.updated")
        );
        assert_eq!(v.get("schema_version").and_then(|x| x.as_i64()), Some(1));
        let payload = v.get("payload").unwrap();
        assert_eq!(
            payload.get("kind").and_then(|x| x.as_str()),
            Some(JOB_KIND_FLUTTER_PROBE)
        );
        assert_eq!(
            payload.get("idempotency_key").and_then(|x| x.as_str()),
            Some("idem-1")
        );
    }

    #[test]
    fn create_job_body_rejects_unknown_fields() {
        let err = serde_json::from_str::<CreateJobBody>(
            r#"{"kind":"k","payload":{},"not_a_field":true}"#,
        )
        .unwrap_err();
        assert!(
            err.to_string().contains("unknown field")
                || err.to_string().contains("unknown variant"),
            "{err}"
        );
    }

    #[test]
    fn trim_query_opt_trims_and_drops_empty() {
        assert_eq!(super::trim_query_opt(None), None);
        assert_eq!(super::trim_query_opt(Some(String::new())), None);
        assert_eq!(super::trim_query_opt(Some("   \t  ".into())), None);
        assert_eq!(
            super::trim_query_opt(Some(format!("  {}  ", JOB_KIND_FLUTTER_PROBE))),
            Some(JOB_KIND_FLUTTER_PROBE.into())
        );
    }

    #[test]
    fn normalize_job_list_status_filter_accepts_known_statuses_case_insensitive() {
        assert_eq!(super::normalize_job_list_status_filter(None).unwrap(), None);
        assert_eq!(
            super::normalize_job_list_status_filter(Some(String::new())).unwrap(),
            None
        );
        assert_eq!(
            super::normalize_job_list_status_filter(Some("  RUNNING  ".into()))
                .unwrap()
                .as_deref(),
            Some("running")
        );
        assert!(super::normalize_job_list_status_filter(Some("nope".into())).is_err());
    }

    #[test]
    fn list_jobs_limit_offset_defaults_and_validates() {
        assert_eq!(super::list_jobs_limit_offset(None, None).unwrap(), (100, 0));
        assert_eq!(
            super::list_jobs_limit_offset(Some(1), Some(0)).unwrap(),
            (1, 0)
        );
        assert_eq!(
            super::list_jobs_limit_offset(Some(100), None).unwrap(),
            (100, 0)
        );
        assert!(super::list_jobs_limit_offset(Some(0), None).is_err());
        assert!(super::list_jobs_limit_offset(Some(101), None).is_err());
        assert!(super::list_jobs_limit_offset(None, Some(-1)).is_err());
    }
}
