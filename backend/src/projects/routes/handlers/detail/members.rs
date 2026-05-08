use axum::{
    extract::{Path, State},
    http::HeaderMap,
    Json,
};
use uuid::Uuid;

use crate::auth::require_user_uuid;
use crate::error::ApiError;
use crate::projects::routes::common::require_project_member_admin_scope;
use crate::state::AppState;

use super::super::super::types::{
    CreateProjectMemberBody, PatchProjectMemberBody, ProjectMemberResponse,
};

fn normalize_project_member_role(role: &str) -> Option<&'static str> {
    let value = role.trim().to_ascii_lowercase();
    match value.as_str() {
        "editor" => Some("editor"),
        "viewer" => Some("viewer"),
        _ => None,
    }
}

async fn ensure_assignable_workspace_member(
    pool: &sqlx::PgPool,
    workspace_id: Uuid,
    project_owner_user_id: Uuid,
    user_id: Uuid,
) -> Result<(), ApiError> {
    let workspace_role: Option<String> = sqlx::query_scalar(
        r#"
        SELECT role
        FROM public.app_workspace_member
        WHERE workspace_id = $1
          AND user_id = $2
        "#,
    )
    .bind(workspace_id)
    .bind(user_id)
    .fetch_optional(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    let Some(workspace_role) = workspace_role else {
        return Err(ApiError::BadRequest(
            "target user must already be a workspace member".into(),
        ));
    };

    if user_id == project_owner_user_id {
        return Err(ApiError::BadRequest(
            "project owner already has full access".into(),
        ));
    }

    if workspace_role == "owner" || workspace_role == "admin" {
        return Err(ApiError::BadRequest(
            "workspace owner/admin already has full access".into(),
        ));
    }

    Ok(())
}

#[utoipa::path(
    get,
    path = "/api/v1/projects/{project_id}/members",
    operation_id = "listProjectMembersV1",
    tag = "projects",
    params(("project_id" = Uuid, Path, description = "Project UUID")),
    responses(
        (status = 200, description = "OK", body = Vec<ProjectMemberResponse>),
        (status = 401, description = "Unauthorized", body = crate::error::ErrorBody),
        (status = 403, description = "Forbidden", body = crate::error::ErrorBody),
        (status = 404, description = "Not found", body = crate::error::ErrorBody)
    ),
    security(("bearerAuth" = []))
)]
pub(crate) async fn list_project_members(
    State(state): State<AppState>,
    Path(project_id): Path<Uuid>,
    headers: HeaderMap,
) -> Result<Json<Vec<ProjectMemberResponse>>, ApiError> {
    let uid = require_user_uuid(&state, &headers)?;
    let pool = state.require_pool()?;
    let scope = require_project_member_admin_scope(&state, uid, project_id).await?;

    let rows = sqlx::query_as::<_, ProjectMemberResponse>(
        r#"
        SELECT project_id, user_id, role, created_at, updated_at
        FROM public.app_project_member
        WHERE project_id = $1
        ORDER BY created_at ASC, user_id ASC
        "#,
    )
    .bind(scope.id)
    .fetch_all(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    Ok(Json(rows))
}

#[utoipa::path(
    post,
    path = "/api/v1/projects/{project_id}/members",
    operation_id = "createProjectMemberV1",
    tag = "projects",
    params(("project_id" = Uuid, Path, description = "Project UUID")),
    request_body = CreateProjectMemberBody,
    responses(
        (status = 200, description = "OK", body = ProjectMemberResponse),
        (status = 400, description = "Bad request", body = crate::error::ErrorBody),
        (status = 401, description = "Unauthorized", body = crate::error::ErrorBody),
        (status = 403, description = "Forbidden", body = crate::error::ErrorBody),
        (status = 404, description = "Not found", body = crate::error::ErrorBody)
    ),
    security(("bearerAuth" = []))
)]
pub(crate) async fn create_project_member(
    State(state): State<AppState>,
    Path(project_id): Path<Uuid>,
    headers: HeaderMap,
    Json(body): Json<CreateProjectMemberBody>,
) -> Result<Json<ProjectMemberResponse>, ApiError> {
    let uid = require_user_uuid(&state, &headers)?;
    let pool = state.require_pool()?;
    let scope = require_project_member_admin_scope(&state, uid, project_id).await?;
    let role = normalize_project_member_role(&body.role)
        .ok_or_else(|| ApiError::BadRequest("role must be editor or viewer".into()))?;

    ensure_assignable_workspace_member(pool, scope.workspace_id, scope.owner_user_id, body.user_id)
        .await?;

    let row = sqlx::query_as::<_, ProjectMemberResponse>(
        r#"
        INSERT INTO public.app_project_member (project_id, user_id, role)
        VALUES ($1, $2, $3)
        ON CONFLICT (project_id, user_id)
        DO UPDATE SET role = EXCLUDED.role, updated_at = NOW()
        RETURNING project_id, user_id, role, created_at, updated_at
        "#,
    )
    .bind(scope.id)
    .bind(body.user_id)
    .bind(role)
    .fetch_one(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    Ok(Json(row))
}

#[utoipa::path(
    patch,
    path = "/api/v1/projects/{project_id}/members/{user_id}",
    operation_id = "patchProjectMemberV1",
    tag = "projects",
    params(
        ("project_id" = Uuid, Path, description = "Project UUID"),
        ("user_id" = Uuid, Path, description = "Target user UUID")
    ),
    request_body = PatchProjectMemberBody,
    responses(
        (status = 200, description = "OK", body = ProjectMemberResponse),
        (status = 400, description = "Bad request", body = crate::error::ErrorBody),
        (status = 401, description = "Unauthorized", body = crate::error::ErrorBody),
        (status = 403, description = "Forbidden", body = crate::error::ErrorBody),
        (status = 404, description = "Not found", body = crate::error::ErrorBody)
    ),
    security(("bearerAuth" = []))
)]
pub(crate) async fn patch_project_member(
    State(state): State<AppState>,
    Path((project_id, user_id)): Path<(Uuid, Uuid)>,
    headers: HeaderMap,
    Json(body): Json<PatchProjectMemberBody>,
) -> Result<Json<ProjectMemberResponse>, ApiError> {
    let uid = require_user_uuid(&state, &headers)?;
    let pool = state.require_pool()?;
    let scope = require_project_member_admin_scope(&state, uid, project_id).await?;
    let role = normalize_project_member_role(&body.role)
        .ok_or_else(|| ApiError::BadRequest("role must be editor or viewer".into()))?;

    ensure_assignable_workspace_member(pool, scope.workspace_id, scope.owner_user_id, user_id)
        .await?;

    let row = sqlx::query_as::<_, ProjectMemberResponse>(
        r#"
        UPDATE public.app_project_member
        SET role = $3, updated_at = NOW()
        WHERE project_id = $1
          AND user_id = $2
        RETURNING project_id, user_id, role, created_at, updated_at
        "#,
    )
    .bind(scope.id)
    .bind(user_id)
    .bind(role)
    .fetch_optional(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?
    .ok_or(ApiError::NotFound)?;

    Ok(Json(row))
}

#[utoipa::path(
    delete,
    path = "/api/v1/projects/{project_id}/members/{user_id}",
    operation_id = "deleteProjectMemberV1",
    tag = "projects",
    params(
        ("project_id" = Uuid, Path, description = "Project UUID"),
        ("user_id" = Uuid, Path, description = "Target user UUID")
    ),
    responses(
        (status = 204, description = "Deleted"),
        (status = 401, description = "Unauthorized", body = crate::error::ErrorBody),
        (status = 403, description = "Forbidden", body = crate::error::ErrorBody),
        (status = 404, description = "Not found", body = crate::error::ErrorBody)
    ),
    security(("bearerAuth" = []))
)]
pub(crate) async fn delete_project_member(
    State(state): State<AppState>,
    Path((project_id, user_id)): Path<(Uuid, Uuid)>,
    headers: HeaderMap,
) -> Result<axum::http::StatusCode, ApiError> {
    let uid = require_user_uuid(&state, &headers)?;
    let pool = state.require_pool()?;
    let scope = require_project_member_admin_scope(&state, uid, project_id).await?;

    let result = sqlx::query(
        r#"
        DELETE FROM public.app_project_member
        WHERE project_id = $1
          AND user_id = $2
        "#,
    )
    .bind(scope.id)
    .bind(user_id)
    .execute(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    if result.rows_affected() == 0 {
        return Err(ApiError::NotFound);
    }

    Ok(axum::http::StatusCode::NO_CONTENT)
}
