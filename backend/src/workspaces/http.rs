use axum::{
    extract::{Path, State},
    http::HeaderMap,
    routing::get,
    Json, Router,
};
use serde::{Deserialize, Serialize};
use serde_json::Value;
use sqlx::{FromRow, PgPool};
use utoipa::ToSchema;
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
}

#[derive(Debug, Clone, FromRow)]
struct WorkspaceRow {
    id: Uuid,
    owner_user_id: Uuid,
    name: String,
    workspace_type: String,
    metadata: Value,
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

    let mut tx = pool
        .begin()
        .await
        .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    let row: WorkspaceRow = sqlx::query_as(
        r#"
        INSERT INTO public.app_workspace (owner_user_id, name, workspace_type, metadata)
        VALUES ($1, $2, 'enterprise', $3)
        RETURNING id, owner_user_id, name, workspace_type, metadata, created_at, updated_at
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
        created_at: row.created_at,
        updated_at: row.updated_at,
    }))
}

#[utoipa::path(
    get,
    path = "/api/v1/workspaces",
    operation_id = "listWorkspacesV1",
    tag = "workspaces",
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
          w.created_at,
          w.updated_at,
          m.role
        FROM public.app_workspace_member m
        INNER JOIN public.app_workspace w ON w.id = m.workspace_id
        WHERE m.user_id = $1
        ORDER BY (w.workspace_type = 'personal') DESC, w.created_at ASC, w.id ASC
        "#,
    )
    .bind(uid)
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
        SELECT id, owner_user_id, name, workspace_type, metadata, created_at, updated_at
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

    let row: Option<WorkspaceRow> = sqlx::query_as(
        r#"
        UPDATE public.app_workspace
        SET
          name = COALESCE($2, name),
          metadata = COALESCE($3, metadata),
          updated_at = NOW()
        WHERE id = $1
        RETURNING id, owner_user_id, name, workspace_type, metadata, created_at, updated_at
        "#,
    )
    .bind(workspace_id)
    .bind(name)
    .bind(body.metadata)
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
