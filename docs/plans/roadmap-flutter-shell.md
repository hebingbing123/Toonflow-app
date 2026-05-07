# 路线图：Flutter 产品壳与工作台

母文档：[`harness-rust-flutter.md`](./harness-rust-flutter.md)  
YAML：`flutter-shell`。

执行进度对照：[`toonflow-platform-progress.md`](./toonflow-platform-progress.md)（项目编辑器 / Agent 工作台 / 短剧空间等）。

## 基线（当前分支）

| 条目 | 状态 | 说明 |
|------|------|------|
| 可配置 baseUrl、桌面 + Web 连 Rust | `baseline_done` | |
| Projects / script / production / tasks / quality / short-video 等产品入口 | `baseline_done` | YAML 长描述已概括 |

## 下一阶段

| 内容 | 状态 | 备注 |
|------|------|------|
| `short_video_space/*` 静态分析告警清零 | `next` | `toonflow-platform-progress.md`「已知阻塞」曾提及 |
| Web：CORS / token / 深链方案文档化 | `next` | 与 [`roadmap-repo-contract-infra.md`](./roadmap-repo-contract-infra.md) 联动 |
| 大屏信息架构（减少单文件复杂度） | `next` | 维持 ≤800 行文件 guideline |

## 验收

- `flutter analyze`、`flutter test`（门禁脚本已包含）。

## 实施步骤（草案）

### WP-A：`short_video_space/*` 静态分析清零

| 项 | 内容 |
|----|------|
| **目标** | `flutter analyze` 无 info/warning 累积（或按团队约定仅允许 exclude 清单内例外）。 |
| **依赖** | 无外部阻塞。 |
| **PR 切片** | （1）`dart analyze` 输出逐项修复（`avoid_print`、`deprecated`、无效 null check 等）；（2）过大文件按职责拆到同级 `*_widgets.dart` / `*_logic.dart`（遵守 ≤800 行指引）。 |
| **触点** | `frontend/lib/short_video_space/`；关联 `rust_api` 若签名变迁。 |
| **测试** | `flutter test` 目录内现有用例 + 新增最小 widget 测试（可选）。 |
| **回滚** | Revert 对应提交；优先小 PR。 |

### WP-B：Web 客户端 CORS / Token / 深链文档

| 项 | 内容 |
|----|------|
| **目标** | 贡献者能在 10 分钟内理解 Web 版如何配 `baseUrl`、Supabase session、刷新 token 失败时的 UX。 |
| **依赖** | 与 [`roadmap-repo-contract-infra.md`](./roadmap-repo-contract-infra.md) WP-A 一致的真实部署 URL 规范。 |
| **PR 切片** | （1）`docs/plans/flutter-web-client.md`（或 README 章节）；（2）代码内统一 `baseUrl` 读取入口注释链接到文档。 |
| **触点** | `frontend/lib/` 下环境与 API client 初始化；`supabase_flutter` 配置处。 |
| **测试** | 文档审查；可选集成测试跳过（Web 驱动成本高）。 |
| **回滚** | 文档删除不影响运行时。 |

### WP-C：大屏信息架构与组件拆分

| 项 | 内容 |
|----|------|
| **目标** | Project editor、Agent workspace、短剧空间等大入口保持「一层导航清晰 + 子组件文件化」。 |
| **依赖** | 产品设计不剧烈摇摆（避免反复改名）。 |
| **PR 切片** | （1）按用户旅程画 ASCII/mermaid 导航图放进 [`toonflow-platform-progress.md`](./toonflow-platform-progress.md) 或本文档；（2）每个 PR 只迁移一个对话框/区块 StatelessWidget；（3）禁止单 PR 超大搬家。 |
| **触点** | `frontend/lib/project_editor/`；`frontend/lib/agent_workspaces/`；`frontend/lib/short_video_space/`。 |
| **测试** | `flutter analyze`；关键路径手动点测。 |
| **回滚** | Git revert 单 PR。 |
