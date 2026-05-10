use axum::{
    extract::{Path, Query, State},
    http::HeaderMap,
    routing::{get, post},
    Json, Router,
};
use serde::{Deserialize, Serialize};
use serde_json::{json, Value};
use sqlx::{Executor, FromRow, Postgres, QueryBuilder};
use utoipa::{IntoParams, ToSchema};
use uuid::Uuid;

use crate::auth::require_user_uuid;
use crate::error::ApiError;
use crate::state::AppState;

#[derive(Debug, Clone, Deserialize, Serialize, ToSchema)]
#[serde(rename_all = "snake_case")]
enum ContentReportTargetType {
    Project,
    Script,
    Storyboard,
    Asset,
    Novel,
    User,
}

impl ContentReportTargetType {
    fn as_str(&self) -> &'static str {
        match self {
            Self::Project => "project",
            Self::Script => "script",
            Self::Storyboard => "storyboard",
            Self::Asset => "asset",
            Self::Novel => "novel",
            Self::User => "user",
        }
    }
}

#[derive(Debug, Clone, Deserialize, Serialize, ToSchema)]
#[serde(rename_all = "snake_case")]
enum ContentReportCategory {
    Copyright,
    Safety,
    Harassment,
    Adult,
    Violence,
    Spam,
    Other,
}

impl ContentReportCategory {
    fn as_str(&self) -> &'static str {
        match self {
            Self::Copyright => "copyright",
            Self::Safety => "safety",
            Self::Harassment => "harassment",
            Self::Adult => "adult",
            Self::Violence => "violence",
            Self::Spam => "spam",
            Self::Other => "other",
        }
    }
}

#[derive(Debug, Clone, Deserialize, Serialize, ToSchema)]
#[serde(rename_all = "snake_case")]
enum ContentReportSeverity {
    Low,
    Medium,
    High,
    Critical,
}

impl ContentReportSeverity {
    fn as_str(&self) -> &'static str {
        match self {
            Self::Low => "low",
            Self::Medium => "medium",
            Self::High => "high",
            Self::Critical => "critical",
        }
    }
}

#[derive(Debug, Clone, Deserialize, Serialize, ToSchema)]
#[serde(rename_all = "snake_case")]
enum ContentReportStatus {
    Pending,
    Claimed,
    Resolved,
    Dismissed,
}

impl ContentReportStatus {
    fn as_str(&self) -> &'static str {
        match self {
            Self::Pending => "pending",
            Self::Claimed => "claimed",
            Self::Resolved => "resolved",
            Self::Dismissed => "dismissed",
        }
    }
}

#[derive(Debug, Clone, Deserialize, ToSchema)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
pub struct CreateContentReportBody {
    target_type: ContentReportTargetType,
    target_id: Uuid,
    category: ContentReportCategory,
    #[serde(default)]
    severity: Option<ContentReportSeverity>,
    #[serde(default)]
    detail: Option<String>,
    #[serde(default)]
    snapshot: Option<Value>,
}

#[derive(Debug, Clone, Deserialize, IntoParams, ToSchema)]
#[into_params(parameter_in = Query)]
pub struct ListContentComplianceReportsQuery {
    #[serde(default)]
    status: Option<String>,
    #[serde(default)]
    category: Option<String>,
    #[serde(default)]
    target_type: Option<String>,
    #[serde(default)]
    claimed_only: Option<bool>,
    #[serde(default)]
    claimed_by_label: Option<String>,
    #[serde(default)]
    sla_bucket: Option<String>,
    #[serde(default)]
    workspace_id: Option<Uuid>,
    #[serde(default)]
    limit: Option<i64>,
}

#[derive(Debug, Clone, Deserialize, ToSchema)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
pub struct BatchMutateContentReportsBody {
    report_ids: Vec<Uuid>,
    action: ContentComplianceBatchAction,
    #[serde(default)]
    actor_label: Option<String>,
    #[serde(default)]
    resolution_note: Option<String>,
    #[serde(default)]
    disposition: Option<ContentReportDisposition>,
}

#[derive(Debug, Clone, Deserialize, ToSchema)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
pub struct ReassignContentReportsBody {
    report_ids: Vec<Uuid>,
    assignee_label: String,
    #[serde(default)]
    actor_label: Option<String>,
    #[serde(default)]
    note: Option<String>,
}

#[derive(Debug, Clone, Deserialize, IntoParams, ToSchema)]
#[into_params(parameter_in = Query)]
pub struct ListContentComplianceAuditQuery {
    #[serde(default)]
    limit: Option<i64>,
}

#[derive(Debug, Clone, Deserialize, ToSchema)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
pub struct ClaimContentReportBody {
    #[serde(default)]
    actor_label: Option<String>,
}

#[derive(Debug, Clone, Deserialize, ToSchema)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
pub struct ResolveContentReportBody {
    status: ContentReportStatus,
    #[serde(default)]
    actor_label: Option<String>,
    #[serde(default)]
    resolution_note: Option<String>,
    #[serde(default)]
    disposition: Option<ContentReportDisposition>,
}

#[derive(Debug, Clone, Deserialize, Serialize, ToSchema)]
#[serde(rename_all = "snake_case")]
enum ContentReportDisposition {
    None,
    ArchiveProject,
    SuspendUser,
}

#[derive(Debug, Clone, Deserialize, Serialize, ToSchema)]
#[serde(rename_all = "snake_case")]
enum ContentComplianceBatchAction {
    Claim,
    Resolve,
    Dismiss,
}

impl ContentComplianceBatchAction {
    fn action_label(&self) -> &'static str {
        match self {
            Self::Claim => "claim",
            Self::Resolve => "resolve",
            Self::Dismiss => "dismiss",
        }
    }
}

#[derive(Debug, Clone, Serialize, ToSchema, FromRow)]
#[serde(rename_all = "camelCase")]
pub struct ContentComplianceReportItem {
    id: Uuid,
    reporter_user_id: Uuid,
    reporter_email: Option<String>,
    target_type: String,
    target_id: Uuid,
    workspace_id: Option<Uuid>,
    workspace_name: Option<String>,
    project_id: Option<Uuid>,
    project_name: Option<String>,
    category: String,
    severity: String,
    status: String,
    detail: Option<String>,
    snapshot: Value,
    claimed_by_label: Option<String>,
    claimed_at: Option<chrono::DateTime<chrono::Utc>>,
    resolution_label: Option<String>,
    resolution_note: Option<String>,
    resolved_at: Option<chrono::DateTime<chrono::Utc>>,
    created_at: chrono::DateTime<chrono::Utc>,
    updated_at: chrono::DateTime<chrono::Utc>,
}

#[derive(Debug, Clone, Serialize, ToSchema)]
#[serde(rename_all = "camelCase")]
pub struct ContentComplianceQueueSummary {
    pending: i64,
    claimed: i64,
    resolved: i64,
    dismissed: i64,
    critical: i64,
    high: i64,
}

#[derive(Debug, Clone, Serialize, ToSchema)]
#[serde(rename_all = "camelCase")]
pub struct ContentComplianceQueueSlaSummary {
    open_over_24h: i64,
    open_over_72h: i64,
    claimed_over_24h: i64,
    unclaimed_critical: i64,
    oldest_open_age_hours: i64,
}

#[derive(Debug, Clone, Serialize, ToSchema, FromRow)]
#[serde(rename_all = "camelCase")]
pub struct ContentComplianceWorkspaceSummary {
    workspace_id: Option<Uuid>,
    workspace_name: Option<String>,
    open_count: i64,
    pending_count: i64,
    claimed_count: i64,
    critical_open_count: i64,
    high_open_count: i64,
    sla_breached_count: i64,
    oldest_open_age_hours: i64,
}

#[derive(Debug, Clone, Serialize, ToSchema, FromRow)]
#[serde(rename_all = "camelCase")]
pub struct ContentComplianceOwnerSummary {
    owner_label: String,
    pending_count: i64,
    claimed_count: i64,
    critical_open_count: i64,
    overdue_count: i64,
    oldest_open_age_hours: i64,
}

#[derive(Debug, Clone, Serialize, ToSchema)]
#[serde(rename_all = "camelCase")]
pub struct ListContentComplianceReportsResponse {
    summary: ContentComplianceQueueSummary,
    sla: ContentComplianceQueueSlaSummary,
    workspace_summaries: Vec<ContentComplianceWorkspaceSummary>,
    owner_summaries: Vec<ContentComplianceOwnerSummary>,
    items: Vec<ContentComplianceReportItem>,
}

#[derive(Debug, Clone, Serialize, ToSchema, FromRow)]
#[serde(rename_all = "camelCase")]
pub struct ContentComplianceAuditItem {
    id: Uuid,
    report_id: Uuid,
    actor_user_id: Option<Uuid>,
    actor_label: String,
    action: String,
    from_status: Option<String>,
    to_status: Option<String>,
    disposition: Option<String>,
    details: Value,
    created_at: chrono::DateTime<chrono::Utc>,
}

#[derive(Debug, Clone, Serialize, ToSchema)]
#[serde(rename_all = "camelCase")]
pub struct BatchMutateContentReportsResultItem {
    report_id: Uuid,
    ok: bool,
    action: String,
    status: Option<String>,
    message: Option<String>,
}

#[derive(Debug, Clone, Serialize, ToSchema)]
#[serde(rename_all = "camelCase")]
pub struct BatchMutateContentReportsResponse {
    requested_count: i64,
    succeeded_count: i64,
    failed_count: i64,
    results: Vec<BatchMutateContentReportsResultItem>,
}

#[derive(Debug, Clone, Serialize, ToSchema)]
#[serde(rename_all = "camelCase")]
pub struct ReassignContentReportsResponse {
    requested_count: i64,
    succeeded_count: i64,
    failed_count: i64,
    assignee_label: String,
    results: Vec<BatchMutateContentReportsResultItem>,
}

#[derive(Debug, FromRow)]
struct SummaryRow {
    pending: i64,
    claimed: i64,
    resolved: i64,
    dismissed: i64,
    critical: i64,
    high: i64,
}

#[derive(Debug, FromRow)]
struct SlaSummaryRow {
    open_over_24h: i64,
    open_over_72h: i64,
    claimed_over_24h: i64,
    unclaimed_critical: i64,
    oldest_open_age_hours: i64,
}

fn internal_ops_token_expected() -> Option<String> {
    std::env::var("TOONFLOW_INTERNAL_OPS_TOKEN")
        .ok()
        .map(|s| s.trim().to_owned())
        .filter(|s| !s.is_empty())
}

fn require_internal_ops_token(headers: &HeaderMap) -> Result<(), ApiError> {
    let Some(expected) = internal_ops_token_expected() else {
        return Err(ApiError::Forbidden(
            "content compliance console disabled (set TOONFLOW_INTERNAL_OPS_TOKEN)".into(),
        ));
    };
    let got = headers
        .get("x-toonflow-internal-token")
        .and_then(|v| v.to_str().ok())
        .unwrap_or("");
    if got != expected {
        return Err(ApiError::Unauthorized);
    }
    Ok(())
}

fn normalize_actor_label(raw: Option<String>) -> String {
    raw.map(|value| value.trim().to_string())
        .filter(|value| !value.is_empty())
        .unwrap_or_else(|| "internal_ops".into())
}

fn normalize_optional_text(raw: Option<String>) -> Option<String> {
    raw.map(|value| value.trim().to_string())
        .filter(|value| !value.is_empty())
}

fn normalize_optional_filter(raw: Option<&str>) -> Option<String> {
    raw.map(str::trim)
        .filter(|value| !value.is_empty())
        .map(ToOwned::to_owned)
}

#[allow(clippy::too_many_arguments)]
async fn append_content_compliance_audit<'e, E>(
    executor: E,
    report_id: Uuid,
    actor_user_id: Option<Uuid>,
    actor_label: &str,
    action: &str,
    from_status: Option<&str>,
    to_status: Option<&str>,
    disposition: Option<&str>,
    details: Value,
) -> Result<(), ApiError>
where
    E: Executor<'e, Database = Postgres>,
{
    sqlx::query(
        r#"
        INSERT INTO public.app_content_compliance_audit (
          report_id,
          actor_user_id,
          actor_label,
          action,
          from_status,
          to_status,
          disposition,
          details
        )
        VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
        "#,
    )
    .bind(report_id)
    .bind(actor_user_id)
    .bind(actor_label)
    .bind(action)
    .bind(from_status)
    .bind(to_status)
    .bind(disposition)
    .bind(details)
    .execute(executor)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;
    Ok(())
}

async fn fetch_content_compliance_report_for_update<'e, E>(
    executor: E,
    report_id: Uuid,
) -> Result<Option<ContentComplianceReportItem>, ApiError>
where
    E: Executor<'e, Database = Postgres>,
{
    sqlx::query_as::<_, ContentComplianceReportItem>(
        r#"
        SELECT
          r.id,
          r.reporter_user_id,
          reporter.email AS reporter_email,
          r.target_type,
          r.target_id,
          r.workspace_id,
          w.name AS workspace_name,
          r.project_id,
          p.name AS project_name,
          r.category,
          r.severity,
          r.status,
          r.detail,
          r.snapshot,
          r.claimed_by_label,
          r.claimed_at,
          r.resolution_label,
          r.resolution_note,
          r.resolved_at,
          r.created_at,
          r.updated_at
        FROM public.app_content_compliance_report r
        LEFT JOIN auth.users reporter ON reporter.id = r.reporter_user_id
        LEFT JOIN public.app_workspace w ON w.id = r.workspace_id
        LEFT JOIN public.app_project p ON p.id = r.project_id
        WHERE r.id = $1
        FOR UPDATE
        "#,
    )
    .bind(report_id)
    .fetch_optional(executor)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))
}

async fn apply_disposition<'e, E>(
    executor: E,
    report: &ContentComplianceReportItem,
    disposition: Option<ContentReportDisposition>,
    resolution_note: Option<String>,
) -> Result<(), ApiError>
where
    E: Executor<'e, Database = Postgres>,
{
    match disposition.unwrap_or(ContentReportDisposition::None) {
        ContentReportDisposition::None => Ok(()),
        ContentReportDisposition::ArchiveProject => {
            let Some(project_id) = report.project_id else {
                return Err(ApiError::BadRequest(
                    "archive_project requires a report linked to project scope".into(),
                ));
            };
            let note = match resolution_note {
                Some(note) => format!("content_compliance report {}: {}", report.id, note),
                None => format!("content_compliance report {}", report.id),
            };
            sqlx::query(
                r#"
                UPDATE public.app_project
                SET
                  archived_at = COALESCE(archived_at, NOW()),
                  metadata = jsonb_set(
                    COALESCE(metadata, '{}'::jsonb),
                    '{internalOps,opsNote}',
                    to_jsonb($2::text),
                    true
                  ),
                  updated_at = NOW()
                WHERE id = $1
                "#,
            )
            .bind(project_id)
            .bind(note)
            .execute(executor)
            .await
            .map_err(|e| ApiError::DatabaseError(e.to_string()))?;
            Ok(())
        }
        ContentReportDisposition::SuspendUser => {
            if report.target_type != "user" {
                return Err(ApiError::BadRequest(
                    "suspend_user is only valid for user reports".into(),
                ));
            }
            let reason = resolution_note
                .clone()
                .unwrap_or_else(|| format!("content_compliance report {}", report.id));
            sqlx::query(
                r#"
                UPDATE public.app_user_profile
                SET
                  operational_status = 'suspended',
                  operational_status_reason = $2,
                  ops_note = $3,
                  updated_at = NOW()
                WHERE user_id = $1
                "#,
            )
            .bind(report.target_id)
            .bind(reason)
            .bind(format!("content_compliance report {}", report.id))
            .execute(executor)
            .await
            .map_err(|e| ApiError::DatabaseError(e.to_string()))?;
            Ok(())
        }
    }
}

async fn resolve_report_scope(
    pool: &sqlx::PgPool,
    target_type: &ContentReportTargetType,
    target_id: Uuid,
) -> Result<(Option<Uuid>, Option<Uuid>), ApiError> {
    match target_type {
        ContentReportTargetType::Project => {
            let row: Option<(Uuid,)> =
                sqlx::query_as("SELECT workspace_id FROM public.app_project WHERE id = $1")
                    .bind(target_id)
                    .fetch_optional(pool)
                    .await
                    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;
            row.map(|(workspace_id,)| (Some(workspace_id), Some(target_id)))
                .ok_or(ApiError::NotFound)
        }
        ContentReportTargetType::Script => {
            let row: Option<(Uuid, Uuid)> = sqlx::query_as(
                r#"
                SELECT s.project_id, p.workspace_id
                FROM public.app_script s
                INNER JOIN public.app_project p ON p.id = s.project_id
                WHERE s.id = $1
                "#,
            )
            .bind(target_id)
            .fetch_optional(pool)
            .await
            .map_err(|e| ApiError::DatabaseError(e.to_string()))?;
            row.map(|(project_id, workspace_id)| (Some(workspace_id), Some(project_id)))
                .ok_or(ApiError::NotFound)
        }
        ContentReportTargetType::Storyboard => {
            let row: Option<(Uuid, Uuid)> = sqlx::query_as(
                r#"
                SELECT s.project_id, p.workspace_id
                FROM public.app_storyboard sb
                INNER JOIN public.app_script s ON s.id = sb.script_id
                INNER JOIN public.app_project p ON p.id = s.project_id
                WHERE sb.id = $1
                "#,
            )
            .bind(target_id)
            .fetch_optional(pool)
            .await
            .map_err(|e| ApiError::DatabaseError(e.to_string()))?;
            row.map(|(project_id, workspace_id)| (Some(workspace_id), Some(project_id)))
                .ok_or(ApiError::NotFound)
        }
        ContentReportTargetType::Asset => {
            let row: Option<(Uuid, Uuid)> = sqlx::query_as(
                r#"
                SELECT a.project_id, p.workspace_id
                FROM public.app_asset a
                INNER JOIN public.app_project p ON p.id = a.project_id
                WHERE a.id = $1
                "#,
            )
            .bind(target_id)
            .fetch_optional(pool)
            .await
            .map_err(|e| ApiError::DatabaseError(e.to_string()))?;
            row.map(|(project_id, workspace_id)| (Some(workspace_id), Some(project_id)))
                .ok_or(ApiError::NotFound)
        }
        ContentReportTargetType::Novel => {
            let row: Option<(Uuid, Uuid)> = sqlx::query_as(
                r#"
                SELECT n.project_id, p.workspace_id
                FROM public.app_novel n
                INNER JOIN public.app_project p ON p.id = n.project_id
                WHERE n.id = $1
                "#,
            )
            .bind(target_id)
            .fetch_optional(pool)
            .await
            .map_err(|e| ApiError::DatabaseError(e.to_string()))?;
            row.map(|(project_id, workspace_id)| (Some(workspace_id), Some(project_id)))
                .ok_or(ApiError::NotFound)
        }
        ContentReportTargetType::User => {
            let exists: bool =
                sqlx::query_scalar("SELECT EXISTS(SELECT 1 FROM auth.users WHERE id = $1)")
                    .bind(target_id)
                    .fetch_one(pool)
                    .await
                    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;
            if exists {
                Ok((None, None))
            } else {
                Err(ApiError::NotFound)
            }
        }
    }
}

async fn ensure_reporter_workspace_scope(
    pool: &sqlx::PgPool,
    reporter_user_id: Uuid,
    workspace_id: Option<Uuid>,
) -> Result<(), ApiError> {
    if let Some(workspace_id) = workspace_id {
        let allowed: bool = sqlx::query_scalar(
            r#"
            SELECT EXISTS(
              SELECT 1
              FROM public.app_workspace_member
              WHERE workspace_id = $1
                AND user_id = $2
            )
            "#,
        )
        .bind(workspace_id)
        .bind(reporter_user_id)
        .fetch_one(pool)
        .await
        .map_err(|e| ApiError::DatabaseError(e.to_string()))?;
        if !allowed {
            return Err(ApiError::Forbidden(
                "not a member of the target workspace".into(),
            ));
        }
    }
    Ok(())
}

#[utoipa::path(
    post,
    path = "/api/v1/content/reports",
    operation_id = "postContentReportV1",
    tag = "settings",
    request_body(content = CreateContentReportBody, content_type = "application/json"),
    responses(
        (status = 200, description = "OK", body = ContentComplianceReportItem),
        (status = 400, description = "Bad request", body = crate::error::ErrorBody),
        (status = 401, description = "Unauthorized", body = crate::error::ErrorBody),
        (status = 403, description = "Forbidden", body = crate::error::ErrorBody),
        (status = 404, description = "Not found", body = crate::error::ErrorBody),
        (status = 503, description = "Unavailable", body = crate::error::ErrorBody)
    ),
    security(("bearerAuth" = []))
)]
pub(crate) async fn create_content_report(
    State(state): State<AppState>,
    headers: HeaderMap,
    Json(body): Json<CreateContentReportBody>,
) -> Result<Json<ContentComplianceReportItem>, ApiError> {
    let reporter_user_id = require_user_uuid(&state, &headers)?;
    let pool = state.require_pool()?;
    let detail = normalize_optional_text(body.detail);
    let snapshot = body.snapshot.unwrap_or_else(|| json!({}));
    let severity = body.severity.unwrap_or(ContentReportSeverity::Medium);
    let (workspace_id, project_id) =
        resolve_report_scope(pool, &body.target_type, body.target_id).await?;
    ensure_reporter_workspace_scope(pool, reporter_user_id, workspace_id).await?;
    let mut tx = pool
        .begin()
        .await
        .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    let item = sqlx::query_as::<_, ContentComplianceReportItem>(
        r#"
        INSERT INTO public.app_content_compliance_report (
          reporter_user_id,
          target_type,
          target_id,
          workspace_id,
          project_id,
          category,
          severity,
          detail,
          snapshot
        )
        VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9)
        RETURNING
          id,
          reporter_user_id,
          NULL::text AS reporter_email,
          target_type,
          target_id,
          workspace_id,
          NULL::text AS workspace_name,
          project_id,
          NULL::text AS project_name,
          category,
          severity,
          status,
          detail,
          snapshot,
          claimed_by_label,
          claimed_at,
          resolution_label,
          resolution_note,
          resolved_at,
          created_at,
          updated_at
        "#,
    )
    .bind(reporter_user_id)
    .bind(body.target_type.as_str())
    .bind(body.target_id)
    .bind(workspace_id)
    .bind(project_id)
    .bind(body.category.as_str())
    .bind(severity.as_str())
    .bind(detail)
    .bind(snapshot)
    .fetch_one(&mut *tx)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    append_content_compliance_audit(
        &mut *tx,
        item.id,
        Some(reporter_user_id),
        "reporter",
        "reported",
        None,
        Some(item.status.as_str()),
        None,
        json!({
            "targetType": item.target_type,
            "targetId": item.target_id,
            "category": item.category,
            "severity": item.severity,
            "workspaceId": item.workspace_id,
            "projectId": item.project_id,
        }),
    )
    .await?;

    tx.commit()
        .await
        .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    Ok(Json(item))
}

#[utoipa::path(
    get,
    path = "/api/v1/internal/compliance/reports",
    operation_id = "getInternalContentComplianceReportsV1",
    tag = "settings",
    params(ListContentComplianceReportsQuery),
    responses(
        (status = 200, description = "OK", body = ListContentComplianceReportsResponse),
        (status = 400, description = "Bad request", body = crate::error::ErrorBody),
        (status = 401, description = "Unauthorized", body = crate::error::ErrorBody),
        (status = 403, description = "Forbidden", body = crate::error::ErrorBody),
        (status = 503, description = "Unavailable", body = crate::error::ErrorBody)
    )
)]
pub(crate) async fn list_content_reports(
    State(state): State<AppState>,
    headers: HeaderMap,
    Query(query): Query<ListContentComplianceReportsQuery>,
) -> Result<Json<ListContentComplianceReportsResponse>, ApiError> {
    require_internal_ops_token(&headers)?;
    let pool = state.require_pool()?;
    let limit = query.limit.unwrap_or(50).clamp(1, 200);
    let claimed_by_label_filter = normalize_optional_filter(query.claimed_by_label.as_deref());
    let sla_bucket_filter = normalize_optional_filter(query.sla_bucket.as_deref());

    let mut qb = QueryBuilder::<Postgres>::new(
        r#"
        SELECT
          r.id,
          r.reporter_user_id,
          reporter.email AS reporter_email,
          r.target_type,
          r.target_id,
          r.workspace_id,
          w.name AS workspace_name,
          r.project_id,
          p.name AS project_name,
          r.category,
          r.severity,
          r.status,
          r.detail,
          r.snapshot,
          r.claimed_by_label,
          r.claimed_at,
          r.resolution_label,
          r.resolution_note,
          r.resolved_at,
          r.created_at,
          r.updated_at
        FROM public.app_content_compliance_report r
        LEFT JOIN auth.users reporter ON reporter.id = r.reporter_user_id
        LEFT JOIN public.app_workspace w ON w.id = r.workspace_id
        LEFT JOIN public.app_project p ON p.id = r.project_id
        WHERE 1 = 1
        "#,
    );
    if let Some(status) = query.status.as_deref() {
        qb.push(" AND r.status = ");
        qb.push_bind(status.trim());
    }
    if let Some(category) = query.category.as_deref() {
        qb.push(" AND r.category = ");
        qb.push_bind(category.trim());
    }
    if let Some(target_type) = query.target_type.as_deref() {
        qb.push(" AND r.target_type = ");
        qb.push_bind(target_type.trim());
    }
    if let Some(claimed_only) = query.claimed_only {
        if claimed_only {
            qb.push(" AND r.claimed_at IS NOT NULL");
        }
    }
    if let Some(claimed_by_label) = claimed_by_label_filter.as_deref() {
        if claimed_by_label == "unclaimed" {
            qb.push(" AND r.status = 'pending' AND r.claimed_by_label IS NULL");
        } else {
            qb.push(" AND r.claimed_by_label = ");
            qb.push_bind(claimed_by_label);
        }
    }
    if let Some(sla_bucket) = sla_bucket_filter.as_deref() {
        match sla_bucket {
            "open_over_24h" => qb.push(
                " AND r.status IN ('pending', 'claimed') AND r.created_at <= NOW() - INTERVAL '24 hours'",
            ),
            "open_over_72h" => qb.push(
                " AND r.status IN ('pending', 'claimed') AND r.created_at <= NOW() - INTERVAL '72 hours'",
            ),
            "claimed_over_24h" => qb.push(
                " AND r.status = 'claimed' AND r.claimed_at IS NOT NULL AND r.claimed_at <= NOW() - INTERVAL '24 hours'",
            ),
            "unclaimed_critical" => qb.push(" AND r.status = 'pending' AND r.severity = 'critical'"),
            _ => &mut qb,
        };
    }
    if let Some(workspace_id) = query.workspace_id {
        qb.push(" AND r.workspace_id = ");
        qb.push_bind(workspace_id);
    }
    qb.push(" ORDER BY CASE r.severity WHEN 'critical' THEN 0 WHEN 'high' THEN 1 WHEN 'medium' THEN 2 ELSE 3 END, r.created_at ASC LIMIT ");
    qb.push_bind(limit);

    let items = qb
        .build_query_as::<ContentComplianceReportItem>()
        .fetch_all(pool)
        .await
        .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    let summary = sqlx::query_as::<_, SummaryRow>(
        r#"
        SELECT
          COUNT(*) FILTER (WHERE status = 'pending')::bigint AS pending,
          COUNT(*) FILTER (WHERE status = 'claimed')::bigint AS claimed,
          COUNT(*) FILTER (WHERE status = 'resolved')::bigint AS resolved,
          COUNT(*) FILTER (WHERE status = 'dismissed')::bigint AS dismissed,
          COUNT(*) FILTER (WHERE severity = 'critical' AND status IN ('pending', 'claimed'))::bigint AS critical,
          COUNT(*) FILTER (WHERE severity = 'high' AND status IN ('pending', 'claimed'))::bigint AS high
        FROM public.app_content_compliance_report
        "#,
    )
    .fetch_one(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    let sla = sqlx::query_as::<_, SlaSummaryRow>(
        r#"
        SELECT
          COUNT(*) FILTER (
            WHERE status IN ('pending', 'claimed')
              AND created_at <= NOW() - INTERVAL '24 hours'
          )::bigint AS open_over_24h,
          COUNT(*) FILTER (
            WHERE status IN ('pending', 'claimed')
              AND created_at <= NOW() - INTERVAL '72 hours'
          )::bigint AS open_over_72h,
          COUNT(*) FILTER (
            WHERE status = 'claimed'
              AND claimed_at IS NOT NULL
              AND claimed_at <= NOW() - INTERVAL '24 hours'
          )::bigint AS claimed_over_24h,
          COUNT(*) FILTER (
            WHERE status = 'pending'
              AND severity = 'critical'
          )::bigint AS unclaimed_critical,
          COALESCE(
            MAX(
              FLOOR(EXTRACT(EPOCH FROM (NOW() - created_at)) / 3600)
            ) FILTER (WHERE status IN ('pending', 'claimed'))::bigint,
            0
          ) AS oldest_open_age_hours
        FROM public.app_content_compliance_report
        "#,
    )
    .fetch_one(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    let workspace_summaries = sqlx::query_as::<_, ContentComplianceWorkspaceSummary>(
        r#"
        SELECT
          r.workspace_id,
          COALESCE(w.name, 'Personal / direct user scope') AS workspace_name,
          COUNT(*) FILTER (WHERE r.status IN ('pending', 'claimed'))::bigint AS open_count,
          COUNT(*) FILTER (WHERE r.status = 'pending')::bigint AS pending_count,
          COUNT(*) FILTER (WHERE r.status = 'claimed')::bigint AS claimed_count,
          COUNT(*) FILTER (
            WHERE r.status IN ('pending', 'claimed')
              AND r.severity = 'critical'
          )::bigint AS critical_open_count,
          COUNT(*) FILTER (
            WHERE r.status IN ('pending', 'claimed')
              AND r.severity = 'high'
          )::bigint AS high_open_count,
          COUNT(*) FILTER (
            WHERE r.status IN ('pending', 'claimed')
              AND r.created_at <= NOW() - INTERVAL '24 hours'
          )::bigint AS sla_breached_count,
          COALESCE(
            MAX(
              FLOOR(EXTRACT(EPOCH FROM (NOW() - r.created_at)) / 3600)
            ) FILTER (WHERE r.status IN ('pending', 'claimed'))::bigint,
            0
          ) AS oldest_open_age_hours
        FROM public.app_content_compliance_report r
        LEFT JOIN public.app_workspace w ON w.id = r.workspace_id
        GROUP BY r.workspace_id, w.name
        HAVING COUNT(*) FILTER (WHERE r.status IN ('pending', 'claimed')) > 0
        ORDER BY
          COUNT(*) FILTER (WHERE r.status IN ('pending', 'claimed')) DESC,
          COUNT(*) FILTER (
            WHERE r.status IN ('pending', 'claimed')
              AND r.severity = 'critical'
          ) DESC,
          oldest_open_age_hours DESC,
          COALESCE(w.name, 'Personal / direct user scope') ASC
        LIMIT 12
        "#,
    )
    .fetch_all(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    let owner_summaries = sqlx::query_as::<_, ContentComplianceOwnerSummary>(
        r#"
        SELECT
          CASE
            WHEN status = 'pending' THEN 'unclaimed'
            ELSE COALESCE(NULLIF(TRIM(claimed_by_label), ''), 'unclaimed')
          END AS owner_label,
          COUNT(*) FILTER (WHERE status = 'pending')::bigint AS pending_count,
          COUNT(*) FILTER (WHERE status = 'claimed')::bigint AS claimed_count,
          COUNT(*) FILTER (
            WHERE status IN ('pending', 'claimed')
              AND severity = 'critical'
          )::bigint AS critical_open_count,
          COUNT(*) FILTER (
            WHERE
              (status = 'pending' AND created_at <= NOW() - INTERVAL '24 hours')
              OR (
                status = 'claimed'
                AND claimed_at IS NOT NULL
                AND claimed_at <= NOW() - INTERVAL '24 hours'
              )
          )::bigint AS overdue_count,
          COALESCE(
            MAX(
              FLOOR(
                EXTRACT(
                  EPOCH FROM (
                    NOW() - CASE
                      WHEN status = 'claimed' AND claimed_at IS NOT NULL THEN claimed_at
                      ELSE created_at
                    END
                  )
                ) / 3600
              )
            ) FILTER (WHERE status IN ('pending', 'claimed'))::bigint,
            0
          ) AS oldest_open_age_hours
        FROM public.app_content_compliance_report
        WHERE status IN ('pending', 'claimed')
        GROUP BY 1
        ORDER BY
          overdue_count DESC,
          critical_open_count DESC,
          claimed_count DESC,
          pending_count DESC,
          owner_label ASC
        LIMIT 12
        "#,
    )
    .fetch_all(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    Ok(Json(ListContentComplianceReportsResponse {
        summary: ContentComplianceQueueSummary {
            pending: summary.pending,
            claimed: summary.claimed,
            resolved: summary.resolved,
            dismissed: summary.dismissed,
            critical: summary.critical,
            high: summary.high,
        },
        sla: ContentComplianceQueueSlaSummary {
            open_over_24h: sla.open_over_24h,
            open_over_72h: sla.open_over_72h,
            claimed_over_24h: sla.claimed_over_24h,
            unclaimed_critical: sla.unclaimed_critical,
            oldest_open_age_hours: sla.oldest_open_age_hours,
        },
        workspace_summaries,
        owner_summaries,
        items,
    }))
}

#[utoipa::path(
    get,
    path = "/api/v1/internal/compliance/reports/{id}/audit",
    operation_id = "getInternalContentComplianceReportAuditV1",
    tag = "settings",
    params(
        ("id" = Uuid, Path, description = "Report UUID"),
        ListContentComplianceAuditQuery
    ),
    responses(
        (status = 200, description = "OK", body = [ContentComplianceAuditItem]),
        (status = 400, description = "Bad request", body = crate::error::ErrorBody),
        (status = 401, description = "Unauthorized", body = crate::error::ErrorBody),
        (status = 403, description = "Forbidden", body = crate::error::ErrorBody),
        (status = 404, description = "Not found", body = crate::error::ErrorBody),
        (status = 503, description = "Unavailable", body = crate::error::ErrorBody)
    )
)]
pub(crate) async fn list_content_report_audit(
    State(state): State<AppState>,
    headers: HeaderMap,
    Path(id): Path<Uuid>,
    Query(query): Query<ListContentComplianceAuditQuery>,
) -> Result<Json<Vec<ContentComplianceAuditItem>>, ApiError> {
    require_internal_ops_token(&headers)?;
    let pool = state.require_pool()?;
    let limit = query.limit.unwrap_or(50).clamp(1, 200);

    let exists: bool = sqlx::query_scalar(
        "SELECT EXISTS(SELECT 1 FROM public.app_content_compliance_report WHERE id = $1)",
    )
    .bind(id)
    .fetch_one(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;
    if !exists {
        return Err(ApiError::NotFound);
    }

    let items = sqlx::query_as::<_, ContentComplianceAuditItem>(
        r#"
        SELECT
          id,
          report_id,
          actor_user_id,
          actor_label,
          action,
          from_status,
          to_status,
          disposition,
          details,
          created_at
        FROM public.app_content_compliance_audit
        WHERE report_id = $1
        ORDER BY created_at DESC, id DESC
        LIMIT $2
        "#,
    )
    .bind(id)
    .bind(limit)
    .fetch_all(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    Ok(Json(items))
}

#[utoipa::path(
    post,
    path = "/api/v1/internal/compliance/reports/{id}/claim",
    operation_id = "postInternalContentComplianceClaimV1",
    tag = "settings",
    params(("id" = Uuid, Path, description = "Report UUID")),
    request_body(content = ClaimContentReportBody, content_type = "application/json"),
    responses(
        (status = 200, description = "OK", body = ContentComplianceReportItem),
        (status = 400, description = "Bad request", body = crate::error::ErrorBody),
        (status = 401, description = "Unauthorized", body = crate::error::ErrorBody),
        (status = 403, description = "Forbidden", body = crate::error::ErrorBody),
        (status = 404, description = "Not found", body = crate::error::ErrorBody),
        (status = 503, description = "Unavailable", body = crate::error::ErrorBody)
    )
)]
pub(crate) async fn claim_content_report(
    State(state): State<AppState>,
    headers: HeaderMap,
    Path(id): Path<Uuid>,
    Json(body): Json<ClaimContentReportBody>,
) -> Result<Json<ContentComplianceReportItem>, ApiError> {
    require_internal_ops_token(&headers)?;
    let pool = state.require_pool()?;
    let actor_label = normalize_actor_label(body.actor_label);
    let mut tx = pool
        .begin()
        .await
        .map_err(|e| ApiError::DatabaseError(e.to_string()))?;
    let item = sqlx::query_as::<_, ContentComplianceReportItem>(
        r#"
        WITH updated AS (
          UPDATE public.app_content_compliance_report
          SET
            status = 'claimed',
            claimed_by_label = $2,
            claimed_at = NOW(),
            updated_at = NOW()
          WHERE id = $1
            AND status = 'pending'
          RETURNING *
        )
        SELECT
          r.id,
          r.reporter_user_id,
          reporter.email AS reporter_email,
          r.target_type,
          r.target_id,
          r.workspace_id,
          w.name AS workspace_name,
          r.project_id,
          p.name AS project_name,
          r.category,
          r.severity,
          r.status,
          r.detail,
          r.snapshot,
          r.claimed_by_label,
          r.claimed_at,
          r.resolution_label,
          r.resolution_note,
          r.resolved_at,
          r.created_at,
          r.updated_at
        FROM updated r
        LEFT JOIN auth.users reporter ON reporter.id = r.reporter_user_id
        LEFT JOIN public.app_workspace w ON w.id = r.workspace_id
        LEFT JOIN public.app_project p ON p.id = r.project_id
        "#,
    )
    .bind(id)
    .bind(&actor_label)
    .fetch_optional(&mut *tx)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?
    .ok_or_else(|| ApiError::BadRequest("report is no longer pending".into()))?;
    append_content_compliance_audit(
        &mut *tx,
        item.id,
        None,
        &actor_label,
        "claimed",
        Some("pending"),
        Some("claimed"),
        None,
        json!({
            "targetType": item.target_type,
            "targetId": item.target_id,
        }),
    )
    .await?;
    tx.commit()
        .await
        .map_err(|e| ApiError::DatabaseError(e.to_string()))?;
    Ok(Json(item))
}

#[utoipa::path(
    post,
    path = "/api/v1/internal/compliance/reports/{id}/resolve",
    operation_id = "postInternalContentComplianceResolveV1",
    tag = "settings",
    params(("id" = Uuid, Path, description = "Report UUID")),
    request_body(content = ResolveContentReportBody, content_type = "application/json"),
    responses(
        (status = 200, description = "OK", body = ContentComplianceReportItem),
        (status = 400, description = "Bad request", body = crate::error::ErrorBody),
        (status = 401, description = "Unauthorized", body = crate::error::ErrorBody),
        (status = 403, description = "Forbidden", body = crate::error::ErrorBody),
        (status = 404, description = "Not found", body = crate::error::ErrorBody),
        (status = 503, description = "Unavailable", body = crate::error::ErrorBody)
    )
)]
pub(crate) async fn resolve_content_report(
    State(state): State<AppState>,
    headers: HeaderMap,
    Path(id): Path<Uuid>,
    Json(body): Json<ResolveContentReportBody>,
) -> Result<Json<ContentComplianceReportItem>, ApiError> {
    require_internal_ops_token(&headers)?;
    let pool = state.require_pool()?;
    let next_status = body.status.as_str();
    if next_status != "resolved" && next_status != "dismissed" {
        return Err(ApiError::BadRequest(
            "status must be resolved or dismissed".into(),
        ));
    }
    let actor_label = normalize_actor_label(body.actor_label);
    let resolution_note = normalize_optional_text(body.resolution_note);
    let mut tx = pool
        .begin()
        .await
        .map_err(|e| ApiError::DatabaseError(e.to_string()))?;
    let previous_status: String = sqlx::query_scalar(
        r#"
        SELECT status
        FROM public.app_content_compliance_report
        WHERE id = $1
          AND status IN ('pending', 'claimed')
        FOR UPDATE
        "#,
    )
    .bind(id)
    .fetch_optional(&mut *tx)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?
    .ok_or_else(|| ApiError::BadRequest("report is no longer open".into()))?;
    let item = sqlx::query_as::<_, ContentComplianceReportItem>(
        r#"
        WITH updated AS (
          UPDATE public.app_content_compliance_report
          SET
            status = $2,
            resolution_label = $3,
            resolution_note = $4,
            resolved_at = NOW(),
            updated_at = NOW()
          WHERE id = $1
            AND status IN ('pending', 'claimed')
          RETURNING *
        )
        SELECT
          r.id,
          r.reporter_user_id,
          reporter.email AS reporter_email,
          r.target_type,
          r.target_id,
          r.workspace_id,
          w.name AS workspace_name,
          r.project_id,
          p.name AS project_name,
          r.category,
          r.severity,
          r.status,
          r.detail,
          r.snapshot,
          r.claimed_by_label,
          r.claimed_at,
          r.resolution_label,
          r.resolution_note,
          r.resolved_at,
          r.created_at,
          r.updated_at
        FROM updated r
        LEFT JOIN auth.users reporter ON reporter.id = r.reporter_user_id
        LEFT JOIN public.app_workspace w ON w.id = r.workspace_id
        LEFT JOIN public.app_project p ON p.id = r.project_id
        "#,
    )
    .bind(id)
    .bind(next_status)
    .bind(&actor_label)
    .bind(&resolution_note)
    .fetch_optional(&mut *tx)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?
    .ok_or_else(|| ApiError::BadRequest("report is no longer open".into()))?;
    let disposition_label = body.disposition.as_ref().map(|value| match value {
        ContentReportDisposition::None => "none",
        ContentReportDisposition::ArchiveProject => "archive_project",
        ContentReportDisposition::SuspendUser => "suspend_user",
    });
    apply_disposition(
        &mut *tx,
        &item,
        body.disposition.clone(),
        resolution_note.clone(),
    )
    .await?;
    append_content_compliance_audit(
        &mut *tx,
        item.id,
        None,
        &actor_label,
        next_status,
        Some(previous_status.as_str()),
        Some(next_status),
        disposition_label,
        json!({
            "resolutionNote": resolution_note,
            "targetType": item.target_type,
            "targetId": item.target_id,
        }),
    )
    .await?;
    if disposition_label.is_some() && disposition_label != Some("none") {
        append_content_compliance_audit(
            &mut *tx,
            item.id,
            None,
            &actor_label,
            "disposition_applied",
            Some(next_status),
            Some(next_status),
            disposition_label,
            json!({
                "projectId": item.project_id,
                "workspaceId": item.workspace_id,
                "targetType": item.target_type,
                "targetId": item.target_id,
            }),
        )
        .await?;
    }
    tx.commit()
        .await
        .map_err(|e| ApiError::DatabaseError(e.to_string()))?;
    Ok(Json(item))
}

#[utoipa::path(
    post,
    path = "/api/v1/internal/compliance/reports/batch-mutate",
    operation_id = "postInternalContentComplianceBatchMutateV1",
    tag = "settings",
    request_body(content = BatchMutateContentReportsBody, content_type = "application/json"),
    responses(
        (status = 200, description = "OK", body = BatchMutateContentReportsResponse),
        (status = 400, description = "Bad request", body = crate::error::ErrorBody),
        (status = 401, description = "Unauthorized", body = crate::error::ErrorBody),
        (status = 403, description = "Forbidden", body = crate::error::ErrorBody),
        (status = 503, description = "Unavailable", body = crate::error::ErrorBody)
    )
)]
pub(crate) async fn batch_mutate_content_reports(
    State(state): State<AppState>,
    headers: HeaderMap,
    Json(body): Json<BatchMutateContentReportsBody>,
) -> Result<Json<BatchMutateContentReportsResponse>, ApiError> {
    require_internal_ops_token(&headers)?;
    if body.report_ids.is_empty() {
        return Err(ApiError::BadRequest("reportIds must not be empty".into()));
    }
    if body.report_ids.len() > 100 {
        return Err(ApiError::BadRequest(
            "reportIds exceeds the maximum batch size of 100".into(),
        ));
    }
    let pool = state.require_pool()?;
    let actor_label = normalize_actor_label(body.actor_label);
    let resolution_note = normalize_optional_text(body.resolution_note);
    let disposition_label = body.disposition.as_ref().map(|value| match value {
        ContentReportDisposition::None => "none",
        ContentReportDisposition::ArchiveProject => "archive_project",
        ContentReportDisposition::SuspendUser => "suspend_user",
    });
    let mut tx = pool
        .begin()
        .await
        .map_err(|e| ApiError::DatabaseError(e.to_string()))?;
    let mut results = Vec::with_capacity(body.report_ids.len());

    for report_id in &body.report_ids {
        let Some(current) =
            fetch_content_compliance_report_for_update(&mut *tx, *report_id).await?
        else {
            results.push(BatchMutateContentReportsResultItem {
                report_id: *report_id,
                ok: false,
                action: body.action.action_label().into(),
                status: None,
                message: Some("report not found".into()),
            });
            continue;
        };

        match body.action {
            ContentComplianceBatchAction::Claim => {
                if current.status != "pending" {
                    results.push(BatchMutateContentReportsResultItem {
                        report_id: *report_id,
                        ok: false,
                        action: "claim".into(),
                        status: Some(current.status),
                        message: Some("report is no longer pending".into()),
                    });
                    continue;
                }
                let updated: ContentComplianceReportItem = sqlx::query_as(
                    r#"
                    UPDATE public.app_content_compliance_report
                    SET
                      status = 'claimed',
                      claimed_by_label = $2,
                      claimed_at = NOW(),
                      updated_at = NOW()
                    WHERE id = $1
                    RETURNING
                      id,
                      reporter_user_id,
                      NULL::text AS reporter_email,
                      target_type,
                      target_id,
                      workspace_id,
                      NULL::text AS workspace_name,
                      project_id,
                      NULL::text AS project_name,
                      category,
                      severity,
                      status,
                      detail,
                      snapshot,
                      claimed_by_label,
                      claimed_at,
                      resolution_label,
                      resolution_note,
                      resolved_at,
                      created_at,
                      updated_at
                    "#,
                )
                .bind(*report_id)
                .bind(&actor_label)
                .fetch_one(&mut *tx)
                .await
                .map_err(|e| ApiError::DatabaseError(e.to_string()))?;
                append_content_compliance_audit(
                    &mut *tx,
                    updated.id,
                    None,
                    &actor_label,
                    "claimed",
                    Some("pending"),
                    Some("claimed"),
                    None,
                    json!({
                        "targetType": updated.target_type,
                        "targetId": updated.target_id,
                        "batchAction": true,
                    }),
                )
                .await?;
                results.push(BatchMutateContentReportsResultItem {
                    report_id: *report_id,
                    ok: true,
                    action: "claim".into(),
                    status: Some("claimed".into()),
                    message: None,
                });
            }
            ContentComplianceBatchAction::Resolve | ContentComplianceBatchAction::Dismiss => {
                if current.status != "pending" && current.status != "claimed" {
                    results.push(BatchMutateContentReportsResultItem {
                        report_id: *report_id,
                        ok: false,
                        action: body.action.action_label().into(),
                        status: Some(current.status),
                        message: Some("report is no longer open".into()),
                    });
                    continue;
                }
                let next_status = match body.action {
                    ContentComplianceBatchAction::Resolve => "resolved",
                    ContentComplianceBatchAction::Dismiss => "dismissed",
                    ContentComplianceBatchAction::Claim => unreachable!(),
                };
                let updated: ContentComplianceReportItem = sqlx::query_as(
                    r#"
                    UPDATE public.app_content_compliance_report
                    SET
                      status = $2,
                      resolution_label = $3,
                      resolution_note = $4,
                      resolved_at = NOW(),
                      updated_at = NOW()
                    WHERE id = $1
                    RETURNING
                      id,
                      reporter_user_id,
                      NULL::text AS reporter_email,
                      target_type,
                      target_id,
                      workspace_id,
                      NULL::text AS workspace_name,
                      project_id,
                      NULL::text AS project_name,
                      category,
                      severity,
                      status,
                      detail,
                      snapshot,
                      claimed_by_label,
                      claimed_at,
                      resolution_label,
                      resolution_note,
                      resolved_at,
                      created_at,
                      updated_at
                    "#,
                )
                .bind(*report_id)
                .bind(next_status)
                .bind(&actor_label)
                .bind(&resolution_note)
                .fetch_one(&mut *tx)
                .await
                .map_err(|e| ApiError::DatabaseError(e.to_string()))?;
                apply_disposition(
                    &mut *tx,
                    &updated,
                    body.disposition.clone(),
                    resolution_note.clone(),
                )
                .await?;
                append_content_compliance_audit(
                    &mut *tx,
                    updated.id,
                    None,
                    &actor_label,
                    next_status,
                    Some(current.status.as_str()),
                    Some(next_status),
                    disposition_label,
                    json!({
                        "resolutionNote": resolution_note,
                        "targetType": updated.target_type,
                        "targetId": updated.target_id,
                        "batchAction": true,
                    }),
                )
                .await?;
                if disposition_label.is_some() && disposition_label != Some("none") {
                    append_content_compliance_audit(
                        &mut *tx,
                        updated.id,
                        None,
                        &actor_label,
                        "disposition_applied",
                        Some(next_status),
                        Some(next_status),
                        disposition_label,
                        json!({
                            "projectId": updated.project_id,
                            "workspaceId": updated.workspace_id,
                            "targetType": updated.target_type,
                            "targetId": updated.target_id,
                            "batchAction": true,
                        }),
                    )
                    .await?;
                }
                results.push(BatchMutateContentReportsResultItem {
                    report_id: *report_id,
                    ok: true,
                    action: body.action.action_label().into(),
                    status: Some(next_status.into()),
                    message: None,
                });
            }
        }
    }

    tx.commit()
        .await
        .map_err(|e| ApiError::DatabaseError(e.to_string()))?;
    let succeeded_count = results.iter().filter(|item| item.ok).count() as i64;
    let failed_count = results.len() as i64 - succeeded_count;
    Ok(Json(BatchMutateContentReportsResponse {
        requested_count: body.report_ids.len() as i64,
        succeeded_count,
        failed_count,
        results,
    }))
}

#[utoipa::path(
    post,
    path = "/api/v1/internal/compliance/reports/reassign",
    operation_id = "postInternalContentComplianceReassignV1",
    tag = "settings",
    request_body(content = ReassignContentReportsBody, content_type = "application/json"),
    responses(
        (status = 200, description = "OK", body = ReassignContentReportsResponse),
        (status = 400, description = "Bad request", body = crate::error::ErrorBody),
        (status = 401, description = "Unauthorized", body = crate::error::ErrorBody),
        (status = 403, description = "Forbidden", body = crate::error::ErrorBody),
        (status = 503, description = "Unavailable", body = crate::error::ErrorBody)
    )
)]
pub(crate) async fn reassign_content_reports(
    State(state): State<AppState>,
    headers: HeaderMap,
    Json(body): Json<ReassignContentReportsBody>,
) -> Result<Json<ReassignContentReportsResponse>, ApiError> {
    require_internal_ops_token(&headers)?;
    if body.report_ids.is_empty() {
        return Err(ApiError::BadRequest("reportIds must not be empty".into()));
    }
    if body.report_ids.len() > 100 {
        return Err(ApiError::BadRequest(
            "reportIds exceeds the maximum batch size of 100".into(),
        ));
    }
    let assignee_label = body.assignee_label.trim().to_string();
    if assignee_label.is_empty() {
        return Err(ApiError::BadRequest(
            "assigneeLabel must not be empty".into(),
        ));
    }
    let actor_label = normalize_actor_label(body.actor_label);
    let note = normalize_optional_text(body.note);
    let pool = state.require_pool()?;
    let mut tx = pool
        .begin()
        .await
        .map_err(|e| ApiError::DatabaseError(e.to_string()))?;
    let mut results = Vec::with_capacity(body.report_ids.len());

    for report_id in &body.report_ids {
        let Some(current) =
            fetch_content_compliance_report_for_update(&mut *tx, *report_id).await?
        else {
            results.push(BatchMutateContentReportsResultItem {
                report_id: *report_id,
                ok: false,
                action: "reassign".into(),
                status: None,
                message: Some("report not found".into()),
            });
            continue;
        };
        if current.status != "pending" && current.status != "claimed" {
            results.push(BatchMutateContentReportsResultItem {
                report_id: *report_id,
                ok: false,
                action: "reassign".into(),
                status: Some(current.status),
                message: Some("report is no longer open".into()),
            });
            continue;
        }
        let previous_label = current.claimed_by_label.clone();
        let next_status = "claimed";
        sqlx::query(
            r#"
            UPDATE public.app_content_compliance_report
            SET
              status = 'claimed',
              claimed_by_label = $2,
              claimed_at = COALESCE(claimed_at, NOW()),
              updated_at = NOW()
            WHERE id = $1
            "#,
        )
        .bind(*report_id)
        .bind(&assignee_label)
        .execute(&mut *tx)
        .await
        .map_err(|e| ApiError::DatabaseError(e.to_string()))?;
        append_content_compliance_audit(
            &mut *tx,
            *report_id,
            None,
            &actor_label,
            "reassigned",
            Some(current.status.as_str()),
            Some(next_status),
            None,
            json!({
                "fromClaimedByLabel": previous_label,
                "toClaimedByLabel": assignee_label.clone(),
                "note": note.clone(),
                "targetType": current.target_type,
                "targetId": current.target_id,
            }),
        )
        .await?;
        results.push(BatchMutateContentReportsResultItem {
            report_id: *report_id,
            ok: true,
            action: "reassign".into(),
            status: Some(next_status.into()),
            message: None,
        });
    }

    tx.commit()
        .await
        .map_err(|e| ApiError::DatabaseError(e.to_string()))?;
    let succeeded_count = results.iter().filter(|item| item.ok).count() as i64;
    let failed_count = results.len() as i64 - succeeded_count;
    Ok(Json(ReassignContentReportsResponse {
        requested_count: body.report_ids.len() as i64,
        succeeded_count,
        failed_count,
        assignee_label,
        results,
    }))
}

pub fn router() -> Router<AppState> {
    Router::new()
        .route("/api/v1/content/reports", post(create_content_report))
        .route(
            "/api/v1/internal/compliance/reports",
            get(list_content_reports),
        )
        .route(
            "/api/v1/internal/compliance/reports/batch-mutate",
            post(batch_mutate_content_reports),
        )
        .route(
            "/api/v1/internal/compliance/reports/reassign",
            post(reassign_content_reports),
        )
        .route(
            "/api/v1/internal/compliance/reports/{id}/claim",
            post(claim_content_report),
        )
        .route(
            "/api/v1/internal/compliance/reports/{id}/audit",
            get(list_content_report_audit),
        )
        .route(
            "/api/v1/internal/compliance/reports/{id}/resolve",
            post(resolve_content_report),
        )
}
