use sqlx::PgPool;
use uuid::Uuid;

use crate::assets::{resolve_asset_id_for_job, resolve_owned_script_linked_asset_row_for_job};
use crate::jobs::worker::common::JobRunError;

use super::super::payload::AssetImageGenCtx;
use super::persist::generate_and_store_asset_image_for_row;

pub(crate) async fn generate_and_store_asset_image(
    ctx: &AssetImageGenCtx<'_>,
    project_numeric_id: i32,
    asset_numeric_id: i32,
    name: &str,
    prompt: &str,
    image_base64: Option<&str>,
) -> Result<serde_json::Value, JobRunError> {
    let asset_id =
        resolve_asset_id_for_job(ctx.pool, ctx.owner, project_numeric_id, asset_numeric_id)
            .await
            .map_err(|e| JobRunError::Failed(e.to_string()))?
            .ok_or_else(|| {
                JobRunError::Failed("asset not found for project or not owned".into())
            })?;

    generate_and_store_asset_image_for_row(
        ctx,
        asset_id,
        asset_numeric_id,
        name,
        prompt,
        image_base64,
    )
    .await
}

pub(crate) async fn ensure_script_scoped_asset_exists(
    pool: &PgPool,
    owner_user_id: Uuid,
    project_numeric_id: i32,
    script_numeric_id: i32,
    asset_numeric_id: i32,
) -> Result<(), JobRunError> {
    resolve_owned_script_linked_asset_row_for_job(
        pool,
        owner_user_id,
        project_numeric_id,
        script_numeric_id,
        asset_numeric_id,
    )
    .await
    .map_err(|e| JobRunError::Failed(e.to_string()))?
    .ok_or_else(|| {
        JobRunError::Failed(
            "asset.generate.batch items: asset not linked to script (script_id in payload)".into(),
        )
    })?;
    Ok(())
}
