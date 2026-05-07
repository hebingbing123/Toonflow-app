//! 可观测性接线占位（路线图 **WP-F**）。
//!
//! 完整 OTLP 导出尚未接入；见 `TOONFLOW_OTEL_EXPORT_ENABLED` 与 `backend/README.md`。

#[inline]
fn truthy_env(name: &str) -> bool {
    match std::env::var(name) {
        Ok(s) => {
            let t = s.trim().to_ascii_lowercase();
            matches!(t.as_str(), "1" | "true" | "yes" | "on")
        }
        Err(_) => false,
    }
}

/// 若设置了 **`TOONFLOW_OTEL_EXPORT_ENABLED`**（`1` / `true` / `yes` / `on`），在 **`tracing`** 已初始化后打出一条 **warn**，
/// 避免运维误以为本构建已向 collector 导出 OTLP。
pub fn log_otel_export_stub_if_requested() {
    if !truthy_env("TOONFLOW_OTEL_EXPORT_ENABLED") {
        return;
    }
    tracing::warn!(
        target: "toonflow.telemetry",
        "TOONFLOW_OTEL_EXPORT_ENABLED is set but OTLP export is not wired in this build (WP-F); spans remain on the default fmt subscriber only."
    );
}

#[cfg(test)]
mod tests {
    use super::truthy_env;
    use std::sync::Mutex;

    static ENV_MUTEX: Mutex<()> = Mutex::new(());

    #[test]
    fn truthy_env_parses() {
        let _g = ENV_MUTEX.lock().expect("lock");
        std::env::remove_var("TOONFLOW_OTEL_EXPORT_ENABLED");
        assert!(!truthy_env("TOONFLOW_OTEL_EXPORT_ENABLED"));
        std::env::set_var("TOONFLOW_OTEL_EXPORT_ENABLED", "1");
        assert!(truthy_env("TOONFLOW_OTEL_EXPORT_ENABLED"));
        std::env::set_var("TOONFLOW_OTEL_EXPORT_ENABLED", "no");
        assert!(!truthy_env("TOONFLOW_OTEL_EXPORT_ENABLED"));
        std::env::remove_var("TOONFLOW_OTEL_EXPORT_ENABLED");
    }
}
