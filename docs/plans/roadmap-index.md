# 路线图索引（从 harness-rust-flutter 拆分）

母文档：[`harness-rust-flutter.md`](./harness-rust-flutter.md)（含 YAML `todos` 与正文 §0–§13）。

竖切落地进度（Phase 1 执行节奏）：[`toonflow-platform-progress.md`](./toonflow-platform-progress.md)。

## 为什么要拆

`harness-rust-flutter.md` 是**总蓝图**：架构取舍、历史评估与里程碑 YAML 挤在一起，不利于「按方向排期、更新状态」。  
这里按**工程方向**拆成独立文件，每个文件内用统一表格跟踪「基线已完成 vs 下一阶段」。

## 状态约定（与各路线图文件一致）

| 状态 | 含义 |
|------|------|
| `baseline_done` | 与当前重构分支一致：YAML 标 completed 或代码已落地 |
| `next` | 建议在下一迭代排期 |
| `blocked` | 依赖外部（凭证、法务、生产环境等） |

## 分文件一览

| 文件 | 覆盖的 YAML `id` / 主题 |
|------|-------------------------|
| [`roadmap-repo-contract-infra.md`](./roadmap-repo-contract-infra.md) | `git-branch`、`monorepo-layout`、`api-contract`、`postgres-ops`、`supabase-auth` |
| [`roadmap-backend-harness.md`](./roadmap-backend-harness.md) | `rust-backend-mvp`、`harness-rust-core` |
| [`roadmap-jobs-saas.md`](./roadmap-jobs-saas.md) | `jobs-and-webhook-hardening`、`saas-product-spec` |
| [`roadmap-quality.md`](./roadmap-quality.md) | `quality-bar` |
| [`roadmap-flutter-shell.md`](./roadmap-flutter-shell.md) | `flutter-shell` |
| [`roadmap-parity-shipping.md`](./roadmap-parity-shipping.md) | `product-shipping-bar`、`master-detailed-parity-audit`、`decommission-electron`、`implementation-order`（仅作顺序引用） |

## 你怎么用

1. **周计划**：从 [`toonflow-platform-progress.md`](./toonflow-platform-progress.md) 看当前 Phase；从本索引跳进对应方向文件，勾选 `next` 行。
2. **发版前**：优先核对 [`roadmap-parity-shipping.md`](./roadmap-parity-shipping.md) 与 [`electron-node-parity.md`](./electron-node-parity.md)。
3. **商业/合规**：[`roadmap-jobs-saas.md`](./roadmap-jobs-saas.md) 里标 `blocked` 的项不要强行在代码里「假装完成」。
