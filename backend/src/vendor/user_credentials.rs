//! Load per-user vendor API keys from `app_vendor_credential` (encrypted at rest).

use sqlx::PgPool;
use uuid::Uuid;

use crate::vendor::catalog::lookup_vendor_catalog;
use crate::vendor::credential::decrypt;

#[derive(sqlx::FromRow)]
struct VendorCredentialRow {
    api_key_encrypted: Option<Vec<u8>>,
    api_secret_encrypted: Option<Vec<u8>>,
    api_token_encrypted: Option<Vec<u8>>,
}

fn push_vendor_candidate(out: &mut Vec<String>, raw: &str) {
    let trimmed = raw.trim();
    if trimmed.is_empty() {
        return;
    }
    if out.iter().any(|v| v == trimmed) {
        return;
    }
    out.push(trimmed.to_string());
    if let Some(vendor) = lookup_vendor_catalog(trimmed) {
        push_vendor_candidate(out, &vendor.numeric_id.to_string());
        push_vendor_candidate(out, &vendor.slug);
    }
}

/// Expand a vendor id / slug / numeric id into lookup keys for `app_vendor_credential.vendor_id`.
pub fn expand_vendor_id_candidates(raw_vendor_id: &str) -> Vec<String> {
    let mut out = Vec::new();
    push_vendor_candidate(&mut out, raw_vendor_id);
    out
}

/// Decrypted key + secret (+ token) for the first matching credential row.
pub async fn load_stored_vendor_credentials(
    pool: &PgPool,
    owner_user_id: Uuid,
    vendor_id_candidates: &[String],
) -> Result<Option<StoredVendorCredentials>, String> {
    for vendor_id in vendor_id_candidates {
        let row = sqlx::query_as::<_, VendorCredentialRow>(
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
        .map_err(|e| e.to_string())?;

        let Some(row) = row else {
            continue;
        };

        let api_key = row
            .api_key_encrypted
            .as_deref()
            .and_then(decrypt)
            .map(|s| s.trim().to_string())
            .filter(|s| !s.is_empty());
        let api_secret = row
            .api_secret_encrypted
            .as_deref()
            .and_then(decrypt)
            .map(|s| s.trim().to_string())
            .filter(|s| !s.is_empty());
        let api_token = row
            .api_token_encrypted
            .as_deref()
            .and_then(decrypt)
            .map(|s| s.trim().to_string())
            .filter(|s| !s.is_empty());

        if api_key.is_some() || api_secret.is_some() || api_token.is_some() {
            return Ok(Some(StoredVendorCredentials {
                api_key,
                api_secret,
                api_token,
            }));
        }
    }
    Ok(None)
}

#[derive(Debug, Clone, Default)]
pub struct StoredVendorCredentials {
    pub api_key: Option<String>,
    pub api_secret: Option<String>,
    pub api_token: Option<String>,
}

/// Decrypted API key for the first matching stored credential row.
pub async fn load_stored_vendor_api_key(
    pool: &PgPool,
    owner_user_id: Uuid,
    vendor_id_candidates: &[String],
) -> Result<Option<String>, String> {
    for vendor_id in vendor_id_candidates {
        let Some(stored) =
            load_stored_vendor_credentials(pool, owner_user_id, std::slice::from_ref(vendor_id))
                .await?
        else {
            continue;
        };
        for value in [
            stored.api_key.as_deref(),
            stored.api_token.as_deref(),
            stored.api_secret.as_deref(),
        ] {
            if let Some(trimmed) = value.map(str::trim).filter(|s| !s.is_empty()) {
                return Ok(Some(trimmed.to_string()));
            }
        }
    }

    Ok(None)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn expand_vendor_id_includes_numeric_slug_and_aliases() {
        let ids = expand_vendor_id_candidates("16");
        assert!(ids.contains(&"16".to_string()));
        let ids_slug = expand_vendor_id_candidates("anthropic");
        assert!(ids_slug.iter().any(|v| v == "16"));
    }

    #[test]
    fn expand_vendor_id_dedupes() {
        let ids = expand_vendor_id_candidates("8");
        let eight = ids.iter().filter(|v| v.as_str() == "8").count();
        assert_eq!(eight, 1);
    }
}
