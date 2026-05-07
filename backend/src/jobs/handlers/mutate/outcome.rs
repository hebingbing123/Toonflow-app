use axum::Json;
use uuid::Uuid;

use crate::error::ApiError;
use crate::jobs::dto::JobRow;
use crate::jobs::enqueue::envelope_generation_job_updated;
use crate::jobs::hydrate_job_row;
use crate::state::AppState;

pub(super) async fn resolve_job_mutation_outcome(
    state: &AppState,
    pool: &sqlx::PgPool,
    uid: Uuid,
    id: Uuid,
    updated: Option<JobRow>,
    conflict_message: &'static str,
) -> Result<Json<JobRow>, ApiError> {
    if let Some(mut row) = updated {
        hydrate_job_row(&mut row);
        let text = envelope_generation_job_updated(&row);
        state.notify.broadcast_to_user(uid, text).await;
        return Ok(Json(row));
    }

    let exists: bool = sqlx::query_scalar(
        r#"
        SELECT EXISTS(
          SELECT 1
          FROM app_generation_job
          WHERE id = $1
            AND (
              owner_user_id = $2
              OR EXISTS (
                SELECT 1
                FROM app_project p
                INNER JOIN app_workspace_member wm ON wm.workspace_id = p.workspace_id
                WHERE wm.user_id = $2
                  AND (app_generation_job.payload->>'project_numeric_id') ~ '^[0-9]+$'
                  AND p.numeric_id = (app_generation_job.payload->>'project_numeric_id')::int
              )
            )
        )
        "#,
    )
    .bind(id)
    .bind(uid)
    .fetch_one(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    if !exists {
        return Err(ApiError::NotFound);
    }

    Err(ApiError::Conflict(conflict_message.into()))
}
