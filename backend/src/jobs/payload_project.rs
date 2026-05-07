//! Resolve project scope from **`app_generation_job.payload`** inside workers.
//!
//! Design note: repository **`docs/plans/assets-generate-job-payload-v2.md`**.

use serde_json::Value;
use sqlx::PgPool;
use uuid::Uuid;

use crate::assets::resolve_owned_project_numeric_from_uuid_or_legacy_id;
use crate::error::ApiError;
use crate::jobs::worker::JobRunError;

/// New enqueue paths for **`assets-generate/*`** dual-write **`project_uuid`** + **`project_numeric_id`**.
pub(crate) const ASSETS_GENERATE_PAYLOAD_SCHEMA_VERSION_V2: i64 = 2;

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
    let project_uuid = payload
        .get("project_uuid")
        .and_then(|v| v.as_str())
        .and_then(|s| Uuid::parse_str(s.trim()).ok());
    let project_numeric_id = payload
        .get("project_numeric_id")
        .and_then(|x| x.as_i64())
        .and_then(|n| i32::try_from(n).ok());

    resolve_owned_project_numeric_from_uuid_or_legacy_id(
        pool,
        actor_user_id,
        project_uuid,
        project_numeric_id,
    )
    .await
    .map_err(api_error_to_job_run)
}
