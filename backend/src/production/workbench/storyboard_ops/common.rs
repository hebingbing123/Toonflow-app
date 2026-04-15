use crate::error::ApiError;
use crate::production::workbench::common as workbench_common;
use crate::state::AppState;

pub(super) fn require_positive_project_script_ids(
    project_id: i32,
    script_id: i32,
) -> Result<(), ApiError> {
    workbench_common::require_positive_project_script(project_id, script_id)
}

pub(super) fn require_pool(state: &AppState) -> Result<&sqlx::PgPool, ApiError> {
    workbench_common::require_pool(state)
}

pub(super) async fn ensure_owned_storyboards(
    pool: &sqlx::PgPool,
    script_id: uuid::Uuid,
    storyboard_ids: &[i32],
) -> Result<(), ApiError> {
    let owned_count = sqlx::query_scalar::<_, i64>(
        r#"
        SELECT COUNT(*)::bigint
        FROM app_storyboard sb
        WHERE sb.script_id = $1
          AND sb.numeric_id = ANY($2::int4[])
        "#,
    )
    .bind(script_id)
    .bind(storyboard_ids)
    .fetch_one(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    if owned_count != storyboard_ids.len() as i64 {
        return Err(ApiError::NotFound);
    }
    Ok(())
}
