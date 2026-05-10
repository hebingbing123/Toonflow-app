use chrono::{DateTime, Utc};
use serde_json::json;
use sqlx::FromRow;
use uuid::Uuid;

use crate::error::ApiError;
use crate::state::AppState;
use crate::workspaces::ensure_personal_workspace;

use super::types::{
    AdminJobSearchHit, AdminJobSummary, AdminOperationalStatusDto, AdminProjectAclMemberSummary,
    AdminProjectDetailResponse, AdminProjectGovernanceAuditSummary,
    AdminProjectGovernanceUpdateBody, AdminProjectOwnerTransferBody, AdminProjectSearchHit,
    AdminProjectSummary, AdminProjectWorkspaceMemberCandidateSummary, AdminQuotaOverrideActionDto,
    AdminSearchResponse, AdminUserDetailResponse, AdminUserGovernanceAuditSummary,
    AdminUserGovernanceUpdateBody, AdminUserMembershipSummary, AdminUserSearchHit,
    AdminUserWorkspaceContextActionDto, AdminUserWorkspaceContextUpdateBody,
    AdminWorkspaceDetailResponse, AdminWorkspaceGovernanceAuditSummary,
    AdminWorkspaceGovernanceUpdateBody, AdminWorkspaceLifecycleActionDto,
    AdminWorkspaceMemberRemediationActionDto, AdminWorkspaceMemberRemediationBody,
    AdminWorkspaceMemberRoleDto, AdminWorkspaceMemberSummary, AdminWorkspaceOpsNoteActionDto,
    AdminWorkspaceOwnerTransferBody, AdminWorkspaceProjectAclSummary, AdminWorkspaceRef,
    AdminWorkspaceSearchHit,
};

#[derive(Debug, FromRow)]
struct UserSearchRow {
    user_id: Uuid,
    email: Option<String>,
    plan_tier: Option<String>,
    operational_status: Option<String>,
    current_workspace_id: Option<Uuid>,
    workspace_count: i64,
    project_count: i64,
    active_job_count: i64,
}

#[derive(Debug, FromRow)]
struct WorkspaceSearchRow {
    workspace_id: Uuid,
    name: String,
    workspace_type: String,
    archived_at: Option<DateTime<Utc>>,
    owner_user_id: Uuid,
    owner_email: Option<String>,
    member_count: i64,
    project_count: i64,
    active_job_count: i64,
}

#[derive(Debug, FromRow)]
struct ProjectSearchRow {
    project_id: Uuid,
    numeric_id: i32,
    name: Option<String>,
    workspace_id: Option<Uuid>,
    workspace_name: Option<String>,
    owner_user_id: Uuid,
    owner_email: Option<String>,
    archived_at: Option<DateTime<Utc>>,
    updated_at: Option<DateTime<Utc>>,
}

#[derive(Debug, FromRow)]
struct JobRow {
    job_id: Uuid,
    owner_user_id: Uuid,
    owner_email: Option<String>,
    kind: String,
    status: String,
    project_id: Option<Uuid>,
    project_numeric_id: Option<i32>,
    created_at: DateTime<Utc>,
}

#[derive(Debug, FromRow)]
struct WorkspaceMemberRow {
    user_id: Uuid,
    email: Option<String>,
    role: String,
    created_at: DateTime<Utc>,
}

#[derive(Debug, FromRow)]
struct ProjectSummaryRow {
    project_id: Uuid,
    numeric_id: i32,
    name: Option<String>,
    owner_user_id: Uuid,
    owner_email: Option<String>,
    updated_at: Option<DateTime<Utc>>,
}

#[derive(Debug, FromRow)]
struct MembershipRow {
    workspace_id: Uuid,
    workspace_name: String,
    workspace_type: String,
    role: String,
    archived_at: Option<DateTime<Utc>>,
}

#[derive(Debug, FromRow)]
struct UserDetailRow {
    user_id: Uuid,
    email: Option<String>,
    created_at: DateTime<Utc>,
    plan_tier: Option<String>,
    operational_status: Option<String>,
    operational_status_reason: Option<String>,
    ops_note: Option<String>,
    daily_job_quota: Option<i64>,
    billing_provider: Option<String>,
    subscription_status: Option<String>,
    current_workspace_id: Option<Uuid>,
    current_workspace_name: Option<String>,
    current_workspace_type: Option<String>,
    current_workspace_archived_at: Option<DateTime<Utc>>,
    workspace_count: i64,
    project_count: i64,
    active_job_count: i64,
    api_key_count: i64,
    unread_notification_count: i64,
}

#[derive(Debug, FromRow)]
struct GovernanceAuditRow {
    audit_id: Uuid,
    actor_label: String,
    created_at: DateTime<Utc>,
    previous_state: serde_json::Value,
    next_state: serde_json::Value,
}

#[derive(Debug, FromRow)]
struct WorkspaceDetailRow {
    workspace_id: Uuid,
    name: String,
    workspace_type: String,
    owner_user_id: Uuid,
    owner_email: Option<String>,
    archived_at: Option<DateTime<Utc>>,
    ops_note: Option<String>,
    member_count: i64,
    project_count: i64,
    active_job_count: i64,
}

#[derive(Debug, FromRow)]
struct WorkspaceGovernanceCurrentRow {
    workspace_type: String,
    archived_at: Option<DateTime<Utc>>,
    metadata: serde_json::Value,
}

#[derive(Debug, FromRow)]
struct ProjectDetailRow {
    project_id: Uuid,
    numeric_id: i32,
    name: Option<String>,
    owner_user_id: Uuid,
    owner_email: Option<String>,
    workspace_id: Option<Uuid>,
    workspace_name: Option<String>,
    workspace_type: Option<String>,
    workspace_archived_at: Option<DateTime<Utc>>,
    project_archived_at: Option<DateTime<Utc>>,
    ops_note: Option<String>,
    created_at: Option<DateTime<Utc>>,
    updated_at: Option<DateTime<Utc>>,
    script_count: i64,
    asset_count: i64,
    job_count: i64,
    active_job_count: i64,
}

#[derive(Debug, FromRow)]
struct ProjectGovernanceCurrentRow {
    archived_at: Option<DateTime<Utc>>,
    metadata: serde_json::Value,
}

#[derive(Debug, FromRow)]
struct WorkspaceProjectAclSummaryRow {
    project_id: Uuid,
    numeric_id: i32,
    name: Option<String>,
    owner_user_id: Uuid,
    owner_email: Option<String>,
    archived_at: Option<DateTime<Utc>>,
    explicit_acl_count: i64,
    editor_count: i64,
    viewer_count: i64,
}

#[derive(Debug, FromRow)]
struct ProjectAclMemberRow {
    user_id: Uuid,
    email: Option<String>,
    workspace_role: String,
    project_role: String,
    created_at: DateTime<Utc>,
    updated_at: DateTime<Utc>,
}

#[derive(Debug, FromRow)]
struct ProjectWorkspaceMemberCandidateRow {
    user_id: Uuid,
    email: Option<String>,
    workspace_role: String,
    explicit_project_role: Option<String>,
}

fn search_pattern(query: &str) -> String {
    format!("%{}%", query.trim())
}

fn query_uuid_prefix(query: &str) -> Option<String> {
    let normalized = query.trim().to_lowercase();
    if normalized.len() >= 6
        && normalized
            .chars()
            .all(|c| c.is_ascii_hexdigit() || c == '-')
    {
        Some(format!("{normalized}%"))
    } else {
        None
    }
}

fn query_numeric(query: &str) -> Option<i32> {
    query.trim().parse::<i32>().ok()
}

fn normalize_optional_text(raw: Option<String>) -> Option<String> {
    raw.map(|value| value.trim().to_string())
        .filter(|value| !value.is_empty())
}

fn internal_ops_note_from_metadata(metadata: &serde_json::Value) -> Option<String> {
    metadata
        .get("internalOps")
        .and_then(|v| v.get("opsNote"))
        .and_then(|v| v.as_str())
        .map(|s| s.trim().to_string())
        .filter(|s| !s.is_empty())
}

fn apply_internal_ops_note_to_metadata(
    mut metadata: serde_json::Value,
    next_note: Option<&str>,
) -> serde_json::Value {
    let root = metadata.as_object_mut().expect("metadata object");
    let mut internal = root
        .get("internalOps")
        .cloned()
        .unwrap_or_else(|| json!({}));
    let obj = internal.as_object_mut().expect("internalOps object");
    match next_note {
        None => {
            obj.remove("opsNote");
        }
        Some(text) => {
            obj.insert("opsNote".into(), json!(text));
        }
    }
    obj.insert(
        "updatedAt".into(),
        json!(chrono::Utc::now().to_rfc3339_opts(chrono::SecondsFormat::Millis, true)),
    );
    root.insert("internalOps".into(), internal);
    metadata
}

fn workspace_member_role_str(role: &AdminWorkspaceMemberRoleDto) -> &'static str {
    match role {
        AdminWorkspaceMemberRoleDto::Admin => "admin",
        AdminWorkspaceMemberRoleDto::Member => "member",
    }
}

async fn reset_user_current_workspace_if_matches(
    pool: &sqlx::PgPool,
    user_id: Uuid,
    workspace_id: Uuid,
) -> Result<bool, ApiError> {
    let personal = ensure_personal_workspace(pool, user_id).await?;
    let updated: u64 = sqlx::query(
        r#"
        UPDATE public.app_user_profile
        SET
          current_workspace_id = $2,
          updated_at = NOW()
        WHERE user_id = $1
          AND current_workspace_id = $3
        "#,
    )
    .bind(user_id)
    .bind(personal.workspace_id)
    .bind(workspace_id)
    .execute(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?
    .rows_affected();
    Ok(updated > 0)
}

async fn append_internal_workspace_governance_audit(
    pool: &sqlx::PgPool,
    workspace_id: Uuid,
    event_type: &str,
    previous_state: serde_json::Value,
    next_state: serde_json::Value,
) -> Result<(), ApiError> {
    sqlx::query(
        r#"
        INSERT INTO public.app_workspace_governance_audit (
          workspace_id,
          event_type,
          actor_label,
          previous_state,
          next_state
        )
        VALUES ($1, $2, 'internal_ops', $3, $4)
        "#,
    )
    .bind(workspace_id)
    .bind(event_type)
    .bind(previous_state)
    .bind(next_state)
    .execute(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;
    Ok(())
}

fn operational_status_str(status: &AdminOperationalStatusDto) -> &'static str {
    match status {
        AdminOperationalStatusDto::Active => "active",
        AdminOperationalStatusDto::Suspended => "suspended",
    }
}

fn resolve_daily_job_quota_override(
    current: Option<i64>,
    body: &AdminUserGovernanceUpdateBody,
) -> Result<Option<i64>, ApiError> {
    match body
        .daily_job_quota_action
        .clone()
        .unwrap_or(AdminQuotaOverrideActionDto::Preserve)
    {
        AdminQuotaOverrideActionDto::Preserve => Ok(current),
        AdminQuotaOverrideActionDto::Clear => Ok(None),
        AdminQuotaOverrideActionDto::Set => match body.daily_job_quota {
            Some(value) if value > 0 => Ok(Some(value)),
            _ => Err(ApiError::BadRequest(
                "dailyJobQuota must be a positive integer when action=set".into(),
            )),
        },
    }
}

fn map_job(row: JobRow) -> AdminJobSummary {
    AdminJobSummary {
        job_id: row.job_id,
        owner_user_id: row.owner_user_id,
        owner_email: row.owner_email,
        kind: row.kind,
        status: row.status,
        project_id: row.project_id,
        project_numeric_id: row.project_numeric_id,
        created_at: row.created_at,
    }
}

pub async fn search_admin_console(
    state: &AppState,
    query: &str,
    limit: i64,
) -> Result<AdminSearchResponse, ApiError> {
    let pool = state.require_pool()?;
    let pattern = search_pattern(query);
    let uuid_prefix = query_uuid_prefix(query);
    let numeric = query_numeric(query);

    let users = sqlx::query_as::<_, UserSearchRow>(
        r#"
        SELECT
          u.id AS user_id,
          u.email,
          p.plan_tier,
          p.operational_status,
          p.current_workspace_id,
          (
            SELECT COUNT(*)::bigint
            FROM public.app_workspace_member m
            WHERE m.user_id = u.id
          ) AS workspace_count,
          (
            SELECT COUNT(*)::bigint
            FROM public.app_project pr
            WHERE pr.owner_user_id = u.id
              AND pr.archived_at IS NULL
          ) AS project_count,
          (
            SELECT COUNT(*)::bigint
            FROM public.app_generation_job j
            WHERE j.owner_user_id = u.id
              AND j.status IN ('queued', 'running')
          ) AS active_job_count
        FROM auth.users u
        LEFT JOIN public.app_user_profile p ON p.user_id = u.id
        WHERE u.email ILIKE $1
           OR ($2::text IS NOT NULL AND u.id::text ILIKE $2)
        ORDER BY u.created_at DESC
        LIMIT $3
        "#,
    )
    .bind(&pattern)
    .bind(uuid_prefix.as_deref())
    .bind(limit)
    .fetch_all(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?
    .into_iter()
    .map(|row| AdminUserSearchHit {
        user_id: row.user_id,
        email: row.email,
        plan_tier: row.plan_tier,
        operational_status: row.operational_status.unwrap_or_else(|| "active".into()),
        current_workspace_id: row.current_workspace_id,
        workspace_count: row.workspace_count,
        project_count: row.project_count,
        active_job_count: row.active_job_count,
    })
    .collect();

    let workspaces = sqlx::query_as::<_, WorkspaceSearchRow>(
        r#"
        SELECT
          w.id AS workspace_id,
          w.name,
          w.workspace_type,
          w.archived_at,
          w.owner_user_id,
          owner.email AS owner_email,
          (
            SELECT COUNT(*)::bigint
            FROM public.app_workspace_member m
            WHERE m.workspace_id = w.id
          ) AS member_count,
          (
            SELECT COUNT(*)::bigint
            FROM public.app_project p
            WHERE p.workspace_id = w.id
              AND p.archived_at IS NULL
          ) AS project_count,
          (
            SELECT COUNT(*)::bigint
            FROM public.app_generation_job j
            WHERE j.status IN ('queued', 'running')
              AND EXISTS (
                SELECT 1
                FROM public.app_project p
                WHERE p.workspace_id = w.id
                  AND p.archived_at IS NULL
                  AND (
                    (j.payload->>'project_uuid') = p.id::text
                    OR (
                      (j.payload->>'project_uuid') IS NULL
                      AND (j.payload->>'project_numeric_id') ~ '^[0-9]+$'
                      AND p.numeric_id = (j.payload->>'project_numeric_id')::int
                    )
                  )
              )
          ) AS active_job_count
        FROM public.app_workspace w
        LEFT JOIN auth.users owner ON owner.id = w.owner_user_id
        WHERE w.name ILIKE $1
           OR ($2::text IS NOT NULL AND w.id::text ILIKE $2)
        ORDER BY w.updated_at DESC NULLS LAST, w.created_at DESC
        LIMIT $3
        "#,
    )
    .bind(&pattern)
    .bind(uuid_prefix.as_deref())
    .bind(limit)
    .fetch_all(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?
    .into_iter()
    .map(|row| AdminWorkspaceSearchHit {
        workspace_id: row.workspace_id,
        name: row.name,
        workspace_type: row.workspace_type,
        archived_at: row.archived_at,
        owner_user_id: row.owner_user_id,
        owner_email: row.owner_email,
        member_count: row.member_count,
        project_count: row.project_count,
        active_job_count: row.active_job_count,
    })
    .collect();

    let projects = sqlx::query_as::<_, ProjectSearchRow>(
        r#"
        SELECT
          p.id AS project_id,
          p.numeric_id,
          p.name,
          p.workspace_id,
          w.name AS workspace_name,
          p.owner_user_id,
          owner.email AS owner_email,
          p.archived_at,
          p.update_time AS updated_at
        FROM public.app_project p
        LEFT JOIN public.app_workspace w ON w.id = p.workspace_id
        LEFT JOIN auth.users owner ON owner.id = p.owner_user_id
        WHERE p.name ILIKE $1
           OR ($2::text IS NOT NULL AND p.id::text ILIKE $2)
           OR ($3::int IS NOT NULL AND p.numeric_id = $3)
        ORDER BY p.update_time DESC NULLS LAST
        LIMIT $4
        "#,
    )
    .bind(&pattern)
    .bind(uuid_prefix.as_deref())
    .bind(numeric)
    .bind(limit)
    .fetch_all(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?
    .into_iter()
    .map(|row| AdminProjectSearchHit {
        project_id: row.project_id,
        numeric_id: row.numeric_id,
        name: row.name,
        workspace_id: row.workspace_id,
        workspace_name: row.workspace_name,
        owner_user_id: row.owner_user_id,
        owner_email: row.owner_email,
        archived_at: row.archived_at,
        updated_at: row.updated_at,
    })
    .collect();

    let jobs = sqlx::query_as::<_, JobRow>(
        r#"
        SELECT
          j.id AS job_id,
          j.owner_user_id,
          owner.email AS owner_email,
          j.kind,
          j.status,
          NULLIF(j.payload->>'project_uuid', '')::uuid AS project_id,
          CASE
            WHEN (j.payload->>'project_numeric_id') ~ '^[0-9]+$'
              THEN (j.payload->>'project_numeric_id')::int
            ELSE NULL
          END AS project_numeric_id,
          j.created_at
        FROM public.app_generation_job j
        LEFT JOIN auth.users owner ON owner.id = j.owner_user_id
        WHERE j.kind ILIKE $1
           OR j.status ILIKE $1
           OR ($2::text IS NOT NULL AND j.id::text ILIKE $2)
           OR ($3::int IS NOT NULL AND (j.payload->>'project_numeric_id') ~ '^[0-9]+$' AND (j.payload->>'project_numeric_id')::int = $3)
        ORDER BY j.created_at DESC
        LIMIT $4
        "#,
    )
    .bind(&pattern)
    .bind(uuid_prefix.as_deref())
    .bind(numeric)
    .bind(limit)
    .fetch_all(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?
    .into_iter()
    .map(|row| AdminJobSearchHit {
        job_id: row.job_id,
        owner_user_id: row.owner_user_id,
        owner_email: row.owner_email,
        kind: row.kind,
        status: row.status,
        project_id: row.project_id,
        project_numeric_id: row.project_numeric_id,
        created_at: row.created_at,
    })
    .collect();

    Ok(AdminSearchResponse {
        query: query.trim().to_string(),
        users,
        workspaces,
        projects,
        jobs,
    })
}

pub async fn get_admin_user_detail(
    state: &AppState,
    user_id: Uuid,
) -> Result<AdminUserDetailResponse, ApiError> {
    let pool = state.require_pool()?;
    let row = sqlx::query_as::<_, UserDetailRow>(
        r#"
        SELECT
          u.id AS user_id,
          u.email,
          u.created_at,
          p.plan_tier,
          p.operational_status,
          p.operational_status_reason,
          p.ops_note,
          p.daily_job_quota,
          p.billing_provider,
          p.subscription_status,
          cw.id AS current_workspace_id,
          cw.name AS current_workspace_name,
          cw.workspace_type AS current_workspace_type,
          cw.archived_at AS current_workspace_archived_at,
          (
            SELECT COUNT(*)::bigint
            FROM public.app_workspace_member m
            WHERE m.user_id = u.id
          ) AS workspace_count,
          (
            SELECT COUNT(*)::bigint
            FROM public.app_project pr
            WHERE pr.owner_user_id = u.id
              AND pr.archived_at IS NULL
          ) AS project_count,
          (
            SELECT COUNT(*)::bigint
            FROM public.app_generation_job j
            WHERE j.owner_user_id = u.id
              AND j.status IN ('queued', 'running')
          ) AS active_job_count,
          (
            SELECT COUNT(*)::bigint
            FROM public.app_api_key k
            WHERE k.owner_user_id = u.id
          ) AS api_key_count,
          (
            SELECT COUNT(*)::bigint
            FROM public.app_notification n
            WHERE n.user_id = u.id
              AND n.read_at IS NULL
          ) AS unread_notification_count
        FROM auth.users u
        LEFT JOIN public.app_user_profile p ON p.user_id = u.id
        LEFT JOIN public.app_workspace cw ON cw.id = p.current_workspace_id
        WHERE u.id = $1
        "#,
    )
    .bind(user_id)
    .fetch_optional(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?
    .ok_or(ApiError::NotFound)?;

    let memberships = sqlx::query_as::<_, MembershipRow>(
        r#"
        SELECT
          w.id AS workspace_id,
          w.name AS workspace_name,
          w.workspace_type,
          m.role,
          w.archived_at
        FROM public.app_workspace_member m
        INNER JOIN public.app_workspace w ON w.id = m.workspace_id
        WHERE m.user_id = $1
        ORDER BY w.created_at DESC
        LIMIT 20
        "#,
    )
    .bind(user_id)
    .fetch_all(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?
    .into_iter()
    .map(|row| AdminUserMembershipSummary {
        workspace_id: row.workspace_id,
        workspace_name: row.workspace_name,
        workspace_type: row.workspace_type,
        role: row.role,
        archived_at: row.archived_at,
    })
    .collect();

    let governance_audit = sqlx::query_as::<_, GovernanceAuditRow>(
        r#"
        SELECT
          id AS audit_id,
          actor_label,
          created_at,
          previous_state,
          next_state
        FROM public.app_user_governance_audit
        WHERE user_id = $1
        ORDER BY created_at DESC
        LIMIT 10
        "#,
    )
    .bind(user_id)
    .fetch_all(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?
    .into_iter()
    .map(|row| AdminUserGovernanceAuditSummary {
        audit_id: row.audit_id,
        actor_label: row.actor_label,
        created_at: row.created_at,
        previous_state: row.previous_state,
        next_state: row.next_state,
    })
    .collect();

    let recent_jobs = sqlx::query_as::<_, JobRow>(
        r#"
        SELECT
          j.id AS job_id,
          j.owner_user_id,
          owner.email AS owner_email,
          j.kind,
          j.status,
          NULLIF(j.payload->>'project_uuid', '')::uuid AS project_id,
          CASE
            WHEN (j.payload->>'project_numeric_id') ~ '^[0-9]+$'
              THEN (j.payload->>'project_numeric_id')::int
            ELSE NULL
          END AS project_numeric_id,
          j.created_at
        FROM public.app_generation_job j
        LEFT JOIN auth.users owner ON owner.id = j.owner_user_id
        WHERE j.owner_user_id = $1
        ORDER BY j.created_at DESC
        LIMIT 10
        "#,
    )
    .bind(user_id)
    .fetch_all(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?
    .into_iter()
    .map(map_job)
    .collect();

    let current_workspace = row
        .current_workspace_id
        .map(|workspace_id| AdminWorkspaceRef {
            workspace_id,
            name: row
                .current_workspace_name
                .unwrap_or_else(|| "Unknown Workspace".into()),
            workspace_type: row
                .current_workspace_type
                .unwrap_or_else(|| "unknown".into()),
            archived_at: row.current_workspace_archived_at,
        });

    Ok(AdminUserDetailResponse {
        user_id: row.user_id,
        email: row.email,
        created_at: row.created_at,
        plan_tier: row.plan_tier.unwrap_or_else(|| "free".into()),
        operational_status: row.operational_status.unwrap_or_else(|| "active".into()),
        operational_status_reason: row.operational_status_reason,
        ops_note: row.ops_note,
        daily_job_quota_override: row.daily_job_quota,
        billing_provider: row.billing_provider,
        subscription_status: row.subscription_status,
        current_workspace,
        workspace_count: row.workspace_count,
        project_count: row.project_count,
        active_job_count: row.active_job_count,
        api_key_count: row.api_key_count,
        unread_notification_count: row.unread_notification_count,
        memberships,
        recent_jobs,
        governance_audit,
    })
}

pub async fn get_admin_workspace_detail(
    state: &AppState,
    workspace_id: Uuid,
) -> Result<AdminWorkspaceDetailResponse, ApiError> {
    let pool = state.require_pool()?;
    let row = sqlx::query_as::<_, WorkspaceDetailRow>(
        r#"
        SELECT
          w.id AS workspace_id,
          w.name,
          w.workspace_type,
          w.owner_user_id,
          owner.email AS owner_email,
          w.archived_at,
          NULLIF(
            BTRIM(COALESCE(w.metadata->'internalOps'->>'opsNote', '')),
            ''
          ) AS ops_note,
          (
            SELECT COUNT(*)::bigint
            FROM public.app_workspace_member m
            WHERE m.workspace_id = w.id
          ) AS member_count,
          (
            SELECT COUNT(*)::bigint
            FROM public.app_project p
            WHERE p.workspace_id = w.id
              AND p.archived_at IS NULL
          ) AS project_count,
          (
            SELECT COUNT(*)::bigint
            FROM public.app_generation_job j
            WHERE j.status IN ('queued', 'running')
              AND EXISTS (
                SELECT 1
                FROM public.app_project p
                WHERE p.workspace_id = w.id
                  AND p.archived_at IS NULL
                  AND (
                    (j.payload->>'project_uuid') = p.id::text
                    OR (
                      (j.payload->>'project_uuid') IS NULL
                      AND (j.payload->>'project_numeric_id') ~ '^[0-9]+$'
                      AND p.numeric_id = (j.payload->>'project_numeric_id')::int
                    )
                  )
              )
          ) AS active_job_count
        FROM public.app_workspace w
        LEFT JOIN auth.users owner ON owner.id = w.owner_user_id
        WHERE w.id = $1
        "#,
    )
    .bind(workspace_id)
    .fetch_optional(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?
    .ok_or(ApiError::NotFound)?;

    let members = sqlx::query_as::<_, WorkspaceMemberRow>(
        r#"
        SELECT
          m.user_id,
          u.email,
          m.role,
          m.created_at
        FROM public.app_workspace_member m
        LEFT JOIN auth.users u ON u.id = m.user_id
        WHERE m.workspace_id = $1
        ORDER BY
          CASE m.role
            WHEN 'owner' THEN 0
            WHEN 'admin' THEN 1
            ELSE 2
          END,
          m.created_at ASC
        LIMIT 30
        "#,
    )
    .bind(workspace_id)
    .fetch_all(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?
    .into_iter()
    .map(|row| AdminWorkspaceMemberSummary {
        user_id: row.user_id,
        email: row.email,
        role: row.role,
        created_at: row.created_at,
    })
    .collect();

    let workspace_role_breakdown: serde_json::Value = sqlx::query_scalar(
        r#"
        SELECT jsonb_build_object(
          'owner', COUNT(*) FILTER (WHERE role = 'owner'),
          'admin', COUNT(*) FILTER (WHERE role = 'admin'),
          'member', COUNT(*) FILTER (WHERE role = 'member')
        )
        FROM public.app_workspace_member
        WHERE workspace_id = $1
        "#,
    )
    .bind(workspace_id)
    .fetch_one(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    let project_acl_summaries = sqlx::query_as::<_, WorkspaceProjectAclSummaryRow>(
        r#"
        SELECT
          p.id AS project_id,
          p.numeric_id,
          p.name,
          p.owner_user_id,
          owner.email AS owner_email,
          p.archived_at,
          COUNT(pm.user_id)::bigint AS explicit_acl_count,
          COUNT(pm.user_id) FILTER (WHERE pm.role = 'editor')::bigint AS editor_count,
          COUNT(pm.user_id) FILTER (WHERE pm.role = 'viewer')::bigint AS viewer_count
        FROM public.app_project p
        LEFT JOIN auth.users owner ON owner.id = p.owner_user_id
        LEFT JOIN public.app_project_member pm ON pm.project_id = p.id
        WHERE p.workspace_id = $1
        GROUP BY p.id, p.numeric_id, p.name, p.owner_user_id, owner.email, p.archived_at
        ORDER BY p.archived_at NULLS FIRST, p.update_time DESC NULLS LAST, p.create_time_ms DESC NULLS LAST
        LIMIT 25
        "#,
    )
    .bind(workspace_id)
    .fetch_all(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?
    .into_iter()
    .map(|row| AdminWorkspaceProjectAclSummary {
        project_id: row.project_id,
        numeric_id: row.numeric_id,
        name: row.name,
        owner_user_id: row.owner_user_id,
        owner_email: row.owner_email,
        archived_at: row.archived_at,
        acl_mode: if row.explicit_acl_count > 0 {
            "restricted".into()
        } else {
            "inherited".into()
        },
        explicit_acl_count: row.explicit_acl_count,
        editor_count: row.editor_count,
        viewer_count: row.viewer_count,
    })
    .collect();

    let recent_projects = sqlx::query_as::<_, ProjectSummaryRow>(
        r#"
        SELECT
          p.id AS project_id,
          p.numeric_id,
          p.name,
          p.owner_user_id,
          owner.email AS owner_email,
          p.update_time AS updated_at
        FROM public.app_project p
        LEFT JOIN auth.users owner ON owner.id = p.owner_user_id
        WHERE p.workspace_id = $1
        ORDER BY p.update_time DESC NULLS LAST, p.create_time_ms DESC NULLS LAST
        LIMIT 10
        "#,
    )
    .bind(workspace_id)
    .fetch_all(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?
    .into_iter()
    .map(|row| AdminProjectSummary {
        project_id: row.project_id,
        numeric_id: row.numeric_id,
        name: row.name,
        owner_user_id: row.owner_user_id,
        owner_email: row.owner_email,
        updated_at: row.updated_at,
    })
    .collect();

    let recent_jobs = sqlx::query_as::<_, JobRow>(
        r#"
        SELECT
          j.id AS job_id,
          j.owner_user_id,
          owner.email AS owner_email,
          j.kind,
          j.status,
          NULLIF(j.payload->>'project_uuid', '')::uuid AS project_id,
          CASE
            WHEN (j.payload->>'project_numeric_id') ~ '^[0-9]+$'
              THEN (j.payload->>'project_numeric_id')::int
            ELSE NULL
          END AS project_numeric_id,
          j.created_at
        FROM public.app_generation_job j
        LEFT JOIN auth.users owner ON owner.id = j.owner_user_id
        WHERE EXISTS (
          SELECT 1
          FROM public.app_project p
          WHERE p.workspace_id = $1
            AND (
              (j.payload->>'project_uuid') = p.id::text
              OR (
                (j.payload->>'project_uuid') IS NULL
                AND (j.payload->>'project_numeric_id') ~ '^[0-9]+$'
                AND p.numeric_id = (j.payload->>'project_numeric_id')::int
              )
            )
        )
        ORDER BY j.created_at DESC
        LIMIT 10
        "#,
    )
    .bind(workspace_id)
    .fetch_all(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?
    .into_iter()
    .map(map_job)
    .collect();

    let governance_audit = sqlx::query_as::<_, GovernanceAuditRow>(
        r#"
        SELECT
          id AS audit_id,
          actor_label,
          created_at,
          previous_state,
          next_state
        FROM public.app_workspace_governance_audit
        WHERE workspace_id = $1
        ORDER BY created_at DESC
        LIMIT 10
        "#,
    )
    .bind(workspace_id)
    .fetch_all(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?
    .into_iter()
    .map(|audit| AdminWorkspaceGovernanceAuditSummary {
        audit_id: audit.audit_id,
        actor_label: audit.actor_label,
        created_at: audit.created_at,
        previous_state: audit.previous_state,
        next_state: audit.next_state,
    })
    .collect();

    Ok(AdminWorkspaceDetailResponse {
        workspace_id: row.workspace_id,
        name: row.name,
        workspace_type: row.workspace_type,
        owner_user_id: row.owner_user_id,
        owner_email: row.owner_email,
        archived_at: row.archived_at,
        ops_note: row.ops_note,
        member_count: row.member_count,
        project_count: row.project_count,
        active_job_count: row.active_job_count,
        members,
        workspace_role_breakdown,
        project_acl_summaries,
        recent_projects,
        recent_jobs,
        governance_audit,
    })
}

pub async fn update_admin_workspace_governance(
    state: &AppState,
    workspace_id: Uuid,
    body: AdminWorkspaceGovernanceUpdateBody,
) -> Result<AdminWorkspaceDetailResponse, ApiError> {
    let pool = state.require_pool()?;

    let cur = sqlx::query_as::<_, WorkspaceGovernanceCurrentRow>(
        r#"
        SELECT workspace_type, archived_at, metadata
        FROM public.app_workspace
        WHERE id = $1
        "#,
    )
    .bind(workspace_id)
    .fetch_optional(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?
    .ok_or(ApiError::NotFound)?;

    if cur.workspace_type == "personal"
        && body.workspace_lifecycle == AdminWorkspaceLifecycleActionDto::Archive
    {
        return Err(ApiError::BadRequest(
            "personal workspaces cannot be archived".into(),
        ));
    }

    let next_archived = match body.workspace_lifecycle {
        AdminWorkspaceLifecycleActionDto::Preserve => cur.archived_at,
        AdminWorkspaceLifecycleActionDto::Archive => match cur.archived_at {
            Some(ts) => Some(ts),
            None => Some(Utc::now()),
        },
        AdminWorkspaceLifecycleActionDto::Restore => None,
    };

    let current_ops = internal_ops_note_from_metadata(&cur.metadata);

    let next_ops: Option<String> = match body.ops_note_action {
        AdminWorkspaceOpsNoteActionDto::Preserve => current_ops.clone(),
        AdminWorkspaceOpsNoteActionDto::Clear => None,
        AdminWorkspaceOpsNoteActionDto::Set => {
            let normalized = normalize_optional_text(body.ops_note.clone());
            if normalized.is_none() {
                return Err(ApiError::BadRequest(
                    "opsNote is required when opsNoteAction is set".into(),
                ));
            }
            normalized
        }
    };

    let meta_changed = match body.ops_note_action {
        AdminWorkspaceOpsNoteActionDto::Preserve => false,
        AdminWorkspaceOpsNoteActionDto::Clear => current_ops.is_some(),
        AdminWorkspaceOpsNoteActionDto::Set => next_ops != current_ops,
    };

    let archived_changed = next_archived != cur.archived_at;

    if !meta_changed && !archived_changed {
        return Err(ApiError::BadRequest(
            "no governance changes requested".into(),
        ));
    }

    let next_metadata = if meta_changed {
        apply_internal_ops_note_to_metadata(cur.metadata.clone(), next_ops.as_deref())
    } else {
        cur.metadata.clone()
    };

    sqlx::query(
        r#"
        UPDATE public.app_workspace
        SET
          archived_at = $1,
          metadata = $2,
          updated_at = NOW()
        WHERE id = $3
        "#,
    )
    .bind(next_archived)
    .bind(next_metadata)
    .bind(workspace_id)
    .execute(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    sqlx::query(
        r#"
        INSERT INTO public.app_workspace_governance_audit (
          workspace_id,
          event_type,
          actor_label,
          previous_state,
          next_state
        )
        VALUES ($1, 'governance_updated', 'internal_ops', $2, $3)
        "#,
    )
    .bind(workspace_id)
    .bind(json!({
        "archivedAt": cur.archived_at,
        "opsNote": current_ops,
    }))
    .bind(json!({
        "archivedAt": next_archived,
        "opsNote": next_ops,
    }))
    .execute(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    get_admin_workspace_detail(state, workspace_id).await
}

pub async fn update_admin_workspace_member_remediation(
    state: &AppState,
    workspace_id: Uuid,
    body: AdminWorkspaceMemberRemediationBody,
) -> Result<AdminWorkspaceDetailResponse, ApiError> {
    let pool = state.require_pool()?;

    let workspace: Option<(String, Option<Uuid>)> = sqlx::query_as(
        r#"
        SELECT workspace_type, owner_user_id
        FROM public.app_workspace
        WHERE id = $1
        "#,
    )
    .bind(workspace_id)
    .fetch_optional(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;
    let Some((workspace_type, owner_user_id)) = workspace else {
        return Err(ApiError::NotFound);
    };

    match body.action {
        AdminWorkspaceMemberRemediationActionDto::Upsert => {
            let role = body.role.as_ref().ok_or_else(|| {
                ApiError::BadRequest("role is required when action=upsert".into())
            })?;
            let current_role: Option<String> = sqlx::query_scalar(
                r#"
                SELECT role
                FROM public.app_workspace_member
                WHERE workspace_id = $1
                  AND user_id = $2
                "#,
            )
            .bind(workspace_id)
            .bind(body.user_id)
            .fetch_optional(pool)
            .await
            .map_err(|e| ApiError::DatabaseError(e.to_string()))?;
            if current_role.as_deref() == Some("owner")
                || owner_user_id.is_some_and(|owner_id| owner_id == body.user_id)
            {
                return Err(ApiError::Conflict(
                    "workspace owner role must use owner-transfer flow".into(),
                ));
            }

            let user_exists: bool =
                sqlx::query_scalar("SELECT EXISTS(SELECT 1 FROM auth.users WHERE id = $1)")
                    .bind(body.user_id)
                    .fetch_one(pool)
                    .await
                    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;
            if !user_exists {
                return Err(ApiError::NotFound);
            }

            let next_role = workspace_member_role_str(role);
            sqlx::query(
                r#"
                INSERT INTO public.app_workspace_member (workspace_id, user_id, role)
                VALUES ($1, $2, $3)
                ON CONFLICT (workspace_id, user_id)
                DO UPDATE SET role = EXCLUDED.role, updated_at = NOW()
                "#,
            )
            .bind(workspace_id)
            .bind(body.user_id)
            .bind(next_role)
            .execute(pool)
            .await
            .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

            append_internal_workspace_governance_audit(
                pool,
                workspace_id,
                "member_upserted_internal",
                json!({
                    "action": "upsert",
                    "targetUserId": body.user_id,
                    "targetRole": current_role,
                    "workspaceType": workspace_type,
                }),
                json!({
                    "action": "upsert",
                    "targetUserId": body.user_id,
                    "targetRole": next_role,
                    "workspaceType": workspace_type,
                }),
            )
            .await?;
        }
        AdminWorkspaceMemberRemediationActionDto::Remove => {
            let current_role: Option<String> = sqlx::query_scalar(
                r#"
                SELECT role
                FROM public.app_workspace_member
                WHERE workspace_id = $1
                  AND user_id = $2
                "#,
            )
            .bind(workspace_id)
            .bind(body.user_id)
            .fetch_optional(pool)
            .await
            .map_err(|e| ApiError::DatabaseError(e.to_string()))?;
            let Some(current_role) = current_role else {
                return Err(ApiError::NotFound);
            };
            if current_role == "owner"
                || owner_user_id.is_some_and(|owner_id| owner_id == body.user_id)
            {
                return Err(ApiError::Conflict(
                    "workspace owner must use owner-transfer flow before removal".into(),
                ));
            }

            let mut tx = pool
                .begin()
                .await
                .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

            sqlx::query(
                r#"
                DELETE FROM public.app_workspace_member
                WHERE workspace_id = $1
                  AND user_id = $2
                "#,
            )
            .bind(workspace_id)
            .bind(body.user_id)
            .execute(&mut *tx)
            .await
            .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

            let pruned_project_acl_count = sqlx::query(
                r#"
                DELETE FROM public.app_project_member pm
                WHERE pm.user_id = $1
                  AND EXISTS (
                    SELECT 1
                    FROM public.app_project p
                    WHERE p.id = pm.project_id
                      AND p.workspace_id = $2
                  )
                "#,
            )
            .bind(body.user_id)
            .bind(workspace_id)
            .execute(&mut *tx)
            .await
            .map_err(|e| ApiError::DatabaseError(e.to_string()))?
            .rows_affected();

            tx.commit()
                .await
                .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

            let current_workspace_reset =
                reset_user_current_workspace_if_matches(pool, body.user_id, workspace_id).await?;

            append_internal_workspace_governance_audit(
                pool,
                workspace_id,
                "member_removed_internal",
                json!({
                    "action": "remove",
                    "targetUserId": body.user_id,
                    "targetRole": current_role,
                    "workspaceType": workspace_type,
                }),
                json!({
                    "action": "remove",
                    "targetUserId": body.user_id,
                    "targetRole": current_role,
                    "workspaceType": workspace_type,
                    "currentWorkspaceReset": current_workspace_reset,
                    "prunedProjectAclCount": pruned_project_acl_count as i64,
                }),
            )
            .await?;
        }
    }

    get_admin_workspace_detail(state, workspace_id).await
}

pub async fn transfer_admin_workspace_owner(
    state: &AppState,
    workspace_id: Uuid,
    body: AdminWorkspaceOwnerTransferBody,
) -> Result<AdminWorkspaceDetailResponse, ApiError> {
    let pool = state.require_pool()?;

    let workspace: Option<(String, Uuid)> = sqlx::query_as(
        r#"
        SELECT workspace_type, owner_user_id
        FROM public.app_workspace
        WHERE id = $1
        "#,
    )
    .bind(workspace_id)
    .fetch_optional(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;
    let Some((workspace_type, owner_user_id)) = workspace else {
        return Err(ApiError::NotFound);
    };

    if workspace_type == "personal" {
        return Err(ApiError::BadRequest(
            "cannot transfer owner of a personal workspace".into(),
        ));
    }
    if body.target_user_id == owner_user_id {
        return Err(ApiError::Conflict(
            "target owner must differ from current owner".into(),
        ));
    }

    let target_role: Option<String> = sqlx::query_scalar(
        r#"
        SELECT role
        FROM public.app_workspace_member
        WHERE workspace_id = $1
          AND user_id = $2
        "#,
    )
    .bind(workspace_id)
    .bind(body.target_user_id)
    .fetch_optional(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;
    let Some(target_previous_role) = target_role else {
        return Err(ApiError::Conflict(
            "target user must already be a workspace member".into(),
        ));
    };

    let mut tx = pool
        .begin()
        .await
        .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    sqlx::query(
        r#"
        UPDATE public.app_workspace_member
        SET role = 'owner', updated_at = NOW()
        WHERE workspace_id = $1
          AND user_id = $2
        "#,
    )
    .bind(workspace_id)
    .bind(body.target_user_id)
    .execute(&mut *tx)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    sqlx::query(
        r#"
        UPDATE public.app_workspace_member
        SET role = 'admin', updated_at = NOW()
        WHERE workspace_id = $1
          AND user_id = $2
        "#,
    )
    .bind(workspace_id)
    .bind(owner_user_id)
    .execute(&mut *tx)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    sqlx::query(
        r#"
        UPDATE public.app_workspace
        SET owner_user_id = $2, updated_at = NOW()
        WHERE id = $1
        "#,
    )
    .bind(workspace_id)
    .bind(body.target_user_id)
    .execute(&mut *tx)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    tx.commit()
        .await
        .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    append_internal_workspace_governance_audit(
        pool,
        workspace_id,
        "owner_transferred_internal",
        json!({
            "previousOwnerUserId": owner_user_id,
            "newOwnerUserId": body.target_user_id,
            "targetPreviousRole": target_previous_role,
            "previousOwnerNewRole": "admin",
            "workspaceType": workspace_type,
        }),
        json!({
            "previousOwnerUserId": owner_user_id,
            "newOwnerUserId": body.target_user_id,
            "targetPreviousRole": target_previous_role,
            "targetRole": "owner",
            "previousOwnerNewRole": "admin",
            "workspaceType": workspace_type,
        }),
    )
    .await?;

    get_admin_workspace_detail(state, workspace_id).await
}

pub async fn get_admin_project_detail(
    state: &AppState,
    project_id: Uuid,
) -> Result<AdminProjectDetailResponse, ApiError> {
    let pool = state.require_pool()?;
    let row = sqlx::query_as::<_, ProjectDetailRow>(
        r#"
        SELECT
          p.id AS project_id,
          p.numeric_id,
          p.name,
          p.owner_user_id,
          owner.email AS owner_email,
          p.workspace_id,
          w.name AS workspace_name,
          w.workspace_type,
          w.archived_at AS workspace_archived_at,
          p.archived_at AS project_archived_at,
          NULLIF(
            BTRIM(COALESCE(p.metadata->'internalOps'->>'opsNote', '')),
            ''
          ) AS ops_note,
          TO_TIMESTAMP(NULLIF(p.create_time_ms, 0) / 1000.0) AT TIME ZONE 'UTC' AS created_at,
          p.update_time AS updated_at,
          (
            SELECT COUNT(*)::bigint
            FROM public.app_script s
            WHERE s.project_id = p.id
          ) AS script_count,
          (
            SELECT COUNT(*)::bigint
            FROM public.app_asset a
            WHERE a.project_id = p.id
          ) AS asset_count,
          (
            SELECT COUNT(*)::bigint
            FROM public.app_generation_job j
            WHERE (j.payload->>'project_uuid') = p.id::text
               OR (
                 (j.payload->>'project_uuid') IS NULL
                 AND (j.payload->>'project_numeric_id') ~ '^[0-9]+$'
                 AND (j.payload->>'project_numeric_id')::int = p.numeric_id
               )
          ) AS job_count,
          (
            SELECT COUNT(*)::bigint
            FROM public.app_generation_job j
            WHERE j.status IN ('queued', 'running')
              AND (
                (j.payload->>'project_uuid') = p.id::text
                OR (
                  (j.payload->>'project_uuid') IS NULL
                  AND (j.payload->>'project_numeric_id') ~ '^[0-9]+$'
                  AND (j.payload->>'project_numeric_id')::int = p.numeric_id
                )
              )
          ) AS active_job_count
        FROM public.app_project p
        LEFT JOIN auth.users owner ON owner.id = p.owner_user_id
        LEFT JOIN public.app_workspace w ON w.id = p.workspace_id
        WHERE p.id = $1
        "#,
    )
    .bind(project_id)
    .fetch_optional(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?
    .ok_or(ApiError::NotFound)?;

    let recent_jobs = sqlx::query_as::<_, JobRow>(
        r#"
        SELECT
          j.id AS job_id,
          j.owner_user_id,
          owner.email AS owner_email,
          j.kind,
          j.status,
          NULLIF(j.payload->>'project_uuid', '')::uuid AS project_id,
          CASE
            WHEN (j.payload->>'project_numeric_id') ~ '^[0-9]+$'
              THEN (j.payload->>'project_numeric_id')::int
            ELSE NULL
          END AS project_numeric_id,
          j.created_at
        FROM public.app_generation_job j
        LEFT JOIN auth.users owner ON owner.id = j.owner_user_id
        WHERE (j.payload->>'project_uuid') = $1::text
           OR (
             (j.payload->>'project_uuid') IS NULL
             AND (j.payload->>'project_numeric_id') ~ '^[0-9]+$'
             AND (j.payload->>'project_numeric_id')::int = $2
           )
        ORDER BY j.created_at DESC
        LIMIT 10
        "#,
    )
    .bind(project_id)
    .bind(row.numeric_id)
    .fetch_all(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?
    .into_iter()
    .map(map_job)
    .collect();

    let acl_members = sqlx::query_as::<_, ProjectAclMemberRow>(
        r#"
        SELECT
          pm.user_id,
          u.email,
          wm.role AS workspace_role,
          pm.role AS project_role,
          pm.created_at,
          pm.updated_at
        FROM public.app_project_member pm
        INNER JOIN public.app_project p ON p.id = pm.project_id
        INNER JOIN public.app_workspace_member wm
          ON wm.workspace_id = p.workspace_id
         AND wm.user_id = pm.user_id
        LEFT JOIN auth.users u ON u.id = pm.user_id
        WHERE pm.project_id = $1
        ORDER BY
          CASE pm.role
            WHEN 'editor' THEN 0
            ELSE 1
          END,
          pm.created_at ASC
        "#,
    )
    .bind(project_id)
    .fetch_all(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?
    .into_iter()
    .map(|row| AdminProjectAclMemberSummary {
        user_id: row.user_id,
        email: row.email,
        workspace_role: row.workspace_role,
        project_role: row.project_role,
        created_at: row.created_at,
        updated_at: row.updated_at,
    })
    .collect::<Vec<_>>();

    let workspace_member_candidates = sqlx::query_as::<_, ProjectWorkspaceMemberCandidateRow>(
        r#"
        SELECT
          wm.user_id,
          u.email,
          wm.role AS workspace_role,
          pm.role AS explicit_project_role
        FROM public.app_project p
        INNER JOIN public.app_workspace_member wm ON wm.workspace_id = p.workspace_id
        LEFT JOIN public.app_project_member pm
          ON pm.project_id = p.id
         AND pm.user_id = wm.user_id
        LEFT JOIN auth.users u ON u.id = wm.user_id
        WHERE p.id = $1
        ORDER BY
          CASE wm.role
            WHEN 'owner' THEN 0
            WHEN 'admin' THEN 1
            ELSE 2
          END,
          u.email ASC NULLS LAST,
          wm.user_id ASC
        LIMIT 40
        "#,
    )
    .bind(project_id)
    .fetch_all(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?
    .into_iter()
    .map(|row| AdminProjectWorkspaceMemberCandidateSummary {
        user_id: row.user_id,
        email: row.email,
        workspace_role: row.workspace_role,
        explicit_project_role: row.explicit_project_role,
    })
    .collect::<Vec<_>>();

    let explicit_acl_count = acl_members.len() as i64;
    let editor_count = acl_members
        .iter()
        .filter(|member| member.project_role == "editor")
        .count() as i64;
    let viewer_count = acl_members
        .iter()
        .filter(|member| member.project_role == "viewer")
        .count() as i64;
    let project_acl_mode = if explicit_acl_count > 0 {
        "restricted".to_string()
    } else {
        "inherited".to_string()
    };

    let governance_audit = sqlx::query_as::<_, GovernanceAuditRow>(
        r#"
        SELECT
          id AS audit_id,
          actor_label,
          created_at,
          previous_state,
          next_state
        FROM public.app_project_governance_audit
        WHERE project_id = $1
        ORDER BY created_at DESC
        LIMIT 10
        "#,
    )
    .bind(project_id)
    .fetch_all(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?
    .into_iter()
    .map(|audit| AdminProjectGovernanceAuditSummary {
        audit_id: audit.audit_id,
        actor_label: audit.actor_label,
        created_at: audit.created_at,
        previous_state: audit.previous_state,
        next_state: audit.next_state,
    })
    .collect();

    Ok(AdminProjectDetailResponse {
        project_id: row.project_id,
        numeric_id: row.numeric_id,
        name: row.name,
        owner_user_id: row.owner_user_id,
        owner_email: row.owner_email,
        workspace: row.workspace_id.map(|workspace_id| AdminWorkspaceRef {
            workspace_id,
            name: row
                .workspace_name
                .unwrap_or_else(|| "Unknown Workspace".into()),
            workspace_type: row.workspace_type.unwrap_or_else(|| "unknown".into()),
            archived_at: row.workspace_archived_at,
        }),
        archived_at: row.project_archived_at,
        ops_note: row.ops_note,
        created_at: row.created_at,
        updated_at: row.updated_at,
        script_count: row.script_count,
        asset_count: row.asset_count,
        job_count: row.job_count,
        active_job_count: row.active_job_count,
        project_acl_mode,
        explicit_acl_count,
        editor_count,
        viewer_count,
        acl_members,
        workspace_member_candidates,
        recent_jobs,
        governance_audit,
    })
}

pub async fn update_admin_project_governance(
    state: &AppState,
    project_id: Uuid,
    body: AdminProjectGovernanceUpdateBody,
) -> Result<AdminProjectDetailResponse, ApiError> {
    let pool = state.require_pool()?;

    let cur = sqlx::query_as::<_, ProjectGovernanceCurrentRow>(
        r#"
        SELECT archived_at, metadata
        FROM public.app_project
        WHERE id = $1
        "#,
    )
    .bind(project_id)
    .fetch_optional(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?
    .ok_or(ApiError::NotFound)?;

    let next_archived = match body.project_lifecycle {
        AdminWorkspaceLifecycleActionDto::Preserve => cur.archived_at,
        AdminWorkspaceLifecycleActionDto::Archive => match cur.archived_at {
            Some(ts) => Some(ts),
            None => Some(Utc::now()),
        },
        AdminWorkspaceLifecycleActionDto::Restore => None,
    };

    let current_ops = internal_ops_note_from_metadata(&cur.metadata);

    let next_ops: Option<String> = match body.ops_note_action {
        AdminWorkspaceOpsNoteActionDto::Preserve => current_ops.clone(),
        AdminWorkspaceOpsNoteActionDto::Clear => None,
        AdminWorkspaceOpsNoteActionDto::Set => {
            let normalized = normalize_optional_text(body.ops_note.clone());
            if normalized.is_none() {
                return Err(ApiError::BadRequest(
                    "opsNote is required when opsNoteAction is set".into(),
                ));
            }
            normalized
        }
    };

    let meta_changed = match body.ops_note_action {
        AdminWorkspaceOpsNoteActionDto::Preserve => false,
        AdminWorkspaceOpsNoteActionDto::Clear => current_ops.is_some(),
        AdminWorkspaceOpsNoteActionDto::Set => next_ops != current_ops,
    };

    let archived_changed = next_archived != cur.archived_at;

    if !meta_changed && !archived_changed {
        return Err(ApiError::BadRequest(
            "no governance changes requested".into(),
        ));
    }

    let next_metadata = if meta_changed {
        apply_internal_ops_note_to_metadata(cur.metadata.clone(), next_ops.as_deref())
    } else {
        cur.metadata.clone()
    };

    sqlx::query(
        r#"
        UPDATE public.app_project
        SET
          archived_at = $1,
          metadata = $2,
          updated_at = NOW()
        WHERE id = $3
        "#,
    )
    .bind(next_archived)
    .bind(next_metadata)
    .bind(project_id)
    .execute(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    sqlx::query(
        r#"
        INSERT INTO public.app_project_governance_audit (
          project_id,
          event_type,
          actor_label,
          previous_state,
          next_state
        )
        VALUES ($1, 'governance_updated', 'internal_ops', $2, $3)
        "#,
    )
    .bind(project_id)
    .bind(json!({
        "archivedAt": cur.archived_at,
        "opsNote": current_ops,
    }))
    .bind(json!({
        "archivedAt": next_archived,
        "opsNote": next_ops,
    }))
    .execute(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    get_admin_project_detail(state, project_id).await
}

#[allow(dead_code)]
pub async fn update_admin_project_batch_governance(
    state: &AppState,
    body: super::types::AdminProjectBatchGovernanceUpdateBody,
) -> Result<super::types::AdminProjectBatchGovernanceResponse, ApiError> {
    let _pool = state.require_pool()?;
    let requested_count = body.project_ids.len() as i64;
    if body.project_ids.is_empty() {
        return Err(ApiError::BadRequest("projectIds must not be empty".into()));
    }
    if body.project_ids.len() > 50 {
        return Err(ApiError::BadRequest(
            "projectIds must not contain more than 50 items".into(),
        ));
    }

    let next_ops = match body.ops_note_action {
        AdminWorkspaceOpsNoteActionDto::Preserve => None,
        AdminWorkspaceOpsNoteActionDto::Clear => Some(None),
        AdminWorkspaceOpsNoteActionDto::Set => {
            let normalized = normalize_optional_text(body.ops_note.clone());
            if normalized.is_none() {
                return Err(ApiError::BadRequest(
                    "opsNote is required when opsNoteAction is set".into(),
                ));
            }
            Some(normalized)
        }
    };

    let mut updated_ids = Vec::new();
    for project_id in &body.project_ids {
        let detail = update_admin_project_governance(
            state,
            *project_id,
            AdminProjectGovernanceUpdateBody {
                project_lifecycle: body.project_lifecycle.clone(),
                ops_note_action: body.ops_note_action.clone(),
                ops_note: next_ops.clone().flatten(),
            },
        )
        .await;

        match detail {
            Ok(_) => updated_ids.push(*project_id),
            Err(ApiError::BadRequest(message)) if message == "no governance changes requested" => {}
            Err(error) => return Err(error),
        }
    }

    let mut projects = Vec::new();
    for project_id in &updated_ids {
        projects.push(get_admin_project_detail(state, *project_id).await?);
    }

    Ok(super::types::AdminProjectBatchGovernanceResponse {
        requested_count,
        updated_count: updated_ids.len() as i64,
        projects,
    })
}

pub async fn transfer_admin_project_owner(
    state: &AppState,
    project_id: Uuid,
    body: AdminProjectOwnerTransferBody,
) -> Result<AdminProjectDetailResponse, ApiError> {
    let pool = state.require_pool()?;

    let project: Option<(Uuid, Uuid)> = sqlx::query_as(
        r#"
        SELECT workspace_id, owner_user_id
        FROM public.app_project
        WHERE id = $1
        "#,
    )
    .bind(project_id)
    .fetch_optional(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;
    let Some((workspace_id, owner_user_id)) = project else {
        return Err(ApiError::NotFound);
    };

    if body.target_user_id == owner_user_id {
        return Err(ApiError::Conflict(
            "target owner must differ from current owner".into(),
        ));
    }

    let target_workspace_role: Option<String> = sqlx::query_scalar(
        r#"
        SELECT role
        FROM public.app_workspace_member
        WHERE workspace_id = $1
          AND user_id = $2
        "#,
    )
    .bind(workspace_id)
    .bind(body.target_user_id)
    .fetch_optional(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;
    let Some(target_workspace_role) = target_workspace_role else {
        return Err(ApiError::Conflict(
            "target user must already be a workspace member".into(),
        ));
    };

    let target_previous_project_role: Option<String> = sqlx::query_scalar(
        r#"
        SELECT role
        FROM public.app_project_member
        WHERE project_id = $1
          AND user_id = $2
        "#,
    )
    .bind(project_id)
    .bind(body.target_user_id)
    .fetch_optional(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    let previous_owner_workspace_role: Option<String> = sqlx::query_scalar(
        r#"
        SELECT role
        FROM public.app_workspace_member
        WHERE workspace_id = $1
          AND user_id = $2
        "#,
    )
    .bind(workspace_id)
    .bind(owner_user_id)
    .fetch_optional(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    let project_acl_enabled: bool = sqlx::query_scalar(
        r#"
        SELECT EXISTS(
          SELECT 1
          FROM public.app_project_member
          WHERE project_id = $1
        )
        "#,
    )
    .bind(project_id)
    .fetch_one(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    let mut tx = pool
        .begin()
        .await
        .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    sqlx::query(
        r#"
        UPDATE public.app_project
        SET owner_user_id = $2, updated_at = NOW()
        WHERE id = $1
        "#,
    )
    .bind(project_id)
    .bind(body.target_user_id)
    .execute(&mut *tx)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    let removed_target_acl_count = sqlx::query(
        r#"
        DELETE FROM public.app_project_member
        WHERE project_id = $1
          AND user_id = $2
        "#,
    )
    .bind(project_id)
    .bind(body.target_user_id)
    .execute(&mut *tx)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?
    .rows_affected();

    let preserved_previous_owner_acl = if project_acl_enabled
        && matches!(previous_owner_workspace_role.as_deref(), Some("member"))
    {
        sqlx::query(
            r#"
            INSERT INTO public.app_project_member (project_id, user_id, role)
            VALUES ($1, $2, 'editor')
            ON CONFLICT (project_id, user_id)
            DO UPDATE SET role = EXCLUDED.role, updated_at = NOW()
            "#,
        )
        .bind(project_id)
        .bind(owner_user_id)
        .execute(&mut *tx)
        .await
        .map_err(|e| ApiError::DatabaseError(e.to_string()))?;
        true
    } else {
        false
    };

    tx.commit()
        .await
        .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    sqlx::query(
        r#"
        INSERT INTO public.app_project_governance_audit (
          project_id,
          event_type,
          actor_label,
          previous_state,
          next_state
        )
        VALUES ($1, 'owner_transferred_internal', 'internal_ops', $2, $3)
        "#,
    )
    .bind(project_id)
    .bind(json!({
        "previousOwnerUserId": owner_user_id,
        "newOwnerUserId": body.target_user_id,
        "targetWorkspaceRole": target_workspace_role,
        "targetPreviousProjectRole": target_previous_project_role,
        "projectAclEnabled": project_acl_enabled,
    }))
    .bind(json!({
        "previousOwnerUserId": owner_user_id,
        "newOwnerUserId": body.target_user_id,
        "targetWorkspaceRole": target_workspace_role,
        "targetPreviousProjectRole": target_previous_project_role,
        "projectAclEnabled": project_acl_enabled,
        "removedTargetProjectAclCount": removed_target_acl_count as i64,
        "preservedPreviousOwnerEditorAccess": preserved_previous_owner_acl,
    }))
    .execute(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    get_admin_project_detail(state, project_id).await
}

pub async fn update_admin_user_governance(
    state: &AppState,
    user_id: Uuid,
    body: AdminUserGovernanceUpdateBody,
) -> Result<AdminUserDetailResponse, ApiError> {
    let pool = state.require_pool()?;
    let current = get_admin_user_detail(state, user_id).await?;
    let next_operational_status = operational_status_str(&body.operational_status).to_string();
    let next_daily_job_quota =
        resolve_daily_job_quota_override(current.daily_job_quota_override, &body)?;
    let next_reason = normalize_optional_text(body.operational_status_reason);
    let next_ops_note = normalize_optional_text(body.ops_note);

    if next_operational_status == "active" && next_reason.is_some() {
        return Err(ApiError::BadRequest(
            "operationalStatusReason is only allowed when status=suspended".into(),
        ));
    }
    if next_operational_status == "suspended" && next_reason.is_none() {
        return Err(ApiError::BadRequest(
            "operationalStatusReason is required when status=suspended".into(),
        ));
    }

    sqlx::query(
        r#"
        INSERT INTO public.app_user_profile (
          user_id,
          operational_status,
          operational_status_reason,
          ops_note,
          daily_job_quota,
          ops_updated_at,
          updated_at
        )
        VALUES ($1, $2, $3, $4, $5, NOW(), NOW())
        ON CONFLICT (user_id) DO UPDATE
        SET
          operational_status = EXCLUDED.operational_status,
          operational_status_reason = EXCLUDED.operational_status_reason,
          ops_note = EXCLUDED.ops_note,
          daily_job_quota = EXCLUDED.daily_job_quota,
          ops_updated_at = NOW(),
          updated_at = NOW()
        "#,
    )
    .bind(user_id)
    .bind(&next_operational_status)
    .bind(next_reason.clone())
    .bind(next_ops_note.clone())
    .bind(next_daily_job_quota)
    .execute(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    sqlx::query(
        r#"
        INSERT INTO public.app_user_governance_audit (
          user_id,
          event_type,
          actor_label,
          previous_state,
          next_state
        )
        VALUES ($1, 'governance_updated', 'internal_ops', $2, $3)
        "#,
    )
    .bind(user_id)
    .bind(json!({
        "operationalStatus": current.operational_status,
        "operationalStatusReason": current.operational_status_reason,
        "opsNote": current.ops_note,
        "dailyJobQuotaOverride": current.daily_job_quota_override,
    }))
    .bind(json!({
        "operationalStatus": next_operational_status,
        "operationalStatusReason": next_reason,
        "opsNote": next_ops_note,
        "dailyJobQuotaOverride": next_daily_job_quota,
    }))
    .execute(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    get_admin_user_detail(state, user_id).await
}

pub async fn update_admin_user_workspace_context(
    state: &AppState,
    user_id: Uuid,
    body: AdminUserWorkspaceContextUpdateBody,
) -> Result<AdminUserDetailResponse, ApiError> {
    let pool = state.require_pool()?;
    let _ = get_admin_user_detail(state, user_id).await?;

    let next_workspace_id = match body.action {
        AdminUserWorkspaceContextActionDto::ResetToPersonal => {
            let personal = ensure_personal_workspace(pool, user_id).await?;
            personal.workspace_id
        }
        AdminUserWorkspaceContextActionDto::SetToWorkspace => {
            let workspace_id = body.workspace_id.ok_or_else(|| {
                ApiError::BadRequest("workspaceId is required when action=set_to_workspace".into())
            })?;
            let row: Option<(Option<DateTime<Utc>>,)> = sqlx::query_as(
                r#"
                SELECT w.archived_at
                FROM public.app_workspace w
                INNER JOIN public.app_workspace_member m
                  ON m.workspace_id = w.id
                WHERE w.id = $1
                  AND m.user_id = $2
                LIMIT 1
                "#,
            )
            .bind(workspace_id)
            .bind(user_id)
            .fetch_optional(pool)
            .await
            .map_err(|e| ApiError::DatabaseError(e.to_string()))?;
            let Some((archived_at,)) = row else {
                return Err(ApiError::BadRequest(
                    "user must still be a member of workspaceId".into(),
                ));
            };
            if archived_at.is_some() {
                return Err(ApiError::BadRequest(
                    "cannot switch current workspace to an archived workspace".into(),
                ));
            }
            workspace_id
        }
    };

    sqlx::query(
        r#"
        INSERT INTO public.app_user_profile (user_id, current_workspace_id, updated_at)
        VALUES ($1, $2, NOW())
        ON CONFLICT (user_id) DO UPDATE
        SET
          current_workspace_id = EXCLUDED.current_workspace_id,
          updated_at = NOW()
        "#,
    )
    .bind(user_id)
    .bind(next_workspace_id)
    .execute(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    get_admin_user_detail(state, user_id).await
}
