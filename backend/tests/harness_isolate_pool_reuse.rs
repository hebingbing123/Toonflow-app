//! Second sequential `isolated_echo` hits idle pool ⇒ `total_process_reuse_hits` increments (`HARNESS_ISOLATE_RUNNER_EXE`).

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
async fn harness_isolate_pool_second_invoke_records_reuse_hit() {
    let exe =
        std::env::var("CARGO_BIN_EXE_toonflow-server").expect("cargo exposes CARGO_BIN_EXE_*");
    let _runner_guard = ScopedEnvVar::capture("HARNESS_ISOLATE_RUNNER_EXE");
    let _max_guard = ScopedEnvVar::capture("HARNESS_ISOLATE_MAX_CONCURRENT");
    let _pool_guard = ScopedEnvVar::capture("HARNESS_ISOLATE_POOL");

    unsafe {
        std::env::set_var("HARNESS_ISOLATE_RUNNER_EXE", &exe);
        std::env::set_var("HARNESS_ISOLATE_MAX_CONCURRENT", "4");
        std::env::remove_var("HARNESS_ISOLATE_POOL");
    }

    let v1 = serde_json::json!({ "pool_reuse_probe": "a" });

    let before = toonflow_server::harness::isolate::metrics_snapshot();

    let out1 = toonflow_server::harness::isolate::isolated_echo(&v1)
        .await
        .expect("first pooled echo");

    assert_eq!(out1["pool_reuse_probe"], "a");

    let mid = toonflow_server::harness::isolate::metrics_snapshot();
    assert_eq!(
        mid.total_process_reuse_hits - before.total_process_reuse_hits,
        0,
        "first invoke must not increment reuse hits"
    );
    assert!(mid.total_child_spawns > before.total_child_spawns);

    let v2 = serde_json::json!({ "pool_reuse_probe": "b" });
    let out2 = toonflow_server::harness::isolate::isolated_echo(&v2)
        .await
        .expect("second pooled echo reuses idle worker");

    assert_eq!(out2["pool_reuse_probe"], "b");

    let after = toonflow_server::harness::isolate::metrics_snapshot();
    assert_eq!(
        after
            .total_process_reuse_hits
            .saturating_sub(mid.total_process_reuse_hits),
        1,
        "reuse hit must increment exactly once after second invoke"
    );
    assert!(
        after.total_child_spawns <= mid.total_child_spawns + 1,
        "second invoke should reuse pool worker (≤1 net new spawn versus mid)"
    );
}
