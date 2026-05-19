//! Prefork fills idle pool ⇒ **first** `isolated_echo` increments **`total_process_reuse_hits`**
//! (contrast `harness_isolate_pool_reuse.rs`, where only the **second** invoke hits reuse).

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
async fn harness_isolate_prefork_first_invoke_records_reuse_hit_and_no_extra_spawn() {
    let exe =
        std::env::var("CARGO_BIN_EXE_openflow-server").expect("cargo exposes CARGO_BIN_EXE_*");
    let _runner_guard = ScopedEnvVar::capture("HARNESS_ISOLATE_RUNNER_EXE");
    let _max_guard = ScopedEnvVar::capture("HARNESS_ISOLATE_MAX_CONCURRENT");
    let _pool_guard = ScopedEnvVar::capture("HARNESS_ISOLATE_POOL");
    let _prefork_guard = ScopedEnvVar::capture("HARNESS_ISOLATE_PREFORK");

    unsafe {
        std::env::set_var("HARNESS_ISOLATE_RUNNER_EXE", &exe);
        std::env::set_var("HARNESS_ISOLATE_MAX_CONCURRENT", "4");
        std::env::remove_var("HARNESS_ISOLATE_POOL");
        std::env::set_var("HARNESS_ISOLATE_PREFORK", "2");
    }

    assert_eq!(
        openflow_server::harness::isolate::effective_isolate_prefork_target(),
        2
    );

    openflow_server::harness::isolate::warm_isolate_pool_prefork().await;

    let after_warm = openflow_server::harness::isolate::metrics_snapshot();
    assert!(
        after_warm.total_child_spawns >= 2,
        "prefork should spawn at least two workers"
    );

    let payload = serde_json::json!({ "prefork_probe": 1 });
    let before_invoke = openflow_server::harness::isolate::metrics_snapshot();

    let out = openflow_server::harness::isolate::isolated_echo(&payload)
        .await
        .expect("pooled echo");

    assert_eq!(out["prefork_probe"], 1);

    let after_invoke = openflow_server::harness::isolate::metrics_snapshot();

    assert_eq!(
        after_invoke.total_process_reuse_hits - before_invoke.total_process_reuse_hits,
        1,
        "first invoke after prefork must count as idle reuse"
    );
    assert_eq!(
        after_invoke.total_child_spawns, before_invoke.total_child_spawns,
        "first invoke must not spawn another pool worker"
    );
}
