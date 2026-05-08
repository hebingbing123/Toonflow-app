//! 最小 WASM 工具路径。
//!
//! 嵌入微型 `probe.wasm` 并通过 wasmi 执行（无原生 WASM 引擎）。
//! 用于验证 WASM 堆栈路径。
//!
//! **WP‑C**：[`validate_user_wasm_upload`] 为将来「用户投递 WASM」提供体量上限与模块解析校验（REST 接线前可单测与内部复用）。

use serde_json::{json, Value};
use wasmi::{Engine, Linker, Module, Store};

const PROBE_WASM: &[u8] = include_bytes!(concat!(env!("OUT_DIR"), "/probe.wasm"));

/// Default cap for untrusted user-supplied WASM payloads (see **`HARNESS_USER_WASM_MAX_BYTES`**).
#[allow(dead_code)] // Used by `validate_user_wasm_upload`; non-test lib has no upload handler yet (WP‑C).
const DEFAULT_USER_WASM_MAX_BYTES: usize = 512 * 1024;

#[allow(dead_code)]
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

/// Reject empty, oversize, or malformed WASM before persistence / registration (WP‑C).
///
/// Enforces **`HARNESS_USER_WASM_MAX_BYTES`** (default **512 KiB**) then
/// **`wasmi::Module::new`** so garbage after the magic/version fails fast.
#[allow(dead_code)] // Upload REST / registration will call; exercised in unit tests until wired.
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
    use std::sync::Mutex;

    static ENV_MUTEX: Mutex<()> = Mutex::new(());

    #[test]
    fn user_wasm_validation_rejects_empty() {
        let err = validate_user_wasm_upload(&[]).expect_err("empty");
        assert!(err.contains("empty"), "{err}");
    }

    #[test]
    fn user_wasm_validation_rejects_oversize() {
        let _g = ENV_MUTEX.lock().expect("lock");
        std::env::set_var("HARNESS_USER_WASM_MAX_BYTES", "16");
        let buf = vec![0u8; 17];
        let err = validate_user_wasm_upload(&buf).expect_err("oversize");
        assert!(err.contains("exceeds max size"), "{err}");
        std::env::remove_var("HARNESS_USER_WASM_MAX_BYTES");
    }

    #[test]
    fn user_wasm_validation_accepts_embedded_probe_when_under_cap() {
        let _g = ENV_MUTEX.lock().expect("lock");
        std::env::set_var(
            "HARNESS_USER_WASM_MAX_BYTES",
            &format!("{}", PROBE_WASM.len().max(1)),
        );
        validate_user_wasm_upload(PROBE_WASM).expect("probe should parse");
        std::env::remove_var("HARNESS_USER_WASM_MAX_BYTES");
    }

    #[test]
    fn user_wasm_validation_rejects_garbage() {
        let _g = ENV_MUTEX.lock().expect("lock");
        std::env::remove_var("HARNESS_USER_WASM_MAX_BYTES");
        let garbage = b"\0asm\x01\x00\x00\x00\xff";
        let err = validate_user_wasm_upload(garbage).expect_err("garbage");
        assert!(err.starts_with("user wasm:"), "{err}");
    }

    #[test]
    fn probe_returns_42() {
        let _g = ENV_MUTEX.lock().expect("lock");
        std::env::remove_var("HARNESS_WASM_PROBE_DISABLED");
        let v = invoke_probe().unwrap();
        assert_eq!(v.get("ok").and_then(|x| x.as_bool()), Some(true));
        assert_eq!(v.get("value").and_then(|x| x.as_i64()), Some(42));
    }

    #[test]
    fn probe_respects_kill_switch() {
        let _g = ENV_MUTEX.lock().expect("lock");
        std::env::set_var("HARNESS_WASM_PROBE_DISABLED", "1");
        let err = invoke_probe().expect_err("disabled");
        assert!(
            err.contains("HARNESS_WASM_PROBE_DISABLED"),
            "unexpected err: {err}"
        );
        std::env::remove_var("HARNESS_WASM_PROBE_DISABLED");
    }
}
