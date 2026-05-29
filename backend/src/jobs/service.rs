//! Job creation service layer (rebuild plan P0-5 pilot).

use axum::http::HeaderMap;
use sqlx::PgPool;
use uuid::Uuid;

use crate::error::ApiError;
use crate::jobs::billing_workspace::resolve_billing_workspace_id;
use crate::jobs::dto::JobRow;
use crate::jobs::idempotency::compose_workspace_idempotency_key;
use crate::jobs::payload_project::{
    normalize_project_scope_in_job_payload, resolved_workspace_id_from_job_payload,
};
use crate::jobs::{
    hydrate_job_row, merge_client_request_id_from_http_headers, merge_default_track_metadata,
};
use crate::metering::quota;
use crate::metering::usage;
use crate::state::AppState;

use super::repository::JobRepository;

fn is_unique_violation(e: &sqlx::Error) -> bool {
    e.as_database_error()
        .and_then(|db| db.code())
        .is_some_and(|code| code == "23505")
}

pub struct JobCreationService;

impl JobCreationService {
    pub async fn create_with_idempotency(
        state: &AppState,
        pool: &PgPool,
        owner_user_id: Uuid,
        kind: &str,
        mut payload: serde_json::Value,
        headers: &HeaderMap,
        client_idempotency_key: Option<String>,
    ) -> Result<JobRow, ApiError> {
        merge_client_request_id_from_http_headers(headers, &mut payload);
        merge_default_track_metadata(kind, &mut payload);

        let resolved_workspace_id =
            normalize_project_scope_in_job_payload(pool, owner_user_id, &mut payload).await?;
        let billing_workspace_id =
            resolve_billing_workspace_id(pool, owner_user_id, resolved_workspace_id).await?;

        let stored_idempotency_key = client_idempotency_key
            .as_ref()
            .map(|key| compose_workspace_idempotency_key(billing_workspace_id, key));

        if let Some(ref key) = stored_idempotency_key {
            if let Some(mut row) =
                JobRepository::find_by_idempotency_key(pool, owner_user_id, key).await?
            {
                hydrate_job_row(&mut row);
                return Ok(row);
            }
        }

        quota::check_daily_job_quota_with_context(
            pool,
            owner_user_id,
            billing_workspace_id,
            &state.billing_config,
        )
        .await?;

        let insert = sqlx::query_as::<_, JobRow>(
            r#"
            INSERT INTO app_generation_job (owner_user_id, kind, payload, status, idempotency_key, workspace_id)
            VALUES ($1, $2, $3, 'queued', $4, $5)
            RETURNING numeric_task_id, id, owner_user_id, kind, status, payload, result,
                      error_message, error_details, idempotency_key, claimed_by, created_at, updated_at
            "#,
        )
        .bind(owner_user_id)
        .bind(kind)
        .bind(payload)
        .bind(stored_idempotency_key.clone())
        .bind(billing_workspace_id)
        .fetch_one(pool)
        .await;

        let mut row = match insert {
            Ok(r) => r,
            Err(e) if is_unique_violation(&e) => {
                let Some(key) = stored_idempotency_key.as_ref() else {
                    return Err(ApiError::DatabaseError(e.to_string()));
                };
                let mut r = JobRepository::find_by_idempotency_key(pool, owner_user_id, key)
                    .await?
                    .ok_or_else(|| {
                        ApiError::DatabaseError("idempotency conflict but row not found".into())
                    })?;
                hydrate_job_row(&mut r);
                return Ok(r);
            }
            Err(e) => return Err(ApiError::DatabaseError(e.to_string())),
        };

        hydrate_job_row(&mut row);

        if let Some(workspace_id) =
            resolved_workspace_id.or_else(|| resolved_workspace_id_from_job_payload(&row.payload))
        {
            tracing::info!(
                event = "generation_job_enqueued",
                user_id = %owner_user_id,
                job_id = %row.id,
                kind = %row.kind,
                workspace_id = %workspace_id,
                billing_workspace_id = %billing_workspace_id,
                "generation job enqueued via service layer"
            );
        }

        if let Err(e) =
            usage::record_generation_job_created(pool, owner_user_id, row.id, &row.kind).await
        {
            tracing::warn!(
                error = %e,
                job_id = %row.id,
                "app_usage_event insert failed for generation_job.created (job still created)"
            );
        }
        Ok(row)
    }
}
