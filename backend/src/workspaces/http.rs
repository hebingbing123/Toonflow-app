use axum::{
    extract::{Path, Query, State},
    http::HeaderMap,
    routing::{delete, get, post},
    Json, Router,
};
use serde::{Deserialize, Serialize};
use serde_json::Value;
use sqlx::{FromRow, PgPool};
use utoipa::{IntoParams, ToSchema};
use uuid::Uuid;

use crate::auth::require_user_uuid;
use crate::error::ApiError;
use crate::settings::notifications::{record_notification, NotificationRecordPayload};
use crate::state::AppState;

#[derive(Debug, Clone, Serialize, ToSchema)]
pub struct WorkspaceResponse {
    pub id: Uuid,
    pub owner_user_id: Uuid,
    pub name: String,
    pub workspace_type: String,
    pub metadata: Value,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub archived_at: Option<chrono::DateTime<chrono::Utc>>,
    pub created_at: chrono::DateTime<chrono::Utc>,
    pub updated_at: chrono::DateTime<chrono::Utc>,
}

#[derive(Debug, Clone, Serialize, ToSchema)]
pub struct WorkspaceListItem {
    #[serde(flatten)]
    pub workspace: WorkspaceResponse,
    pub role: String,
}

#[derive(Debug, Deserialize, ToSchema)]
#[serde(deny_unknown_fields)]
pub struct CreateWorkspaceBody {
    pub name: String,
    #[serde(default)]
    pub metadata: Option<Value>,
}

#[derive(Debug, Deserialize, ToSchema)]
#[serde(deny_unknown_fields)]
pub struct PatchWorkspaceBody {
    #[serde(default)]
    pub name: Option<String>,
    #[serde(default)]
    pub metadata: Option<Value>,
    /// Archive (**`true`**) or restore (**`false`**) an **enterprise** workspace. Omit for no change.
    #[serde(default)]
    pub archive: Option<bool>,
}

#[derive(Debug, Deserialize, ToSchema)]
#[serde(deny_unknown_fields)]
pub struct AddWorkspaceMemberBody {
    pub user_id: Uuid,
    /// Allowed: **`admin`** or **`member`**. (`owner` requires dedicated transfer flow.)
    pub role: String,
}

#[derive(Debug, Deserialize, ToSchema)]
#[serde(deny_unknown_fields)]
pub struct PatchWorkspaceMemberBody {
    /// Allowed: **`admin`** or **`member`**. (`owner` requires dedicated transfer flow.)
    pub role: String,
}

#[derive(Debug, Deserialize, ToSchema)]
#[serde(deny_unknown_fields)]
pub struct TransferWorkspaceOwnerBody {
    pub target_user_id: Uuid,
}

#[derive(Debug, Clone, Serialize, ToSchema, FromRow)]
pub struct WorkspaceMemberResponse {
    pub workspace_id: Uuid,
    pub user_id: Uuid,
    pub role: String,
    pub created_at: chrono::DateTime<chrono::Utc>,
    pub updated_at: chrono::DateTime<chrono::Utc>,
}

#[derive(Debug, Deserialize, IntoParams)]
#[into_params(parameter_in = Query)]
pub struct ListWorkspaceInvitesQuery {
    /// Filter by **`status`** (`pending`, `accepted`, `revoked`).
    #[serde(default)]
    #[param(example = "pending")]
    pub status: Option<String>,
    /// Max rows (**1–200**, default **50**).
    #[serde(default)]
    #[param(example = 50)]
    pub limit: Option<i64>,
    /// Pagination offset (default **0**).
    #[serde(default)]
    #[param(example = 0)]
    pub offset: Option<i64>,
    /// When **false** (default), rows with **`status = revoked`** are omitted unless **`status=revoked`** is set explicitly.
    #[serde(default)]
    #[param(example = false)]
    pub include_revoked: bool,
}

#[derive(Debug, Serialize, ToSchema)]
pub struct ListWorkspaceInvitesEnvelope {
    pub items: Vec<WorkspaceInviteResponse>,
    pub has_more: bool,
}

#[derive(Debug, Clone, Serialize, ToSchema, FromRow)]
pub struct WorkspaceAuditResponse {
    pub id: i64,
    pub workspace_id: Uuid,
    pub actor_user_id: Uuid,
    pub action: String,
    pub target_user_id: Option<Uuid>,
    pub details: Value,
    pub created_at: chrono::DateTime<chrono::Utc>,
}

#[derive(Debug, Deserialize, IntoParams, ToSchema)]
#[into_params(parameter_in = Query)]
pub struct ListWorkspaceAuditQuery {
    /// Filter by exact action name (for example `workspace_member_upserted`).
    #[serde(default)]
    #[param(example = "workspace_invite_created")]
    pub action: Option<String>,
    /// Max rows (**1–200**, default **50**).
    #[serde(default)]
    #[param(example = 50)]
    pub limit: Option<i64>,
    /// Pagination offset (default **0**).
    #[serde(default)]
    #[param(example = 0)]
    pub offset: Option<i64>,
}

#[derive(Debug, Serialize, ToSchema)]
pub struct ListWorkspaceAuditEnvelope {
    pub items: Vec<WorkspaceAuditResponse>,
    pub has_more: bool,
}

#[derive(Debug, Default, Deserialize, ToSchema)]
#[serde(deny_unknown_fields)]
pub struct ResendWorkspaceInviteBody {
    /// New expiry window in hours (default **168**, max **720**), same rules as create.
    #[serde(default)]
    pub expires_in_hours: Option<i64>,
}

#[derive(Debug, Deserialize, ToSchema)]
#[serde(deny_unknown_fields)]
pub struct CreateWorkspaceInviteBody {
    pub email: String,
    /// Allowed: **`admin`** or **`member`**.
    pub role: String,
    /// Invite expiry window in hours (default **168** = 7d, max **720** = 30d).
    #[serde(default)]
    pub expires_in_hours: Option<i64>,
}

#[derive(Debug, Deserialize, ToSchema)]
#[serde(deny_unknown_fields)]
pub struct AcceptWorkspaceInviteBody {
    pub token: String,
}

#[derive(Debug, Clone, Serialize, ToSchema, FromRow)]
pub struct WorkspaceInviteResponse {
    pub id: Uuid,
    pub workspace_id: Uuid,
    pub email: String,
    pub token: String,
    pub role: String,
    pub invited_by: Uuid,
    pub status: String,
    pub expires_at: chrono::DateTime<chrono::Utc>,
    pub accepted_by: Option<Uuid>,
    pub accepted_at: Option<chrono::DateTime<chrono::Utc>>,
    pub created_at: chrono::DateTime<chrono::Utc>,
    pub updated_at: chrono::DateTime<chrono::Utc>,
}

#[derive(Debug, Deserialize, IntoParams)]
#[into_params(parameter_in = Query)]
pub struct ListWorkspacesQuery {
    /// Include rows with **`archived_at`** set (default **false**).
    #[serde(default)]
    #[param(example = false)]
    pub include_archived: bool,
}

#[derive(Debug, Clone, FromRow)]
struct WorkspaceRow {
    id: Uuid,
    owner_user_id: Uuid,
    name: String,
    workspace_type: String,
    metadata: Value,
    archived_at: Option<chrono::DateTime<chrono::Utc>>,
    created_at: chrono::DateTime<chrono::Utc>,
    updated_at: chrono::DateTime<chrono::Utc>,
}

#[derive(Debug, Clone, FromRow)]
struct WorkspaceListRow {
    #[sqlx(flatten)]
    workspace: WorkspaceRow,
    role: String,
}

pub(crate) fn router() -> Router<AppState> {
    Router::new()
        .route(
            "/api/v1/workspaces",
            get(list_workspaces).post(create_workspace),
        )
        .route(
            "/api/v1/workspaces/{workspace_id}",
            get(get_workspace).patch(patch_workspace),
        )
        .route(
            "/api/v1/workspaces/{workspace_id}/members",
            get(list_workspace_members).post(add_workspace_member),
        )
        .route(
            "/api/v1/workspaces/{workspace_id}/members/{user_id}",
            axum::routing::patch(patch_workspace_member).delete(remove_workspace_member),
        )
        .route(
            "/api/v1/workspaces/{workspace_id}/members/me",
            axum::routing::delete(leave_workspace),
        )
        .route(
            "/api/v1/workspaces/{workspace_id}/owner-transfer",
            post(transfer_workspace_owner),
        )
        .route(
            "/api/v1/workspaces/{workspace_id}/audit",
            get(list_workspace_audit),
        )
        .route(
            "/api/v1/workspaces/{workspace_id}/invites/{invite_id}/resend",
            post(resend_workspace_invite),
        )
        .route(
            "/api/v1/workspaces/{workspace_id}/invites/{invite_id}",
            delete(revoke_workspace_invite),
        )
        .route(
            "/api/v1/workspaces/{workspace_id}/invites",
            get(list_workspace_invites).post(create_workspace_invite),
        )
        .route(
            "/api/v1/workspaces/invites/accept",
            post(accept_workspace_invite),
        )
}

async fn require_workspace_member_role(
    pool: &PgPool,
    user_id: Uuid,
    workspace_id: Uuid,
) -> Result<String, ApiError> {
    sqlx::query_scalar(
        r#"
        SELECT role
        FROM public.app_workspace_member
        WHERE workspace_id = $1 AND user_id = $2
        "#,
    )
    .bind(workspace_id)
    .bind(user_id)
    .fetch_optional(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?
    .ok_or_else(|| ApiError::Forbidden("not a workspace member".into()))
}

async fn require_workspace_admin_or_owner(
    pool: &PgPool,
    user_id: Uuid,
    workspace_id: Uuid,
) -> Result<(), ApiError> {
    let role = require_workspace_member_role(pool, user_id, workspace_id).await?;
    if role == "owner" || role == "admin" {
        Ok(())
    } else {
        Err(ApiError::Forbidden(
            "requires workspace owner or admin".into(),
        ))
    }
}

async fn require_workspace_owner(
    pool: &PgPool,
    user_id: Uuid,
    workspace_id: Uuid,
) -> Result<(), ApiError> {
    let role = require_workspace_member_role(pool, user_id, workspace_id).await?;
    if role == "owner" {
        Ok(())
    } else {
        Err(ApiError::Forbidden("requires workspace owner".into()))
    }
}

fn normalize_member_role(role: &str) -> Option<&'static str> {
    let v = role.trim().to_ascii_lowercase();
    match v.as_str() {
        "admin" => Some("admin"),
        "member" => Some("member"),
        _ => None,
    }
}

fn parse_invite_expires_hours(expires_in_hours: Option<i64>) -> Result<i64, ApiError> {
    let hours = expires_in_hours.unwrap_or(168);
    if !(1..=720).contains(&hours) {
        return Err(ApiError::BadRequest(
            "expires_in_hours must be between 1 and 720".into(),
        ));
    }
    Ok(hours)
}

async fn count_workspace_owners(pool: &PgPool, workspace_id: Uuid) -> Result<i64, ApiError> {
    let n: i64 = sqlx::query_scalar(
        r#"
        SELECT COUNT(*)::bigint
        FROM public.app_workspace_member
        WHERE workspace_id = $1 AND role = 'owner'
        "#,
    )
    .bind(workspace_id)
    .fetch_one(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;
    Ok(n)
}

async fn append_workspace_audit(
    pool: &PgPool,
    workspace_id: Uuid,
    actor_user_id: Uuid,
    action: &str,
    target_user_id: Option<Uuid>,
    details: Value,
) -> Result<(), ApiError> {
    sqlx::query(
        r#"
        INSERT INTO public.app_workspace_audit (
          workspace_id, actor_user_id, action, target_user_id, details
        )
        VALUES ($1, $2, $3, $4, $5)
        "#,
    )
    .bind(workspace_id)
    .bind(actor_user_id)
    .bind(action)
    .bind(target_user_id)
    .bind(details)
    .execute(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;
    Ok(())
}

async fn load_workspace_name(pool: &PgPool, workspace_id: Uuid) -> Result<String, ApiError> {
    sqlx::query_scalar(
        r#"
        SELECT name
        FROM public.app_workspace
        WHERE id = $1
        "#,
    )
    .bind(workspace_id)
    .fetch_one(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))
}

#[allow(clippy::too_many_arguments)]
async fn record_workspace_invite_notification(
    state: &AppState,
    user_id: Uuid,
    workspace_id: Uuid,
    workspace_name: &str,
    notification_type: &str,
    title: String,
    message: String,
    payload: Value,
) -> Result<(), ApiError> {
    record_notification(
        state.require_pool()?,
        Some(&state.notify),
        NotificationRecordPayload {
            user_id,
            workspace_id: Some(workspace_id),
            project_id: None,
            project_numeric_id: None,
            job_id: None,
            notification_type: notification_type.to_string(),
            title,
            message,
            link_path: Some(format!(
                "/product/team-workspaces?workspaceId={workspace_id}"
            )),
            payload,
            file_path: None,
            changed_at: None,
        },
    )
    .await?;
    tracing::debug!(
        user_id = %user_id,
        workspace_id = %workspace_id,
        workspace_name = workspace_name,
        notification_type,
        "workspace invite notification recorded"
    );
    Ok(())
}

fn max_enterprise_workspaces_per_user() -> i64 {
    std::env::var("TOONFLOW_MAX_ENTERPRISE_WORKSPACES_PER_USER")
        .ok()
        .and_then(|s| s.trim().parse::<i64>().ok())
        .filter(|n| *n > 0)
        .unwrap_or(50)
}

fn max_workspace_member_mutations_per_hour() -> i64 {
    std::env::var("TOONFLOW_WORKSPACE_MEMBER_MUTATIONS_PER_HOUR")
        .ok()
        .and_then(|s| s.trim().parse::<i64>().ok())
        .filter(|n| *n > 0)
        .unwrap_or(120)
}

async fn guard_workspace_member_mutation_rate(
    pool: &PgPool,
    workspace_id: Uuid,
) -> Result<(), ApiError> {
    let cap = max_workspace_member_mutations_per_hour();
    let used: i64 = sqlx::query_scalar(
        r#"
        SELECT COUNT(*)::bigint
        FROM public.app_workspace_audit
        WHERE workspace_id = $1
          AND action IN (
            'workspace_member_upserted',
            'workspace_owner_transferred',
            'workspace_invite_created',
            'workspace_invite_resent',
            'workspace_invite_revoked'
          )
          AND created_at >= NOW() - INTERVAL '1 hour'
        "#,
    )
    .bind(workspace_id)
    .fetch_one(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;
    if used >= cap {
        return Err(ApiError::QuotaExceeded(format!(
            "workspace member/invite mutations exceed {cap} per hour (set TOONFLOW_WORKSPACE_MEMBER_MUTATIONS_PER_HOUR)"
        )));
    }
    Ok(())
}

async fn count_owned_active_enterprise(
    pool: &PgPool,
    owner_user_id: Uuid,
) -> Result<i64, ApiError> {
    let n: i64 = sqlx::query_scalar(
        r#"
        SELECT COUNT(*)::bigint
        FROM public.app_workspace
        WHERE owner_user_id = $1
          AND workspace_type = 'enterprise'
          AND archived_at IS NULL
        "#,
    )
    .bind(owner_user_id)
    .fetch_one(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;
    Ok(n)
}

/// If **`current_workspace_id`** points at **`workspace_id`**, move context to the user's personal workspace.
async fn reset_current_workspace_if_matches(
    pool: &PgPool,
    user_id: Uuid,
    workspace_id: Uuid,
) -> Result<(), ApiError> {
    sqlx::query(
        r#"
        UPDATE public.app_user_profile p
        SET
          current_workspace_id = sub.id,
          updated_at = NOW()
        FROM (
          SELECT id
          FROM public.app_workspace
          WHERE owner_user_id = $1
            AND workspace_type = 'personal'
          ORDER BY created_at ASC, id ASC
          LIMIT 1
        ) AS sub
        WHERE p.user_id = $1
          AND p.current_workspace_id = $2
        "#,
    )
    .bind(user_id)
    .bind(workspace_id)
    .execute(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;
    Ok(())
}

#[utoipa::path(
    post,
    path = "/api/v1/workspaces",
    operation_id = "createWorkspaceV1",
    tag = "workspaces",
    request_body(content = CreateWorkspaceBody, content_type = "application/json"),
    responses(
        (status = 200, description = "OK", body = WorkspaceResponse),
        (status = 400, description = "Bad request", body = crate::error::ErrorBody),
        (status = 401, description = "Unauthorized", body = crate::error::ErrorBody),
        (status = 403, description = "Forbidden", body = crate::error::ErrorBody),
        (status = 429, description = "Quota exceeded", body = crate::error::ErrorBody),
        (status = 503, description = "Unavailable", body = crate::error::ErrorBody)
    ),
    security(("bearerAuth" = []))
)]
pub(crate) async fn create_workspace(
    State(state): State<AppState>,
    headers: HeaderMap,
    Json(body): Json<CreateWorkspaceBody>,
) -> Result<Json<WorkspaceResponse>, ApiError> {
    let uid = require_user_uuid(&state, &headers)?;
    let pool = state.require_pool()?;
    let name = body.name.trim();
    if name.is_empty() {
        return Err(ApiError::BadRequest("name must not be empty".into()));
    }
    if name.len() > 120 {
        return Err(ApiError::BadRequest(
            "name must be at most 120 chars".into(),
        ));
    }
    let metadata = body
        .metadata
        .unwrap_or_else(|| Value::Object(Default::default()));
    if !metadata.is_object() {
        return Err(ApiError::BadRequest("metadata must be an object".into()));
    }

    let cap = max_enterprise_workspaces_per_user();
    let n = count_owned_active_enterprise(pool, uid).await?;
    if n >= cap {
        return Err(ApiError::QuotaExceeded(format!(
            "at most {cap} active enterprise workspace(s) per user (set TOONFLOW_MAX_ENTERPRISE_WORKSPACES_PER_USER)"
        )));
    }

    let mut tx = pool
        .begin()
        .await
        .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    let row: WorkspaceRow = sqlx::query_as(
        r#"
        INSERT INTO public.app_workspace (owner_user_id, name, workspace_type, metadata)
        VALUES ($1, $2, 'enterprise', $3)
        RETURNING id, owner_user_id, name, workspace_type, metadata, archived_at, created_at, updated_at
        "#,
    )
    .bind(uid)
    .bind(name)
    .bind(metadata)
    .fetch_one(&mut *tx)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    sqlx::query(
        r#"
        INSERT INTO public.app_workspace_member (workspace_id, user_id, role)
        VALUES ($1, $2, 'owner')
        ON CONFLICT (workspace_id, user_id) DO NOTHING
        "#,
    )
    .bind(row.id)
    .bind(uid)
    .execute(&mut *tx)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    tx.commit()
        .await
        .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    Ok(Json(WorkspaceResponse {
        id: row.id,
        owner_user_id: row.owner_user_id,
        name: row.name,
        workspace_type: row.workspace_type,
        metadata: row.metadata,
        archived_at: row.archived_at,
        created_at: row.created_at,
        updated_at: row.updated_at,
    }))
}

#[utoipa::path(
    get,
    path = "/api/v1/workspaces",
    operation_id = "listWorkspacesV1",
    tag = "workspaces",
    params(ListWorkspacesQuery),
    responses(
        (status = 200, description = "OK", body = [WorkspaceListItem]),
        (status = 401, description = "Unauthorized", body = crate::error::ErrorBody),
        (status = 503, description = "Unavailable", body = crate::error::ErrorBody)
    ),
    security(("bearerAuth" = []))
)]
pub(crate) async fn list_workspaces(
    State(state): State<AppState>,
    headers: HeaderMap,
    Query(query): Query<ListWorkspacesQuery>,
) -> Result<Json<Vec<WorkspaceListItem>>, ApiError> {
    let uid = require_user_uuid(&state, &headers)?;
    let pool = state.require_pool()?;

    let rows: Vec<WorkspaceListRow> = sqlx::query_as(
        r#"
        SELECT
          w.id,
          w.owner_user_id,
          w.name,
          w.workspace_type,
          w.metadata,
          w.archived_at,
          w.created_at,
          w.updated_at,
          m.role
        FROM public.app_workspace_member m
        INNER JOIN public.app_workspace w ON w.id = m.workspace_id
        WHERE m.user_id = $1
          AND ($2 OR w.archived_at IS NULL)
        ORDER BY (w.workspace_type = 'personal') DESC, w.created_at ASC, w.id ASC
        "#,
    )
    .bind(uid)
    .bind(query.include_archived)
    .fetch_all(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    let items = rows
        .into_iter()
        .map(|row| WorkspaceListItem {
            workspace: WorkspaceResponse {
                id: row.workspace.id,
                owner_user_id: row.workspace.owner_user_id,
                name: row.workspace.name,
                workspace_type: row.workspace.workspace_type,
                metadata: row.workspace.metadata,
                archived_at: row.workspace.archived_at,
                created_at: row.workspace.created_at,
                updated_at: row.workspace.updated_at,
            },
            role: row.role,
        })
        .collect();

    Ok(Json(items))
}

#[utoipa::path(
    get,
    path = "/api/v1/workspaces/{workspace_id}",
    operation_id = "getWorkspaceV1",
    tag = "workspaces",
    params(
        ("workspace_id" = Uuid, Path, description = "Workspace UUID")
    ),
    responses(
        (status = 200, description = "OK", body = WorkspaceResponse),
        (status = 401, description = "Unauthorized", body = crate::error::ErrorBody),
        (status = 403, description = "Forbidden", body = crate::error::ErrorBody),
        (status = 404, description = "Not found", body = crate::error::ErrorBody),
        (status = 503, description = "Unavailable", body = crate::error::ErrorBody)
    ),
    security(("bearerAuth" = []))
)]
pub(crate) async fn get_workspace(
    State(state): State<AppState>,
    headers: HeaderMap,
    Path(workspace_id): Path<Uuid>,
) -> Result<Json<WorkspaceResponse>, ApiError> {
    let uid = require_user_uuid(&state, &headers)?;
    let pool = state.require_pool()?;

    // Membership check first (403) even if the workspace doesn't exist.
    let _ = require_workspace_member_role(pool, uid, workspace_id).await?;

    let row: Option<WorkspaceRow> = sqlx::query_as(
        r#"
        SELECT id, owner_user_id, name, workspace_type, metadata, archived_at, created_at, updated_at
        FROM public.app_workspace
        WHERE id = $1
        "#,
    )
    .bind(workspace_id)
    .fetch_optional(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    let row = row.ok_or(ApiError::NotFound)?;
    Ok(Json(WorkspaceResponse {
        id: row.id,
        owner_user_id: row.owner_user_id,
        name: row.name,
        workspace_type: row.workspace_type,
        metadata: row.metadata,
        archived_at: row.archived_at,
        created_at: row.created_at,
        updated_at: row.updated_at,
    }))
}

#[utoipa::path(
    patch,
    path = "/api/v1/workspaces/{workspace_id}",
    operation_id = "patchWorkspaceV1",
    tag = "workspaces",
    params(
        ("workspace_id" = Uuid, Path, description = "Workspace UUID")
    ),
    request_body(content = PatchWorkspaceBody, content_type = "application/json"),
    responses(
        (status = 200, description = "OK", body = WorkspaceResponse),
        (status = 400, description = "Bad request", body = crate::error::ErrorBody),
        (status = 401, description = "Unauthorized", body = crate::error::ErrorBody),
        (status = 403, description = "Forbidden", body = crate::error::ErrorBody),
        (status = 404, description = "Not found", body = crate::error::ErrorBody),
        (status = 503, description = "Unavailable", body = crate::error::ErrorBody)
    ),
    security(("bearerAuth" = []))
)]
pub(crate) async fn patch_workspace(
    State(state): State<AppState>,
    headers: HeaderMap,
    Path(workspace_id): Path<Uuid>,
    Json(body): Json<PatchWorkspaceBody>,
) -> Result<Json<WorkspaceResponse>, ApiError> {
    let uid = require_user_uuid(&state, &headers)?;
    let pool = state.require_pool()?;
    require_workspace_admin_or_owner(pool, uid, workspace_id).await?;

    let ws_type: Option<String> =
        sqlx::query_scalar("SELECT workspace_type::text FROM public.app_workspace WHERE id = $1")
            .bind(workspace_id)
            .fetch_optional(pool)
            .await
            .map_err(|e| ApiError::DatabaseError(e.to_string()))?;
    let Some(ws_type) = ws_type else {
        return Err(ApiError::NotFound);
    };

    if body.archive == Some(true) && ws_type == "personal" {
        return Err(ApiError::BadRequest(
            "cannot archive a personal workspace".into(),
        ));
    }

    let name = body
        .name
        .map(|s| s.trim().to_string())
        .filter(|s| !s.is_empty());
    if let Some(ref n) = name {
        if n.len() > 120 {
            return Err(ApiError::BadRequest(
                "name must be at most 120 chars".into(),
            ));
        }
    }
    if let Some(ref meta) = body.metadata {
        if !meta.is_object() {
            return Err(ApiError::BadRequest("metadata must be an object".into()));
        }
    }

    let archive_op: i16 = match body.archive {
        None => -1,
        Some(true) => 1,
        Some(false) => 0,
    };

    let row: Option<WorkspaceRow> = sqlx::query_as(
        r#"
        UPDATE public.app_workspace
        SET
          name = COALESCE($2, name),
          metadata = COALESCE($3, metadata),
          archived_at = CASE
            WHEN $4 = 1 THEN NOW()
            WHEN $4 = 0 THEN NULL
            ELSE archived_at
          END,
          updated_at = NOW()
        WHERE id = $1
        RETURNING id, owner_user_id, name, workspace_type, metadata, archived_at, created_at, updated_at
        "#,
    )
    .bind(workspace_id)
    .bind(name)
    .bind(body.metadata)
    .bind(archive_op)
    .fetch_optional(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    let row = row.ok_or(ApiError::NotFound)?;

    if body.archive == Some(true) {
        reset_current_workspace_if_matches(pool, uid, workspace_id).await?;
    }

    Ok(Json(WorkspaceResponse {
        id: row.id,
        owner_user_id: row.owner_user_id,
        name: row.name,
        workspace_type: row.workspace_type,
        metadata: row.metadata,
        archived_at: row.archived_at,
        created_at: row.created_at,
        updated_at: row.updated_at,
    }))
}

#[utoipa::path(
    get,
    path = "/api/v1/workspaces/{workspace_id}/members",
    operation_id = "listWorkspaceMembersV1",
    tag = "workspaces",
    params(
        ("workspace_id" = Uuid, Path, description = "Workspace UUID")
    ),
    responses(
        (status = 200, description = "OK", body = [WorkspaceMemberResponse]),
        (status = 401, description = "Unauthorized", body = crate::error::ErrorBody),
        (status = 403, description = "Forbidden", body = crate::error::ErrorBody),
        (status = 503, description = "Unavailable", body = crate::error::ErrorBody)
    ),
    security(("bearerAuth" = []))
)]
pub(crate) async fn list_workspace_members(
    State(state): State<AppState>,
    headers: HeaderMap,
    Path(workspace_id): Path<Uuid>,
) -> Result<Json<Vec<WorkspaceMemberResponse>>, ApiError> {
    let uid = require_user_uuid(&state, &headers)?;
    let pool = state.require_pool()?;
    let _ = require_workspace_member_role(pool, uid, workspace_id).await?;

    let rows: Vec<WorkspaceMemberResponse> = sqlx::query_as(
        r#"
        SELECT workspace_id, user_id, role, created_at, updated_at
        FROM public.app_workspace_member
        WHERE workspace_id = $1
        ORDER BY created_at ASC, user_id ASC
        "#,
    )
    .bind(workspace_id)
    .fetch_all(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;
    Ok(Json(rows))
}

#[utoipa::path(
    post,
    path = "/api/v1/workspaces/{workspace_id}/members",
    operation_id = "addWorkspaceMemberV1",
    tag = "workspaces",
    params(
        ("workspace_id" = Uuid, Path, description = "Workspace UUID")
    ),
    request_body(content = AddWorkspaceMemberBody, content_type = "application/json"),
    responses(
        (status = 200, description = "OK", body = WorkspaceMemberResponse),
        (status = 400, description = "Bad request", body = crate::error::ErrorBody),
        (status = 401, description = "Unauthorized", body = crate::error::ErrorBody),
        (status = 403, description = "Forbidden", body = crate::error::ErrorBody),
        (status = 404, description = "Not found", body = crate::error::ErrorBody),
        (status = 429, description = "Quota exceeded", body = crate::error::ErrorBody),
        (status = 503, description = "Unavailable", body = crate::error::ErrorBody)
    ),
    security(("bearerAuth" = []))
)]
pub(crate) async fn add_workspace_member(
    State(state): State<AppState>,
    headers: HeaderMap,
    Path(workspace_id): Path<Uuid>,
    Json(body): Json<AddWorkspaceMemberBody>,
) -> Result<Json<WorkspaceMemberResponse>, ApiError> {
    let uid = require_user_uuid(&state, &headers)?;
    let pool = state.require_pool()?;
    require_workspace_admin_or_owner(pool, uid, workspace_id).await?;
    guard_workspace_member_mutation_rate(pool, workspace_id).await?;

    let role = normalize_member_role(&body.role).ok_or_else(|| {
        ApiError::BadRequest("role must be admin or member (owner requires transfer flow)".into())
    })?;

    let ws_exists: bool =
        sqlx::query_scalar("SELECT EXISTS(SELECT 1 FROM public.app_workspace WHERE id = $1)")
            .bind(workspace_id)
            .fetch_one(pool)
            .await
            .map_err(|e| ApiError::DatabaseError(e.to_string()))?;
    if !ws_exists {
        return Err(ApiError::NotFound);
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

    let row: WorkspaceMemberResponse = sqlx::query_as(
        r#"
        INSERT INTO public.app_workspace_member (workspace_id, user_id, role)
        VALUES ($1, $2, $3)
        ON CONFLICT (workspace_id, user_id) DO UPDATE
        SET role = EXCLUDED.role, updated_at = NOW()
        RETURNING workspace_id, user_id, role, created_at, updated_at
        "#,
    )
    .bind(workspace_id)
    .bind(body.user_id)
    .bind(role)
    .fetch_one(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;
    append_workspace_audit(
        pool,
        workspace_id,
        uid,
        "workspace_member_upserted",
        Some(row.user_id),
        serde_json::json!({ "role": row.role.clone() }),
    )
    .await?;
    Ok(Json(row))
}

#[utoipa::path(
    patch,
    path = "/api/v1/workspaces/{workspace_id}/members/{user_id}",
    operation_id = "patchWorkspaceMemberV1",
    tag = "workspaces",
    params(
        ("workspace_id" = Uuid, Path, description = "Workspace UUID"),
        ("user_id" = Uuid, Path, description = "Member user UUID")
    ),
    request_body(content = PatchWorkspaceMemberBody, content_type = "application/json"),
    responses(
        (status = 200, description = "OK", body = WorkspaceMemberResponse),
        (status = 400, description = "Bad request", body = crate::error::ErrorBody),
        (status = 401, description = "Unauthorized", body = crate::error::ErrorBody),
        (status = 403, description = "Forbidden", body = crate::error::ErrorBody),
        (status = 404, description = "Not found", body = crate::error::ErrorBody),
        (status = 409, description = "Conflict", body = crate::error::ErrorBody),
        (status = 503, description = "Unavailable", body = crate::error::ErrorBody)
    ),
    security(("bearerAuth" = []))
)]
pub(crate) async fn patch_workspace_member(
    State(state): State<AppState>,
    headers: HeaderMap,
    Path((workspace_id, user_id)): Path<(Uuid, Uuid)>,
    Json(body): Json<PatchWorkspaceMemberBody>,
) -> Result<Json<WorkspaceMemberResponse>, ApiError> {
    let uid = require_user_uuid(&state, &headers)?;
    let pool = state.require_pool()?;
    require_workspace_admin_or_owner(pool, uid, workspace_id).await?;
    let role = normalize_member_role(&body.role)
        .ok_or_else(|| ApiError::BadRequest("role must be admin or member".into()))?;

    let current_role: Option<String> = sqlx::query_scalar(
        "SELECT role FROM public.app_workspace_member WHERE workspace_id = $1 AND user_id = $2",
    )
    .bind(workspace_id)
    .bind(user_id)
    .fetch_optional(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;
    let Some(current_role) = current_role else {
        return Err(ApiError::NotFound);
    };
    if current_role == "owner" {
        let owner_count = count_workspace_owners(pool, workspace_id).await?;
        if owner_count <= 1 {
            return Err(ApiError::Conflict(
                "cannot demote the last workspace owner".into(),
            ));
        }
    }

    let row: WorkspaceMemberResponse = sqlx::query_as(
        r#"
        UPDATE public.app_workspace_member
        SET role = $3, updated_at = NOW()
        WHERE workspace_id = $1 AND user_id = $2
        RETURNING workspace_id, user_id, role, created_at, updated_at
        "#,
    )
    .bind(workspace_id)
    .bind(user_id)
    .bind(role)
    .fetch_one(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;
    append_workspace_audit(
        pool,
        workspace_id,
        uid,
        "workspace_member_role_changed",
        Some(row.user_id),
        serde_json::json!({ "role": row.role.clone() }),
    )
    .await?;
    Ok(Json(row))
}

#[utoipa::path(
    delete,
    path = "/api/v1/workspaces/{workspace_id}/members/{user_id}",
    operation_id = "removeWorkspaceMemberV1",
    tag = "workspaces",
    params(
        ("workspace_id" = Uuid, Path, description = "Workspace UUID"),
        ("user_id" = Uuid, Path, description = "Member user UUID")
    ),
    responses(
        (status = 200, description = "OK", body = WorkspaceMemberResponse),
        (status = 401, description = "Unauthorized", body = crate::error::ErrorBody),
        (status = 403, description = "Forbidden", body = crate::error::ErrorBody),
        (status = 404, description = "Not found", body = crate::error::ErrorBody),
        (status = 409, description = "Conflict", body = crate::error::ErrorBody),
        (status = 503, description = "Unavailable", body = crate::error::ErrorBody)
    ),
    security(("bearerAuth" = []))
)]
pub(crate) async fn remove_workspace_member(
    State(state): State<AppState>,
    headers: HeaderMap,
    Path((workspace_id, user_id)): Path<(Uuid, Uuid)>,
) -> Result<Json<WorkspaceMemberResponse>, ApiError> {
    let uid = require_user_uuid(&state, &headers)?;
    let pool = state.require_pool()?;
    require_workspace_admin_or_owner(pool, uid, workspace_id).await?;

    let current_role: Option<String> = sqlx::query_scalar(
        "SELECT role FROM public.app_workspace_member WHERE workspace_id = $1 AND user_id = $2",
    )
    .bind(workspace_id)
    .bind(user_id)
    .fetch_optional(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;
    let Some(current_role) = current_role else {
        return Err(ApiError::NotFound);
    };
    if current_role == "owner" {
        let owner_count = count_workspace_owners(pool, workspace_id).await?;
        if owner_count <= 1 {
            return Err(ApiError::Conflict(
                "cannot remove the last workspace owner".into(),
            ));
        }
    }

    let row: WorkspaceMemberResponse = sqlx::query_as(
        r#"
        DELETE FROM public.app_workspace_member
        WHERE workspace_id = $1 AND user_id = $2
        RETURNING workspace_id, user_id, role, created_at, updated_at
        "#,
    )
    .bind(workspace_id)
    .bind(user_id)
    .fetch_one(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;
    append_workspace_audit(
        pool,
        workspace_id,
        uid,
        "workspace_member_removed",
        Some(row.user_id),
        serde_json::json!({ "role": row.role.clone() }),
    )
    .await?;
    Ok(Json(row))
}

#[utoipa::path(
    delete,
    path = "/api/v1/workspaces/{workspace_id}/members/me",
    operation_id = "leaveWorkspaceV1",
    tag = "workspaces",
    params(
        ("workspace_id" = Uuid, Path, description = "Workspace UUID")
    ),
    responses(
        (status = 200, description = "OK", body = WorkspaceMemberResponse),
        (status = 400, description = "Bad request", body = crate::error::ErrorBody),
        (status = 401, description = "Unauthorized", body = crate::error::ErrorBody),
        (status = 403, description = "Forbidden", body = crate::error::ErrorBody),
        (status = 404, description = "Not found", body = crate::error::ErrorBody),
        (status = 409, description = "Conflict", body = crate::error::ErrorBody),
        (status = 503, description = "Unavailable", body = crate::error::ErrorBody)
    ),
    security(("bearerAuth" = []))
)]
pub(crate) async fn leave_workspace(
    State(state): State<AppState>,
    headers: HeaderMap,
    Path(workspace_id): Path<Uuid>,
) -> Result<Json<WorkspaceMemberResponse>, ApiError> {
    let uid = require_user_uuid(&state, &headers)?;
    let pool = state.require_pool()?;
    let role = require_workspace_member_role(pool, uid, workspace_id).await?;

    let ws_type: Option<String> =
        sqlx::query_scalar("SELECT workspace_type::text FROM public.app_workspace WHERE id = $1")
            .bind(workspace_id)
            .fetch_optional(pool)
            .await
            .map_err(|e| ApiError::DatabaseError(e.to_string()))?;
    let Some(ws_type) = ws_type else {
        return Err(ApiError::NotFound);
    };
    if ws_type == "personal" {
        return Err(ApiError::BadRequest(
            "cannot leave personal workspace".into(),
        ));
    }

    if role == "owner" {
        let owner_count = count_workspace_owners(pool, workspace_id).await?;
        if owner_count <= 1 {
            return Err(ApiError::Conflict(
                "cannot leave workspace as the last owner".into(),
            ));
        }
    }

    let row: WorkspaceMemberResponse = sqlx::query_as(
        r#"
        DELETE FROM public.app_workspace_member
        WHERE workspace_id = $1 AND user_id = $2
        RETURNING workspace_id, user_id, role, created_at, updated_at
        "#,
    )
    .bind(workspace_id)
    .bind(uid)
    .fetch_one(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    append_workspace_audit(
        pool,
        workspace_id,
        uid,
        "workspace_member_left",
        Some(uid),
        serde_json::json!({ "role": row.role.clone() }),
    )
    .await?;
    reset_current_workspace_if_matches(pool, uid, workspace_id).await?;
    Ok(Json(row))
}

#[utoipa::path(
    post,
    path = "/api/v1/workspaces/{workspace_id}/owner-transfer",
    operation_id = "transferWorkspaceOwnerV1",
    tag = "workspaces",
    params(
        ("workspace_id" = Uuid, Path, description = "Workspace UUID")
    ),
    request_body(content = TransferWorkspaceOwnerBody, content_type = "application/json"),
    responses(
        (status = 200, description = "OK", body = WorkspaceResponse),
        (status = 400, description = "Bad request", body = crate::error::ErrorBody),
        (status = 401, description = "Unauthorized", body = crate::error::ErrorBody),
        (status = 403, description = "Forbidden", body = crate::error::ErrorBody),
        (status = 404, description = "Not found", body = crate::error::ErrorBody),
        (status = 409, description = "Conflict", body = crate::error::ErrorBody),
        (status = 503, description = "Unavailable", body = crate::error::ErrorBody)
    ),
    security(("bearerAuth" = []))
)]
pub(crate) async fn transfer_workspace_owner(
    State(state): State<AppState>,
    headers: HeaderMap,
    Path(workspace_id): Path<Uuid>,
    Json(body): Json<TransferWorkspaceOwnerBody>,
) -> Result<Json<WorkspaceResponse>, ApiError> {
    let uid = require_user_uuid(&state, &headers)?;
    let pool = state.require_pool()?;
    require_workspace_owner(pool, uid, workspace_id).await?;
    guard_workspace_member_mutation_rate(pool, workspace_id).await?;

    if body.target_user_id == uid {
        return Err(ApiError::Conflict(
            "target owner must differ from current owner".into(),
        ));
    }

    let workspace: Option<WorkspaceRow> = sqlx::query_as(
        r#"
        SELECT id, owner_user_id, name, workspace_type, metadata, archived_at, created_at, updated_at
        FROM public.app_workspace
        WHERE id = $1
        "#,
    )
    .bind(workspace_id)
    .fetch_optional(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;
    let Some(workspace) = workspace else {
        return Err(ApiError::NotFound);
    };

    if workspace.workspace_type == "personal" {
        return Err(ApiError::BadRequest(
            "cannot transfer owner of a personal workspace".into(),
        ));
    }
    if workspace.owner_user_id != uid {
        return Err(ApiError::Conflict(
            "only the current primary owner may transfer ownership".into(),
        ));
    }

    let target_role: Option<String> = sqlx::query_scalar(
        "SELECT role FROM public.app_workspace_member WHERE workspace_id = $1 AND user_id = $2",
    )
    .bind(workspace_id)
    .bind(body.target_user_id)
    .fetch_optional(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;
    let Some(target_role) = target_role else {
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
        WHERE workspace_id = $1 AND user_id = $2
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
        WHERE workspace_id = $1 AND user_id = $2
        "#,
    )
    .bind(workspace_id)
    .bind(uid)
    .execute(&mut *tx)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    let row: WorkspaceRow = sqlx::query_as(
        r#"
        UPDATE public.app_workspace
        SET owner_user_id = $2, updated_at = NOW()
        WHERE id = $1
        RETURNING id, owner_user_id, name, workspace_type, metadata, archived_at, created_at, updated_at
        "#,
    )
    .bind(workspace_id)
    .bind(body.target_user_id)
    .fetch_one(&mut *tx)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    tx.commit()
        .await
        .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    append_workspace_audit(
        pool,
        workspace_id,
        uid,
        "workspace_owner_transferred",
        Some(body.target_user_id),
        serde_json::json!({
            "previous_owner_user_id": uid,
            "new_owner_user_id": body.target_user_id,
            "target_previous_role": target_role,
            "previous_owner_new_role": "admin"
        }),
    )
    .await?;

    Ok(Json(WorkspaceResponse {
        id: row.id,
        owner_user_id: row.owner_user_id,
        name: row.name,
        workspace_type: row.workspace_type,
        metadata: row.metadata,
        archived_at: row.archived_at,
        created_at: row.created_at,
        updated_at: row.updated_at,
    }))
}

fn normalize_invite_list_status(raw: Option<String>) -> Result<Option<String>, ApiError> {
    let Some(s) = raw else {
        return Ok(None);
    };
    let t = s.trim().to_ascii_lowercase();
    if t.is_empty() {
        return Ok(None);
    }
    match t.as_str() {
        "pending" | "accepted" | "revoked" => Ok(Some(t)),
        _ => Err(ApiError::BadRequest(
            "status must be pending, accepted, or revoked".into(),
        )),
    }
}

fn normalize_workspace_audit_action(raw: Option<String>) -> Option<String> {
    raw.and_then(|value| {
        let trimmed = value.trim();
        if trimmed.is_empty() {
            None
        } else {
            Some(trimmed.to_owned())
        }
    })
}

#[utoipa::path(
    get,
    path = "/api/v1/workspaces/{workspace_id}/audit",
    operation_id = "listWorkspaceAuditV1",
    tag = "workspaces",
    params(
        ("workspace_id" = Uuid, Path, description = "Workspace UUID"),
        ListWorkspaceAuditQuery
    ),
    responses(
        (status = 200, description = "OK", body = ListWorkspaceAuditEnvelope),
        (status = 401, description = "Unauthorized", body = crate::error::ErrorBody),
        (status = 403, description = "Forbidden", body = crate::error::ErrorBody),
        (status = 503, description = "Unavailable", body = crate::error::ErrorBody)
    ),
    security(("bearerAuth" = []))
)]
pub(crate) async fn list_workspace_audit(
    State(state): State<AppState>,
    headers: HeaderMap,
    Path(workspace_id): Path<Uuid>,
    Query(q): Query<ListWorkspaceAuditQuery>,
) -> Result<Json<ListWorkspaceAuditEnvelope>, ApiError> {
    let uid = require_user_uuid(&state, &headers)?;
    let pool = state.require_pool()?;
    require_workspace_admin_or_owner(pool, uid, workspace_id).await?;

    let action_filter = normalize_workspace_audit_action(q.action);
    let page_size = q.limit.unwrap_or(50).clamp(1, 200);
    let offset = q.offset.unwrap_or(0).max(0);
    let fetch_limit = page_size.saturating_add(1);

    let rows: Vec<WorkspaceAuditResponse> = sqlx::query_as(
        r#"
        SELECT
          id,
          workspace_id,
          actor_user_id,
          action,
          target_user_id,
          details,
          created_at
        FROM public.app_workspace_audit
        WHERE workspace_id = $1
          AND ($2::text IS NULL OR action = $2)
        ORDER BY created_at DESC, id DESC
        LIMIT $3 OFFSET $4
        "#,
    )
    .bind(workspace_id)
    .bind(action_filter)
    .bind(fetch_limit)
    .bind(offset)
    .fetch_all(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    let mut rows = rows;
    let has_more = (rows.len() as i64) > page_size;
    if has_more {
        rows.truncate(page_size as usize);
    }

    Ok(Json(ListWorkspaceAuditEnvelope {
        items: rows,
        has_more,
    }))
}

#[utoipa::path(
    get,
    path = "/api/v1/workspaces/{workspace_id}/invites",
    operation_id = "listWorkspaceInvitesV1",
    tag = "workspaces",
    params(
        ("workspace_id" = Uuid, Path, description = "Workspace UUID"),
        ListWorkspaceInvitesQuery
    ),
    responses(
        (status = 200, description = "OK", body = ListWorkspaceInvitesEnvelope),
        (status = 400, description = "Bad request", body = crate::error::ErrorBody),
        (status = 401, description = "Unauthorized", body = crate::error::ErrorBody),
        (status = 403, description = "Forbidden", body = crate::error::ErrorBody),
        (status = 503, description = "Unavailable", body = crate::error::ErrorBody)
    ),
    security(("bearerAuth" = []))
)]
pub(crate) async fn list_workspace_invites(
    State(state): State<AppState>,
    headers: HeaderMap,
    Path(workspace_id): Path<Uuid>,
    Query(q): Query<ListWorkspaceInvitesQuery>,
) -> Result<Json<ListWorkspaceInvitesEnvelope>, ApiError> {
    let uid = require_user_uuid(&state, &headers)?;
    let pool = state.require_pool()?;
    require_workspace_admin_or_owner(pool, uid, workspace_id).await?;

    let status_filter = normalize_invite_list_status(q.status.clone())?;
    let page_size = q.limit.unwrap_or(50).clamp(1, 200);
    let offset = q.offset.unwrap_or(0).max(0);
    let fetch_limit = page_size.saturating_add(1);

    let include_revoked = q.include_revoked || status_filter.as_deref() == Some("revoked");

    let rows: Vec<WorkspaceInviteResponse> = sqlx::query_as(
        r#"
        SELECT
          id, workspace_id, email, token, role, invited_by, status, expires_at,
          accepted_by, accepted_at, created_at, updated_at
        FROM public.app_workspace_invite
        WHERE workspace_id = $1
          AND ($2::text IS NULL OR status = $2)
          AND ($3::bool OR status <> 'revoked')
        ORDER BY created_at DESC, id DESC
        LIMIT $4 OFFSET $5
        "#,
    )
    .bind(workspace_id)
    .bind(status_filter)
    .bind(include_revoked)
    .bind(fetch_limit)
    .bind(offset)
    .fetch_all(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    let mut rows = rows;
    let has_more = (rows.len() as i64) > page_size;
    if has_more {
        rows.truncate(page_size as usize);
    }

    Ok(Json(ListWorkspaceInvitesEnvelope {
        items: rows,
        has_more,
    }))
}

#[utoipa::path(
    delete,
    path = "/api/v1/workspaces/{workspace_id}/invites/{invite_id}",
    operation_id = "revokeWorkspaceInviteV1",
    tag = "workspaces",
    params(
        ("workspace_id" = Uuid, Path, description = "Workspace UUID"),
        ("invite_id" = String, Path, description = "Invite row UUID")
    ),
    responses(
        (status = 200, description = "Revoked", body = WorkspaceInviteResponse),
        (status = 400, description = "Bad request", body = crate::error::ErrorBody),
        (status = 401, description = "Unauthorized", body = crate::error::ErrorBody),
        (status = 403, description = "Forbidden", body = crate::error::ErrorBody),
        (status = 404, description = "Not found", body = crate::error::ErrorBody),
        (status = 409, description = "Conflict", body = crate::error::ErrorBody),
        (status = 503, description = "Unavailable", body = crate::error::ErrorBody)
    ),
    security(("bearerAuth" = []))
)]
pub(crate) async fn revoke_workspace_invite(
    State(state): State<AppState>,
    headers: HeaderMap,
    Path((workspace_id, invite_id_raw)): Path<(Uuid, String)>,
) -> Result<Json<WorkspaceInviteResponse>, ApiError> {
    let invite_id = Uuid::parse_str(invite_id_raw.trim())
        .map_err(|_| ApiError::BadRequest("invite_id must be a UUID".into()))?;
    let uid = require_user_uuid(&state, &headers)?;
    let pool = state.require_pool()?;
    require_workspace_admin_or_owner(pool, uid, workspace_id).await?;
    guard_workspace_member_mutation_rate(pool, workspace_id).await?;

    let row: Option<WorkspaceInviteResponse> = sqlx::query_as(
        r#"
        UPDATE public.app_workspace_invite
        SET status = 'revoked', updated_at = NOW()
        WHERE id = $1
          AND workspace_id = $2
          AND status = 'pending'
        RETURNING
          id, workspace_id, email, token, role, invited_by, status, expires_at,
          accepted_by, accepted_at, created_at, updated_at
        "#,
    )
    .bind(invite_id)
    .bind(workspace_id)
    .fetch_optional(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    let Some(row) = row else {
        let exists: bool = sqlx::query_scalar(
            "SELECT EXISTS(SELECT 1 FROM public.app_workspace_invite WHERE id = $1 AND workspace_id = $2)",
        )
        .bind(invite_id)
        .bind(workspace_id)
        .fetch_one(pool)
        .await
        .map_err(|e| ApiError::DatabaseError(e.to_string()))?;
        if exists {
            return Err(ApiError::Conflict(
                "invite cannot be revoked (not pending)".into(),
            ));
        }
        return Err(ApiError::NotFound);
    };

    append_workspace_audit(
        pool,
        workspace_id,
        uid,
        "workspace_invite_revoked",
        None,
        serde_json::json!({ "invite_id": row.id, "email": row.email }),
    )
    .await?;
    let workspace_name = load_workspace_name(pool, workspace_id).await?;
    record_workspace_invite_notification(
        &state,
        uid,
        workspace_id,
        &workspace_name,
        "workspace_invite_revoked",
        format!("邀请已撤销 · {workspace_name}"),
        format!("已撤销发往 {} 的团队邀请。", row.email),
        serde_json::json!({
            "inviteId": row.id,
            "workspaceId": workspace_id,
            "workspaceName": workspace_name,
            "email": row.email,
            "role": row.role,
            "status": row.status,
        }),
    )
    .await?;

    Ok(Json(row))
}

#[utoipa::path(
    post,
    path = "/api/v1/workspaces/{workspace_id}/invites/{invite_id}/resend",
    operation_id = "resendWorkspaceInviteV1",
    tag = "workspaces",
    params(
        ("workspace_id" = Uuid, Path, description = "Workspace UUID"),
        ("invite_id" = String, Path, description = "Invite row UUID")
    ),
    request_body = ResendWorkspaceInviteBody,
    responses(
        (status = 200, description = "OK", body = WorkspaceInviteResponse),
        (status = 400, description = "Bad request", body = crate::error::ErrorBody),
        (status = 401, description = "Unauthorized", body = crate::error::ErrorBody),
        (status = 403, description = "Forbidden", body = crate::error::ErrorBody),
        (status = 404, description = "Not found", body = crate::error::ErrorBody),
        (status = 409, description = "Conflict", body = crate::error::ErrorBody),
        (status = 429, description = "Quota exceeded", body = crate::error::ErrorBody),
        (status = 503, description = "Unavailable", body = crate::error::ErrorBody)
    ),
    security(("bearerAuth" = []))
)]
pub(crate) async fn resend_workspace_invite(
    State(state): State<AppState>,
    headers: HeaderMap,
    Path((workspace_id, invite_id_raw)): Path<(Uuid, String)>,
    Json(body): Json<ResendWorkspaceInviteBody>,
) -> Result<Json<WorkspaceInviteResponse>, ApiError> {
    let invite_id = Uuid::parse_str(invite_id_raw.trim())
        .map_err(|_| ApiError::BadRequest("invite_id must be a UUID".into()))?;
    let uid = require_user_uuid(&state, &headers)?;
    let pool = state.require_pool()?;
    require_workspace_admin_or_owner(pool, uid, workspace_id).await?;
    guard_workspace_member_mutation_rate(pool, workspace_id).await?;

    let expires_hours = parse_invite_expires_hours(body.expires_in_hours)?;
    let new_token = Uuid::new_v4().to_string();

    let row: Option<WorkspaceInviteResponse> = sqlx::query_as(
        r#"
        UPDATE public.app_workspace_invite
        SET
          token = $3,
          expires_at = NOW() + make_interval(hours => $4),
          updated_at = NOW()
        WHERE id = $1
          AND workspace_id = $2
          AND status = 'pending'
        RETURNING
          id, workspace_id, email, token, role, invited_by, status, expires_at,
          accepted_by, accepted_at, created_at, updated_at
        "#,
    )
    .bind(invite_id)
    .bind(workspace_id)
    .bind(new_token)
    .bind(expires_hours)
    .fetch_optional(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    let Some(row) = row else {
        let exists: bool = sqlx::query_scalar(
            "SELECT EXISTS(SELECT 1 FROM public.app_workspace_invite WHERE id = $1 AND workspace_id = $2)",
        )
        .bind(invite_id)
        .bind(workspace_id)
        .fetch_one(pool)
        .await
        .map_err(|e| ApiError::DatabaseError(e.to_string()))?;
        if exists {
            return Err(ApiError::Conflict(
                "invite cannot be resent (not pending)".into(),
            ));
        }
        return Err(ApiError::NotFound);
    };

    append_workspace_audit(
        pool,
        workspace_id,
        uid,
        "workspace_invite_resent",
        None,
        serde_json::json!({
            "invite_id": row.id,
            "email": row.email,
            "expires_at": row.expires_at
        }),
    )
    .await?;
    let workspace_name = load_workspace_name(pool, workspace_id).await?;
    record_workspace_invite_notification(
        &state,
        uid,
        workspace_id,
        &workspace_name,
        "workspace_invite_resent",
        format!("邀请已重发 · {workspace_name}"),
        format!("已向 {} 重发团队邀请。", row.email),
        serde_json::json!({
            "inviteId": row.id,
            "workspaceId": workspace_id,
            "workspaceName": workspace_name,
            "email": row.email,
            "role": row.role,
            "status": row.status,
            "expiresAt": row.expires_at,
        }),
    )
    .await?;

    Ok(Json(row))
}

#[utoipa::path(
    post,
    path = "/api/v1/workspaces/{workspace_id}/invites",
    operation_id = "createWorkspaceInviteV1",
    tag = "workspaces",
    params(
        ("workspace_id" = Uuid, Path, description = "Workspace UUID")
    ),
    request_body(content = CreateWorkspaceInviteBody, content_type = "application/json"),
    responses(
        (status = 200, description = "OK", body = WorkspaceInviteResponse),
        (status = 400, description = "Bad request", body = crate::error::ErrorBody),
        (status = 401, description = "Unauthorized", body = crate::error::ErrorBody),
        (status = 403, description = "Forbidden", body = crate::error::ErrorBody),
        (status = 404, description = "Not found", body = crate::error::ErrorBody),
        (status = 429, description = "Quota exceeded", body = crate::error::ErrorBody),
        (status = 503, description = "Unavailable", body = crate::error::ErrorBody)
    ),
    security(("bearerAuth" = []))
)]
pub(crate) async fn create_workspace_invite(
    State(state): State<AppState>,
    headers: HeaderMap,
    Path(workspace_id): Path<Uuid>,
    Json(body): Json<CreateWorkspaceInviteBody>,
) -> Result<Json<WorkspaceInviteResponse>, ApiError> {
    let uid = require_user_uuid(&state, &headers)?;
    let pool = state.require_pool()?;
    require_workspace_admin_or_owner(pool, uid, workspace_id).await?;
    guard_workspace_member_mutation_rate(pool, workspace_id).await?;

    let role = normalize_member_role(&body.role)
        .ok_or_else(|| ApiError::BadRequest("role must be admin or member".into()))?;
    let email = body.email.trim().to_ascii_lowercase();
    if email.is_empty() || !email.contains('@') {
        return Err(ApiError::BadRequest("email must be a valid address".into()));
    }
    let expires_hours = parse_invite_expires_hours(body.expires_in_hours)?;
    let token = Uuid::new_v4().to_string();

    let row: WorkspaceInviteResponse = sqlx::query_as(
        r#"
        INSERT INTO public.app_workspace_invite (
          workspace_id, email, token, role, invited_by, status, expires_at
        )
        VALUES ($1, $2, $3, $4, $5, 'pending', NOW() + make_interval(hours => $6))
        RETURNING
          id, workspace_id, email, token, role, invited_by, status, expires_at,
          accepted_by, accepted_at, created_at, updated_at
        "#,
    )
    .bind(workspace_id)
    .bind(email)
    .bind(token)
    .bind(role)
    .bind(uid)
    .bind(expires_hours)
    .fetch_one(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;
    append_workspace_audit(
        pool,
        workspace_id,
        uid,
        "workspace_invite_created",
        None,
        serde_json::json!({
            "invite_id": row.id,
            "email": row.email.clone(),
            "role": row.role.clone(),
            "expires_at": row.expires_at
        }),
    )
    .await?;
    let workspace_name = load_workspace_name(pool, workspace_id).await?;
    record_workspace_invite_notification(
        &state,
        uid,
        workspace_id,
        &workspace_name,
        "workspace_invite_created",
        format!("邀请已创建 · {workspace_name}"),
        format!("已向 {} 发送团队邀请，角色 {}。", row.email, row.role),
        serde_json::json!({
            "inviteId": row.id,
            "workspaceId": workspace_id,
            "workspaceName": workspace_name,
            "email": row.email,
            "role": row.role,
            "status": row.status,
            "expiresAt": row.expires_at,
        }),
    )
    .await?;

    Ok(Json(row))
}

#[utoipa::path(
    post,
    path = "/api/v1/workspaces/invites/accept",
    operation_id = "acceptWorkspaceInviteV1",
    tag = "workspaces",
    request_body(content = AcceptWorkspaceInviteBody, content_type = "application/json"),
    responses(
        (status = 200, description = "OK", body = WorkspaceMemberResponse),
        (status = 400, description = "Bad request", body = crate::error::ErrorBody),
        (status = 401, description = "Unauthorized", body = crate::error::ErrorBody),
        (status = 404, description = "Not found", body = crate::error::ErrorBody),
        (status = 409, description = "Conflict", body = crate::error::ErrorBody),
        (status = 503, description = "Unavailable", body = crate::error::ErrorBody)
    ),
    security(("bearerAuth" = []))
)]
pub(crate) async fn accept_workspace_invite(
    State(state): State<AppState>,
    headers: HeaderMap,
    Json(body): Json<AcceptWorkspaceInviteBody>,
) -> Result<Json<WorkspaceMemberResponse>, ApiError> {
    let uid = require_user_uuid(&state, &headers)?;
    let pool = state.require_pool()?;
    let token = body.token.trim();
    if token.is_empty() {
        return Err(ApiError::BadRequest("token must not be empty".into()));
    }

    let mut tx = pool
        .begin()
        .await
        .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    let invite: Option<WorkspaceInviteResponse> = sqlx::query_as(
        r#"
        SELECT
          id, workspace_id, email, token, role, invited_by, status, expires_at,
          accepted_by, accepted_at, created_at, updated_at
        FROM public.app_workspace_invite
        WHERE token = $1
        FOR UPDATE
        "#,
    )
    .bind(token)
    .fetch_optional(&mut *tx)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;
    let invite = invite.ok_or(ApiError::NotFound)?;
    if invite.status != "pending" {
        return Err(ApiError::Conflict("invite is not pending".into()));
    }
    if invite.expires_at < chrono::Utc::now() {
        return Err(ApiError::Conflict("invite has expired".into()));
    }

    let member: WorkspaceMemberResponse = sqlx::query_as(
        r#"
        INSERT INTO public.app_workspace_member (workspace_id, user_id, role)
        VALUES ($1, $2, $3)
        ON CONFLICT (workspace_id, user_id) DO UPDATE
        SET role = EXCLUDED.role, updated_at = NOW()
        RETURNING workspace_id, user_id, role, created_at, updated_at
        "#,
    )
    .bind(invite.workspace_id)
    .bind(uid)
    .bind(invite.role)
    .fetch_one(&mut *tx)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    sqlx::query(
        r#"
        UPDATE public.app_workspace_invite
        SET status = 'accepted', accepted_by = $2, accepted_at = NOW(), updated_at = NOW()
        WHERE id = $1
        "#,
    )
    .bind(invite.id)
    .bind(uid)
    .execute(&mut *tx)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    tx.commit()
        .await
        .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    append_workspace_audit(
        pool,
        invite.workspace_id,
        uid,
        "workspace_invite_accepted",
        Some(uid),
        serde_json::json!({
            "invite_id": invite.id,
            "role": member.role.clone()
        }),
    )
    .await?;
    let workspace_name = load_workspace_name(pool, invite.workspace_id).await?;
    record_workspace_invite_notification(
        &state,
        uid,
        invite.workspace_id,
        &workspace_name,
        "workspace_invite_accepted",
        format!("已加入团队工作区 · {workspace_name}"),
        format!("你已接受团队邀请，当前角色 {}。", member.role),
        serde_json::json!({
            "inviteId": invite.id,
            "workspaceId": invite.workspace_id,
            "workspaceName": workspace_name,
            "role": member.role,
            "status": "accepted",
        }),
    )
    .await?;
    if invite.invited_by != uid {
        record_workspace_invite_notification(
            &state,
            invite.invited_by,
            invite.workspace_id,
            &workspace_name,
            "workspace_invite_accepted",
            format!("邀请已接受 · {workspace_name}"),
            format!("{} 已接受团队邀请，角色 {}。", invite.email, member.role),
            serde_json::json!({
                "inviteId": invite.id,
                "workspaceId": invite.workspace_id,
                "workspaceName": workspace_name,
                "email": invite.email,
                "acceptedBy": uid,
                "role": member.role,
                "status": "accepted",
            }),
        )
        .await?;
    }

    Ok(Json(member))
}

#[derive(utoipa::OpenApi)]
#[openapi(
    paths(
        create_workspace,
        list_workspaces,
        get_workspace,
        patch_workspace,
        list_workspace_members,
        add_workspace_member,
        patch_workspace_member,
        remove_workspace_member,
        leave_workspace,
        transfer_workspace_owner,
        list_workspace_audit,
        list_workspace_invites,
        revoke_workspace_invite,
        resend_workspace_invite,
        create_workspace_invite,
        accept_workspace_invite
    ),
    components(schemas(
        WorkspaceResponse,
        WorkspaceListItem,
        WorkspaceMemberResponse,
        WorkspaceInviteResponse,
        WorkspaceAuditResponse,
        ListWorkspaceInvitesEnvelope,
        ListWorkspaceAuditEnvelope,
        ResendWorkspaceInviteBody,
        CreateWorkspaceBody,
        AddWorkspaceMemberBody,
        PatchWorkspaceMemberBody,
        CreateWorkspaceInviteBody,
        AcceptWorkspaceInviteBody,
        PatchWorkspaceBody,
        ListWorkspaceAuditQuery,
        crate::error::ErrorBody
    )),
    tags((name = "workspaces", description = "Workspace lifecycle (personal + enterprise)"))
)]
pub struct WorkspacesOpenApi;
