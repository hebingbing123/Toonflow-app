//! Resolve project scope from **`app_generation_job.payload`** inside workers.
//!
//! Design note: repository **`docs/plans/assets-generate-job-payload-v2.md`**.
//! Workspace observability: **`docs/plans/workspace-observability-spec.md`** (W10.1).

use serde_json::Value;
use sqlx::PgPool;
use uuid::Uuid;

use crate::assets::resolve_owned_project_numeric_from_uuid_or_legacy_id;
use crate::assets::resolve_owned_project_pk_and_numeric_from_uuid_or_legacy_id;
use crate::error::ApiError;
use crate::jobs::worker::JobRunError;
use crate::legacy_numeric_id::legacy_numeric_write_enabled;

/// Derives workspace_id from job payload by extracting project_uuid or project_numeric_id
/// and querying the database for the project's workspace.
///
/// Returns `None` if:
/// - The payload contains no project information (neither project_uuid nor project_numeric_id)
/// - The project is not found or archived
/// - The actor is not a member of the project's workspace
///
/// This function is used for workspace-aware job visibility filtering (W4.5).
pub async fn derive_workspace_from_job_payload(
    pool: &PgPool,
    actor_user_id: Uuid,
    payload: &Value,
) -> Result<Option<Uuid>, ApiError> {
    let project_uuid = payload_project_uuid(payload);
    let project_numeric_id = payload_project_numeric_id(payload);

    // If no project information in payload, return None (job is not project-scoped)
    if project_uuid.is_none() && project_numeric_id.is_none() {
        return Ok(None);
    }

    // Resolve project and get workspace_id
    match resolve_owned_project_pk_and_numeric_from_uuid_or_legacy_id(
        pool,
        actor_user_id,
        project_uuid,
        project_numeric_id,
    )
    .await
    {
        Ok((_project_uuid, _project_numeric_id, workspace_id)) => Ok(Some(workspace_id)),
        Err(ApiError::NotFound) => Ok(None), // Project not found or not accessible
        Err(e) => Err(e),                    // Propagate other errors
    }
}

/// New enqueue paths for **`assets-generate/*`** dual-write **`project_uuid`** + **`project_numeric_id`**.
pub(crate) const ASSETS_GENERATE_PAYLOAD_SCHEMA_VERSION_V2: i64 = 2;

pub(crate) fn payload_project_uuid(payload: &Value) -> Option<Uuid> {
    payload
        .get("project_uuid")
        .and_then(|v| v.as_str())
        .and_then(|s| Uuid::parse_str(s.trim()).ok())
}

pub(crate) fn payload_project_numeric_id(payload: &Value) -> Option<i32> {
    payload
        .get("project_numeric_id")
        .and_then(|x| x.as_i64())
        .and_then(|n| i32::try_from(n).ok())
}

pub(crate) fn payload_workspace_id(payload: &Value) -> Option<Uuid> {
    payload
        .get("workspace_id")
        .and_then(|v| v.as_str())
        .and_then(|s| Uuid::parse_str(s.trim()).ok())
}

pub(crate) fn resolved_workspace_id_from_job_payload(payload: &Value) -> Option<Uuid> {
    if payload_project_uuid(payload).is_none() && payload_project_numeric_id(payload).is_none() {
        return None;
    }
    payload_workspace_id(payload)
}

pub(crate) async fn normalize_project_scope_in_job_payload(
    pool: &PgPool,
    actor_user_id: Uuid,
    payload: &mut Value,
) -> Result<Option<Uuid>, ApiError> {
    let project_uuid = payload_project_uuid(payload);
    let project_numeric_id = payload_project_numeric_id(payload);
    if project_uuid.is_none() && project_numeric_id.is_none() {
        return Ok(None);
    }

    let (project_uuid, project_numeric_id, workspace_id) =
        resolve_owned_project_pk_and_numeric_from_uuid_or_legacy_id(
            pool,
            actor_user_id,
            project_uuid,
            project_numeric_id,
        )
        .await?;

    if let Some(obj) = payload.as_object_mut() {
        obj.insert(
            "project_uuid".into(),
            Value::String(project_uuid.to_string()),
        );
        if legacy_numeric_write_enabled() {
            obj.insert(
                "project_numeric_id".into(),
                Value::Number(project_numeric_id.into()),
            );
        } else {
            obj.remove("project_numeric_id");
        }
        obj.insert(
            "workspace_id".into(),
            Value::String(workspace_id.to_string()),
        );
    }

    Ok(Some(workspace_id))
}

#[inline]
fn api_error_to_job_run(err: ApiError) -> JobRunError {
    match err {
        ApiError::BadRequest(msg) => JobRunError::Failed(msg),
        ApiError::NotFound => {
            JobRunError::Failed("project not found or not accessible for job payload".into())
        }
        ApiError::DatabaseError(msg) => JobRunError::Failed(msg),
        other => JobRunError::Failed(format!("project resolve error: {other:?}")),
    }
}

/// Prefer **`project_uuid`** (string) when present; fall back to **`project_numeric_id`** (v1 rows).
///
/// Matches HTTP-layer semantics from [`crate::assets::resolve_owned_project_numeric_from_uuid_or_legacy_id`].
pub(crate) async fn resolve_project_numeric_from_job_payload(
    pool: &PgPool,
    actor_user_id: Uuid,
    payload: &Value,
) -> Result<i32, JobRunError> {
    let project_uuid = payload_project_uuid(payload);
    let project_numeric_id = payload_project_numeric_id(payload);

    resolve_owned_project_numeric_from_uuid_or_legacy_id(
        pool,
        actor_user_id,
        project_uuid,
        project_numeric_id,
    )
    .await
    .map_err(api_error_to_job_run)
}

/// Like [`resolve_project_numeric_from_job_payload`] but preserves legacy behavior for jobs that
/// never carried project scope in their payload.
pub(crate) async fn resolve_optional_project_numeric_from_job_payload(
    pool: &PgPool,
    actor_user_id: Uuid,
    payload: &Value,
) -> Result<Option<i32>, JobRunError> {
    let project_uuid = payload_project_uuid(payload);
    let project_numeric_id = payload_project_numeric_id(payload);
    if project_uuid.is_none() && project_numeric_id.is_none() {
        return Ok(None);
    }

    resolve_owned_project_numeric_from_uuid_or_legacy_id(
        pool,
        actor_user_id,
        project_uuid,
        project_numeric_id,
    )
    .await
    .map(Some)
    .map_err(api_error_to_job_run)
}

#[cfg(test)]
mod tests {
    use serde_json::json;
    use uuid::Uuid;

    #[test]
    fn resolved_workspace_id_from_job_payload_parses_uuid_string() {
        let ws = Uuid::new_v4();
        let p = json!({
            "project_uuid": Uuid::new_v4().to_string(),
            "workspace_id": ws.to_string()
        });
        assert_eq!(super::resolved_workspace_id_from_job_payload(&p), Some(ws));
    }

    #[test]
    fn resolved_workspace_id_from_job_payload_rejects_garbage() {
        let p = json!({
            "project_numeric_id": 42,
            "workspace_id": "not-a-uuid"
        });
        assert!(super::resolved_workspace_id_from_job_payload(&p).is_none());
    }

    #[test]
    fn resolved_workspace_id_from_job_payload_ignores_non_project_payloads() {
        let ws = Uuid::new_v4();
        let p = json!({ "workspace_id": ws.to_string() });
        assert!(super::resolved_workspace_id_from_job_payload(&p).is_none());
    }

    // Integration tests for derive_workspace_from_job_payload
    #[sqlx::test]
    #[ignore = "requires database setup"]
    async fn test_derive_workspace_from_job_payload_with_project_uuid(
        pool: sqlx::PgPool,
    ) -> Result<(), Box<dyn std::error::Error>> {
        // Create test user
        let user_id = Uuid::new_v4();
        sqlx::query(
            "INSERT INTO public.app_user (id, email, created_at, updated_at) 
             VALUES ($1, $2, NOW(), NOW())",
        )
        .bind(user_id)
        .bind(format!("test-{}@example.com", user_id))
        .execute(&pool)
        .await?;

        // Create personal workspace
        let workspace_id = Uuid::new_v4();
        sqlx::query(
            "INSERT INTO public.app_workspace (id, name, workspace_type, created_at, updated_at) 
             VALUES ($1, $2, 'personal', NOW(), NOW())",
        )
        .bind(workspace_id)
        .bind("Test Workspace")
        .execute(&pool)
        .await?;

        // Add user as workspace member
        sqlx::query(
            "INSERT INTO public.app_workspace_member (workspace_id, user_id, role, created_at, updated_at) 
             VALUES ($1, $2, 'owner', NOW(), NOW())",
        )
        .bind(workspace_id)
        .bind(user_id)
        .execute(&pool)
        .await?;

        // Create project
        let project_id = Uuid::new_v4();
        sqlx::query(
            "INSERT INTO public.app_project (id, numeric_id, workspace_id, owner_user_id, name, created_at, updated_at) 
             VALUES ($1, $2, $3, $4, $5, NOW(), NOW())",
        )
        .bind(project_id)
        .bind(1)
        .bind(workspace_id)
        .bind(user_id)
        .bind("Test Project")
        .execute(&pool)
        .await?;

        // Test with project_uuid in payload
        let payload = json!({
            "project_uuid": project_id.to_string(),
        });

        let result = super::derive_workspace_from_job_payload(&pool, user_id, &payload)
            .await
            .map_err(|e| format!("{:?}", e))?;
        assert_eq!(result, Some(workspace_id));

        Ok(())
    }

    #[sqlx::test]
    #[ignore = "requires database setup"]
    async fn test_derive_workspace_from_job_payload_with_project_numeric_id(
        pool: sqlx::PgPool,
    ) -> Result<(), Box<dyn std::error::Error>> {
        // Create test user
        let user_id = Uuid::new_v4();
        sqlx::query(
            "INSERT INTO public.app_user (id, email, created_at, updated_at) 
             VALUES ($1, $2, NOW(), NOW())",
        )
        .bind(user_id)
        .bind(format!("test-{}@example.com", user_id))
        .execute(&pool)
        .await?;

        // Create personal workspace
        let workspace_id = Uuid::new_v4();
        sqlx::query(
            "INSERT INTO public.app_workspace (id, name, workspace_type, created_at, updated_at) 
             VALUES ($1, $2, 'personal', NOW(), NOW())",
        )
        .bind(workspace_id)
        .bind("Test Workspace")
        .execute(&pool)
        .await?;

        // Add user as workspace member
        sqlx::query(
            "INSERT INTO public.app_workspace_member (workspace_id, user_id, role, created_at, updated_at) 
             VALUES ($1, $2, 'owner', NOW(), NOW())",
        )
        .bind(workspace_id)
        .bind(user_id)
        .execute(&pool)
        .await?;

        // Create project
        let project_id = Uuid::new_v4();
        let project_numeric_id = 42;
        sqlx::query(
            "INSERT INTO public.app_project (id, numeric_id, workspace_id, owner_user_id, name, created_at, updated_at) 
             VALUES ($1, $2, $3, $4, $5, NOW(), NOW())",
        )
        .bind(project_id)
        .bind(project_numeric_id)
        .bind(workspace_id)
        .bind(user_id)
        .bind("Test Project")
        .execute(&pool)
        .await?;

        // Test with project_numeric_id in payload
        let payload = json!({
            "project_numeric_id": project_numeric_id,
        });

        let result = super::derive_workspace_from_job_payload(&pool, user_id, &payload)
            .await
            .map_err(|e| format!("{:?}", e))?;
        assert_eq!(result, Some(workspace_id));

        Ok(())
    }

    #[sqlx::test]
    #[ignore = "requires database setup"]
    async fn test_derive_workspace_from_job_payload_with_both_ids(
        pool: sqlx::PgPool,
    ) -> Result<(), Box<dyn std::error::Error>> {
        // Create test user
        let user_id = Uuid::new_v4();
        sqlx::query(
            "INSERT INTO public.app_user (id, email, created_at, updated_at) 
             VALUES ($1, $2, NOW(), NOW())",
        )
        .bind(user_id)
        .bind(format!("test-{}@example.com", user_id))
        .execute(&pool)
        .await?;

        // Create personal workspace
        let workspace_id = Uuid::new_v4();
        sqlx::query(
            "INSERT INTO public.app_workspace (id, name, workspace_type, created_at, updated_at) 
             VALUES ($1, $2, 'personal', NOW(), NOW())",
        )
        .bind(workspace_id)
        .bind("Test Workspace")
        .execute(&pool)
        .await?;

        // Add user as workspace member
        sqlx::query(
            "INSERT INTO public.app_workspace_member (workspace_id, user_id, role, created_at, updated_at) 
             VALUES ($1, $2, 'owner', NOW(), NOW())",
        )
        .bind(workspace_id)
        .bind(user_id)
        .execute(&pool)
        .await?;

        // Create project
        let project_id = Uuid::new_v4();
        let project_numeric_id = 99;
        sqlx::query(
            "INSERT INTO public.app_project (id, numeric_id, workspace_id, owner_user_id, name, created_at, updated_at) 
             VALUES ($1, $2, $3, $4, $5, NOW(), NOW())",
        )
        .bind(project_id)
        .bind(project_numeric_id)
        .bind(workspace_id)
        .bind(user_id)
        .bind("Test Project")
        .execute(&pool)
        .await?;

        // Test with both project_uuid and project_numeric_id in payload
        let payload = json!({
            "project_uuid": project_id.to_string(),
            "project_numeric_id": project_numeric_id,
        });

        let result = super::derive_workspace_from_job_payload(&pool, user_id, &payload)
            .await
            .map_err(|e| format!("{:?}", e))?;
        assert_eq!(result, Some(workspace_id));

        Ok(())
    }

    #[sqlx::test]
    #[ignore = "requires database setup"]
    async fn test_derive_workspace_from_job_payload_no_project_info(
        pool: sqlx::PgPool,
    ) -> Result<(), Box<dyn std::error::Error>> {
        let user_id = Uuid::new_v4();

        // Test with payload that has no project information
        let payload = json!({
            "some_other_field": "value",
        });

        let result = super::derive_workspace_from_job_payload(&pool, user_id, &payload)
            .await
            .map_err(|e| format!("{:?}", e))?;
        assert_eq!(result, None);

        Ok(())
    }

    #[sqlx::test]
    #[ignore = "requires database setup"]
    async fn test_derive_workspace_from_job_payload_project_not_found(
        pool: sqlx::PgPool,
    ) -> Result<(), Box<dyn std::error::Error>> {
        let user_id = Uuid::new_v4();
        let non_existent_project_id = Uuid::new_v4();

        // Test with non-existent project
        let payload = json!({
            "project_uuid": non_existent_project_id.to_string(),
        });

        let result = super::derive_workspace_from_job_payload(&pool, user_id, &payload)
            .await
            .map_err(|e| format!("{:?}", e))?;
        assert_eq!(result, None);

        Ok(())
    }

    #[sqlx::test]
    #[ignore = "requires database setup"]
    async fn test_derive_workspace_from_job_payload_not_workspace_member(
        pool: sqlx::PgPool,
    ) -> Result<(), Box<dyn std::error::Error>> {
        // Create project owner
        let owner_id = Uuid::new_v4();
        sqlx::query(
            "INSERT INTO public.app_user (id, email, created_at, updated_at) 
             VALUES ($1, $2, NOW(), NOW())",
        )
        .bind(owner_id)
        .bind(format!("owner-{}@example.com", owner_id))
        .execute(&pool)
        .await?;

        // Create workspace
        let workspace_id = Uuid::new_v4();
        sqlx::query(
            "INSERT INTO public.app_workspace (id, name, workspace_type, created_at, updated_at) 
             VALUES ($1, $2, 'personal', NOW(), NOW())",
        )
        .bind(workspace_id)
        .bind("Owner Workspace")
        .execute(&pool)
        .await?;

        // Add owner as workspace member
        sqlx::query(
            "INSERT INTO public.app_workspace_member (workspace_id, user_id, role, created_at, updated_at) 
             VALUES ($1, $2, 'owner', NOW(), NOW())",
        )
        .bind(workspace_id)
        .bind(owner_id)
        .execute(&pool)
        .await?;

        // Create project
        let project_id = Uuid::new_v4();
        sqlx::query(
            "INSERT INTO public.app_project (id, numeric_id, workspace_id, owner_user_id, name, created_at, updated_at) 
             VALUES ($1, $2, $3, $4, $5, NOW(), NOW())",
        )
        .bind(project_id)
        .bind(1)
        .bind(workspace_id)
        .bind(owner_id)
        .bind("Owner Project")
        .execute(&pool)
        .await?;

        // Create another user who is NOT a member of the workspace
        let other_user_id = Uuid::new_v4();
        sqlx::query(
            "INSERT INTO public.app_user (id, email, created_at, updated_at) 
             VALUES ($1, $2, NOW(), NOW())",
        )
        .bind(other_user_id)
        .bind(format!("other-{}@example.com", other_user_id))
        .execute(&pool)
        .await?;

        // Test with user who is not a workspace member
        let payload = json!({
            "project_uuid": project_id.to_string(),
        });

        let result = super::derive_workspace_from_job_payload(&pool, other_user_id, &payload)
            .await
            .map_err(|e| format!("{:?}", e))?;
        assert_eq!(result, None);

        Ok(())
    }

    #[sqlx::test]
    #[ignore = "requires database setup"]
    async fn test_derive_workspace_from_job_payload_archived_project(
        pool: sqlx::PgPool,
    ) -> Result<(), Box<dyn std::error::Error>> {
        // Create test user
        let user_id = Uuid::new_v4();
        sqlx::query(
            "INSERT INTO public.app_user (id, email, created_at, updated_at) 
             VALUES ($1, $2, NOW(), NOW())",
        )
        .bind(user_id)
        .bind(format!("test-{}@example.com", user_id))
        .execute(&pool)
        .await?;

        // Create workspace
        let workspace_id = Uuid::new_v4();
        sqlx::query(
            "INSERT INTO public.app_workspace (id, name, workspace_type, created_at, updated_at) 
             VALUES ($1, $2, 'personal', NOW(), NOW())",
        )
        .bind(workspace_id)
        .bind("Test Workspace")
        .execute(&pool)
        .await?;

        // Add user as workspace member
        sqlx::query(
            "INSERT INTO public.app_workspace_member (workspace_id, user_id, role, created_at, updated_at) 
             VALUES ($1, $2, 'owner', NOW(), NOW())",
        )
        .bind(workspace_id)
        .bind(user_id)
        .execute(&pool)
        .await?;

        // Create archived project
        let project_id = Uuid::new_v4();
        sqlx::query(
            "INSERT INTO public.app_project (id, numeric_id, workspace_id, owner_user_id, name, archived_at, created_at, updated_at) 
             VALUES ($1, $2, $3, $4, $5, NOW(), NOW(), NOW())",
        )
        .bind(project_id)
        .bind(1)
        .bind(workspace_id)
        .bind(user_id)
        .bind("Archived Project")
        .execute(&pool)
        .await?;

        // Test with archived project - should return error (Forbidden)
        let payload = json!({
            "project_uuid": project_id.to_string(),
        });

        let result = super::derive_workspace_from_job_payload(&pool, user_id, &payload).await;
        assert!(result.is_err());
        if let Err(e) = result {
            assert!(matches!(e, crate::error::ApiError::Forbidden(_)));
        }

        Ok(())
    }
}
