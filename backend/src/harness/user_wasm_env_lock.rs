//! Serialize tests that flip `HARNESS_USER_WASM_*` / `HARNESS_WASM_*` env vars (process-global).

use std::sync::{Mutex, MutexGuard, OnceLock};

static USER_WASM_TEST_ENV_MUTEX: OnceLock<Mutex<()>> = OnceLock::new();

/// Lock held for the whole test body so parallel `cargo test` workers do not clobber env.
pub fn user_wasm_test_env_lock() -> MutexGuard<'static, ()> {
    USER_WASM_TEST_ENV_MUTEX
        .get_or_init(|| Mutex::new(()))
        .lock()
        .unwrap_or_else(|poisoned| poisoned.into_inner())
}
