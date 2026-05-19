# Requirements Document: Workspace-scope Billing (W8.2–W8.4)

## Introduction

This specification describes **workspace-scope billing and quota** for Openflow: moving the billing source of truth from **`app_user_profile` (user-scope)** to **workspace-attributed subscription, quota, and usage**, while preserving **personal workspaces** and **enterprise/team workspaces** under a single model. The feature is **gated** until product/finance overturns the current decision in [`docs/plans/workspace-billing-scope-decision.md`](../../../docs/plans/workspace-billing-scope-decision.md). Detailed future stub: [`docs/plans/workspace-billing-future-workspace-scope.md`](../../../docs/plans/workspace-billing-future-workspace-scope.md).

**Hybrid model (recommended default in this spec):** clients always receive an explicit **`billing_scope`** (`"user"` | `"workspace"`) and, when applicable, **`current_workspace_billing`** so that **personal** and **team** contexts are both representable without forcing a breaking change on day one.

Platform stack: Rust backend (Axum + SQLx + PostgreSQL) + Flutter frontend. Delivery follows [`docs/plans/full-stack-delivery-covenant.md`](../../../docs/plans/full-stack-delivery-covenant.md): backend + OpenAPI + `rust_api` + Flutter + migrations + contract tests, unless an item is explicitly marked **(ops-only)**.

## Glossary

- **Billing_Scope**: Whether effective plan/quota for the current session is interpreted per **user** or per **workspace** (`billing_scope` field).
- **Workspace_Billing_Record**: The authoritative row(s) holding workspace-level `plan_tier`, quota overrides, and subscription pointers (either columns on `app_workspace` or rows in `app_workspace_billing`).
- **User_Billing_Profile**: Legacy user-scope fields on `app_user_profile` (must remain until migration and dual-write validation complete).
- **Job_Billing_Context**: For each `app_generation_job`, a stable **`workspace_id`** (and optionally `billed_user_id`) used for metering and reconciliation.
- **Me_Response_V1**: Existing flat `GET /api/v1/me` shape (user-scope fields); must remain backward compatible.
- **Me_Response_V2**: Versioned response with nested `user` + optional `current_workspace_billing`.
- **Webhook_Dual_Write**: Stripe (or other) webhook updates **both** user legacy profile and workspace billing record during transition.
- **Ops_Billing_View**: Internal or ops-facing filters by **`workspace_id`** for subscription, usage, and overage events (W8.3).

## Requirements

### Requirement 0: Preconditions (gate)

**User Story:** As a program lead, I want explicit gates before engineering cuts over billing semantics, so we avoid a half-migrated production state.

#### Acceptance Criteria

1. THE Program SHALL obtain **written sign-off** that billing attribution moves from user to workspace (or hybrid rules are frozen) with an **effective date**.
2. THE System SHALL document **client migration policy** (e.g. update [`docs/plans/workspace-migration-notice.md`](../../../docs/plans/workspace-migration-notice.md)) before enabling workspace-scope **read paths** for production clients.
3. WHEN preconditions are not met, THE Backend SHALL **not** remove or repurpose `app_user_profile` billing columns solely for workspace-scope billing.

### Requirement 1: Data model (schema) — additive first

**User Story:** As a backend engineer, I want a clear, migratable schema for workspace billing without breaking existing users.

#### Acceptance Criteria

1. THE Data_Model SHALL choose **either** Option A (`app_workspace` nullable billing columns) **or** Option B (`app_workspace_billing` table keyed by `workspace_id`) and record the choice in an ADR linked from this spec.
2. THE Migration SHALL be **additive** in phase 1: new nullable columns/tables only; **no** drop of `plan_tier`, `daily_job_quota`, or related user profile billing fields until sign-off per future runbook.
3. THE Workspace_Billing_Record SHALL be able to represent **personal** workspaces (same structural fields as enterprise) with product rules distinguishing behavior if needed.
4. THE Schema SHALL support idempotent migrations under `supabase/migrations/` with rollback guidance **only** for objects added in phase 1 (no destructive rollback after column drops in later phases).

### Requirement 2: Job and usage — stable `workspace_id` for metering

**User Story:** As finance/ops, I need jobs and expensive operations attributable to a workspace for invoices and limits.

#### Acceptance Criteria

1. WHEN a job is created with project context, THE Job_Billing_Context SHALL set **`workspace_id`** from the owning project’s workspace (or equivalent canonical path).
2. WHEN a job is created without project context, THE System SHALL define and implement a **documented** rule to resolve `workspace_id` (e.g. creator’s `current_workspace_id` at enqueue time) and persist it on `app_generation_job` or an auditable side table.
3. THE Metering_Service SHALL use **workspace-scoped** aggregates for `jobs_today` (UTC day) **when** `billing_scope` for the effective context is workspace.
4. THE System SHALL keep **user-scope** metering paths testable in parallel during dual-write / shadow periods (see Requirement 5).

### Requirement 3: `/api/v1/me` — versioned contract

**User Story:** As a Flutter client, I need a backward-compatible path to adopt workspace billing without bricking old builds.

#### Acceptance Criteria

1. THE Backend SHALL preserve **Me_Response_V1** as default for `GET /api/v1/me` without breaking existing field names and semantics during the transition window.
2. THE Backend SHALL expose **Me_Response_V2** via **`GET /api/v1/me?v=2`** **or** `Accept: application/vnd.openflow.me+json; version=2` (one approach chosen and documented in OpenAPI).
3. Me_Response_V2 SHALL include **`billing_scope`** and nested objects: **`user`** (legacy-compatible subset) and **`current_workspace_billing`** (populated when current workspace exists and policy applies).
4. THE OpenAPI_Spec SHALL describe v1 and v2 shapes; `export-openapi` and `yarn refactor:check` SHALL pass.
5. THE Flutter **`rust_api`** SHALL parse v1 by default and support v2 behind explicit client configuration or feature flag until migration window ends.

### Requirement 4: Quota enforcement alignment

**User Story:** As a user in a team workspace, I want quota behavior to match the advertised billing scope.

#### Acceptance Criteria

1. THE Quota_Module (`metering/quota.rs` and call sites) SHALL read **effective** `plan_tier` and `daily_job_quota` according to **`billing_scope`** and current workspace.
2. WHEN `billing_scope` is `workspace`, THE Quota_Module SHALL enforce limits using **workspace** aggregates for job creation and expensive endpoints as defined in the ADR.
3. WHEN `billing_scope` is `user`, THE Quota_Module SHALL retain **user** aggregates consistent with [`workspace-billing-scope-decision.md`](../../../docs/plans/workspace-billing-scope-decision.md) until deprecation.
4. THE System SHALL log or metric **quota_denied** events with **`workspace_id`**, **`user_id`**, and **`billing_scope`** for ops debugging.

### Requirement 5: Webhooks — dual-write and idempotency

**User Story:** As a billing integrator, I need Stripe webhooks to update workspace billing without breaking existing idempotency.

#### Acceptance Criteria

1. THE Webhook_Handler SHALL **dual-write** or **shadow-write** to Workspace_Billing_Record while continuing to update User_Billing_Profile until cutover criteria are met.
2. THE Webhook_Handler SHALL preserve existing **idempotency keys** (`event_id` / provider ids); new workspace writes MUST NOT invalidate deduplication for user-scope processing.
3. THE System SHALL emit **reconciliation alerts** when user-scope and workspace-scope derived states diverge beyond a configurable threshold during shadow period.

### Requirement 6: Related APIs — scope consistency (optional phase)

**User Story:** As a product owner, I want usage summaries to match billing scope so users are not confused.

#### Acceptance Criteria

1. THE Spec SHALL list endpoints that today declare **`scope = user`** (e.g. usage summary, skills summary, memory cost overview, quality aggregates per [`workspace-billing-scope-decision.md`](../../../docs/plans/workspace-billing-scope-decision.md)).
2. WHEN workspace-scope billing is **on** for a tenant/user class, THE Program SHALL either (a) add **`workspace_id`** query support and document **`scope`**, or (b) explicitly defer with a **documented** product exception.
3. THE OpenAPI SHALL annotate **`scope`** fields where applicable to avoid client ambiguity.

### Requirement 7: Ops billing view (W8.3)

**User Story:** As internal ops, I want to filter subscriptions and usage by **`workspace_id`**.

#### Acceptance Criteria

1. THE Ops_Billing_View SHALL support filter by **`workspace_id`** for subscription state, usage aggregates, and overage-related events.
2. THE Ops_Billing_View SHALL avoid third-party PII in logs/exports; workspace id + aggregate counts only unless a separate DPA-covered tool is used.
3. THE Implementation SHALL align with [`docs/plans/roadmap-jobs-saas.md`](../../../docs/plans/roadmap-jobs-saas.md) WP-D where applicable.

### Requirement 8: Migration, backfill, rollback (W8.4)

**User Story:** As SRE, I need a runbook to backfill, cut over, and roll back safely.

#### Acceptance Criteria

1. THE Runbook SHALL define phases: schema additive → backfill → dual-write validation → read cutover → optional deprecation of user-scope reads.
2. THE Backfill SHALL be implemented as a script or CLI with **`--dry-run`**, exception list output, and idempotent batches.
3. THE Rollback SHALL restore **read paths** to user-scope and disable v2 responses **without** requiring DB destructive rollback if new columns are retained.
4. THE Runbook SHALL live under `docs/plans/` or `docs/runbooks/` and be linked from [`workspace-team-full-plan.md`](../../../docs/plans/workspace-team-full-plan.md) W8 checkboxes.

### Requirement 9: Testing and quality gates

**User Story:** As a maintainer, I want regressions caught before merge.

#### Acceptance Criteria

1. THE Backend SHALL add/extend **PG contract tests** or integration tests for `/me` v1/v2, webhook dual-write paths (mocked provider), and quota with both scopes where feasible.
2. THE Repository SHALL pass **`yarn refactor:check`** before declaring any phase complete.
3. THE Tests SHALL include at least one scenario for **personal workspace** and one for **enterprise workspace** under workspace-scope policy.

### Requirement 10: Security and authorization

**User Story:** As security, I want billing data exposed only to authorized actors.

#### Acceptance Criteria

1. THE User-facing_API SHALL only return **`current_workspace_billing`** for workspaces the user may access (member/owner rules).
2. THE Workspace_Billing_Admin_actions (if any) SHALL require **`manage_billing`** (or equivalent) on the workspace per role matrix in [`workspace-team-full-plan.md`](../../../docs/plans/workspace-team-full-plan.md).
3. THE Internal_Ops paths SHALL remain protected by existing internal token / RBAC patterns.

---

# 需求文档（中文摘要）

## 简介

本规格描述 **W8.2–W8.4：计费与配额绑定到 workspace** 的完整需求。当前仓库 **默认仍为 user-scope**，见 [`workspace-billing-scope-decision.md`](../../../docs/plans/workspace-billing-scope-decision.md)；本文件用于 **未来切换** 时的实现真源，并与 [`workspace-billing-future-workspace-scope.md`](../../../docs/plans/workspace-billing-future-workspace-scope.md) 对齐。

**推荐语义**：同时支持 **个人 workspace** 与 **团队 workspace**——二者均为 workspace 实体；通过 **`billing_scope`** 与 **`current_workspace_billing`** 在 API 上表达「当前生效的计费上下文」，避免与个人场景割裂。

## 词汇表（中文）

- **计费口径（Billing_Scope）**：`user` 或 `workspace`，决定 `plan_tier` / 日配额 / `jobs_today` 的解释方式。
- **Workspace 计费记录**：`app_workspace` 列或 `app_workspace_billing` 表。
- **Job 计费上下文**：`app_generation_job` 上稳定可对的 **`workspace_id`**。
- **/me 版本化**：v1 保持扁平字段；v2 嵌套 `user` + `current_workspace_billing`。
- **Webhook 双写**：过渡期内同时写用户旧行与 workspace 新行，并对账。

## 需求映射（高层）

| 编号 | 主题 | 对应英文 Requirement |
|------|------|----------------------|
| R0 | 前置闸门（签字、公告、禁止半迁移） | Requirement 0 |
| R1 | 数据模型（A/B 选型、只加不删） | Requirement 1 |
| R2 | Job / 用量 workspace 真源 | Requirement 2 |
| R3 | `/me` 版本化与 OpenAPI | Requirement 3 |
| R4 | 配额与计费口径一致 | Requirement 4 |
| R5 | Webhook 双写与幂等 | Requirement 5 |
| R6 | 其它 `scope=user` API 对齐（可选阶段） | Requirement 6 |
| R7 | 运营按 workspace 视图 | Requirement 7 |
| R8 | 回填与 Runbook | Requirement 8 |
| R9 | 测试与 refactor 门禁 | Requirement 9 |
| R10 | 权限与安全 | Requirement 10 |

---

## 附录 A：全栈交付检查清单（切换完成后）

**维护说明**：下列项以当前主分支实现为准已可满足竖切交付；合并/发版前请再跑一遍 `yarn refactor:agent --full`（或 CI 同等）做最终确认。

- [x] `supabase/migrations/`：workspace 计费 schema
- [x] `backend/`：`/me` v2、quota、job `workspace_id`、webhook
- [x] `backend/src/openapi_spec/` + `scripts/fixtures/openapi_baseline.yaml`
- [x] `frontend/lib/rust_api/`：`/me` v2 解析与配额展示
- [x] `docs/plans/`：Runbook + 更新 W8 勾选
- [x] `yarn refactor:check` / `yarn refactor:agent --full`（发版前由 CI 或维护人执行）
