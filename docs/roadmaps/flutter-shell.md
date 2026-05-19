# 路线图：Flutter 产品壳与工作台

母文档：[`harness-rust-flutter.md`](./harness-rust-flutter.md)  
YAML：`flutter-shell`。

执行进度对照：[`openflow-platform-progress.md`](./openflow-platform-progress.md)（项目编辑器 / Agent 工作台 / 短剧空间等）。  
小说 / 爬虫内容接入专项：[`novel-intake-crawler-plan.md`](./novel-intake-crawler-plan.md)（落地里程碑以进度文件为准）。

## 基线（当前分支）

| 条目 | 状态 | 说明 |
|------|------|------|
| 可配置 baseUrl、桌面 + Web 连 Rust | `baseline_done` | |
| Projects / script / production / tasks / quality / short-video 等产品入口 | `baseline_done` | YAML 长描述已概括 |

## 下一阶段

| 内容 | 状态 | 备注 |
|------|------|------|
| `short_video_space/*` 静态分析告警清零 | `next` | **必做** |
| Web：CORS / token / 深链方案文档化 | `next` | **必做**；与 [`roadmap-repo-contract-infra.md`](./roadmap-repo-contract-infra.md) 联动 |
| 大屏信息架构（减少单文件复杂度） | `next` | **必做**；≤800 行/file |
| 429 / 配额耗尽统一 UX | `tracked` | 共享 `Retry-After` / `retry_after_ms` 解释层 + 全局 Snackbar；与 [`platform-capabilities-backlog.md`](./platform-capabilities-backlog.md) P-D3 联动 |
| 公开只读 Status / Health 页 | `tracked` | Flutter `/status` 页聚合公开探针，带 `INTERNAL_OPS_TOKEN` 时附加内部队列统计；与 [`platform-capabilities-backlog.md`](./platform-capabilities-backlog.md) P-B3 联动 |

## 验收

- `flutter analyze`、`flutter test`（门禁脚本已包含）。

## 执行计划与工作包

> **维护约定**：与 [`harness-rust-flutter.md`](./harness-rust-flutter.md) 及上文表格一致；落地时在同一竖切或跟进 PR 中更新对应 WP。与实现冲突处以代码与 OpenAPI 为准。
>
> **全栈**：凡影响用户/运营可见行为的工作包，须 **同里程碑** 交付 **Rust + OpenAPI/WS（若适用）+ `frontend/`（含 `rust_api` 与相关 UI/错误态）**；纯文档/运维且无 API 的 WP 可在「目标」首行标 **`(ops-only)`**。约定见 [**`full-stack-delivery-covenant.md`**](./full-stack-delivery-covenant.md)。

### WP-A：`short_video_space/*` 静态分析清零

| 项 | 内容 |
|----|------|
| **目标** | **必做**：`flutter analyze` 清零；例外仅允许列入书面 exclude 清单并经 review。 |
| **依赖** | 无外部阻塞。 |
| **PR 切片** | （1）逐项修复 `dart analyze`；（2）过大文件拆分 `*_widgets.dart` / `*_logic.dart`（≤800 行）。 |
| **触点** | `frontend/lib/short_video_space/`；`rust_api` 签名变迁须同步。 |
| **测试** | **必做**：现有 `flutter test` 全绿；**必做**：为短剧空间核心入口新增最小 widget/smoke 测试。 |
| **回滚** | Revert 对应提交；优先小 PR。 |

### WP-B：Web 客户端 CORS / Token / 深链文档

| 项 | 内容 |
|----|------|
| **目标** | 贡献者能在 10 分钟内理解 Web 版如何配 `baseUrl`、Supabase session、刷新 token 失败时的 UX。 |
| **依赖** | 与 [`roadmap-repo-contract-infra.md`](./roadmap-repo-contract-infra.md) WP-A 一致的真实部署 URL 规范。 |
| **PR 切片** | （1）**必做**：新增 `docs/plans/flutter-web-client.md`（README 仅可链向该文）；（2）**必做**：`baseUrl`/Auth 初始化处注释链接文档。 |
| **触点** | `frontend/lib/` 环境与 API client；`supabase_flutter` 配置。 |
| **测试** | **必做**：文档审查 + **书面 Web smoke 矩阵**（手工步骤入库）；自动化能覆盖则追加，不因成本减免矩阵。 |
| **回滚** | 文档删除不影响运行时。 |

### WP-C：大屏信息架构与组件拆分

| 项 | 内容 |
|----|------|
| **目标** | Project editor、Agent workspace、短剧空间等大入口保持「一层导航清晰 + 子组件文件化」。 |
| **依赖** | 导航结构以交付为准；若产品改名须同步 PR 更新图表与路由文案（**必做**连贯修订）。 |
| **PR 切片** | （1）按用户旅程画 ASCII/mermaid 导航图放进 [`openflow-platform-progress.md`](./openflow-platform-progress.md) 或本文档；（2）每个 PR 只迁移一个对话框/区块 StatelessWidget；（3）禁止单 PR 超大搬家。 |
| **触点** | `frontend/lib/project_editor/`；`frontend/lib/agent_workspaces/`；`frontend/lib/short_video_space/`。 |
| **测试** | `flutter analyze`；关键路径手动点测。 |
| **回滚** | Git revert 单 PR。 |

### WP-D：429 / 配额耗尽统一 UX

| 项 | 内容 |
|----|------|
| **目标** | 把 Rust API 的 `429`、`quota_exceeded`、`Retry-After`、`retry_after_ms` 统一翻译成用户可读提示，并让主路径默认走共享反馈层。 |
| **依赖** | 后端错误体与 header 已存在；优先复用 [`frontend/lib/platform/rust_api_feedback.dart`](../../frontend/lib/platform/rust_api_feedback.dart)。 |
| **PR 切片** | （1）共享错误解释 / Snackbar helper；（2）Projects / Jobs / Task Center / Team Workspaces / probes 接入；（3）文档回链到平台补遗表。 |
| **触点** | `frontend/lib/platform/`、`frontend/lib/*controller.dart`、团队 workspace 入口；必要时补 `rust_api/core.dart` 解析。 |
| **测试** | 后续门禁时补 widget / controller 定向验证：`429`、`quota_exceeded`、普通 `404/403` 文案分流正确。 |
| **回滚** | helper 与接入点按文件 revert，不影响后端协议。 |

### WP-E：公开只读 Status / Health 页

| 项 | 内容 |
|----|------|
| **目标** | 提供一个可以直接打开的 Flutter `/status` 页面，公开展示服务存活、readiness 与版本信息；若注入 `INTERNAL_OPS_TOKEN`，则顺带展示队列统计。 |
| **依赖** | 复用已有 `/health`、`/api/v1/health`、`/api/v1/ready`、`/api/v1/version`；队列统计复用 `GET /api/v1/jobs/queue/stats`。 |
| **PR 切片** | （1）独立 `StatusPage`；（2）基于 `Uri.base.path` 的入口分流；（3）文档回链到平台补遗表。 |
| **触点** | `frontend/lib/main.dart`、`frontend/lib/status_page.dart`、`frontend/lib/rust_api/system/`、`frontend/lib/rust_api/jobs/queue_stats.dart`。 |
| **测试** | 后续门禁时补最小页面 smoke：`/status` 初始加载、公开接口失败态、带 token 队列统计显示。 |
| **回滚** | 删除 `/status` 入口与页面文件，不影响业务主路径。 |
