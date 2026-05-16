use axum::{extract::State, http::HeaderMap, Json};

use crate::auth::require_user_uuid;
use crate::error::ApiError;
use crate::jobs::billing_workspace::resolve_billing_workspace_id;
use crate::jobs::dto::{CreateJobBody, JobRow};
use crate::jobs::payload_project::{
    normalize_project_scope_in_job_payload, resolved_workspace_id_from_job_payload,
};
use crate::jobs::{
    hydrate_job_row, merge_client_request_id_from_http_headers, merge_default_track_metadata,
};
use crate::metering::quota;
use crate::metering::usage;
use crate::state::AppState;

use super::super::common::{idempotency_key_header, is_unique_violation, require_pool};

/// Validates workspace member access when creating jobs with project fields in payload.
///
/// This validation is performed by `normalize_project_scope_in_job_payload` which:
/// 1. Extracts `project_uuid` and/or `project_numeric_id` from the payload
/// 2. Validates that the project exists and is not archived
/// 3. Validates that the user is a workspace member of the project's workspace
/// 4. Returns 404 (not 403) when user doesn't have access to maintain security
/// 5. Normalizes the payload with correct `project_uuid`, `project_numeric_id`, and `workspace_id`
///
/// Jobs without project fields (personal jobs) are allowed without validation.
///
/// See: Task W2.6 in platform-completion-phase2 spec

#[utoipa::path(
    post,
    path = "/api/v1/jobs",
    operation_id = "createJobV1",
    tag = "jobs",
    description = "Create a new job with workspace membership validation for project-associated jobs.

## Workspace Membership Validation

When creating a job with project scope fields in the payload (`project_uuid` preferred, `project_numeric_id` legacy fallback), the endpoint validates:

1. **Project exists**: The project must exist and not be archived
2. **Workspace membership**: The user must be a member of the project's workspace
3. **Payload normalization**: The payload is normalized with correct `project_uuid`, `project_numeric_id`, and `workspace_id`

### Personal Jobs

Jobs without project fields (no `project_uuid` or `project_numeric_id` in payload) are **personal jobs** and do not require workspace membership validation.

### Access Denied

If the user is not a workspace member of the project, the endpoint returns 404 Not Found (not 403 Forbidden) to maintain security by not revealing the existence of projects the user cannot access.

### Archived Projects

Attempting to create a job for an archived project returns 403 Forbidden.

## Visibility After Creation

Once created, the job follows the standard visibility rules:
- **Owner visibility**: Always visible to the job owner
- **Workspace member visibility**: Visible to workspace members if associated with a project",
    request_body(content = serde_json::Value, content_type = "application/json"),
    responses(
        (status = 200, description = "OK", body = serde_json::Value),
        (status = 400, description = "Bad request", body = crate::error::ErrorBody),
        (status = 401, description = "Unauthorized", body = crate::error::ErrorBody),
        (status = 403, description = "Forbidden", body = crate::error::ErrorBody),
        (status = 404, description = "Not found", body = crate::error::ErrorBody),
        (status = 409, description = "Conflict", body = crate::error::ErrorBody),
        (status = 429, description = "Too many requests", body = crate::error::ErrorBody),
        (status = 500, description = "Server error", body = crate::error::ErrorBody),
        (status = 503, description = "Unavailable", body = crate::error::ErrorBody)
    ),
    security(("bearerAuth" = []))
)]
pub(crate) async fn create_job(
    State(state): State<AppState>,
    headers: HeaderMap,
    Json(body): Json<CreateJobBody>,
) -> Result<Json<JobRow>, ApiError> {
    let uid = require_user_uuid(&state, &headers)?;
    let pool = require_pool(&state)?;
    let kind = body.kind.trim();
    if kind.is_empty() {
        return Err(ApiError::BadRequest("kind must not be empty".into()));
    }

    let idem = idempotency_key_header(&headers);
    if let Some(ref key) = idem {
        if let Some(mut row) = sqlx::query_as::<_, JobRow>(
            r#"
            SELECT numeric_task_id, id, owner_user_id, kind, status, payload, result, error_message, error_details, idempotency_key, claimed_by, created_at, updated_at
            FROM app_generation_job
            WHERE owner_user_id = $1 AND idempotency_key = $2
            "#,
        )
        .bind(uid)
        .bind(key)
        .fetch_optional(pool)
        .await
        .map_err(|e| ApiError::DatabaseError(e.to_string()))?
        {
            hydrate_job_row(&mut row);
            return Ok(Json(row));
        }
    }

    let mut payload = body.payload;
    merge_client_request_id_from_http_headers(&headers, &mut payload);
    merge_default_track_metadata(kind, &mut payload);

    // Resolve workspace_id from project context (if applicable)
    let resolved_workspace_id =
        normalize_project_scope_in_job_payload(pool, uid, &mut payload).await?;

    // Canonical workspace_id resolution for billing attribution (Task 2.1)
    let billing_workspace_id =
        resolve_billing_workspace_id(pool, uid, resolved_workspace_id).await?;

    // Check quota with effective billing context (Task 3.3)
    quota::check_daily_job_quota_with_context(
        pool,
        uid,
        billing_workspace_id,
        &state.billing_config,
    )
    .await?;

    let insert = sqlx::query_as::<_, JobRow>(
        r#"
        INSERT INTO app_generation_job (owner_user_id, kind, payload, status, idempotency_key, workspace_id)
        VALUES ($1, $2, $3, 'queued', $4, $5)
        RETURNING numeric_task_id, id, owner_user_id, kind, status, payload, result, error_message, error_details, idempotency_key, claimed_by, created_at, updated_at
        "#,
    )
    .bind(uid)
    .bind(kind)
    .bind(payload)
    .bind(idem.clone())
    .bind(billing_workspace_id)
    .fetch_one(pool)
    .await;

    let mut row = match insert {
        Ok(r) => r,
        Err(e) if is_unique_violation(&e) => {
            let Some(key) = idem.as_ref() else {
                return Err(ApiError::DatabaseError(e.to_string()));
            };
            let mut r = sqlx::query_as::<_, JobRow>(
                r#"
                SELECT numeric_task_id, id, owner_user_id, kind, status, payload, result, error_message, error_details, idempotency_key, claimed_by, created_at, updated_at
                FROM app_generation_job
                WHERE owner_user_id = $1 AND idempotency_key = $2
                "#,
            )
            .bind(uid)
            .bind(key)
            .fetch_optional(pool)
            .await
            .map_err(|e| ApiError::DatabaseError(e.to_string()))?
            .ok_or_else(|| {
                ApiError::DatabaseError("idempotency conflict but row not found".into())
            })?;
            hydrate_job_row(&mut r);
            r
        }
        Err(e) => return Err(ApiError::DatabaseError(e.to_string())),
    };

    hydrate_job_row(&mut row);

    if let Some(workspace_id) =
        resolved_workspace_id.or_else(|| resolved_workspace_id_from_job_payload(&row.payload))
    {
        tracing::info!(
            event = "generation_job_enqueued",
            user_id = %uid,
            job_id = %row.id,
            kind = %row.kind,
            workspace_id = %workspace_id,
            billing_workspace_id = %billing_workspace_id,
            client_request_id = row
                .payload
                .get("client_request_id")
                .or_else(|| row.payload.get("request_id"))
                .and_then(|v| v.as_str())
                .unwrap_or(""),
            "generation job enqueued"
        );
    } else {
        tracing::info!(
            event = "generation_job_enqueued",
            user_id = %uid,
            job_id = %row.id,
            kind = %row.kind,
            billing_workspace_id = %billing_workspace_id,
            client_request_id = row
                .payload
                .get("client_request_id")
                .or_else(|| row.payload.get("request_id"))
                .and_then(|v| v.as_str())
                .unwrap_or(""),
            "generation job enqueued (no project context)"
        );
    }

    if let Err(e) = usage::record_generation_job_created(pool, uid, row.id, &row.kind).await {
        tracing::warn!(
            error = %e,
            job_id = %row.id,
            "app_usage_event insert failed for generation_job.created (job still created)"
        );
    }

    Ok(Json(row))
}

#[cfg(test)]
mod tests {
    use super::*;
    use serde_json::json;
    use uuid::Uuid;

    /// Test W2.6: Validate workspace member access when creating jobs with project_uuid
    #[sqlx::test]
    #[ignore = "requires database setup"]
    async fn test_create_job_with_project_uuid_validates_workspace_membership(
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
             VALUES ($1, $2, 'enterprise', NOW(), NOW())",
        )
        .bind(workspace_id)
        .bind("Test Workspace")
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
        .bind("Test Project")
        .execute(&pool)
        .await?;

        // Create another user who is NOT a member of the workspace
        let outsider_id = Uuid::new_v4();
        sqlx::query(
            "INSERT INTO public.app_user (id, email, created_at, updated_at) 
             VALUES ($1, $2, NOW(), NOW())",
        )
        .bind(outsider_id)
        .bind(format!("outsider-{}@example.com", outsider_id))
        .execute(&pool)
        .await?;

        // Create personal workspace for outsider
        let outsider_workspace_id = Uuid::new_v4();
        sqlx::query(
            "INSERT INTO public.app_workspace (id, name, workspace_type, created_at, updated_at) 
             VALUES ($1, $2, 'personal', NOW(), NOW())",
        )
        .bind(outsider_workspace_id)
        .bind("Outsider Personal")
        .execute(&pool)
        .await?;

        sqlx::query(
            "INSERT INTO public.app_workspace_member (workspace_id, user_id, role, created_at, updated_at) 
             VALUES ($1, $2, 'owner', NOW(), NOW())",
        )
        .bind(outsider_workspace_id)
        .bind(outsider_id)
        .execute(&pool)
        .await?;

        // Test: Outsider tries to create job with project_uuid - should fail with 404
        let mut payload = json!({
            "project_uuid": project_id.to_string(),
            "some_data": "test"
        });

        let result = normalize_project_scope_in_job_payload(&pool, outsider_id, &mut payload).await;

        assert!(result.is_err());
        if let Err(e) = result {
            // Should return 404 (not 403) to maintain security
            assert!(matches!(e, ApiError::NotFound));
        }

        Ok(())
    }

    /// Test W2.6: Validate workspace member access when creating jobs with project_numeric_id
    #[sqlx::test]
    #[ignore = "requires database setup"]
    async fn test_create_job_with_project_numeric_id_validates_workspace_membership(
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
             VALUES ($1, $2, 'enterprise', NOW(), NOW())",
        )
        .bind(workspace_id)
        .bind("Test Workspace")
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
        let project_numeric_id = 42;
        sqlx::query(
            "INSERT INTO public.app_project (id, numeric_id, workspace_id, owner_user_id, name, created_at, updated_at) 
             VALUES ($1, $2, $3, $4, $5, NOW(), NOW())",
        )
        .bind(project_id)
        .bind(project_numeric_id)
        .bind(workspace_id)
        .bind(owner_id)
        .bind("Test Project")
        .execute(&pool)
        .await?;

        // Create another user who is NOT a member of the workspace
        let outsider_id = Uuid::new_v4();
        sqlx::query(
            "INSERT INTO public.app_user (id, email, created_at, updated_at) 
             VALUES ($1, $2, NOW(), NOW())",
        )
        .bind(outsider_id)
        .bind(format!("outsider-{}@example.com", outsider_id))
        .execute(&pool)
        .await?;

        // Create personal workspace for outsider
        let outsider_workspace_id = Uuid::new_v4();
        sqlx::query(
            "INSERT INTO public.app_workspace (id, name, workspace_type, created_at, updated_at) 
             VALUES ($1, $2, 'personal', NOW(), NOW())",
        )
        .bind(outsider_workspace_id)
        .bind("Outsider Personal")
        .execute(&pool)
        .await?;

        sqlx::query(
            "INSERT INTO public.app_workspace_member (workspace_id, user_id, role, created_at, updated_at) 
             VALUES ($1, $2, 'owner', NOW(), NOW())",
        )
        .bind(outsider_workspace_id)
        .bind(outsider_id)
        .execute(&pool)
        .await?;

        // Test: Outsider tries to create job with project_numeric_id - should fail with 404
        let mut payload = json!({
            "project_numeric_id": project_numeric_id,
            "some_data": "test"
        });

        let result = normalize_project_scope_in_job_payload(&pool, outsider_id, &mut payload).await;

        assert!(result.is_err());
        if let Err(e) = result {
            // Should return 404 (not 403) to maintain security
            assert!(matches!(e, ApiError::NotFound));
        }

        Ok(())
    }

    /// Test W2.6: Workspace member can create job with project fields
    #[sqlx::test]
    #[ignore = "requires database setup"]
    async fn test_create_job_with_project_allows_workspace_member(
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
             VALUES ($1, $2, 'enterprise', NOW(), NOW())",
        )
        .bind(workspace_id)
        .bind("Test Workspace")
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
        let project_numeric_id = 99;
        sqlx::query(
            "INSERT INTO public.app_project (id, numeric_id, workspace_id, owner_user_id, name, created_at, updated_at) 
             VALUES ($1, $2, $3, $4, $5, NOW(), NOW())",
        )
        .bind(project_id)
        .bind(project_numeric_id)
        .bind(workspace_id)
        .bind(owner_id)
        .bind("Test Project")
        .execute(&pool)
        .await?;

        // Create another user who IS a member of the workspace
        let member_id = Uuid::new_v4();
        sqlx::query(
            "INSERT INTO public.app_user (id, email, created_at, updated_at) 
             VALUES ($1, $2, NOW(), NOW())",
        )
        .bind(member_id)
        .bind(format!("member-{}@example.com", member_id))
        .execute(&pool)
        .await?;

        // Add member to workspace
        sqlx::query(
            "INSERT INTO public.app_workspace_member (workspace_id, user_id, role, created_at, updated_at) 
             VALUES ($1, $2, 'member', NOW(), NOW())",
        )
        .bind(workspace_id)
        .bind(member_id)
        .execute(&pool)
        .await?;

        // Test: Member can create job with project_uuid - should succeed
        let mut payload = json!({
            "project_uuid": project_id.to_string(),
            "some_data": "test"
        });

        let result = normalize_project_scope_in_job_payload(&pool, member_id, &mut payload).await;

        assert!(result.is_ok());
        let resolved_workspace = result.unwrap();
        assert_eq!(resolved_workspace, Some(workspace_id));

        // Verify payload was normalized with all project fields
        assert_eq!(
            payload.get("project_uuid").and_then(|v| v.as_str()),
            Some(project_id.to_string().as_str())
        );
        assert_eq!(
            payload.get("project_numeric_id").and_then(|v| v.as_i64()),
            Some(project_numeric_id as i64)
        );
        assert_eq!(
            payload
                .get("workspace_id")
                .and_then(|v| v.as_str())
                .and_then(|s| Uuid::parse_str(s).ok()),
            Some(workspace_id)
        );

        Ok(())
    }

    /// Test W2.6: Job creation without project fields (personal jobs) is allowed
    #[sqlx::test]
    #[ignore = "requires database setup"]
    async fn test_create_job_without_project_fields_allowed(
        pool: sqlx::PgPool,
    ) -> Result<(), Box<dyn std::error::Error>> {
        // Create user
        let user_id = Uuid::new_v4();
        sqlx::query(
            "INSERT INTO public.app_user (id, email, created_at, updated_at) 
             VALUES ($1, $2, NOW(), NOW())",
        )
        .bind(user_id)
        .bind(format!("user-{}@example.com", user_id))
        .execute(&pool)
        .await?;

        // Create personal workspace
        let workspace_id = Uuid::new_v4();
        sqlx::query(
            "INSERT INTO public.app_workspace (id, name, workspace_type, created_at, updated_at) 
             VALUES ($1, $2, 'personal', NOW(), NOW())",
        )
        .bind(workspace_id)
        .bind("Personal Workspace")
        .execute(&pool)
        .await?;

        sqlx::query(
            "INSERT INTO public.app_workspace_member (workspace_id, user_id, role, created_at, updated_at) 
             VALUES ($1, $2, 'owner', NOW(), NOW())",
        )
        .bind(workspace_id)
        .bind(user_id)
        .execute(&pool)
        .await?;

        // Test: User can create job without project fields - should succeed
        let mut payload = json!({
            "some_data": "test",
            "no_project": true
        });

        let result = normalize_project_scope_in_job_payload(&pool, user_id, &mut payload).await;

        assert!(result.is_ok());
        let resolved_workspace = result.unwrap();
        // Personal jobs have no workspace context
        assert_eq!(resolved_workspace, None);

        // Verify payload was not modified with project fields
        assert!(payload.get("project_uuid").is_none());
        assert!(payload.get("project_numeric_id").is_none());
        assert!(payload.get("workspace_id").is_none());

        Ok(())
    }

    /// Test W2.6: Archived project returns error
    #[sqlx::test]
    #[ignore = "requires database setup"]
    async fn test_create_job_with_archived_project_fails(
        pool: sqlx::PgPool,
    ) -> Result<(), Box<dyn std::error::Error>> {
        // Create user
        let user_id = Uuid::new_v4();
        sqlx::query(
            "INSERT INTO public.app_user (id, email, created_at, updated_at) 
             VALUES ($1, $2, NOW(), NOW())",
        )
        .bind(user_id)
        .bind(format!("user-{}@example.com", user_id))
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

        // Test: User tries to create job with archived project - should fail
        let mut payload = json!({
            "project_uuid": project_id.to_string(),
            "some_data": "test"
        });

        let result = normalize_project_scope_in_job_payload(&pool, user_id, &mut payload).await;

        assert!(result.is_err());
        if let Err(e) = result {
            // Archived projects should return Forbidden
            assert!(matches!(e, ApiError::Forbidden(_)));
        }

        Ok(())
    }

    /// Test W2.6: Non-existent project returns 404
    #[sqlx::test]
    #[ignore = "requires database setup"]
    async fn test_create_job_with_nonexistent_project_returns_404(
        pool: sqlx::PgPool,
    ) -> Result<(), Box<dyn std::error::Error>> {
        // Create user
        let user_id = Uuid::new_v4();
        sqlx::query(
            "INSERT INTO public.app_user (id, email, created_at, updated_at) 
             VALUES ($1, $2, NOW(), NOW())",
        )
        .bind(user_id)
        .bind(format!("user-{}@example.com", user_id))
        .execute(&pool)
        .await?;

        // Create personal workspace
        let workspace_id = Uuid::new_v4();
        sqlx::query(
            "INSERT INTO public.app_workspace (id, name, workspace_type, created_at, updated_at) 
             VALUES ($1, $2, 'personal', NOW(), NOW())",
        )
        .bind(workspace_id)
        .bind("Personal Workspace")
        .execute(&pool)
        .await?;

        sqlx::query(
            "INSERT INTO public.app_workspace_member (workspace_id, user_id, role, created_at, updated_at) 
             VALUES ($1, $2, 'owner', NOW(), NOW())",
        )
        .bind(workspace_id)
        .bind(user_id)
        .execute(&pool)
        .await?;

        // Test: User tries to create job with non-existent project - should fail with 404
        let non_existent_project_id = Uuid::new_v4();
        let mut payload = json!({
            "project_uuid": non_existent_project_id.to_string(),
            "some_data": "test"
        });

        let result = normalize_project_scope_in_job_payload(&pool, user_id, &mut payload).await;

        assert!(result.is_err());
        if let Err(e) = result {
            // Non-existent projects should return 404
            assert!(matches!(e, ApiError::NotFound));
        }

        Ok(())
    }
}
