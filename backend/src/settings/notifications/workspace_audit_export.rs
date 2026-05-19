//! Shared workspace cleared-template **audit** export: sync inline body vs async job artifact.

use std::path::PathBuf;

use axum::{
    body::Body,
    http::{header, HeaderValue, StatusCode},
    response::{IntoResponse, Response},
};
use serde_json::{json, Value};
use sqlx::{types::Json, FromRow, PgPool};
use uuid::Uuid;

use crate::error::helpers::bad_request_i18n;
use crate::error::ApiError;
use crate::jobs::worker::{job_ok, JobCompletion, JobRunError};
use crate::jobs::{JobRow, JOB_KIND_SETTINGS_WORKSPACE_SHARED_AUDIT_EXPORT};

use super::types::{
    ContentComplianceClearedTemplateAuditItem,
    ExportWorkspaceContentComplianceClearedTemplateAuditQuery,
    WorkspaceContentComplianceClearedTemplateAuditExportRecord,
    WorkspaceSharedAuditExportJobRecord,
};
use super::workspace_audit_export_artifact_storage;

pub(crate) const SHARED_TEMPLATES_AUDIT_KEY: &str =
    "content_compliance_cleared_templates_shared_audit";
pub(crate) const SHARED_TEMPLATES_AUDIT_EXPORTS_KEY: &str =
    "content_compliance_cleared_templates_shared_audit_exports";

const WORKSPACE_SHARED_AUDIT_EXPORT_ENV: &str = "OPENFLOW_LOCAL_WORKSPACE_SHARED_AUDIT_EXPORT_DIR";

/// Max **`queued` + `running`** export jobs per user for this kind (back-pressure; aligns with account export observability).
pub(crate) const WORKSPACE_SHARED_AUDIT_EXPORT_MAX_ACTIVE: i64 = 3;

/// Parameters for appending an export history record
pub(crate) struct ExportHistoryParams {
    pub workspace_id: Uuid,
    pub uid: Uuid,
    pub format: String,
    pub file_name: String,
    pub template_id: Option<String>,
    pub action: Option<String>,
    pub start_at: Option<String>,
    pub end_at: Option<String>,
    pub job_id: Option<Uuid>,
    pub export_delivery: String,
}

pub(crate) async fn count_active_workspace_shared_audit_export_jobs(
    pool: &PgPool,
    owner_user_id: Uuid,
) -> Result<i64, ApiError> {
    sqlx::query_scalar(
        r#"
        SELECT COUNT(*)::bigint
        FROM public.app_generation_job
        WHERE owner_user_id = $1
          AND kind = $2
          AND status IN ('queued', 'running')
        "#,
    )
    .bind(owner_user_id)
    .bind(JOB_KIND_SETTINGS_WORKSPACE_SHARED_AUDIT_EXPORT)
    .fetch_one(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))
}

pub(crate) fn workspace_shared_audit_export_root_dir() -> PathBuf {
    std::env::var(WORKSPACE_SHARED_AUDIT_EXPORT_ENV)
        .ok()
        .map(|value| value.trim().to_string())
        .filter(|value| !value.is_empty())
        .map(PathBuf::from)
        .unwrap_or_else(|| std::env::temp_dir().join("openflow-workspace-shared-audit-exports"))
}

fn workspace_export_user_dir(user_id: Uuid) -> PathBuf {
    workspace_shared_audit_export_root_dir().join(user_id.to_string())
}

pub(crate) fn workspace_shared_audit_export_file_path(user_id: Uuid, file_name: &str) -> PathBuf {
    workspace_export_user_dir(user_id).join(file_name)
}

pub(crate) async fn load_workspace_shared_template_audit(
    pool: &PgPool,
    workspace_id: Uuid,
) -> Result<Vec<ContentComplianceClearedTemplateAuditItem>, ApiError> {
    let metadata: Option<Value> =
        sqlx::query_scalar("SELECT metadata FROM public.app_workspace WHERE id = $1")
            .bind(workspace_id)
            .fetch_optional(pool)
            .await
            .map_err(|e| ApiError::DatabaseError(e.to_string()))?;
    let Some(metadata) = metadata else {
        return Ok(Vec::new());
    };
    let items = metadata
        .as_object()
        .and_then(|obj| obj.get(SHARED_TEMPLATES_AUDIT_KEY))
        .cloned()
        .unwrap_or_else(|| json!([]));
    let parsed: Vec<ContentComplianceClearedTemplateAuditItem> =
        serde_json::from_value(items).unwrap_or_default();
    Ok(parsed)
}

pub(crate) fn filter_workspace_shared_audit_items(
    mut items: Vec<ContentComplianceClearedTemplateAuditItem>,
    template_id: Option<&str>,
    action: Option<&str>,
    start_at: Option<&str>,
    end_at: Option<&str>,
) -> Vec<ContentComplianceClearedTemplateAuditItem> {
    let template_filter = template_id
        .map(|v| v.trim().to_ascii_lowercase())
        .filter(|v| !v.is_empty());
    let action_filter = action
        .map(|v| v.trim().to_ascii_lowercase())
        .filter(|v| !v.is_empty());
    let start_at_filter = start_at.and_then(|v| {
        chrono::DateTime::parse_from_rfc3339(v.trim())
            .ok()
            .map(|dt| dt.with_timezone(&chrono::Utc))
    });
    let end_at_filter = end_at.and_then(|v| {
        chrono::DateTime::parse_from_rfc3339(v.trim())
            .ok()
            .map(|dt| dt.with_timezone(&chrono::Utc))
    });
    if template_filter.is_some() || action_filter.is_some() {
        items.retain(|item| {
            let template_ok = match template_filter.as_ref() {
                None => true,
                Some(expect) => item.template_id.trim().to_ascii_lowercase() == expect.as_str(),
            };
            let action_ok = match action_filter.as_ref() {
                None => true,
                Some(expect) => item.action.trim().to_ascii_lowercase() == expect.as_str(),
            };
            template_ok && action_ok
        });
    }
    if start_at_filter.is_some() || end_at_filter.is_some() {
        items.retain(|item| {
            let start_ok = match start_at_filter.as_ref() {
                None => true,
                Some(start) => item.at >= *start,
            };
            let end_ok = match end_at_filter.as_ref() {
                None => true,
                Some(end) => item.at <= *end,
            };
            start_ok && end_ok
        });
    }
    items
}

pub(crate) fn filter_workspace_shared_audit_export_records(
    mut items: Vec<WorkspaceContentComplianceClearedTemplateAuditExportRecord>,
    format_filter: Option<&str>,
    exported_start: Option<chrono::DateTime<chrono::Utc>>,
    exported_end: Option<chrono::DateTime<chrono::Utc>>,
) -> Vec<WorkspaceContentComplianceClearedTemplateAuditExportRecord> {
    let fmt = format_filter
        .map(|v| v.trim().to_ascii_lowercase())
        .filter(|v| !v.is_empty());
    if let Some(ref expected) = fmt {
        items.retain(|item| item.format.trim().to_ascii_lowercase() == expected.as_str());
    }
    if exported_start.is_some() || exported_end.is_some() {
        items.retain(|item| {
            let start_ok = match exported_start.as_ref() {
                None => true,
                Some(s) => item.exported_at >= *s,
            };
            let end_ok = match exported_end.as_ref() {
                None => true,
                Some(e) => item.exported_at <= *e,
            };
            start_ok && end_ok
        });
    }
    items
}

async fn load_legacy_workspace_shared_audit_exports_from_metadata(
    pool: &PgPool,
    workspace_id: Uuid,
) -> Result<Vec<WorkspaceContentComplianceClearedTemplateAuditExportRecord>, ApiError> {
    let metadata: Option<Value> =
        sqlx::query_scalar("SELECT metadata FROM public.app_workspace WHERE id = $1")
            .bind(workspace_id)
            .fetch_optional(pool)
            .await
            .map_err(|e| ApiError::DatabaseError(e.to_string()))?;
    let Some(metadata) = metadata else {
        return Ok(Vec::new());
    };
    let items = metadata
        .as_object()
        .and_then(|obj| obj.get(SHARED_TEMPLATES_AUDIT_EXPORTS_KEY))
        .cloned()
        .unwrap_or_else(|| json!([]));
    let parsed: Vec<WorkspaceContentComplianceClearedTemplateAuditExportRecord> =
        serde_json::from_value(items).unwrap_or_default();
    Ok(parsed)
}

async fn workspace_shared_audit_export_table_count(
    pool: &PgPool,
    workspace_id: Uuid,
) -> Result<i64, ApiError> {
    sqlx::query_scalar::<_, i64>(
        r#"SELECT COUNT(*)::bigint FROM public.app_workspace_shared_audit_export WHERE workspace_id = $1"#,
    )
    .bind(workspace_id)
    .fetch_one(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))
}

/// Paginated export history: **`app_workspace_shared_audit_export`** when populated; otherwise
/// legacy **`metadata.content_compliance_cleared_templates_shared_audit_exports`** (pre-migration).
pub(crate) async fn query_workspace_shared_audit_exports_page(
    pool: &PgPool,
    workspace_id: Uuid,
    format_filter: Option<&str>,
    exported_start: Option<chrono::DateTime<chrono::Utc>>,
    exported_end: Option<chrono::DateTime<chrono::Utc>>,
    offset: i64,
    limit: i64,
) -> Result<
    (
        Vec<WorkspaceContentComplianceClearedTemplateAuditExportRecord>,
        i64,
    ),
    ApiError,
> {
    let fmt = format_filter
        .map(|v| v.trim().to_ascii_lowercase())
        .filter(|v| !v.is_empty());
    if workspace_shared_audit_export_table_count(pool, workspace_id).await? == 0 {
        let raw =
            load_legacy_workspace_shared_audit_exports_from_metadata(pool, workspace_id).await?;
        let filtered = filter_workspace_shared_audit_export_records(
            raw,
            format_filter,
            exported_start,
            exported_end,
        );
        let total = filtered.len() as i64;
        let off = offset.max(0) as usize;
        let lim = limit.clamp(1, 100) as usize;
        let paged = filtered.into_iter().skip(off).take(lim).collect();
        return Ok((paged, total));
    }

    #[derive(Debug, FromRow)]
    struct Row {
        exported_at: chrono::DateTime<chrono::Utc>,
        actor_user_id: Uuid,
        format: String,
        file_name: String,
        template_id: Option<String>,
        action: Option<String>,
        start_at: Option<String>,
        end_at: Option<String>,
        job_id: Option<Uuid>,
        export_delivery: String,
    }

    let total: i64 = sqlx::query_scalar(
        r#"
        SELECT COUNT(*)::bigint
        FROM public.app_workspace_shared_audit_export
        WHERE workspace_id = $1
          AND ($2::text IS NULL OR trim(lower(format)) = trim(lower($2)))
          AND ($3::timestamptz IS NULL OR exported_at >= $3)
          AND ($4::timestamptz IS NULL OR exported_at <= $4)
        "#,
    )
    .bind(workspace_id)
    .bind(fmt.as_deref())
    .bind(exported_start)
    .bind(exported_end)
    .fetch_one(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    let rows: Vec<Row> = sqlx::query_as(
        r#"
        SELECT
          exported_at,
          actor_user_id,
          format,
          file_name,
          template_id,
          action,
          start_at,
          end_at,
          job_id,
          export_delivery
        FROM public.app_workspace_shared_audit_export
        WHERE workspace_id = $1
          AND ($2::text IS NULL OR trim(lower(format)) = trim(lower($2)))
          AND ($3::timestamptz IS NULL OR exported_at >= $3)
          AND ($4::timestamptz IS NULL OR exported_at <= $4)
        ORDER BY exported_at DESC, id DESC
        OFFSET $5
        LIMIT $6
        "#,
    )
    .bind(workspace_id)
    .bind(fmt.as_deref())
    .bind(exported_start)
    .bind(exported_end)
    .bind(offset.max(0))
    .bind(limit.clamp(1, 100))
    .fetch_all(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    let items = rows
        .into_iter()
        .map(
            |r| WorkspaceContentComplianceClearedTemplateAuditExportRecord {
                exported_at: r.exported_at,
                actor_user_id: r.actor_user_id,
                format: r.format,
                file_name: r.file_name,
                template_id: r.template_id,
                action: r.action,
                start_at: r.start_at,
                end_at: r.end_at,
                job_id: r.job_id,
                export_delivery: Some(r.export_delivery),
            },
        )
        .collect();
    Ok((items, total))
}

pub(crate) fn build_filtered_audit_export_body(
    query: &ExportWorkspaceContentComplianceClearedTemplateAuditQuery,
    items: Vec<ContentComplianceClearedTemplateAuditItem>,
) -> Result<(String, String, String), ApiError> {
    let format = query
        .format
        .as_deref()
        .map(|v| v.trim().to_ascii_lowercase())
        .filter(|v| v == "csv" || v == "json")
        .unwrap_or_else(|| "json".to_string());
    let timestamp = chrono::Utc::now().format("%Y%m%dT%H%M%SZ");
    let (file_name, content) = if format == "csv" {
        let mut csv = String::from("at,actor_user_id,action,template_id,note\n");
        for item in items {
            let at = item.at.to_rfc3339();
            let row = [
                at,
                item.actor_user_id.to_string(),
                item.action,
                item.template_id,
                item.note.unwrap_or_default(),
            ]
            .map(|cell| format!("\"{}\"", cell.replace('"', "\"\"")))
            .join(",");
            csv.push_str(&row);
            csv.push('\n');
        }
        (
            format!("workspace_shared_template_audit_{timestamp}.csv"),
            csv,
        )
    } else {
        (
            format!("workspace_shared_template_audit_{timestamp}.json"),
            serde_json::to_string_pretty(&items).map_err(|e| {
                bad_request_i18n(
                    &format!("Failed to serialize audit items: {}", e),
                    &format!("审计项序列化失败：{}", e),
                )
            })?,
        )
    };
    Ok((format, file_name, content))
}

pub(crate) async fn append_export_history_record(
    pool: &PgPool,
    params: ExportHistoryParams,
) -> Result<(), ApiError> {
    let now = chrono::Utc::now();
    sqlx::query(
        r#"
        INSERT INTO public.app_workspace_shared_audit_export (
          workspace_id,
          actor_user_id,
          exported_at,
          format,
          file_name,
          template_id,
          action,
          start_at,
          end_at,
          job_id,
          export_delivery
        )
        VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11)
        "#,
    )
    .bind(params.workspace_id)
    .bind(params.uid)
    .bind(now)
    .bind(&params.format)
    .bind(&params.file_name)
    .bind(params.template_id.as_deref())
    .bind(params.action.as_deref())
    .bind(params.start_at.as_deref())
    .bind(params.end_at.as_deref())
    .bind(params.job_id)
    .bind(&params.export_delivery)
    .execute(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    // Cap per-workspace history (platform hygiene; replaces prior JSON trim to 200 / 30d).
    let _ = sqlx::query(
        r#"
        DELETE FROM public.app_workspace_shared_audit_export e
        USING (
          SELECT id
          FROM public.app_workspace_shared_audit_export
          WHERE workspace_id = $1
          ORDER BY exported_at DESC, id DESC
          OFFSET 2000
        ) AS doomed
        WHERE e.id = doomed.id
        "#,
    )
    .bind(params.workspace_id)
    .execute(pool)
    .await;

    Ok(())
}

#[derive(Debug, FromRow)]
struct WorkspaceSharedAuditExportJobRow {
    numeric_task_id: i64,
    id: Uuid,
    status: String,
    result: Option<Json<Value>>,
    error_message: Option<String>,
    created_at: chrono::DateTime<chrono::Utc>,
    updated_at: chrono::DateTime<chrono::Utc>,
}

pub(crate) fn to_workspace_shared_audit_export_job_record(
    row: &JobRow,
    workspace_id: Uuid,
) -> WorkspaceSharedAuditExportJobRecord {
    let result = row.result.as_ref();
    let file_name = result
        .and_then(|value| value.get("file_name"))
        .and_then(|value| value.as_str())
        .map(str::to_string);
    let content_type = result
        .and_then(|value| value.get("content_type"))
        .and_then(|value| value.as_str())
        .map(str::to_string);
    let byte_size = result
        .and_then(|value| value.get("byte_size"))
        .and_then(|value| value.as_i64());
    WorkspaceSharedAuditExportJobRecord {
        id: row.id,
        numeric_task_id: row.numeric_task_id,
        status: row.status.clone(),
        workspace_id,
        created_at: row.created_at,
        updated_at: row.updated_at,
        error_message: row.error_message.clone(),
        file_name: file_name.clone(),
        content_type,
        byte_size,
        download_ready: row.status == "succeeded" && file_name.is_some(),
    }
}

fn map_workspace_shared_audit_export_job_row(
    row: WorkspaceSharedAuditExportJobRow,
    workspace_id: Uuid,
) -> WorkspaceSharedAuditExportJobRecord {
    let status = row.status.clone();
    let result = row.result.as_ref().map(|value| &value.0);
    let file_name = result
        .and_then(|value| value.get("file_name"))
        .and_then(|value| value.as_str())
        .map(str::to_string);
    let content_type = result
        .and_then(|value| value.get("content_type"))
        .and_then(|value| value.as_str())
        .map(str::to_string);
    let byte_size = result
        .and_then(|value| value.get("byte_size"))
        .and_then(|value| value.as_i64());
    WorkspaceSharedAuditExportJobRecord {
        id: row.id,
        numeric_task_id: row.numeric_task_id,
        status,
        workspace_id,
        created_at: row.created_at,
        updated_at: row.updated_at,
        error_message: row.error_message,
        file_name: file_name.clone(),
        content_type,
        byte_size,
        download_ready: row.status == "succeeded" && file_name.is_some(),
    }
}

#[derive(Debug, FromRow)]
struct WorkspaceSharedAuditExportJobRowWithWs {
    numeric_task_id: i64,
    id: Uuid,
    status: String,
    result: Option<Json<Value>>,
    error_message: Option<String>,
    created_at: chrono::DateTime<chrono::Utc>,
    updated_at: chrono::DateTime<chrono::Utc>,
    workspace_id: Uuid,
}

pub(crate) async fn fetch_workspace_shared_audit_export_job_for_user(
    pool: &PgPool,
    user_id: Uuid,
    job_id: Uuid,
) -> Result<WorkspaceSharedAuditExportJobRecord, ApiError> {
    let row = sqlx::query_as::<_, WorkspaceSharedAuditExportJobRowWithWs>(
        r#"
        SELECT
          numeric_task_id,
          id,
          status,
          result,
          error_message,
          created_at,
          updated_at,
          (payload->>'workspace_id')::uuid AS workspace_id
        FROM public.app_generation_job
        WHERE id = $1
          AND owner_user_id = $2
          AND kind = $3
        "#,
    )
    .bind(job_id)
    .bind(user_id)
    .bind(JOB_KIND_SETTINGS_WORKSPACE_SHARED_AUDIT_EXPORT)
    .fetch_optional(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?
    .ok_or(ApiError::NotFound)?;
    let mapped = WorkspaceSharedAuditExportJobRow {
        numeric_task_id: row.numeric_task_id,
        id: row.id,
        status: row.status,
        result: row.result,
        error_message: row.error_message,
        created_at: row.created_at,
        updated_at: row.updated_at,
    };
    Ok(map_workspace_shared_audit_export_job_row(
        mapped,
        row.workspace_id,
    ))
}

pub(crate) async fn get_workspace_shared_audit_export_file_response(
    pool: &PgPool,
    user_id: Uuid,
    job_id: Uuid,
) -> Result<Response, ApiError> {
    #[derive(Debug, FromRow)]
    struct JobFetchRow {
        status: String,
        result: Option<Json<Value>>,
    }
    let row = sqlx::query_as::<_, JobFetchRow>(
        r#"
        SELECT status, result
        FROM public.app_generation_job
        WHERE id = $1
          AND owner_user_id = $2
          AND kind = $3
        "#,
    )
    .bind(job_id)
    .bind(user_id)
    .bind(JOB_KIND_SETTINGS_WORKSPACE_SHARED_AUDIT_EXPORT)
    .fetch_optional(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?
    .ok_or(ApiError::NotFound)?;
    if row.status != "succeeded" {
        return Err(ApiError::NotFound);
    }
    let result = row.result.ok_or(ApiError::NotFound)?.0;
    let storage = result
        .get("storage")
        .and_then(|value| value.as_str())
        .unwrap_or("local");
    let file_name = result
        .get("file_name")
        .and_then(|value| value.as_str())
        .filter(|value| !value.trim().is_empty())
        .ok_or(ApiError::NotFound)?;
    let content_type = result
        .get("content_type")
        .and_then(|value| value.as_str())
        .filter(|value| !value.trim().is_empty())
        .unwrap_or("application/octet-stream");
    let bytes = match storage {
        "local" => tokio::fs::read(workspace_shared_audit_export_file_path(user_id, file_name))
            .await
            .map_err(|_| ApiError::NotFound)?,
        "s3" => {
            let bucket = result
                .get("s3_bucket")
                .and_then(|value| value.as_str())
                .filter(|value| !value.trim().is_empty())
                .ok_or(ApiError::NotFound)?;
            let key = result
                .get("s3_key")
                .and_then(|value| value.as_str())
                .filter(|value| !value.trim().is_empty())
                .ok_or(ApiError::NotFound)?;
            workspace_audit_export_artifact_storage::get_workspace_shared_audit_export_s3_object(
                bucket, key,
            )
            .await
            .map_err(|_| ApiError::NotFound)?
        }
        _ => return Err(ApiError::NotFound),
    };
    let mut disposition = HeaderValue::from_str(&format!("attachment; filename=\"{file_name}\""))
        .map_err(|_| ApiError::Internal)?;
    disposition.set_sensitive(true);
    Ok((
        StatusCode::OK,
        [
            (
                header::CONTENT_TYPE,
                HeaderValue::from_str(content_type).map_err(|_| ApiError::Internal)?,
            ),
            (
                header::CACHE_CONTROL,
                HeaderValue::from_static("private, max-age=0"),
            ),
            (header::CONTENT_DISPOSITION, disposition),
        ],
        Body::from(bytes),
    )
        .into_response())
}

/// Worker defense-in-depth: job owner must be workspace owner or member (matches HTTP export semantics).
async fn user_may_access_workspace_for_shared_audit_export(
    pool: &PgPool,
    user_id: Uuid,
    workspace_id: Uuid,
) -> Result<(), JobRunError> {
    let ok = sqlx::query_scalar::<_, bool>(
        r#"
        SELECT EXISTS (
          SELECT 1
          FROM public.app_workspace w
          WHERE w.id = $1
            AND (
              w.owner_user_id = $2
              OR EXISTS (
                SELECT 1 FROM public.app_workspace_member m
                WHERE m.workspace_id = w.id AND m.user_id = $2
              )
            )
        )
        "#,
    )
    .bind(workspace_id)
    .bind(user_id)
    .fetch_one(pool)
    .await
    .map_err(|e| JobRunError::Failed(e.to_string()))?;
    if ok {
        Ok(())
    } else {
        Err(JobRunError::Failed(
            "job owner is not allowed to read this workspace (shared audit export)".into(),
        ))
    }
}

pub(crate) async fn build_workspace_shared_audit_export_artifact(
    pool: &PgPool,
    owner_user_id: Uuid,
    job_id: Uuid,
    payload: &Value,
) -> Result<JobCompletion, JobRunError> {
    let workspace_id = payload
        .get("workspace_id")
        .and_then(|v| v.as_str())
        .and_then(|s| Uuid::parse_str(s.trim()).ok())
        .ok_or_else(|| JobRunError::Failed("workspace_id missing from job payload".into()))?;
    user_may_access_workspace_for_shared_audit_export(pool, owner_user_id, workspace_id).await?;
    let format = payload
        .get("format")
        .and_then(|v| v.as_str())
        .map(|s| s.trim().to_ascii_lowercase())
        .filter(|s| s == "csv" || s == "json")
        .unwrap_or_else(|| "json".to_string());
    let template_id = payload
        .get("template_id")
        .and_then(|v| v.as_str())
        .map(|s| s.to_string());
    let action = payload
        .get("action")
        .and_then(|v| v.as_str())
        .map(|s| s.to_string());
    let start_at = payload
        .get("start_at")
        .and_then(|v| v.as_str())
        .map(|s| s.to_string());
    let end_at = payload
        .get("end_at")
        .and_then(|v| v.as_str())
        .map(|s| s.to_string());
    let items = filter_workspace_shared_audit_items(
        load_workspace_shared_template_audit(pool, workspace_id)
            .await
            .map_err(|e| JobRunError::Failed(format!("{e:?}")))?,
        template_id.as_deref(),
        action.as_deref(),
        start_at.as_deref(),
        end_at.as_deref(),
    );
    let query = ExportWorkspaceContentComplianceClearedTemplateAuditQuery {
        template_id: template_id.clone(),
        action: action.clone(),
        start_at: start_at.clone(),
        end_at: end_at.clone(),
        format: Some(format.clone()),
    };
    let (format_res, file_name, content) = build_filtered_audit_export_body(&query, items)
        .map_err(|e| JobRunError::Failed(format!("{e:?}")))?;
    let content_type = if format_res == "csv" {
        "text/csv; charset=utf-8"
    } else {
        "application/json; charset=utf-8"
    };
    let bytes = content.into_bytes();
    let byte_size = i64::try_from(bytes.len()).unwrap_or(i64::MAX);

    let storage_json = if workspace_audit_export_artifact_storage::use_s3_for_workspace_shared_audit_export_artifacts()
    {
        let (bucket, key) = workspace_audit_export_artifact_storage::put_workspace_shared_audit_export_s3_object(
            owner_user_id,
            &file_name,
            content_type,
            &bytes,
        )
        .await
        .map_err(JobRunError::Failed)?;
        json!({
            "storage": "s3",
            "s3_bucket": bucket,
            "s3_key": key,
            "file_name": file_name.clone(),
            "content_type": content_type,
            "byte_size": byte_size,
            "workspace_id": workspace_id,
            "download_path": format!("/api/v1/settings/notifications/content-compliance/cleared-templates/shared/audit/export-jobs/{job_id}/file"),
        })
    } else {
        let user_dir = workspace_export_user_dir(owner_user_id);
        tokio::fs::create_dir_all(&user_dir)
            .await
            .map_err(|e| JobRunError::Failed(e.to_string()))?;
        tokio::fs::write(user_dir.join(&file_name), &bytes)
            .await
            .map_err(|e| JobRunError::Failed(e.to_string()))?;
        json!({
            "storage": "local",
            "file_name": file_name.clone(),
            "content_type": content_type,
            "byte_size": byte_size,
            "workspace_id": workspace_id,
            "download_path": format!("/api/v1/settings/notifications/content-compliance/cleared-templates/shared/audit/export-jobs/{job_id}/file"),
        })
    };

    append_export_history_record(
        pool,
        ExportHistoryParams {
            workspace_id,
            uid: owner_user_id,
            format: format_res.clone(),
            file_name: file_name.clone(),
            template_id: template_id.clone(),
            action: action.clone(),
            start_at: start_at.clone(),
            end_at: end_at.clone(),
            job_id: Some(job_id),
            export_delivery: "async".to_string(),
        },
    )
    .await
    .map_err(|e| JobRunError::Failed(format!("{e:?}")))?;
    Ok(job_ok(storage_json))
}
