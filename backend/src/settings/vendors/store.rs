use sqlx::PgPool;
use uuid::Uuid;

use crate::error::ApiError;
use crate::state::VendorConfig;

pub(super) async fn load_vendor_config(pool: &PgPool, uid: Uuid) -> Result<VendorConfig, ApiError> {
    let row: Option<sqlx::types::Json<VendorConfig>> = sqlx::query_scalar(
        r#"
        SELECT vendor_config FROM app_user_profile WHERE user_id = $1
        "#,
    )
    .bind(uid)
    .fetch_optional(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;
    Ok(row.map(|j| j.0).unwrap_or_default())
}

pub(super) async fn save_vendor_config(
    pool: &PgPool,
    uid: Uuid,
    cfg: &VendorConfig,
) -> Result<(), ApiError> {
    sqlx::query(
        r#"
        INSERT INTO app_user_profile (user_id, vendor_config)
        VALUES ($1, $2)
        ON CONFLICT (user_id) DO UPDATE SET vendor_config = $2
        "#,
    )
    .bind(uid)
    .bind(sqlx::types::Json(cfg))
    .execute(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;
    Ok(())
}
