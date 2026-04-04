//! Emit `probe.wasm` (tiny `probe` export) into `OUT_DIR` for [`include_bytes!`].

fn main() {
    let wat = r#"(module
  (func (export "probe") (result i32)
    i32.const 42)
)"#;
    let wasm = wat::parse_str(wat).expect("wat parse probe module");
    let out_dir = std::env::var("OUT_DIR").expect("OUT_DIR");
    let path = std::path::Path::new(&out_dir).join("probe.wasm");
    std::fs::write(&path, wasm).expect("write OUT_DIR/probe.wasm");
    println!("cargo:rerun-if-changed=build.rs");
}
