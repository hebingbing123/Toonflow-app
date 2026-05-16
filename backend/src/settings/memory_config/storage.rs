use sqlx::types::Json as SqlxJson;

use crate::error::ApiError;
use crate::state::MemoryConfig;

pub(super) async fn load_memory_config(
    pool: &sqlx::PgPool,
    uid: uuid::Uuid,
    defaults: MemoryConfig,
) -> Result<MemoryConfig, ApiError> {
    let row: Option<(Option<SqlxJson<MemoryConfig>>,)> =
        sqlx::query_as(r#"SELECT memory_config FROM app_user_profile WHERE user_id = $1"#)
            .bind(uid)
            .fetch_optional(pool)
            .await
            .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    Ok(row.and_then(|r| r.0).map(|j| j.0).unwrap_or(defaults))
}

pub(super) async fn save_memory_config(
    pool: &sqlx::PgPool,
    uid: uuid::Uuid,
    cfg: &MemoryConfig,
) -> Result<(), ApiError> {
    let cfg_json = SqlxJson(cfg.clone());
    sqlx::query(
        r#"
        INSERT INTO app_user_profile (user_id, memory_config, updated_at)
        VALUES ($1, $2, NOW())
        ON CONFLICT (user_id) DO UPDATE SET memory_config = EXCLUDED.memory_config, updated_at = NOW()
        "#,
    )
    .bind(uid)
    .bind(cfg_json)
    .execute(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;
    Ok(())
}
