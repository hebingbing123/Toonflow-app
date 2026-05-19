# Generated Bridge Output

这个目录保留给 `flutter_rust_bridge_codegen` 输出 Dart glue。

当前约定：

- Rust 输入：`../../../../rust_core/crates/openflow_core_bridge/src/lib.rs`
- Dart 输出目录：本目录
- Rust glue：`../../../../rust_core/crates/openflow_core_bridge/src/frb_generated.rs`
- 业务代码入口：`../openflow_native_bridge.dart`

这样可以把生成代码和手写代码隔开。
