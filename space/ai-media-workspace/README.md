# AI Media Workspace

## 定位

这个 Space 用来收口 Openflow 后续的 **AI 视频工作流 + 图片素材编辑 + 桌面生产 / Web 协作** 能力。

它不是替代现有 `short-video` 资料，而是把之前分散在短视频、成片装配、Flutter + Rust 重构讨论里的结论，提升成一个更上层的产品空间：

- **桌面端**：主生产工作台，承担重型视频/图片编辑、代理生成、导出、批量任务。
- **Web / 手机端**：协作、审核、任务入口、结果回看；遇到重型剪辑时引导用户切到桌面端。
- **Rust**：由根目录同级的 [`../../rust_core/`](../../rust_core/README.md) 承载媒体处理、工作流编排、时间线 / 图层 / 任务引擎。
- **Flutter**：统一 UI 壳、交互、参数面板、工作台导航。

## 核心判断

1. **视频 / 图片编辑内核应该以 Rust 为主**，但不把完整重媒体负载默认压到中心服务端。
2. **Flutter 负责跨端 UI**，Rust 以内嵌引擎或服务形态承载核心能力。
3. **不与 Photoshop 绑定**，图片编辑走自定义图层 / 蒙版 / 变换 / AI 素材工作流模型。
4. **Web / 手机端不追求完整重剪辑**，主打协作和任务入口，并把重操作顺滑接力到桌面端。

## 文档索引

- [`requirements.md`](./requirements.md)：产品范围、平台分工、验收边界
- [`architecture.md`](./architecture.md)：桌面 / Web / Rust Core / Rust Service 分层架构
- [`tasks.md`](./tasks.md)：按波次拆分的实施任务清单

## 与已有 spec 的关系

这个 Space 建立在以下既有文档之上，不推翻原结论，而是做统一收口：

- [`../../rust_core/README.md`](../../rust_core/README.md)：桌面与服务端共用的 Rust 编辑内核目录
- [`../../docs/plans/harness-rust-flutter.md`](../../docs/plans/harness-rust-flutter.md)：Rust + Flutter 主重构路线
- [`../short-video/README.md`](../short-video/README.md)：短视频 Space 总览
- [`../../docs/plans/moneyprinter-short-video-space.md`](../../docs/plans/moneyprinter-short-video-space.md)：短视频入口编排与流水线视角
- [`../../docs/plans/short-video-light-editing-spec.md`](../../docs/plans/short-video-light-editing-spec.md)：成片装配与轻量粗剪边界
- [`../../docs/plans/studio-competitive-ui-benchmark.md`](../../docs/plans/studio-competitive-ui-benchmark.md)：Studio 工作台 UI 方向
- [`../../docs/plans/workspace-team-full-plan.md`](../../docs/plans/workspace-team-full-plan.md)：团队协作与多用户上下文

## 这份 Space 解决什么问题

之前的结论已经足够说明：

- Rust 很适合做 AI 视频工作流引擎
- 桌面端适合承载重媒体编辑
- Web / 手机端不适合硬做完整 NLE

但这些判断还分散在多份文档里，缺少一个统一的产品层空间来回答下面几个问题：

- 哪些能力一定在桌面端？
- 哪些能力只做协作入口？
- Rust Core 与 Rust Service 的边界如何切？
- 图片编辑和视频剪辑怎样共用项目 / 任务 / 资产模型？
- 用户从 Web / 手机端切到桌面端时，怎样无缝接力？

这个 Space 就是为这些问题服务的。
