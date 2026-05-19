//! Idle TTL evicts pooled workers; next `isolated_echo` spawns fresh (counts in `total_pool_evictions`).

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
async fn harness_isolate_pool_idle_ttl_evicts_before_reuse() {
    let exe =
        std::env::var("CARGO_BIN_EXE_openflow-server").expect("cargo exposes CARGO_BIN_EXE_*");
    let _runner_guard = ScopedEnvVar::capture("HARNESS_ISOLATE_RUNNER_EXE");
    let _max_guard = ScopedEnvVar::capture("HARNESS_ISOLATE_MAX_CONCURRENT");
    let _pool_guard = ScopedEnvVar::capture("HARNESS_ISOLATE_POOL");
    let _idle_ttl_guard = ScopedEnvVar::capture("HARNESS_ISOLATE_POOL_IDLE_TTL_SECS");
    let _max_age_guard = ScopedEnvVar::capture("HARNESS_ISOLATE_POOL_MAX_WORKER_AGE_SECS");

    unsafe {
        std::env::set_var("HARNESS_ISOLATE_RUNNER_EXE", &exe);
        std::env::set_var("HARNESS_ISOLATE_MAX_CONCURRENT", "4");
        std::env::remove_var("HARNESS_ISOLATE_POOL");
        std::env::set_var("HARNESS_ISOLATE_POOL_IDLE_TTL_SECS", "1");
        std::env::remove_var("HARNESS_ISOLATE_POOL_MAX_WORKER_AGE_SECS");
    }

    let v1 = serde_json::json!({ "ttl_probe": "first" });
    let before = openflow_server::harness::isolate::metrics_snapshot();

    openflow_server::harness::isolate::isolated_echo(&v1)
        .await
        .expect("first echo");

    let v2 = serde_json::json!({ "ttl_probe": "second" });
    openflow_server::harness::isolate::isolated_echo(&v2)
        .await
        .expect("second echo reuses idle worker");

    let mid = openflow_server::harness::isolate::metrics_snapshot();
    assert!(
        mid.total_process_reuse_hits > before.total_process_reuse_hits,
        "second invoke should record a reuse hit"
    );

    tokio::time::sleep(std::time::Duration::from_millis(1200)).await;

    let v3 = serde_json::json!({ "ttl_probe": "third" });
    openflow_server::harness::isolate::isolated_echo(&v3)
        .await
        .expect("third echo after idle TTL");

    let after = openflow_server::harness::isolate::metrics_snapshot();
    assert!(
        after.total_pool_evictions > mid.total_pool_evictions,
        "idle TTL should evict at least one worker before third acquire (mid evictions={}, after evictions={})",
        mid.total_pool_evictions,
        after.total_pool_evictions
    );
    assert!(
        after.total_child_spawns > mid.total_child_spawns,
        "third invoke should spawn after eviction"
    );
}
