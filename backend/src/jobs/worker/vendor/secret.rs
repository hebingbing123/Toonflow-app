use sqlx::PgPool;
use uuid::Uuid;

use crate::vendor::credential::decrypt;

use super::super::JobRunError;

#[derive(sqlx::FromRow)]
struct VendorCredentialProbeRow {
    api_key_encrypted: Option<Vec<u8>>,
    api_secret_encrypted: Option<Vec<u8>>,
    api_token_encrypted: Option<Vec<u8>>,
}

pub(super) async fn load_vendor_probe_secret(
    pool: &PgPool,
    owner_user_id: Uuid,
    candidates: &[String],
) -> Result<Option<String>, JobRunError> {
    for vendor_id in candidates {
        let row = sqlx::query_as::<_, VendorCredentialProbeRow>(
            r#"
            SELECT api_key_encrypted, api_secret_encrypted, api_token_encrypted
            FROM app_vendor_credential
            WHERE owner_user_id = $1 AND vendor_id = $2
            "#,
        )
        .bind(owner_user_id)
        .bind(vendor_id)
        .fetch_optional(pool)
        .await
        .map_err(|e| JobRunError::Failed(e.to_string()))?;

        let Some(row) = row else {
            continue;
        };

        for encrypted in [
            row.api_key_encrypted.as_deref(),
            row.api_token_encrypted.as_deref(),
            row.api_secret_encrypted.as_deref(),
        ]
        .into_iter()
        .flatten()
        {
            if let Some(value) = decrypt(encrypted) {
                let trimmed = value.trim();
                if !trimmed.is_empty() {
                    return Ok(Some(trimmed.to_string()));
                }
            }
        }
    }

    Ok(None)
}
