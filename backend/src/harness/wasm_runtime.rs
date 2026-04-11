//! 最小 WASM 工具路径。
//!
//! 嵌入微型 `probe.wasm` 并通过 wasmi 执行（无原生 WASM 引擎）。
//! 用于验证 WASM 堆栈路径。

use serde_json::{json, Value};
use wasmi::{Engine, Linker, Module, Store};

const PROBE_WASM: &[u8] = include_bytes!(concat!(env!("OUT_DIR"), "/probe.wasm"));

/// Runs embedded module export **`probe`** `() -> i32` (returns 42). Validates the WASM stack path.
pub fn invoke_probe() -> Result<Value, String> {
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

    #[test]
    fn probe_returns_42() {
        let v = invoke_probe().unwrap();
        assert_eq!(v.get("ok").and_then(|x| x.as_bool()), Some(true));
        assert_eq!(v.get("value").and_then(|x| x.as_i64()), Some(42));
    }
}
