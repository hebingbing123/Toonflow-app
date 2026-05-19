# ADR: Workspace Billing Attribution Decision

**Status**: Accepted  
**Date**: 2025-01-XX (Effective Date TBD - Pending Owner Sign-off)  
**Decision Owner**: [PENDING - Product/Finance Lead to Sign]  
**Related Documents**:
- [Workspace Billing Scope Decision (W8.1)](./workspace-billing-scope-decision.md)
- [Workspace-Scope Billing Spec](./.kiro/specs/workspace-scope-billing/)
- [Workspace Team Full Plan](./workspace-team-full-plan.md)

---

## Context

Openflow currently implements **user-scope billing**, where subscriptions, quotas, and usage tracking are attributed to individual users via `app_user_profile`. As we expand workspace capabilities (W8.2–W8.4), we must formally decide whether billing attribution should:

1. **Remain user-scope** (current state)
2. **Move to workspace-scope** (team-level billing)
3. **Adopt a hybrid model** (both user and workspace billing contexts)

This decision has significant implications for:
- Data model migrations (`app_user_profile` vs `app_workspace` billing fields)
- API contracts (`/api/v1/me` response shape, versioning)
- Job attribution (`app_generation_job.workspace_id` requirement)
- Quota enforcement (user vs workspace aggregates)
- Stripe webhook handling (dual-write during transition)
- Client migration strategy (Flutter, API versioning)

---

## Decision

**We maintain USER-SCOPE BILLING as the current production behavior.**

Billing attribution remains tied to individual users:
- `plan_tier`, `billing_currency`, `billing_provider` → `app_user_profile`
- `daily_job_quota`, `jobs_today` → user-level aggregates
- Subscriptions belong to users, not workspaces
- Multi-user workspace collaboration does NOT share quota pools

**Rationale:**
1. **Current implementation is user-scope**: Changing to workspace-scope requires a full data migration, not a simple configuration change
2. **Consistency with other user-scope features**: Usage summaries, skills, memory, and quality metrics are all user-scoped (see W4.6)
3. **Job ownership clarity**: `app_generation_job` currently lacks stable `workspace_id` attribution; forcing workspace billing before job attribution is complete creates semantic confusion
4. **Product interpretation alignment**: Current model treats workspaces as collaboration/visibility boundaries, while billing remains individual responsibility
5. **Risk mitigation**: Avoids half-migrated state where billing is workspace-scope but related features remain user-scope

---

## Consequences

### Immediate (No Action Required)

- ✅ No changes to `app_user_profile` billing columns
- ✅ No changes to `/api/v1/me` response shape
- ✅ No new `workspace_id` column on `app_generation_job` for billing purposes
- ✅ No workspace-level `plan_tier` or `daily_job_quota` fields
- ✅ No Stripe webhook dual-write implementation
- ✅ Flutter continues displaying quota as "current user's capacity"

### Future (If Decision Reverses)

**Trigger Conditions** for re-evaluating workspace-scope billing (W8.2–W8.4):

At least TWO of the following must be true:
1. Product explicitly requires "team buys subscription, members share quota" model
2. Finance/business requires workspace-level billing entities for invoicing
3. Jobs/usage/quality/memory have workspace-aggregated views implemented
4. `app_generation_job` and expensive operations have stable workspace attribution

**Implementation Path** (if triggered):
- Follow complete spec in `.kiro/specs/workspace-scope-billing/`
- Additive schema first (nullable columns/tables)
- Versioned `/api/v1/me` (v1 backward-compatible, v2 with nested billing context)
- Dual-write period with reconciliation alerts
- Backfill script with dry-run and rollback plan
- Client migration notice and feature flags

---

## Sign-off

**This decision is GATED and requires explicit approval before any workspace-scope billing implementation may proceed.**

### Approval Required From:

- [ ] **Product Lead**: _________________________ Date: _________
  - Confirms billing attribution model aligns with product vision
  - Approves user-facing messaging ("your quota" vs "team quota")

- [ ] **Finance/Business Lead**: _________________________ Date: _________
  - Confirms billing entity model (user vs workspace invoicing)
  - Approves Stripe customer mapping strategy

- [ ] **Engineering Lead**: _________________________ Date: _________
  - Confirms technical feasibility and migration risk assessment
  - Approves implementation timeline if decision changes

### Effective Date

**Effective Date**: [TO BE DETERMINED upon sign-off completion]

Until all three approvals are obtained and an effective date is set, the current user-scope billing model remains in force per [workspace-billing-scope-decision.md](./workspace-billing-scope-decision.md).

---

## Alternatives Considered

### Alternative 1: Immediate Workspace-Scope Migration

**Rejected** because:
- Requires breaking changes to `/api/v1/me` contract
- Jobs lack stable `workspace_id` attribution (W4.5 decision: no workspace_id column)
- Usage/quality APIs remain user-scope (W4.6), creating semantic inconsistency
- High risk of half-migrated production state

### Alternative 2: Hybrid Model (Both User and Workspace Billing)

**Deferred** because:
- Adds complexity without clear product requirement
- Requires explicit `billing_scope` enum and branching logic throughout codebase
- Better suited as future enhancement after workspace-scope foundation is proven
- Can be implemented later if specific use cases emerge (e.g., personal vs enterprise workspace tiers)

### Alternative 3: Workspace-Scope with Long Transition Period

**Deferred** because:
- Still requires all migration work upfront (schema, dual-write, versioning)
- Transition period complexity (reconciliation, rollback) not justified without business driver
- Better to wait for clear trigger conditions (see "Future" section above)

---

## References

- **Current Decision (W8.1)**: [workspace-billing-scope-decision.md](./workspace-billing-scope-decision.md)
- **Future Workspace-Scope Spec**: [workspace-billing-future-workspace-scope.md](./workspace-billing-future-workspace-scope.md)
- **Complete Implementation Spec**: [.kiro/specs/workspace-scope-billing/](../../.kiro/specs/workspace-scope-billing/)
- **Workspace Team Plan**: [workspace-team-full-plan.md](./workspace-team-full-plan.md) Phase W8
- **Job Attribution Decision**: W4.5 in workspace-team-full-plan.md (no workspace_id column)
- **Usage Scope Decision**: W4.6 in workspace-team-full-plan.md (user-scope for usage/skills/memory/quality)

---

## Revision History

| Date | Author | Change |
|------|--------|--------|
| 2025-01-XX | Kiro (AI Agent) | Initial ADR creation for Task 0.1 |

