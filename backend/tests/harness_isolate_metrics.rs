//! `isolated_echo` aggregates + tracing hook (`HARNESS_ISOLATE_RUNNER_EXE` → server binary).

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
async fn harness_isolate_metrics_increment_on_echo_via_runner_env() {
    let exe =
        std::env::var("CARGO_BIN_EXE_openflow-server").expect("cargo exposes CARGO_BIN_EXE_*");
    let _runner_guard = ScopedEnvVar::capture("HARNESS_ISOLATE_RUNNER_EXE");
    let _max_guard = ScopedEnvVar::capture("HARNESS_ISOLATE_MAX_CONCURRENT");

    unsafe {
        std::env::set_var("HARNESS_ISOLATE_RUNNER_EXE", &exe);
        std::env::set_var("HARNESS_ISOLATE_MAX_CONCURRENT", "4");
    }

    let before = openflow_server::harness::isolate::metrics_snapshot();

    let v = serde_json::json!({ "integration": "harness-isolate-metrics" });
    let out = openflow_server::harness::isolate::isolated_echo(&v)
        .await
        .expect("isolated echo against openflow-server binary");

    let after = openflow_server::harness::isolate::metrics_snapshot();

    assert_eq!(out["integration"], "harness-isolate-metrics");
    assert_eq!(after.max_slots, 4);
    assert!(after.total_invocations > before.total_invocations);
    assert!(after.total_child_spawns > before.total_child_spawns);
}
