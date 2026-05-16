//! 将单集提取标记为失败（`extract_state = -1`）。

use sqlx::PgPool;
use uuid::Uuid;

use crate::scope;

pub(super) async fn mark_script_failed(
    pool: &PgPool,
    project_uuid: Uuid,
    uid: Uuid,
    script_numeric_id: i32,
    reason: &str,
) -> Result<(), String> {
    let Ok(oip) = scope::owned_script_in_project(pool, uid, project_uuid, script_numeric_id).await
    else {
        return Ok(());
    };
    sqlx::query(
        r#"
        UPDATE app_script
        SET extract_state = -1, error_reason = $2, updated_at = NOW()
        WHERE id = $1
        "#,
    )
    .bind(oip.script_id)
    .bind(reason)
    .execute(pool)
    .await
    .map_err(|e| e.to_string())?;
    Ok(())
}
