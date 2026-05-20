use sqlx::PgPool;
use uuid::Uuid;

use crate::vendor::user_credentials::load_stored_vendor_api_key;

use super::super::JobRunError;

pub(super) async fn load_vendor_probe_secret(
    pool: &PgPool,
    owner_user_id: Uuid,
    candidates: &[String],
) -> Result<Option<String>, JobRunError> {
    load_stored_vendor_api_key(pool, owner_user_id, candidates)
        .await
        .map_err(JobRunError::Failed)
}
