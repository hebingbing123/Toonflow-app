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

/// New enqueue paths for **`assets-generate/*`** dual-write **`project_uuid`** + **`project_numeric_id`**.
pub(crate) const ASSETS_GENERATE_PAYLOAD_SCHEMA_VERSION_V2: i64 = 2;

fn payload_project_uuid(payload: &Value) -> Option<Uuid> {
    payload
        .get("project_uuid")
        .and_then(|v| v.as_str())
        .and_then(|s| Uuid::parse_str(s.trim()).ok())
}

fn payload_project_numeric_id(payload: &Value) -> Option<i32> {
    payload
        .get("project_numeric_id")
        .and_then(|x| x.as_i64())
        .and_then(|n| i32::try_from(n).ok())
}

fn payload_workspace_id(payload: &Value) -> Option<Uuid> {
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
        obj.insert(
            "project_numeric_id".into(),
            Value::Number(project_numeric_id.into()),
        );
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
}
