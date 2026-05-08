//! **WP‑C** Postgres stubs for **`app_harness_user_wasm`** (persist + list).

use chrono::{DateTime, Utc};
use sha2::{Digest, Sha256};
use sqlx::PgPool;
use uuid::Uuid;

use crate::error::ApiError;
use crate::harness::wasm_runtime;

#[derive(Clone, Debug)]
pub(crate) struct UserWasmPersistResult {
    pub id: Uuid,
    pub wasm_sha256_hex: String,
    pub size_bytes: u64,
    pub created_at: DateTime<Utc>,
}

const DEFAULT_LIST_CAP: i64 = 100;
const DEFAULT_MAX_STORED_PER_USER: i64 = 64;

fn list_cap_from_env() -> i64 {
    match std::env::var("HARNESS_USER_WASM_LIST_CAP") {
        Ok(s) => {
            let n: i64 = s.trim().parse().unwrap_or(DEFAULT_LIST_CAP);
            n.clamp(1, 500)
        }
        Err(_) => DEFAULT_LIST_CAP,
    }
}

fn max_stored_per_user_from_env() -> i64 {
    match std::env::var("HARNESS_USER_WASM_MAX_STORED_PER_USER") {
        Ok(s) => {
            let n: i64 = s.trim().parse().unwrap_or(DEFAULT_MAX_STORED_PER_USER);
            n.clamp(1, 4096)
        }
        Err(_) => DEFAULT_MAX_STORED_PER_USER,
    }
}

/// Insert one validated WASM row when the owner is below the stored-row cap (**atomic guard** inside SQL).
///
/// [`wasm_runtime::validate_user_wasm_upload`] must succeed before calling.
pub(crate) async fn persist_user_wasm_checked(
    pool: &PgPool,
    owner_user_id: Uuid,
    wasm_bytes: &[u8],
) -> Result<UserWasmPersistResult, ApiError> {
    wasm_runtime::validate_user_wasm_upload(wasm_bytes).map_err(ApiError::BadRequest)?;
    let max_rows = max_stored_per_user_from_env();
    let digest = Sha256::digest(wasm_bytes);
    let sz_i64 = wasm_bytes.len() as i64;

    let row: Option<(Uuid, i64, DateTime<Utc>)> = sqlx::query_as(
        r#"
        INSERT INTO app_harness_user_wasm (owner_user_id, wasm_sha256, wasm_bytes, size_bytes)
        SELECT $1, $2, $3::bytea, $4::bigint
        WHERE (
          SELECT COUNT(*)::bigint FROM app_harness_user_wasm WHERE owner_user_id = $1
        ) < $5::bigint
        RETURNING id, size_bytes, created_at
        "#,
    )
    .bind(owner_user_id)
    .bind(digest.as_slice())
    .bind(wasm_bytes)
    .bind(sz_i64)
    .bind(max_rows)
    .fetch_optional(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    let Some((id, sz, created_at)) = row else {
        return Err(ApiError::BadRequest(format!(
            "user wasm: stored uploads limit reached (max rows per user={max_rows}; set HARNESS_USER_WASM_MAX_STORED_PER_USER)"
        )));
    };
    Ok(UserWasmPersistResult {
        id,
        wasm_sha256_hex: hex::encode(digest.as_slice()),
        size_bytes: sz as u64,
        created_at,
    })
}

pub(crate) struct UserWasmSummaryRow {
    pub id: Uuid,
    pub wasm_sha256_hex: String,
    pub size_bytes: u64,
    pub created_at: DateTime<Utc>,
}

pub(crate) async fn list_user_wasm_for_owner(
    pool: &PgPool,
    owner_user_id: Uuid,
) -> Result<Vec<UserWasmSummaryRow>, ApiError> {
    let cap = list_cap_from_env();
    let rows: Vec<(Uuid, Vec<u8>, i64, DateTime<Utc>)> = sqlx::query_as(
        r#"
        SELECT id, wasm_sha256, size_bytes, created_at
        FROM app_harness_user_wasm
        WHERE owner_user_id = $1
        ORDER BY created_at DESC
        LIMIT $2
        "#,
    )
    .bind(owner_user_id)
    .bind(cap)
    .fetch_all(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    Ok(rows
        .into_iter()
        .map(|(id, sha, sz, created_at)| UserWasmSummaryRow {
            id,
            wasm_sha256_hex: hex::encode(sha),
            size_bytes: sz as u64,
            created_at,
        })
        .collect())
}
