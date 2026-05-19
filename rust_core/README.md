# Rust Core

`rust_core/` 是和 `backend/`、`frontend/` 同级的独立 Rust workspace。

它的职责不是做 HTTP 服务，也不是做 Flutter UI，而是承载 Openflow 后续的媒体编辑与 AI 工作流内核：

- 视频时间线
- 图片编辑文档
- 工作流图与任务编排
- 代理 / 预览 / 导出语义

## 为什么单独放一层

把编辑引擎单独放在 `rust_core/`，可以避免两类长期耦合：

1. `backend/` 被桌面端编辑实现细节拖着走
2. `frontend/` 反向定义媒体核心模型

这个目录默认服务两个宿主：

- **桌面端宿主**：Flutter Desktop 通过 FFI / bridge 调用
- **服务端宿主**：`backend/` 按需复用相同领域模型与校验逻辑

## 当前 crate

- `openflow_core_bridge`：Flutter Desktop 直接对接的桥接入口 crate
- `media_timeline`：视频粗剪 / 时间线文档基础模型
- `media_image_doc`：图片图层 / 蒙版 / 变换基础模型
- `media_workflow`：AI 工作流节点、依赖和运行状态基础模型

## Flutter bridge 约定

桌面端优先采用 `flutter_rust_bridge`。

- Rust 入口：`rust_core/crates/openflow_core_bridge/src/lib.rs`
- Dart 入口目录：`frontend/lib/native_bridge/`
- 生成输出目录：`frontend/lib/native_bridge/generated/`

建议流程：

1. 在 Flutter 侧引入 `flutter_rust_bridge`
2. 用 `flutter_rust_bridge_codegen generate` 从 `crate::api` 生成 Dart glue 和 Rust glue
3. 让 Flutter 只依赖 `openflow_core_bridge`，不要直接跨进 `media_*` crate

## 下一步建议

1. 给桌面端选定 bridge 方案，例如 `flutter_rust_bridge`
2. 在 `backend/` 内按需引入 `path = "../rust_core/crates/..."` 的依赖
3. 把 `short_video` 中稳定的时间线 / assembly 规则逐步下沉到 `media_timeline`
4. 再补 `media_export`、`media_preview`、`media_assets`
