use axum::Json;
use uuid::Uuid;

use crate::error::ApiError;
use crate::jobs::dto::JobRow;
use crate::jobs::enqueue::envelope_generation_job_updated;
use crate::jobs::handlers::common::workspace_visibility_clause;
use crate::jobs::hydrate_job_row;
use crate::jobs::record_job_notification;
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
        record_job_notification(state, &row).await?;
        let text = envelope_generation_job_updated(&row);
        state
            .notify
            .broadcast_to_user(row.owner_user_id, text)
            .await;
        return Ok(Json(row));
    }

    let exists: bool = sqlx::query_scalar(&format!(
        r#"
            SELECT EXISTS(
              SELECT 1
              FROM app_generation_job
              WHERE id = $1
                AND {}
            )
            "#,
        workspace_visibility_clause().replace("$1", "$2")
    ))
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
