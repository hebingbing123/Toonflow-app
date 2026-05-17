//! Enforce **`short-video-readiness`** gates before expensive generation work.

use sqlx::PgPool;
use uuid::Uuid;

use crate::error::ApiError;
use crate::short_video::storyboard_readiness::{
    enforce_storyboards_ready_for_generation, eval_from_row, load_script_storyboard_readiness,
};

/// Block video / prompt generation when storyboards fail readiness (**MP-W3 / cost guard**).
pub(crate) async fn assert_storyboards_ready_for_generation(
    pool: &PgPool,
    project_id: Uuid,
    owner_user_id: Uuid,
    script_numeric_id: i32,
    storyboard_numeric_ids: &[i32],
) -> Result<(), ApiError> {
    if storyboard_numeric_ids.is_empty() {
        return Ok(());
    }
    let rows = load_script_storyboard_readiness(
        pool,
        project_id,
        owner_user_id,
        script_numeric_id,
        Some(storyboard_numeric_ids),
    )
    .await?;
    let evaluations: Vec<_> = rows.iter().map(eval_from_row).collect();
    enforce_storyboards_ready_for_generation(&evaluations)
}
