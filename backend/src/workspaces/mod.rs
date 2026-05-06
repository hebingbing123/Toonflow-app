use sqlx::{FromRow, PgPool};
use uuid::Uuid;

use crate::error::ApiError;

#[derive(Debug, Clone, FromRow)]
pub struct WorkspaceContext {
    pub workspace_id: Uuid,
    pub workspace_name: String,
    pub workspace_type: String,
}

pub async fn ensure_personal_workspace(
    pool: &PgPool,
    user_id: Uuid,
) -> Result<WorkspaceContext, ApiError> {
    let mut tx = pool
        .begin()
        .await
        .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    sqlx::query(
        r#"
        INSERT INTO public.app_workspace (owner_user_id, name, workspace_type)
        VALUES ($1, 'Personal Workspace', 'personal')
        ON CONFLICT DO NOTHING
        "#,
    )
    .bind(user_id)
    .execute(&mut *tx)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    let workspace = sqlx::query_as::<_, WorkspaceContext>(
        r#"
        SELECT
          w.id AS workspace_id,
          w.name AS workspace_name,
          w.workspace_type
        FROM public.app_workspace w
        WHERE w.owner_user_id = $1
          AND w.workspace_type = 'personal'
        ORDER BY w.created_at ASC, w.id ASC
        LIMIT 1
        "#,
    )
    .bind(user_id)
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
    .bind(workspace.workspace_id)
    .bind(user_id)
    .execute(&mut *tx)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    sqlx::query(
        r#"
        INSERT INTO public.app_user_profile (user_id, current_workspace_id)
        VALUES ($1, $2)
        ON CONFLICT (user_id) DO UPDATE
        SET
          current_workspace_id = COALESCE(public.app_user_profile.current_workspace_id, EXCLUDED.current_workspace_id),
          updated_at = NOW()
        "#,
    )
    .bind(user_id)
    .bind(workspace.workspace_id)
    .execute(&mut *tx)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    tx.commit()
        .await
        .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    Ok(workspace)
}
