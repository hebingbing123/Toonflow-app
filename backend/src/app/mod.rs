//! HTTP router composition and core JSON routes (`/health`, `/api/v1/me`, …).

mod handlers;
mod router;

pub use router::build_router;

#[cfg(test)]
mod jwt_fixture {
    use chrono::Utc;
    use jsonwebtoken::{encode, EncodingKey, Header};
    use serde::Serialize;
    use uuid::Uuid;

    #[derive(Serialize)]
    struct SmokeJwtClaims {
        sub: String,
        exp: i64,
        aud: &'static str,
    }

    pub(crate) fn encode_supabase_style(sub: Uuid, secret: &[u8]) -> String {
        encode(
            &Header::default(),
            &SmokeJwtClaims {
                sub: sub.to_string(),
                exp: Utc::now().timestamp() + 86_400,
                aud: "authenticated",
            },
            &EncodingKey::from_secret(secret),
        )
        .expect("encode test jwt")
    }
}

#[cfg(test)]
static VENDOR_CREDENTIAL_TEST_MUTEX: std::sync::OnceLock<tokio::sync::Mutex<()>> =
    std::sync::OnceLock::new();

#[cfg(test)]
async fn vendor_credential_test_lock() -> tokio::sync::MutexGuard<'static, ()> {
    VENDOR_CREDENTIAL_TEST_MUTEX
        .get_or_init(|| tokio::sync::Mutex::new(()))
        .lock()
        .await
}

#[cfg(test)]
mod contract_smoke_tests;

/// Postgres-backed contract checks (opt-in: **`#[ignore]`** so default **`cargo test`** stays DB-free).
#[cfg(test)]
mod pg_contract_tests;
