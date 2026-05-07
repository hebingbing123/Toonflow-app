//! Concurrency-slot behaviour: semaphore wait totals grow when parallel invokes exceed slots.
//!
//! Uses `HARNESS_ISOLATE_MAX_CONCURRENT=1` — isolate `LazyLock` must see env **before first use**
//! (`metrics_snapshot`). Kept separate from `tests/harness_isolate_metrics.rs` so processes stay
//! single-scenario without env races.

use std::sync::Arc;

use tokio::sync::Barrier;
use toonflow_server::harness::isolate::{isolated_echo, metrics_snapshot};

struct ScopedEnvVar {
    key: &'static str,
    prior_value: Option<std::ffi::OsString>,
}

impl ScopedEnvVar {
    fn capture(key: &'static str) -> Self {
        Self {
            key,
            prior_value: std::env::var_os(key),
        }
    }
}

impl Drop for ScopedEnvVar {
    fn drop(&mut self) {
        match self.prior_value.take() {
            Some(v) => unsafe { std::env::set_var(self.key, v) },
            None => unsafe { std::env::remove_var(self.key) },
        }
    }
}

#[tokio::test]
async fn three_parallel_echoes_under_one_slot_accumulate_sem_wait() {
    let exe =
        std::env::var("CARGO_BIN_EXE_toonflow-server").expect("cargo exposes CARGO_BIN_EXE_*");
    let _runner_guard = ScopedEnvVar::capture("HARNESS_ISOLATE_RUNNER_EXE");
    let _max_guard = ScopedEnvVar::capture("HARNESS_ISOLATE_MAX_CONCURRENT");
    unsafe {
        std::env::set_var("HARNESS_ISOLATE_RUNNER_EXE", &exe);
        std::env::set_var("HARNESS_ISOLATE_MAX_CONCURRENT", "1");
    }

    let before = metrics_snapshot();
    assert_eq!(before.max_slots, 1);

    let barrier = Arc::new(Barrier::new(4));
    let mut handles = Vec::with_capacity(3);
    for i in 0u32..3 {
        let b = barrier.clone();
        let payload = serde_json::json!({ "slot": i });
        handles.push(tokio::spawn(async move {
            let _same = b.wait().await;
            isolated_echo(&payload).await
        }));
    }

    barrier.wait().await;

    for h in handles {
        h.await
            .expect("join isolate task")
            .expect("isolated.echo must succeed via server subprocess");
    }

    let after = metrics_snapshot();
    let delta_sem = after
        .total_semaphore_wait_ms
        .saturating_sub(before.total_semaphore_wait_ms);
    assert!(
        delta_sem >= 10,
        "expected non-trivial semaphore wait under slots=1, delta_sem_wait_ms={delta_sem}"
    );
    assert!(
        after.total_invocations >= before.total_invocations + 3,
        "metrics should advance by three invokes"
    );
}
