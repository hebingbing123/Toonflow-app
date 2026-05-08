# Workspace-scope billing — future implementation stub（W8.2–W8.4）

**状态**：**未实施**。仅在产品/财务推翻 [`workspace-billing-scope-decision.md`](./workspace-billing-scope-decision.md) 的 user-scope 结论后启用本文件。  
主计划：[`workspace-team-full-plan.md`](./workspace-team-full-plan.md) Phase W8。

## 1) 前置条件（全部满足后再开工）

- 书面签字：**计费归属**从 user 改为 workspace（或 hybrid）及生效日期。
- **jobs / usage / expensive calls** 能稳定解析 `workspace_id` 作为计费真源（至少与 `app_generation_job` 或等价视图对齐）。
- **客户端版本策略**：破坏性变更须同步 [`workspace-migration-notice.md`](./workspace-migration-notice.md)。

## 2) W8.2 — 字段落点、`/me` 形状与 webhook（版本化）

### 2.1 数据模型选项（选定其一并在迁移 PR 固定）

| 字段（示例） | 选项 A：workspace 列 | 选项 B：独立 `app_workspace_billing` |
|--------------|----------------------|-------------------------------------|
| `plan_tier` | `app_workspace.plan_tier` | 外键到 workspace |
| `daily_job_quota` | 同上或 JSON policy | 同上 |
| `jobs_today`（派生） | 物化视图按 `workspace_id` 聚合 job | 同上 |

**禁止**：在未完成回填与双写验证前删除 `app_user_profile` 上的旧列。

### 2.2 Webhook（Stripe 等）

- **过渡期**：webhook handler **双写**（user 旧行 + workspace 新行）或 **影子写入**新表，对照报表一致后再切读路径。
- **幂等**：沿用现有 `event_id` / provider idempotency；新增 workspace 维度不得破坏既有幂等键。

### 2.3 `/api/v1/me` 版本化（推荐）

- **默认**：保持现有响应（user-scope 字段），标记 `billing_scope: "user"`（若尚未存在则新增可选字段，默认 `user`）。
- **新形状**：新路由 **`GET /api/v1/me?v=2`** 或 **`Accept: application/vnd.toonflow.me+json; version=2`** 返回嵌套结构，例如：
  - `user`: `{ plan_tier, jobs_today, … }`（个人维度保留用于非团队场景）
  - `current_workspace_billing`: `{ workspace_id, plan_tier, quota, usage_summary }`（仅当 `current_workspace` 存在且策略为 workspace-scope 时填充）
- Flutter：`rust_api` 生成层按版本分支；旧客户端永不强制升级直到公告窗口结束。

## 3) W8.3 — Billing 运营视图（按 workspace 过滤）

- **目标**：运营后台或内部工具按 **`workspace_id`** 筛选订阅、用量、超额事件。
- **对齐**：[`roadmap-jobs-saas.md`](./roadmap-jobs-saas.md) WP-D（jobs SaaS 运营面）；数据源以 **workspace 聚合 job / invoice 指针** 为准，不与 Rust API 可见性假设冲突。
- **脱敏**：日志与导出不含第三方 PII；仅 workspace id + 聚合计数。

## 4) W8.4 — 迁移、回填与回滚 Runbook（提纲）

### 4.1 推荐阶段

1. **Schema**：加 nullable workspace 计费列或新表；无行为变更。
2. **回填**：批处理脚本：`workspace_id` 可由「enterprise owner 的首个付费 workspace」或产品规则映射；记录例外清单。
3. **双写**：webhook + job 计数双路径校验告警。
4. **切读**：`/me` v2、Flutter 读 workspace 配额。
5. **删冗**：停用 user 级聚合口径（若产品允许）；归档旧列。

### 4.2 回滚

- 保留 user-scope 列直至窗口结束；一键回滚 = 读路径回到 user + 关闭 v2 响应。
- **数据库**：rollback migration 仅在未删列前提下执行 `DROP` 新增对象。

### 4.3 脚本位置约定

- 迁移 SQL：`supabase/migrations/` 独立前缀批次。
- 回填：`scripts/` 或 `backend/` 一次性 crate，带 `--dry-run`。

---

*本文件仅为规格占位；未触发 workspace-scope 决策前，实现代码应保持 user-scope，避免半迁移状态。*
