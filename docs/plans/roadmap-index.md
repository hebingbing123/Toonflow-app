# 路线图索引（从 harness-rust-flutter 拆分）

母文档：[`harness-rust-flutter.md`](./harness-rust-flutter.md)（含 YAML `todos` 与正文 §0–§13）。

竖切落地进度（Phase 1 执行节奏）：[`toonflow-platform-progress.md`](./toonflow-platform-progress.md)。

## 为什么要拆

`harness-rust-flutter.md` 是**总蓝图**：架构取舍、历史评估与里程碑 YAML 挤在一起，不利于「按方向排期、更新状态」。  
这里按**工程方向**拆成独立文件，每个文件内用统一表格跟踪「基线已完成 vs 下一阶段」。  
各分册文末另有 **`## 执行计划与工作包`**：按 **工作包（WP）** 列出目标、依赖、PR 切片、代码/文档触点、测试与回滚。**本节与母文档同级维护**：实现或契约变动时，应在同一竖切或紧跟的 PR 里更新对应 WP——这是仓库**默认采纳**的执行拆解，不是搁置的「待定草案」。若文字与实现不一致，以代码与 OpenAPI 为真源，并须 PR 修正本节。

**全栈交付**：用户/运营可见的能力 **默认 = `backend/` + `frontend/`（含 `rust_api`）+ 契约文档** 同里程碑；例外须标 **`(ops-only)`**。全文见 [**`full-stack-delivery-covenant.md`**](./full-stack-delivery-covenant.md)。**平台级补遗能力池**（通知、搜索、API Key、出站 webhook、合规导出等）见 [**`platform-capabilities-backlog.md`**](./platform-capabilities-backlog.md)，纳入迭代时在对应 `roadmap-*` 或 `workspace-team-full-plan` 打勾并回链本表。

**必做约定**：各分册「下一阶段」表与工作包 **一律要求收口**（观测、抽象、文档、验收、Gate 定义），不作「无责任人路线图」。表中区分 **落地顺序**、**外部 Gate**（`blocked`：凭证、法务、生产 URL 等），以及 **架构 Gate**（母文档已否掉的默认组件——典型如旁路队列——**未触发量化瓶颈前不立项**）。合并代码时不得把未完成项伪装成已完成。

**真源优先级（三者冲突时）**：① 代码与 OpenAPI / `docs/websocket-events.md` ② [`harness-rust-flutter.md`](./harness-rust-flutter.md) 架构取舍（尤其 §7.1、§11–§13）③ 本分册 roadmap ④ `.kiro/specs/` 专题。

## 状态约定（与各路线图文件一致）

| 状态 | 含义 |
|------|------|
| `baseline_done` | 与当前重构分支一致：YAML 标 completed 或代码已落地 |
| `next` | 待落地（已排入迭代；**必做收口**，按 Phase / 依赖排序） |
| `blocked` | **仍须跟踪**；含 **外部 Gate**（凭证、法务、环境）或 **架构 Gate**（例：旁路队列未立项）；条件满足后转入 `next` 并执行对应 WP |

## 分文件一览

| 文件 | 覆盖的 YAML `id` / 主题 |
|------|-------------------------|
| [`roadmap-repo-contract-infra.md`](./roadmap-repo-contract-infra.md) | `git-branch`、`monorepo-layout`、`api-contract`、`postgres-ops`、`supabase-auth` |
| [`roadmap-backend-harness.md`](./roadmap-backend-harness.md) | `rust-backend-mvp`、`harness-rust-core` |
| [`roadmap-jobs-saas.md`](./roadmap-jobs-saas.md) | `jobs-and-webhook-hardening`、`saas-product-spec` |
| [`roadmap-quality.md`](./roadmap-quality.md) | `quality-bar` |
| [`roadmap-flutter-shell.md`](./roadmap-flutter-shell.md) | `flutter-shell` |
| [`roadmap-parity-shipping.md`](./roadmap-parity-shipping.md) | `product-shipping-bar`、`master-detailed-parity-audit`、`decommission-electron`、`implementation-order`（仅作顺序引用） |

## 尚未单独拆册的关联文档

竖切执行时经常要对照下列文件（后续若膨胀再考虑独立 `roadmap-*`）：

| 文档 | 用途 |
|------|------|
| [`http-api-cleanup.md`](./http-api-cleanup.md) | HTTP 收敛与迁移阶段（与 parity、OpenAPI 联动） |
| [`novel-intake-crawler-plan.md`](./novel-intake-crawler-plan.md) | 小说 / 爬虫内容接入与调度 |
| [`database-migration-history-policy.md`](./database-migration-history-policy.md) | `legacy_*` 与 historical 术语策略 |
| [`electron-node-parity.md`](./electron-node-parity.md) | 功能 parity 主表（发版前权威） |
| [`master-detailed-parity-audit.md`](./master-detailed-parity-audit.md) | master 逐项审计结论 |
| [仓库根 `AGENTS.md`](../../AGENTS.md) | Agent 门禁、`yarn refactor:check`、commit 约定 |
| [`tasks-pg-queue-observability.md`](./tasks-pg-queue-observability.md) | PG 队列 WP-A0 竖切（指标、Runbook、旁路队列 Gate） |
| [`jobs-pg-queue-runbook.md`](./jobs-pg-queue-runbook.md) | PG 任务队列运维 Runbook（与 WP-A0/A1 对齐） |
| [`tasks-http-api-cleanup.md`](./tasks-http-api-cleanup.md) | HTTP 收敛 **B·其余域** 竖切（H0–H5） |
| [`workspace-team-full-plan.md`](./workspace-team-full-plan.md) | 团队 Workspace **完整功能**任务总表（W1–W11，非 MVP） |
| [`full-stack-delivery-covenant.md`](./full-stack-delivery-covenant.md) | **全栈交付约定**（禁止只合后端无 Flutter） |
| [`platform-capabilities-backlog.md`](./platform-capabilities-backlog.md) | **平台级能力补遗**（全栈任务池，与主路线图正交） |

## 你怎么用

1. **周计划**：从 [`toonflow-platform-progress.md`](./toonflow-platform-progress.md) 看当前 Phase；从本索引跳进对应方向文件，勾选 `next` 行。
2. **发版前**：优先核对 [`roadmap-parity-shipping.md`](./roadmap-parity-shipping.md) 与 [`electron-node-parity.md`](./electron-node-parity.md)。
3. **商业/合规**：[`roadmap-jobs-saas.md`](./roadmap-jobs-saas.md) 中标 `blocked` 的仍是 **必做项**；在 Gate 未满足前不得伪造prod完成态，但须在 staging/文档侧把实现与验收清单做到「Gate 一开即可收口」。
4. **落到迭代**：把某个 WP 标成「本周在做」，做完把对应表格行从 `next` 改成 `baseline_done`（或打上完成日期），并在 [`toonflow-platform-progress.md`](./toonflow-platform-progress.md) 记一笔竖切 commit。
5. **契约门禁**：合并前默认跑 [`scripts/refactor-check.sh`](../../scripts/refactor-check.sh)（`yarn refactor:check`）；OpenAPI drift、`rust_api` 一致性、fmt/clippy/test 已覆盖，**不必**在 roadmap 里重复实现第二套检查，只在改契约时更新文档触点。
6. **平台级查漏**：每季度对照 [**`platform-capabilities-backlog.md`**](./platform-capabilities-backlog.md) 与 `harness-rust-flutter` 正文，将选中项并入某 `roadmap-*` WP 或 `workspace-team-full-plan` Phase。
