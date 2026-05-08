//! 最小 WASM 工具路径。
//!
//! 嵌入微型 `probe.wasm` 并通过 wasmi 执行（无原生 WASM 引擎）。
//! 用于验证 WASM 堆栈路径。
//!
//! **WP‑C**：[`validate_user_wasm_upload`] 为将来「用户投递 WASM」提供体量上限与模块解析校验（REST 接线前可单测与内部复用）。
//!
//! Fuel-capped execution (`invoke_user_probe`) is staged for WS dispatch; Clippy
//! would otherwise flag the whole helper cluster as dead until that path lands.

#![allow(dead_code)]

use serde_json::{json, Value};
use wasmi::{Config, Engine, Linker, Module, Store};

const PROBE_WASM: &[u8] = include_bytes!(concat!(env!("OUT_DIR"), "/probe.wasm"));

/// Bytes of the build-time **`probe`** module; only needed for **`#[cfg(test)]`** smoke tests (**contract_smoke_tests**).
#[cfg(test)]
#[inline]
pub fn probe_wasm_bytes() -> &'static [u8] {
    PROBE_WASM
}

/// Default cap for untrusted user-supplied WASM payloads (see **`HARNESS_USER_WASM_MAX_BYTES`**).
const DEFAULT_USER_WASM_MAX_BYTES: usize = 512 * 1024;
const DEFAULT_USER_WASM_FUEL_LIMIT: u64 = 50_000_000;
const DEFAULT_USER_WASM_INVOKE_TIMEOUT_MS: u64 = 3_000;

#[inline]
fn user_wasm_max_bytes_from_env() -> usize {
    match std::env::var("HARNESS_USER_WASM_MAX_BYTES") {
        Ok(s) => match s.trim().parse::<usize>() {
            Ok(0) | Err(_) => DEFAULT_USER_WASM_MAX_BYTES,
            Ok(n) => n,
        },
        Err(_) => DEFAULT_USER_WASM_MAX_BYTES,
    }
}

#[inline]
fn user_wasm_fuel_limit_from_env() -> u64 {
    match std::env::var("HARNESS_USER_WASM_FUEL_LIMIT") {
        Ok(s) => match s.trim().parse::<u64>() {
            Ok(0) | Err(_) => DEFAULT_USER_WASM_FUEL_LIMIT,
            Ok(n) => n,
        },
        Err(_) => DEFAULT_USER_WASM_FUEL_LIMIT,
    }
}

#[inline]
pub fn user_wasm_invoke_timeout_ms_from_env() -> u64 {
    match std::env::var("HARNESS_USER_WASM_INVOKE_TIMEOUT_MS") {
        Ok(s) => match s.trim().parse::<u64>() {
            Ok(0) | Err(_) => DEFAULT_USER_WASM_INVOKE_TIMEOUT_MS,
            Ok(n) => n,
        },
        Err(_) => DEFAULT_USER_WASM_INVOKE_TIMEOUT_MS,
    }
}

/// Reject empty, oversize, or malformed WASM before persistence / registration (WP‑C).
///
/// Enforces **`HARNESS_USER_WASM_MAX_BYTES`** (default **512 KiB**) then
/// **`wasmi::Module::new`** so garbage after the magic/version fails fast.
pub fn validate_user_wasm_upload(bytes: &[u8]) -> Result<(), String> {
    if bytes.is_empty() {
        return Err("user wasm: empty module".into());
    }
    let max = user_wasm_max_bytes_from_env();
    if bytes.len() > max {
        return Err(format!("user wasm: exceeds max size ({max} bytes)"));
    }
    let engine = Engine::default();
    Module::new(&engine, bytes).map_err(|e| format!("user wasm: {e}"))?;
    Ok(())
}

#[inline]
fn user_wasm_disabled_by_env() -> bool {
    match std::env::var("HARNESS_USER_WASM_DISABLED") {
        Ok(s) => {
            let t = s.trim().to_ascii_lowercase();
            matches!(t.as_str(), "1" | "true" | "yes" | "on")
        }
        Err(_) => false,
    }
}

/// Runs a user-uploaded module export `probe() -> i32` with fuel protection.
///
/// This keeps ABI parity with the built-in `wasm.probe` tool while allowing
/// WS dispatch to execute owner-scoped active WASM rows.
pub fn invoke_user_probe(wasm_bytes: &[u8]) -> Result<Value, String> {
    if user_wasm_disabled_by_env() {
        return Err("user wasm disabled by HARNESS_USER_WASM_DISABLED".into());
    }
    #[cfg(test)]
    {
        if let Ok(s) = std::env::var("HARNESS_USER_WASM_TEST_SLEEP_MS") {
            if let Ok(ms) = s.trim().parse::<u64>() {
                if ms > 0 {
                    std::thread::sleep(std::time::Duration::from_millis(ms));
                }
            }
        }
    }
    validate_user_wasm_upload(wasm_bytes)?;

    let mut cfg = Config::default();
    cfg.consume_fuel(true);
    let engine = Engine::new(&cfg);
    let module = Module::new(&engine, wasm_bytes).map_err(|e| format!("user wasm module: {e}"))?;
    let mut store = Store::new(&engine, ());
    let fuel = user_wasm_fuel_limit_from_env();
    store
        .add_fuel(fuel)
        .map_err(|e| format!("user wasm fuel setup: {e}"))?;
    let linker = Linker::new(&engine);
    let instance = linker
        .instantiate(&mut store, &module)
        .map_err(|e| format!("user wasm instantiate: {e}"))?
        .start(&mut store)
        .map_err(|e| format!("user wasm start: {e}"))?;
    let probe = instance
        .get_typed_func::<(), i32>(&mut store, "probe")
        .map_err(|e| format!("user wasm export probe: {e}"))?;
    let v = probe
        .call(&mut store, ())
        .map_err(|e| format!("user wasm trap: {e}"))?;
    Ok(json!({ "ok": true, "value": v }))
}

#[inline]
fn wasm_probe_disabled_by_env() -> bool {
    match std::env::var("HARNESS_WASM_PROBE_DISABLED") {
        Ok(s) => {
            let t = s.trim().to_ascii_lowercase();
            matches!(t.as_str(), "1" | "true" | "yes" | "on")
        }
        Err(_) => false,
    }
}

/// Runs embedded module export **`probe`** `() -> i32` (returns 42). Validates the WASM stack path.
pub fn invoke_probe() -> Result<Value, String> {
    if wasm_probe_disabled_by_env() {
        return Err("wasm.probe disabled by HARNESS_WASM_PROBE_DISABLED".into());
    }
    let engine = Engine::default();
    let module = Module::new(&engine, PROBE_WASM).map_err(|e| format!("wasm module: {e}"))?;
    let mut store = Store::new(&engine, ());
    let linker = Linker::new(&engine);
    let instance = linker
        .instantiate(&mut store, &module)
        .map_err(|e| format!("instantiate: {e}"))?
        .start(&mut store)
        .map_err(|e| format!("start: {e}"))?;
    let probe = instance
        .get_typed_func::<(), i32>(&mut store, "probe")
        .map_err(|e| format!("export probe: {e}"))?;
    let v = probe
        .call(&mut store, ())
        .map_err(|e| format!("wasm trap: {e}"))?;
    Ok(json!({ "ok": true, "value": v }))
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::harness::user_wasm_test_env_lock;

    #[test]
    fn user_wasm_validation_rejects_empty() {
        let err = validate_user_wasm_upload(&[]).expect_err("empty");
        assert!(err.contains("empty"), "{err}");
    }

    #[test]
    fn user_wasm_validation_rejects_oversize() {
        let _g = user_wasm_test_env_lock();
        std::env::set_var("HARNESS_USER_WASM_MAX_BYTES", "16");
        let buf = vec![0u8; 17];
        let err = validate_user_wasm_upload(&buf).expect_err("oversize");
        assert!(err.contains("exceeds max size"), "{err}");
        std::env::remove_var("HARNESS_USER_WASM_MAX_BYTES");
    }

    #[test]
    fn user_wasm_validation_accepts_embedded_probe_when_under_cap() {
        let _g = user_wasm_test_env_lock();
        std::env::set_var(
            "HARNESS_USER_WASM_MAX_BYTES",
            format!("{}", PROBE_WASM.len().max(1)),
        );
        validate_user_wasm_upload(PROBE_WASM).expect("probe should parse");
        std::env::remove_var("HARNESS_USER_WASM_MAX_BYTES");
    }

    #[test]
    fn user_wasm_validation_rejects_garbage() {
        let _g = user_wasm_test_env_lock();
        std::env::remove_var("HARNESS_USER_WASM_MAX_BYTES");
        let garbage = b"\0asm\x01\x00\x00\x00\xff";
        let err = validate_user_wasm_upload(garbage).expect_err("garbage");
        assert!(err.starts_with("user wasm:"), "{err}");
    }

    #[test]
    fn probe_returns_42() {
        let _g = user_wasm_test_env_lock();
        std::env::remove_var("HARNESS_WASM_PROBE_DISABLED");
        let v = invoke_probe().unwrap();
        assert_eq!(v.get("ok").and_then(|x| x.as_bool()), Some(true));
        assert_eq!(v.get("value").and_then(|x| x.as_i64()), Some(42));
    }

    #[test]
    fn probe_respects_kill_switch() {
        let _g = user_wasm_test_env_lock();
        std::env::set_var("HARNESS_WASM_PROBE_DISABLED", "1");
        let err = invoke_probe().expect_err("disabled");
        assert!(
            err.contains("HARNESS_WASM_PROBE_DISABLED"),
            "unexpected err: {err}"
        );
        std::env::remove_var("HARNESS_WASM_PROBE_DISABLED");
    }

    #[test]
    fn user_probe_respects_kill_switch() {
        let _g = user_wasm_test_env_lock();
        std::env::set_var("HARNESS_USER_WASM_DISABLED", "1");
        let err = invoke_user_probe(PROBE_WASM).expect_err("disabled");
        assert!(err.contains("HARNESS_USER_WASM_DISABLED"), "{err}");
        std::env::remove_var("HARNESS_USER_WASM_DISABLED");
    }

    #[test]
    fn user_probe_runs_probe_export() {
        let _g = user_wasm_test_env_lock();
        std::env::remove_var("HARNESS_USER_WASM_DISABLED");
        std::env::set_var("HARNESS_USER_WASM_FUEL_LIMIT", "100000");
        let out = invoke_user_probe(PROBE_WASM).expect("user probe ok");
        assert_eq!(out.get("ok").and_then(|x| x.as_bool()), Some(true));
        assert_eq!(out.get("value").and_then(|x| x.as_i64()), Some(42));
        std::env::remove_var("HARNESS_USER_WASM_FUEL_LIMIT");
    }

    #[test]
    fn user_probe_fuel_exhaustion_returns_err() {
        let _g = user_wasm_test_env_lock();
        std::env::remove_var("HARNESS_USER_WASM_MAX_BYTES");
        std::env::remove_var("HARNESS_USER_WASM_DISABLED");
        std::env::set_var("HARNESS_USER_WASM_FUEL_LIMIT", "1");
        let err = invoke_user_probe(PROBE_WASM).expect_err("fuel should exhaust");
        let lower = err.to_ascii_lowercase();
        assert!(
            lower.contains("fuel") || lower.contains("trap") || lower.contains("exhaust"),
            "unexpected err: {err}"
        );
        std::env::remove_var("HARNESS_USER_WASM_FUEL_LIMIT");
    }
}
