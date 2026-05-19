//! Legacy **`app_* .numeric_id`** policy for the HTTP API **H5·D** removal window.
//!
//! PG identifier columns are **not dropped** here — blocked by `promote_import_snapshots()`,
//! job payload filters, and contract tests (see `docs/plans/tasks-http-api-cleanup.md` H5·D).
//!
//! ## Environment
//!
//! | Variable | Default | Effect |
//! |----------|---------|--------|
//! | `OPENFLOW_NUMERIC_ID_LEGACY_READ` | `true` | When `false`, numeric-only project resolution is rejected. |
//! | `OPENFLOW_NUMERIC_ID_LEGACY_WRITE` | `true` | When `false`, job payload normalization omits `project_numeric_id` dual-write. |
//!
//! ## Sunset
//!
//! Target end of numeric-only client paths: **`2026-11-01`** (operational; not auto-enforced).
//! Column drops remain a separate DBA-signed milestone after import + `/jobs/page` UUID filter migration.

use crate::error::{bad_request_i18n, ApiError};

pub const ENV_LEGACY_NUMERIC_READ: &str = "OPENFLOW_NUMERIC_ID_LEGACY_READ";
pub const ENV_LEGACY_NUMERIC_WRITE: &str = "OPENFLOW_NUMERIC_ID_LEGACY_WRITE";

/// Documented sunset for numeric-only API paths (see module docs).
pub const LEGACY_NUMERIC_SUNSET: &str = "2026-11-01";

fn env_bool(name: &str, default: bool) -> bool {
    match std::env::var(name) {
        Ok(raw) => {
            let t = raw.trim().to_ascii_lowercase();
            if matches!(t.as_str(), "1" | "true" | "yes" | "on") {
                true
            } else if matches!(t.as_str(), "0" | "false" | "no" | "off") {
                false
            } else {
                default
            }
        }
        Err(_) => default,
    }
}

#[must_use]
pub fn legacy_numeric_read_enabled() -> bool {
    env_bool(ENV_LEGACY_NUMERIC_READ, true)
}

#[must_use]
pub fn legacy_numeric_write_enabled() -> bool {
    env_bool(ENV_LEGACY_NUMERIC_WRITE, true)
}

/// Reject requests that rely on numeric-only project scope when the read window is closed.
pub fn ensure_legacy_numeric_read_allowed() -> Result<(), ApiError> {
    if legacy_numeric_read_enabled() {
        Ok(())
    } else {
        Err(bad_request_i18n(
            "Legacy numeric project id is no longer accepted; send project UUID",
            "已不再接受 legacy numeric project id，请改用 project UUID",
        ))
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::sync::{Mutex, MutexGuard};

    static ENV_LOCK: Mutex<()> = Mutex::new(());

    fn env_test_lock() -> MutexGuard<'static, ()> {
        ENV_LOCK.lock().unwrap_or_else(|e| e.into_inner())
    }

    #[test]
    fn legacy_read_defaults_enabled_without_env() {
        let _guard = env_test_lock();
        std::env::remove_var(ENV_LEGACY_NUMERIC_READ);
        assert!(legacy_numeric_read_enabled());
    }

    #[test]
    fn legacy_read_honors_false_env() {
        let _guard = env_test_lock();
        std::env::set_var(ENV_LEGACY_NUMERIC_READ, "false");
        assert!(!legacy_numeric_read_enabled());
        std::env::remove_var(ENV_LEGACY_NUMERIC_READ);
    }
}
