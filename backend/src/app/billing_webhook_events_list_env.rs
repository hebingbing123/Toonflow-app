//! Test helper: serialize `BILLING_WEBHOOK_EVENTS_LIST_ENABLED` across parallel `cargo test` workers.

use std::sync::{Mutex, OnceLock};

static ENV_MUTEX: OnceLock<Mutex<()>> = OnceLock::new();

const KEY: &str = "BILLING_WEBHOOK_EVENTS_LIST_ENABLED";

/// Restores the previous value of [`KEY`] on drop.
pub(crate) struct BillingWebhookEventsListEnvGuard {
    _lock: std::sync::MutexGuard<'static, ()>,
    prev: Option<String>,
}

impl BillingWebhookEventsListEnvGuard {
    pub(crate) fn enable() -> Self {
        let _lock = ENV_MUTEX
            .get_or_init(|| Mutex::new(()))
            .lock()
            .expect("billing events list env mutex");
        let prev = std::env::var(KEY).ok();
        std::env::set_var(KEY, "1");
        Self { _lock, prev }
    }

    pub(crate) fn disabled() -> Self {
        let _lock = ENV_MUTEX
            .get_or_init(|| Mutex::new(()))
            .lock()
            .expect("billing events list env mutex");
        let prev = std::env::var(KEY).ok();
        std::env::remove_var(KEY);
        Self { _lock, prev }
    }
}

impl Drop for BillingWebhookEventsListEnvGuard {
    fn drop(&mut self) {
        match &self.prev {
            None => std::env::remove_var(KEY),
            Some(v) => std::env::set_var(KEY, v),
        }
    }
}
