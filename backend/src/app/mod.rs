//! 应用模块：HTTP 路由组合和核心 JSON 路由。
//!
//! 子模块：
//! - `handlers` — 核心处理器（健康检查、版本、用户信息）
//! - `router` — 路由构建
//! - `ops` — 操作命令
//! - `contract_smoke_tests` — 契约冒烟测试
//! - `pg_contract_tests` — PostgreSQL 契约测试

mod handlers;
pub mod ops;
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
