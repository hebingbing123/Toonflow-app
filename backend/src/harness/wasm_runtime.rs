//! 最小 WASM 工具路径。
//!
//! 嵌入微型 `probe.wasm` 并通过 wasmi 执行（无原生 WASM 引擎）。
//! 用于验证 WASM 堆栈路径。

use serde_json::{json, Value};
use wasmi::{Engine, Linker, Module, Store};

const PROBE_WASM: &[u8] = include_bytes!(concat!(env!("OUT_DIR"), "/probe.wasm"));

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
