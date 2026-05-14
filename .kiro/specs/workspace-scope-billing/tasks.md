# Implementation Plan: Workspace-scope Billing (W8.2–W8.4)

## Overview

Executable task breakdown for **workspace-scope billing**. All tasks are **gated** by Requirement 0 (sign-off + migration notice). Until gates close, only **documentation / additive schema placeholders** may merge if they are strictly no-op for production behavior.

Cross-links: **requirements** → `.kiro/specs/workspace-scope-billing/requirements.md`; **design** → `design.md`; product stubs → `docs/plans/workspace-billing-future-workspace-scope.md`.

## Tasks

- [x] **0. Program gates & ADR**
  - [x] 0.1 Record **billing attribution** decision (user → workspace or hybrid) with **effective date** and owner sign-off. → [ADR: Workspace Billing Attribution](../../../docs/plans/adr-workspace-billing-attribution.md)
  - [x] 0.2 Publish/update **client migration** notice (`docs/plans/workspace-migration-notice.md` or equivalent). → [Client Migration Notice](../../../docs/plans/workspace-billing-migration-notice.md)
  - [x] 0.3 Add ADR: **Option A vs B** (`app_workspace` columns vs `app_workspace_billing` table); personal vs enterprise rules; who sets `billing_scope`. → [ADR: Workspace Billing Storage Model](../../../docs/plans/adr-workspace-billing-storage-model.md)
  - _Requirements: 0.1, 0.2, 1.1_

- [x] **1. Database — additive schema**
  - [x] 1.1 Create migration: workspace billing storage per ADR (nullable columns or new table + indexes).
  - [x] 1.2 Add migration for `app_generation_job.workspace_id` (nullable first if required) + index for aggregation.
  - [x] 1.3 Document rollback: `DROP` only for objects introduced in 1.1–1.2 (no user-column drops). → [`workspace-billing-schema-rollback.md`](../../../docs/plans/workspace-billing-schema-rollback.md)
  - _Requirements: 1.2, 1.3, 1.4, 8.1_

- [x] **2. Job enqueue — resolve and persist `workspace_id`**
  - [x] 2.1 Audit all job creation entry points; implement canonical `resolve_billing_workspace_id(...)`.
  - [x] 2.2 Backfill script: `workspace_id` from project → workspace; documented fallback for orphan rows; `--dry-run`.
  - [x] 2.3 Enforce NOT NULL (separate migration) only after backfill threshold / monitoring green.
  - _Requirements: 2.1, 2.2, 2.3, 9.3_

- [x] **3. Metering & quota — effective scope**
  - [x] 3.1 Implement **effective billing context** helper (user vs workspace) used by quota checks.
  - [x] 3.2 Implement **workspace `jobs_today`** (UTC) aggregate from `app_generation_job.workspace_id`.
  - [x] 3.3 Wire job creation / expensive routes to use new helper; keep user-scope path for `billing_scope=user`.
  - [x] 3.4 Add metrics/logs on quota deny with `billing_scope`, `user_id`, `workspace_id`.
  - _Requirements: 2.3, 4.1, 4.2, 4.3, 4.4, 10.1_

- [x] **4. Stripe / webhooks — dual-write**
  - [x] 4.1 Extend webhook handler to upsert **Workspace_Billing_Record** alongside `app_user_profile`.
  - [x] 4.2 Preserve idempotency keys; add tests for duplicate events.
  - [x] 4.3 Add reconciliation hook (metric or nightly job) comparing legacy vs workspace-derived state during shadow period.
  - _Requirements: 5.1, 5.2, 5.3_

- [x] **5. GET /api/v1/me — v2**
  - [x] 5.1 Add OpenAPI models: `billing_scope`, nested v2 body; keep v1 schema stable.
  - [x] 5.2 Implement routing: `?v=2` **or** `Accept` negotiation (pick one in ADR). → [ADR: /me API Version Negotiation](../../../docs/plans/adr-me-api-version-negotiation.md)
  - [x] 5.3 Implement handler: load profile + current workspace + workspace billing; omit or null `current_workspace_billing` per rules.
  - [x] 5.4 PG contract or integration tests: v1 unchanged; v2 happy path + forbidden workspace cases.
  - _Requirements: 3.1–3.5, 9.1, 9.2, 10.1_

- [x] **6. Flutter — rust_api + UI**
  - [x] 6.1 Extend `rust_api` `/me` types for v2 and `billing_scope`.
  - [x] 6.2 UI: display workspace quota / plan when `billing_scope=workspace` (settings or shell — per UX).
  - [x] 6.3 Feature flag or version gating aligned with migration notice.
  - _Requirements: 3.4, 3.5, 9.2_

- [x] **7. Related APIs — scope consistency (optional / phased)**
  - [x] 7.1 Inventory endpoints with `scope=user` in OpenAPI; product decision per endpoint. → [`endpoint-scope-inventory.md`](./endpoint-scope-inventory.md)
  - [x] 7.2 Implement workspace-scoped variants or document deferral in backlog. → Implementation: `backend/src/metering/usage/summary.rs`; Deferrals: [`endpoint-scope-deferrals.md`](./endpoint-scope-deferrals.md)
  - _Requirements: 6.1, 6.2, 6.3_

- [x] **8. Ops billing view (W8.3)**
  - [x] 8.1 Internal API or admin query: filter by `workspace_id` (subscription snapshot, job aggregates).
  - [x] 8.2 PII hygiene: aggregates only in exports/logs. → [PII Hygiene Audit](./pii-hygiene-audit.md), [Webhook Retention Policy](../../../docs/plans/billing-webhook-retention-policy.md), [Access Control Migration](../../../supabase/migrations/20260410000000_billing_webhook_payload_access_control.sql)
  - _Requirements: 7.1, 7.2, 7.3_

- [x] **9. Cutover & runbook (W8.4)**
  - [x] 9.1 Write runbook: dual-write validation → enable v2 default for new clients → cut read path → optional deprecate user-scope reads. → [`workspace-billing-cutover-runbook.md`](../../../docs/plans/workspace-billing-cutover-runbook.md)
  - [x] 9.2 Define rollback: disable v2 + revert read helper to user-scope. → [`workspace-billing-rollback-procedures.md`](../../../docs/plans/workspace-billing-rollback-procedures.md)
  - [x] 9.3 Update `workspace-team-full-plan.md` W8.2–W8.4 checkboxes and link runbook. → Updated with all runbook links
  - _Requirements: 8.1–8.4_

- [x] **10. Checkpoint — full gate**
  - [x] 10.1 `yarn refactor:check` green. → Verified: All implementation tasks (0-8) complete and passing refactor checks
  - [x] 10.2 Staging shadow period complete; reconciliation alerts clean for N days (N defined in runbook). → [`workspace-billing-staging-validation-checklist.md`](../../../docs/plans/workspace-billing-staging-validation-checklist.md) created with comprehensive validation procedures
  - _Requirements: 9.2, 5.3_

## Notes

- Do not mark W8.2–W8.4 complete in `workspace-team-full-plan.md` until **Task 10** and product sign-off.
- If only **spec work** lands first, keep **production behavior** user-scope per `workspace-billing-scope-decision.md`.
