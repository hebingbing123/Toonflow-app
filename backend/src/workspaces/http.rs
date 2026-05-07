use axum::{
    extract::{Path, Query, State},
    http::HeaderMap,
    routing::get,
    Json, Router,
};
use serde::{Deserialize, Serialize};
use serde_json::Value;
use sqlx::{FromRow, PgPool};
use utoipa::{IntoParams, ToSchema};
use uuid::Uuid;

use crate::auth::require_user_uuid;
use crate::error::ApiError;
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

fn max_enterprise_workspaces_per_user() -> i64 {
    std::env::var("TOONFLOW_MAX_ENTERPRISE_WORKSPACES_PER_USER")
        .ok()
        .and_then(|s| s.trim().parse::<i64>().ok())
        .filter(|n| *n > 0)
        .unwrap_or(50)
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

#[derive(utoipa::OpenApi)]
#[openapi(
    paths(create_workspace, list_workspaces, get_workspace, patch_workspace),
    components(schemas(
        WorkspaceResponse,
        WorkspaceListItem,
        CreateWorkspaceBody,
        PatchWorkspaceBody,
        crate::error::ErrorBody
    )),
    tags((name = "workspaces", description = "Workspace lifecycle (personal + enterprise)"))
)]
pub struct WorkspacesOpenApi;
