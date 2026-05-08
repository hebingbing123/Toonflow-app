use crate::http_kit::json_patch::FieldPatch;
use crate::{error::ApiError, state::AppState};
use uuid::Uuid;

/// Stable key for `pg_advisory_xact_lock` when allocating `app_project.numeric_id` (global uniqueness).
pub(super) const ADV_LOCK_PROJECT_NUMERIC_ID: i64 = 884_422_001;

pub(super) fn trim_opt(s: Option<String>) -> Option<String> {
    s.and_then(|v| {
        let t = v.trim();
        if t.is_empty() {
            None
        } else {
            Some(t.to_owned())
        }
    })
}

pub(super) fn merge_text_patch(
    current: &Option<String>,
    patch: FieldPatch<String>,
) -> Option<String> {
    match patch {
        FieldPatch::Absent => current.clone(),
        FieldPatch::Set(v) => v,
    }
}

#[derive(Debug, Clone, Copy)]
pub(crate) struct ProjectAccessScope {
    pub id: Uuid,
    pub actor_user_id: Uuid,
    pub workspace_id: Uuid,
    pub owner_user_id: Uuid,
    pub project_acl_enabled: bool,
    pub workspace_role: ProjectWorkspaceRole,
    pub project_role: Option<ProjectMemberRole>,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub(crate) enum ProjectWorkspaceRole {
    Owner,
    Admin,
    Member,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub(crate) enum ProjectMemberRole {
    Editor,
    Viewer,
}

impl ProjectAccessScope {
    pub(crate) fn can_write(&self) -> bool {
        if self.is_workspace_admin_or_owner() {
            return true;
        }
        if self.is_project_owner() {
            return true;
        }
        if !self.project_acl_enabled {
            return true;
        }
        matches!(self.project_role, Some(ProjectMemberRole::Editor))
    }

    pub(crate) fn can_manage_members(&self) -> bool {
        self.is_workspace_admin_or_owner() || self.is_project_owner()
    }

    pub(crate) fn can_delete_project(&self) -> bool {
        self.is_workspace_admin_or_owner() || self.is_project_owner()
    }

    fn is_workspace_admin_or_owner(&self) -> bool {
        matches!(
            self.workspace_role,
            ProjectWorkspaceRole::Owner | ProjectWorkspaceRole::Admin
        )
    }

    fn is_project_owner(&self) -> bool {
        self.owner_user_id == self.actor_user_id
    }

    pub(crate) fn access_mode_label(&self) -> &'static str {
        if self.project_acl_enabled {
            "restricted"
        } else {
            "inherited"
        }
    }

    pub(crate) fn access_role_label(&self) -> &'static str {
        if self.is_workspace_admin_or_owner() {
            return match self.workspace_role {
                ProjectWorkspaceRole::Owner => "workspace_owner",
                ProjectWorkspaceRole::Admin => "workspace_admin",
                ProjectWorkspaceRole::Member => "member",
            };
        }
        if self.is_project_owner() {
            return "project_owner";
        }
        match self.project_role {
            Some(ProjectMemberRole::Editor) => "editor",
            Some(ProjectMemberRole::Viewer) => "viewer",
            None => "member",
        }
    }
}

#[derive(Debug, sqlx::FromRow)]
struct ProjectAccessRow {
    id: Uuid,
    workspace_id: Uuid,
    owner_user_id: Uuid,
    workspace_role: String,
    project_role: Option<String>,
    project_acl_enabled: bool,
}

fn parse_workspace_role(raw: &str) -> Result<ProjectWorkspaceRole, ApiError> {
    match raw {
        "owner" => Ok(ProjectWorkspaceRole::Owner),
        "admin" => Ok(ProjectWorkspaceRole::Admin),
        "member" => Ok(ProjectWorkspaceRole::Member),
        other => Err(ApiError::DatabaseError(format!(
            "unexpected workspace role `{other}`"
        ))),
    }
}

fn parse_project_role(raw: Option<&str>) -> Result<Option<ProjectMemberRole>, ApiError> {
    match raw {
        None => Ok(None),
        Some("editor") => Ok(Some(ProjectMemberRole::Editor)),
        Some("viewer") => Ok(Some(ProjectMemberRole::Viewer)),
        Some(other) => Err(ApiError::DatabaseError(format!(
            "unexpected project role `{other}`"
        ))),
    }
}

async fn load_project_access_scope(
    state: &AppState,
    user_id: Uuid,
    project_id: Uuid,
) -> Result<ProjectAccessScope, ApiError> {
    let pool = state.require_pool()?;
    let exists: bool = sqlx::query_scalar("SELECT EXISTS(SELECT 1 FROM app_project WHERE id = $1)")
        .bind(project_id)
        .fetch_one(pool)
        .await
        .map_err(|e| ApiError::DatabaseError(e.to_string()))?;
    if !exists {
        return Err(ApiError::NotFound);
    }

    let row: Option<ProjectAccessRow> = sqlx::query_as(
        r#"
        SELECT
          p.id,
          p.workspace_id,
          p.owner_user_id,
          wm.role AS workspace_role,
          pm.role AS project_role,
          EXISTS (
            SELECT 1
            FROM public.app_project_member pm_any
            WHERE pm_any.project_id = p.id
          ) AS project_acl_enabled
        FROM app_project p
        INNER JOIN public.app_workspace_member wm
          ON wm.workspace_id = p.workspace_id
         AND wm.user_id = $2
        LEFT JOIN public.app_project_member pm
          ON pm.project_id = p.id
         AND pm.user_id = $2
        WHERE p.id = $1
        LIMIT 1
        "#,
    )
    .bind(project_id)
    .bind(user_id)
    .fetch_optional(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    let row = row.ok_or_else(|| ApiError::Forbidden("not a member of project workspace".into()))?;
    let workspace_role = parse_workspace_role(&row.workspace_role)?;
    let project_role = parse_project_role(row.project_role.as_deref())?;
    let scope = ProjectAccessScope {
        id: row.id,
        actor_user_id: user_id,
        workspace_id: row.workspace_id,
        owner_user_id: row.owner_user_id,
        project_acl_enabled: row.project_acl_enabled,
        workspace_role,
        project_role,
    };

    let allowed = scope.is_workspace_admin_or_owner()
        || scope.is_project_owner()
        || !scope.project_acl_enabled
        || scope.project_role.is_some();
    if !allowed {
        return Err(ApiError::Forbidden(
            "project requires explicit viewer or editor access".into(),
        ));
    }

    tracing::debug!(
        event = "project_workspace_scope_resolved",
        user_id = %user_id,
        project_id = %scope.id,
        workspace_id = %scope.workspace_id,
        project_acl_enabled = scope.project_acl_enabled,
        workspace_role = ?scope.workspace_role,
        project_role = ?scope.project_role,
        outcome = "project_acl_scope",
        "project workspace scope resolved"
    );
    Ok(scope)
}

pub(crate) async fn require_project_workspace_member_scope(
    state: &AppState,
    user_id: Uuid,
    project_id: Uuid,
) -> Result<ProjectAccessScope, ApiError> {
    load_project_access_scope(state, user_id, project_id).await
}

pub(crate) async fn require_project_write_scope(
    state: &AppState,
    user_id: Uuid,
    project_id: Uuid,
) -> Result<ProjectAccessScope, ApiError> {
    let scope = load_project_access_scope(state, user_id, project_id).await?;
    if scope.can_write() {
        Ok(scope)
    } else {
        Err(ApiError::Forbidden(
            "project requires explicit editor access for mutations".into(),
        ))
    }
}

pub(crate) async fn require_project_member_admin_scope(
    state: &AppState,
    user_id: Uuid,
    project_id: Uuid,
) -> Result<ProjectAccessScope, ApiError> {
    let scope = load_project_access_scope(state, user_id, project_id).await?;
    if scope.can_manage_members() {
        Ok(scope)
    } else {
        Err(ApiError::Forbidden(
            "requires workspace owner/admin or project owner".into(),
        ))
    }
}
