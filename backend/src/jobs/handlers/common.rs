use axum::http::HeaderMap;
use uuid::Uuid;

use crate::error::{bad_request_i18n, ApiError};
use crate::jobs::dto::JobRow;
use crate::jobs::hydrate_job_row;

pub(crate) fn require_pool(state: &crate::state::AppState) -> Result<&sqlx::PgPool, ApiError> {
    state.require_pool()
}

pub(crate) fn idempotency_key_header(headers: &HeaderMap) -> Option<String> {
    headers
        .get("idempotency-key")
        .and_then(|v| v.to_str().ok())
        .map(str::trim)
        .filter(|s| !s.is_empty())
        .map(|s| s.chars().take(200).collect())
}

pub(crate) fn trim_query_opt(s: Option<String>) -> Option<String> {
    s.and_then(|v| {
        let t = v.trim();
        if t.is_empty() {
            None
        } else {
            Some(t.to_owned())
        }
    })
}

pub(crate) fn normalize_job_list_status_filter(
    raw: Option<String>,
) -> Result<Option<String>, ApiError> {
    let Some(s) = trim_query_opt(raw) else {
        return Ok(None);
    };
    let s = s.to_ascii_lowercase();
    if matches!(
        s.as_str(),
        "queued" | "running" | "succeeded" | "failed" | "cancelled"
    ) {
        Ok(Some(s))
    } else {
        Err(bad_request_i18n(
            "status must be one of: queued, running, succeeded, failed, cancelled",
            "status 必须是以下之一：queued、running、succeeded、failed、cancelled",
        ))
    }
}

pub(crate) fn list_jobs_limit_offset(
    limit: Option<i64>,
    offset: Option<i64>,
) -> Result<(i64, i64), ApiError> {
    let limit = match limit {
        None => 100,
        Some(x) if (1..=100).contains(&x) => x,
        Some(_) => {
            return Err(bad_request_i18n(
                "limit must be between 1 and 100",
                "limit 必须在 1 到 100 之间",
            ));
        }
    };
    let offset = offset.unwrap_or(0);
    if offset < 0 {
        return Err(bad_request_i18n(
            "offset must be greater than or equal to 0",
            "offset 必须大于或等于 0",
        ));
    }
    Ok((limit, offset))
}

pub(crate) fn normalize_task_page_project_filter(project_id: Option<i32>) -> Option<String> {
    project_id
        .filter(|id| *id > 0)
        .map(|id| id.to_string())
        .filter(|s| !s.is_empty())
}

pub(crate) fn workspace_visibility_clause() -> &'static str {
    r#"
        (
            app_generation_job.owner_user_id = $1
            OR EXISTS (
                SELECT 1
                FROM app_project p
                INNER JOIN app_workspace_member wm ON wm.workspace_id = p.workspace_id
                WHERE wm.user_id = $1
                  AND (
                    (app_generation_job.payload->>'project_uuid' IS NOT NULL
                     AND p.id::text = app_generation_job.payload->>'project_uuid')
                    OR
                    (app_generation_job.payload->>'project_numeric_id' IS NOT NULL
                     AND (app_generation_job.payload->>'project_numeric_id') ~ '^[0-9]+$'
                     AND p.numeric_id = (app_generation_job.payload->>'project_numeric_id')::int)
                  )
                  AND p.archived_at IS NULL
            )
        )
    "#
}

pub(crate) fn payload_matches_project_numeric_clause(project_bind: &str) -> String {
    format!(
        r#"
        (
          (payload->>'project_uuid' IS NOT NULL AND EXISTS (
            SELECT 1
            FROM app_project p
            WHERE p.id::text = payload->>'project_uuid'
              AND p.numeric_id::text = {project_bind}
          ))
          OR
          (payload->>'project_numeric_id' IS NOT NULL
           AND payload->>'project_numeric_id' = {project_bind})
        )
        "#
    )
}

pub(crate) async fn ensure_workspace_member_project_numeric_access(
    pool: &sqlx::PgPool,
    uid: Uuid,
    project_numeric_id: &str,
) -> Result<(), ApiError> {
    let has_project_access: bool = sqlx::query_scalar(
        r#"
        SELECT EXISTS (
          SELECT 1
          FROM app_project p
          INNER JOIN app_workspace_member wm ON wm.workspace_id = p.workspace_id
          WHERE p.numeric_id::text = $1
            AND wm.user_id = $2
        )
        "#,
    )
    .bind(project_numeric_id)
    .bind(uid)
    .fetch_one(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;
    if !has_project_access {
        return Err(ApiError::NotFound);
    }
    Ok(())
}

pub(crate) fn job_status_allows_retry(status: &str) -> bool {
    status.eq_ignore_ascii_case("failed")
}

pub(crate) fn compute_task_page_offset(page: i32, limit: i32) -> i64 {
    i64::from(page - 1) * i64::from(limit)
}

pub(crate) async fn fetch_job_by_numeric_task_id(
    pool: &sqlx::PgPool,
    uid: Uuid,
    numeric_task_id: i64,
) -> Result<JobRow, ApiError> {
    // First fetch the job without permission check to get the payload
    let mut row = sqlx::query_as::<_, JobRow>(
        r#"
        SELECT numeric_task_id, id, owner_user_id, kind, status, payload, result, error_message, error_details, idempotency_key, claimed_by, created_at, updated_at
        FROM app_generation_job
        WHERE numeric_task_id = $1
        "#,
    )
    .bind(numeric_task_id)
    .fetch_optional(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?
    .ok_or(ApiError::NotFound)?;

    // If user is the job owner, grant access immediately
    if row.owner_user_id == uid {
        hydrate_job_row(&mut row);
        return Ok(row);
    }

    // Otherwise, check workspace membership via derive_workspace_from_job_payload
    let workspace_id =
        crate::jobs::payload_project::derive_workspace_from_job_payload(pool, uid, &row.payload)
            .await?;

    // If derive_workspace_from_job_payload returns None, the user doesn't have access
    // Return 404 (not 403) to maintain security
    if workspace_id.is_none() {
        return Err(ApiError::NotFound);
    }

    hydrate_job_row(&mut row);
    Ok(row)
}

/// Validates that the user has access to a job based on workspace membership.
/// Returns 404 (not 403) when user doesn't have access to maintain security.
///
/// Access is granted if:
/// - User is the job owner, OR
/// - Job is associated with a project in a workspace where user is a member
///
/// Excludes archived projects from workspace member access.
pub(crate) async fn require_job_access(
    pool: &sqlx::PgPool,
    uid: Uuid,
    job_id: Uuid,
) -> Result<JobRow, ApiError> {
    // First fetch the job without permission check to get the payload
    let mut row = sqlx::query_as::<_, JobRow>(
        r#"
        SELECT numeric_task_id, id, owner_user_id, kind, status, payload, result, error_message, error_details, idempotency_key, claimed_by, created_at, updated_at
        FROM app_generation_job
        WHERE id = $1
        "#,
    )
    .bind(job_id)
    .fetch_optional(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?
    .ok_or(ApiError::NotFound)?;

    // If user is the job owner, grant access immediately
    if row.owner_user_id == uid {
        hydrate_job_row(&mut row);
        return Ok(row);
    }

    // Otherwise, check workspace membership via derive_workspace_from_job_payload
    let workspace_id =
        crate::jobs::payload_project::derive_workspace_from_job_payload(pool, uid, &row.payload)
            .await?;

    // If derive_workspace_from_job_payload returns None, the user doesn't have access
    // Return 404 (not 403) to maintain security
    if workspace_id.is_none() {
        return Err(ApiError::NotFound);
    }

    hydrate_job_row(&mut row);
    Ok(row)
}

pub(crate) async fn fetch_job_by_id(
    pool: &sqlx::PgPool,
    uid: Uuid,
    id: Uuid,
) -> Result<JobRow, ApiError> {
    require_job_access(pool, uid, id).await
}

#[cfg(test)]
mod tests {
    use super::job_status_allows_retry;
    use proptest::prelude::*;

    proptest! {
        #![proptest_config(ProptestConfig::with_cases(20))]

        // Feature: drama-platform-completion, Property 15: 失败任务重试资格
        // 验证：需求 18.3
        #[test]
        fn prop_only_failed_jobs_are_retry_eligible(
            failed_variant in prop_oneof![
                Just("failed".to_string()),
                Just("FAILED".to_string()),
                Just("Failed".to_string()),
            ],
            other_status in prop_oneof![
                Just("queued".to_string()),
                Just("running".to_string()),
                Just("succeeded".to_string()),
                Just("cancelled".to_string()),
                "[a-z_]{3,16}".prop_filter("exclude failed", |value| !value.eq_ignore_ascii_case("failed")),
            ],
        ) {
            prop_assert!(job_status_allows_retry(&failed_variant));
            prop_assert!(!job_status_allows_retry(&other_status));
        }
    }
}
