//! **WP‑C** Postgres stubs for **`app_harness_user_wasm`** (persist, list active, revoke).

use chrono::{DateTime, Utc};
use sha2::{Digest, Sha256};
use sqlx::PgPool;
use uuid::Uuid;

use crate::error::ApiError;
use crate::harness::wasm_runtime;

type ActiveUserWasmSqlRow = (Uuid, Vec<u8>, Vec<u8>, i64, DateTime<Utc>);

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
          SELECT COUNT(*)::bigint
          FROM app_harness_user_wasm
          WHERE owner_user_id = $1
            AND revoked_at IS NULL
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
          AND revoked_at IS NULL
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

/// Sets **`revoked_at`** if still active; idempotent if already revoked (**same** `revoked_at` returned).
pub(crate) async fn revoke_user_wasm_for_owner(
    pool: &PgPool,
    owner_user_id: Uuid,
    wasm_id: Uuid,
) -> Result<DateTime<Utc>, ApiError> {
    let row: Option<(DateTime<Utc>,)> = sqlx::query_as(
        r#"
        UPDATE app_harness_user_wasm
        SET revoked_at = COALESCE(revoked_at, NOW())
        WHERE id = $1
          AND owner_user_id = $2
        RETURNING revoked_at
        "#,
    )
    .bind(wasm_id)
    .bind(owner_user_id)
    .fetch_optional(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    let Some((revoked_at,)) = row else {
        return Err(ApiError::NotFound);
    };
    Ok(revoked_at)
}

#[allow(dead_code)]
#[derive(Debug, Clone)]
pub(crate) struct UserWasmActiveRow {
    pub id: Uuid,
    pub wasm_sha256_hex: String,
    pub wasm_bytes: Vec<u8>,
    pub size_bytes: u64,
    pub created_at: DateTime<Utc>,
}

/// Fetch one user WASM row that is still active (**`revoked_at IS NULL`**).
///
/// This is a minimal safety hook for any future WS execution path so that
/// "revoked" uploads can never be invoked.
#[allow(dead_code)]
pub(crate) async fn get_active_user_wasm_for_owner(
    pool: &PgPool,
    owner_user_id: Uuid,
    wasm_id: Uuid,
) -> Result<UserWasmActiveRow, ApiError> {
    let row: Option<ActiveUserWasmSqlRow> = sqlx::query_as(
        r#"
        SELECT id, wasm_sha256, wasm_bytes, size_bytes, created_at
        FROM app_harness_user_wasm
        WHERE id = $1
          AND owner_user_id = $2
          AND revoked_at IS NULL
        "#,
    )
    .bind(wasm_id)
    .bind(owner_user_id)
    .fetch_optional(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    let Some((id, sha, bytes, sz, created_at)) = row else {
        return Err(ApiError::NotFound);
    };

    Ok(UserWasmActiveRow {
        id,
        wasm_sha256_hex: hex::encode(sha),
        wasm_bytes: bytes,
        size_bytes: sz as u64,
        created_at,
    })
}

#[cfg(test)]
mod tests {
    // Tests hold a std mutex across awaits to serialize env + temp PG table usage.
    #![allow(clippy::await_holding_lock)]

    use super::*;
    use crate::harness::wasm_runtime;
    use sqlx::postgres::PgPoolOptions;
    use std::sync::Mutex;

    static ENV_MUTEX: Mutex<()> = Mutex::new(());

    async fn maybe_connect() -> Option<PgPool> {
        let url = std::env::var("DATABASE_URL").ok()?;
        let pool = PgPoolOptions::new()
            .max_connections(1)
            .connect(&url)
            .await
            .ok()?;
        Some(pool)
    }

    async fn setup_temp_table(pool: &PgPool) -> Result<(), ApiError> {
        sqlx::query("CREATE EXTENSION IF NOT EXISTS pgcrypto;")
            .execute(pool)
            .await
            .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

        // Keep schema minimal and side-effect free for unit tests.
        // We use a TEMP TABLE with the same name so SQL in this module
        // transparently targets it.
        sqlx::query(
            r#"
            CREATE TEMP TABLE app_harness_user_wasm (
              id UUID PRIMARY KEY DEFAULT gen_random_uuid (),
              owner_user_id UUID NOT NULL,
              wasm_sha256 BYTEA NOT NULL,
              wasm_bytes BYTEA NOT NULL,
              size_bytes BIGINT NOT NULL,
              created_at TIMESTAMPTZ NOT NULL DEFAULT NOW (),
              revoked_at TIMESTAMPTZ NULL,
              CONSTRAINT app_harness_user_wasm_size_chk CHECK (
                size_bytes >= 1
                AND size_bytes = octet_length (wasm_bytes)
              ),
              CONSTRAINT app_harness_user_wasm_sha_len_chk CHECK (octet_length (wasm_sha256) = 32)
            );
            "#,
        )
        .execute(pool)
        .await
        .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

        Ok(())
    }

    #[tokio::test]
    async fn revoke_sets_revoked_at_and_list_filters_revoked_rows() {
        let _g = ENV_MUTEX.lock().expect("lock");
        let Some(pool) = maybe_connect().await else {
            eprintln!("DATABASE_URL not set; skipping user_wasm_db unit tests");
            return;
        };

        setup_temp_table(&pool).await.expect("temp table");

        std::env::set_var("HARNESS_USER_WASM_MAX_STORED_PER_USER", "64");
        std::env::set_var("HARNESS_USER_WASM_LIST_CAP", "100");

        let owner = Uuid::new_v4();
        let wasm = wasm_runtime::probe_wasm_bytes().to_vec();

        let a = persist_user_wasm_checked(&pool, owner, &wasm)
            .await
            .unwrap();
        assert_eq!(
            list_user_wasm_for_owner(&pool, owner).await.unwrap().len(),
            1
        );

        let revoked_at = revoke_user_wasm_for_owner(&pool, owner, a.id)
            .await
            .unwrap();
        assert!(revoked_at.timestamp() > 0);

        let items = list_user_wasm_for_owner(&pool, owner).await.unwrap();
        assert!(items.is_empty(), "revoked rows must not be listed");

        std::env::remove_var("HARNESS_USER_WASM_MAX_STORED_PER_USER");
        std::env::remove_var("HARNESS_USER_WASM_LIST_CAP");
    }

    #[tokio::test]
    async fn revoked_rows_do_not_count_toward_per_user_stored_cap() {
        let _g = ENV_MUTEX.lock().expect("lock");
        let Some(pool) = maybe_connect().await else {
            eprintln!("DATABASE_URL not set; skipping user_wasm_db unit tests");
            return;
        };

        setup_temp_table(&pool).await.expect("temp table");

        std::env::set_var("HARNESS_USER_WASM_MAX_STORED_PER_USER", "1");
        std::env::set_var("HARNESS_USER_WASM_LIST_CAP", "100");

        let owner = Uuid::new_v4();
        let wasm = wasm_runtime::probe_wasm_bytes().to_vec();

        let first = persist_user_wasm_checked(&pool, owner, &wasm)
            .await
            .unwrap();
        assert_eq!(
            list_user_wasm_for_owner(&pool, owner).await.unwrap().len(),
            1
        );

        // Soft-revoke first; the active row count should drop to 0.
        revoke_user_wasm_for_owner(&pool, owner, first.id)
            .await
            .unwrap();

        let second = persist_user_wasm_checked(&pool, owner, &wasm)
            .await
            .unwrap();
        assert_ne!(second.id, first.id);

        let items = list_user_wasm_for_owner(&pool, owner).await.unwrap();
        assert_eq!(items.len(), 1);
        assert_eq!(items[0].id, second.id);

        std::env::remove_var("HARNESS_USER_WASM_MAX_STORED_PER_USER");
        std::env::remove_var("HARNESS_USER_WASM_LIST_CAP");
    }

    #[tokio::test]
    async fn revoke_is_idempotent_and_returns_same_revoked_at() {
        let _g = ENV_MUTEX.lock().expect("lock");
        let Some(pool) = maybe_connect().await else {
            eprintln!("DATABASE_URL not set; skipping user_wasm_db unit tests");
            return;
        };

        setup_temp_table(&pool).await.expect("temp table");

        std::env::set_var("HARNESS_USER_WASM_MAX_STORED_PER_USER", "64");
        std::env::set_var("HARNESS_USER_WASM_LIST_CAP", "100");

        let owner = Uuid::new_v4();
        let wasm = wasm_runtime::probe_wasm_bytes().to_vec();

        let row = persist_user_wasm_checked(&pool, owner, &wasm)
            .await
            .unwrap();
        let revoked_at_1 = revoke_user_wasm_for_owner(&pool, owner, row.id)
            .await
            .unwrap();
        let revoked_at_2 = revoke_user_wasm_for_owner(&pool, owner, row.id)
            .await
            .unwrap();

        assert_eq!(
            revoked_at_1, revoked_at_2,
            "COALESCE(revoked_at, NOW()) must keep revoked_at stable"
        );

        std::env::remove_var("HARNESS_USER_WASM_MAX_STORED_PER_USER");
        std::env::remove_var("HARNESS_USER_WASM_LIST_CAP");
    }
}
