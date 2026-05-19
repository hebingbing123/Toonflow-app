# ADR: Workspace Billing Storage Model (Option A vs B)

**Status**: Accepted  
**Date**: 2025-01-XX  
**Related Documents**:
- [ADR: Workspace Billing Attribution](./adr-workspace-billing-attribution.md)
- [Workspace Billing Scope Decision (W8.1)](./workspace-billing-scope-decision.md)
- [Workspace-Scope Billing Spec](../../.kiro/specs/workspace-scope-billing/)
- [Workspace Team Full Plan](./workspace-team-full-plan.md)

---

## Context

This ADR addresses **Task 0.3** of the workspace-scope billing specification. While [adr-workspace-billing-attribution.md](./adr-workspace-billing-attribution.md) establishes that **user-scope billing remains the current production behavior**, this document defines the **technical implementation model** for when/if workspace-scope billing is activated in the future.

Three key decisions must be made:

1. **Storage Model**: Where to store workspace billing data (Option A vs Option B)
2. **Personal vs Enterprise Rules**: How personal and enterprise workspaces differ in billing behavior
3. **Billing Scope Authority**: Who/what determines the `billing_scope` field value

### Current State

- **User billing fields** exist on `app_user_profile`:
  - `plan_tier TEXT NOT NULL DEFAULT 'free'`
  - `billing_currency TEXT`
  - `billing_provider TEXT`
  - `daily_job_quota INTEGER` (nullable override)

- **Workspace table** (`app_workspace`) currently has:
  - `id`, `owner_user_id`, `name`, `workspace_type`, `metadata`, timestamps
  - `workspace_type` constrained to `('personal', 'enterprise')`
  - No billing-specific columns

- **Job attribution**: `app_generation_job` currently uses `owner_user_id` for billing attribution; no `workspace_id` column exists for billing purposes

---

## Decision

### 1. Storage Model: **Option A — Nullable Columns on `app_workspace`**

**We will add billing fields as nullable columns directly to the `app_workspace` table.**

#### Rationale

**Advantages of Option A:**
- **Simpler queries**: Single table join for workspace + billing context
- **Atomic updates**: Workspace and billing state change together
- **Fewer tables**: Reduces schema complexity and join overhead
- **Natural fit**: Billing is a core attribute of a workspace, not a separate entity
- **Migration simplicity**: Additive columns are straightforward; rollback is `ALTER TABLE DROP COLUMN`
- **Consistent with current pattern**: `app_user_profile` already uses this model (billing fields on the entity table)

**Disadvantages of Option A:**
- **Column proliferation**: If billing model becomes complex, table grows wider
- **Nullable semantics**: Must handle NULL vs default vs override logic in application code
- **Less flexible for history**: Harder to track billing changes over time without audit table

**Why Option B was rejected:**
- **Over-engineering**: Separate `app_workspace_billing` table adds complexity without clear benefit at current scale
- **Join overhead**: Every workspace query that needs billing context requires an additional join
- **Premature optimization**: No evidence that billing data will be complex enough to warrant separation
- **Inconsistent pattern**: Would diverge from `app_user_profile` model without strong justification

#### Implementation Details

**New columns on `app_workspace`:**

```sql
ALTER TABLE public.app_workspace
  ADD COLUMN IF NOT EXISTS plan_tier TEXT,
  ADD COLUMN IF NOT EXISTS billing_currency TEXT,
  ADD COLUMN IF NOT EXISTS billing_provider TEXT,
  ADD COLUMN IF NOT EXISTS billing_customer_id TEXT,
  ADD COLUMN IF NOT EXISTS daily_job_quota INTEGER
    CONSTRAINT app_workspace_daily_job_quota_positive 
    CHECK (daily_job_quota IS NULL OR daily_job_quota > 0);

COMMENT ON COLUMN public.app_workspace.plan_tier IS 
  'Workspace-level plan tier when billing_scope=workspace. NULL = use user-scope billing.';
COMMENT ON COLUMN public.app_workspace.daily_job_quota IS 
  'Workspace-level daily job quota override. NULL = use plan_tier default.';
```

**Nullability semantics:**
- `NULL` in workspace billing columns means "not applicable" or "use user-scope billing"
- Non-NULL values indicate workspace-scope billing is active for this workspace
- Application code must check `billing_scope` enum before interpreting these fields

**Indexes:**
```sql
CREATE INDEX IF NOT EXISTS idx_app_workspace_billing_customer
  ON public.app_workspace (billing_customer_id)
  WHERE billing_customer_id IS NOT NULL;
```

---

### 2. Personal vs Enterprise Workspace Rules

**Both personal and enterprise workspaces use the same structural model** (same columns on `app_workspace`). Product behavior differs based on `workspace_type` and `billing_scope` policy.

#### Personal Workspaces (`workspace_type = 'personal'`)

**Current behavior (user-scope billing):**
- Personal workspace is a **collaboration/visibility boundary** only
- Billing remains tied to the user (`app_user_profile`)
- `app_workspace.plan_tier` remains `NULL`
- User's `plan_tier` and `daily_job_quota` apply to all jobs they create

**Future behavior (if workspace-scope billing activated):**
- Personal workspace **may** have its own `plan_tier` and `daily_job_quota`
- Semantically equivalent to "user's default workspace has a plan"
- Allows unified API contract: `/me` v2 always returns `current_workspace_billing`
- Simplifies client logic: no special-casing for personal vs enterprise

**Migration path for personal workspaces:**
```sql
-- Backfill personal workspace billing from user profile
UPDATE public.app_workspace w
SET 
  plan_tier = u.plan_tier,
  billing_currency = u.billing_currency,
  billing_provider = u.billing_provider,
  daily_job_quota = u.daily_job_quota
FROM public.app_user_profile u
WHERE 
  w.owner_user_id = u.user_id
  AND w.workspace_type = 'personal'
  AND w.plan_tier IS NULL;  -- Only backfill if not already set
```

#### Enterprise Workspaces (`workspace_type = 'enterprise'`)

**Current behavior (user-scope billing):**
- Enterprise workspace is a **collaboration/visibility boundary** only
- Each member's billing remains independent (their own `app_user_profile.plan_tier`)
- Members do NOT share quota pools
- `app_workspace.plan_tier` remains `NULL`

**Future behavior (if workspace-scope billing activated):**
- Enterprise workspace **has** its own `plan_tier` and `daily_job_quota`
- All members **share** the workspace's quota pool
- Workspace owner (or designated billing admin) manages subscription
- Individual member's `app_user_profile.plan_tier` becomes irrelevant for workspace-scoped operations

**Product rules (when workspace-scope billing is active):**

| Aspect | Personal Workspace | Enterprise Workspace |
|--------|-------------------|---------------------|
| **Subscription owner** | Workspace owner (= user) | Workspace owner or billing admin |
| **Quota pool** | Workspace-level (effectively user-level) | Shared among all members |
| **Billing entity** | Individual user | Workspace (team/organization) |
| **Member independence** | N/A (single user) | Members share quota; no individual limits |
| **Stripe customer mapping** | `billing_customer_id` on workspace (or user) | `billing_customer_id` on workspace |

**Authorization rules:**
- **Personal workspace**: Only owner can view/modify billing
- **Enterprise workspace**: Requires `manage_billing` permission (owner or admin role with explicit grant)

---

### 3. Billing Scope Authority: **Product Configuration + Workspace Type**

**The `billing_scope` field is NOT stored in the database.** It is **derived at runtime** based on product configuration and workspace context.

#### Resolution Logic

```rust
pub enum BillingScope {
    User,
    Workspace,
}

pub fn resolve_billing_scope(
    workspace: &Workspace,
    global_config: &BillingConfig,
) -> BillingScope {
    // 1. Check global feature flag
    if !global_config.workspace_billing_enabled {
        return BillingScope::User;
    }
    
    // 2. Check workspace-level override (if workspace has billing fields populated)
    if workspace.plan_tier.is_some() {
        return BillingScope::Workspace;
    }
    
    // 3. Default based on workspace type (product policy)
    match workspace.workspace_type {
        WorkspaceType::Personal => {
            // Personal workspaces default to user-scope unless explicitly migrated
            BillingScope::User
        }
        WorkspaceType::Enterprise => {
            // Enterprise workspaces default to workspace-scope if feature enabled
            if global_config.enterprise_workspace_billing_default {
                BillingScope::Workspace
            } else {
                BillingScope::User
            }
        }
    }
}
```

#### Configuration Hierarchy

**Priority order (highest to lowest):**

1. **Global kill-switch**: `workspace_billing_enabled = false` → always `User`
2. **Workspace-level data**: If `app_workspace.plan_tier IS NOT NULL` → `Workspace`
3. **Workspace type policy**: Enterprise workspaces may default to `Workspace` scope
4. **Fallback**: `User` (current production behavior)

#### Who Sets Billing Scope?

| Actor | Mechanism | When |
|-------|-----------|------|
| **Product/Finance** | Global feature flag in backend config | Initial rollout, emergency rollback |
| **Migration script** | Backfills `app_workspace.plan_tier` from user profiles | One-time migration |
| **Billing webhook** | Sets `app_workspace.plan_tier` on subscription events | Ongoing for workspace subscriptions |
| **Admin API** (future) | Explicit workspace billing setup | Manual workspace creation/upgrade |

**Key principle**: `billing_scope` is **never user-settable**. It is a **product policy decision** enforced by backend logic.

#### API Contract

**`GET /api/v1/me` v2 response includes explicit `billing_scope`:**

```json
{
  "billing_scope": "workspace",  // or "user"
  "user": { ... },
  "current_workspace_billing": { ... }  // null if billing_scope=user
}
```

**Clients MUST respect `billing_scope`** when displaying quota/plan information:
- `billing_scope=user` → show `user.plan_tier`, `user.jobs_today`
- `billing_scope=workspace` → show `current_workspace_billing.plan_tier`, `current_workspace_billing.jobs_today`

---

## Consequences

### Immediate (Additive Schema Phase)

✅ **Safe to implement:**
- Add nullable billing columns to `app_workspace` (no behavior change)
- Columns remain `NULL` in production until migration triggered
- No impact on existing user-scope billing logic
- Rollback is simple: `ALTER TABLE DROP COLUMN`

✅ **Documentation complete:**
- Storage model decision recorded
- Personal vs enterprise rules defined
- Billing scope resolution logic specified

### Future (If Workspace-Scope Billing Activated)

**Migration requirements:**
1. Backfill `app_workspace.plan_tier` from `app_user_profile` for personal workspaces
2. Set up enterprise workspace billing via admin API or migration script
3. Enable global feature flag `workspace_billing_enabled`
4. Deploy `/me` v2 API with `billing_scope` field
5. Update Flutter clients to respect `billing_scope` in UI

**Operational considerations:**
- **Dual-write period**: Webhooks update both `app_user_profile` and `app_workspace` billing fields
- **Reconciliation**: Nightly job compares user-scope vs workspace-scope derived states
- **Rollback**: Disable feature flag + revert read paths to user-scope (no DB rollback needed)

**Testing requirements:**
- Unit tests for `resolve_billing_scope()` logic
- Integration tests for `/me` v2 with both scopes
- Contract tests for webhook dual-write
- E2E tests for personal and enterprise workspace quota enforcement

---

## Alternatives Considered

### Alternative 1: Option B — Separate `app_workspace_billing` Table

**Structure:**
```sql
CREATE TABLE public.app_workspace_billing (
  workspace_id UUID PRIMARY KEY REFERENCES public.app_workspace(id),
  plan_tier TEXT,
  billing_currency TEXT,
  billing_provider TEXT,
  billing_customer_id TEXT,
  daily_job_quota INTEGER,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
```

**Rejected because:**
- Adds join overhead for common queries
- No clear benefit at current scale
- Harder to reason about "workspace without billing record" vs "workspace with NULL billing fields"
- Inconsistent with `app_user_profile` pattern

**When to reconsider:**
- If billing history/versioning becomes critical (use audit table instead)
- If billing fields exceed ~10 columns (not expected)
- If billing data has different access patterns than workspace data (no evidence)

### Alternative 2: Store `billing_scope` in Database

**Rejected because:**
- Adds state that must be kept in sync with product policy
- Harder to roll back (requires data migration, not just config change)
- Complicates migration (must backfill `billing_scope` column)
- Derived value is simpler and more flexible

**When to reconsider:**
- If per-workspace billing scope overrides become a product requirement
- If global policy becomes too complex to express in code

### Alternative 3: Different Schemas for Personal vs Enterprise

**Rejected because:**
- Violates DRY principle
- Complicates queries (UNION or polymorphic joins)
- Makes migration harder (two separate backfill paths)
- Product rules can differ without schema differences

---

## Implementation Checklist

- [x] **Task 0.3**: Document Option A vs B decision (this ADR)
- [ ] **Task 1.1**: Create migration with nullable billing columns on `app_workspace`
- [ ] **Task 1.2**: Add `app_generation_job.workspace_id` column (separate ADR if needed)
- [ ] **Backend**: Implement `resolve_billing_scope()` helper
- [ ] **Backend**: Extend `/me` v2 with `billing_scope` field
- [ ] **Backend**: Webhook dual-write logic
- [ ] **Frontend**: Update `rust_api` models for v2
- [ ] **Frontend**: UI respects `billing_scope` in quota display
- [ ] **Tests**: Unit, integration, and contract tests per spec
- [ ] **Runbook**: Migration and rollback procedures

---

## References

- **Parent ADR**: [adr-workspace-billing-attribution.md](./adr-workspace-billing-attribution.md) — Establishes user-scope as current production behavior
- **Current Decision**: [workspace-billing-scope-decision.md](./workspace-billing-scope-decision.md) — W8.1 conclusion
- **Future Spec**: [workspace-billing-future-workspace-scope.md](./workspace-billing-future-workspace-scope.md) — Implementation stub
- **Complete Spec**: [.kiro/specs/workspace-scope-billing/](../../.kiro/specs/workspace-scope-billing/) — Requirements, design, tasks
- **Workspace Plan**: [workspace-team-full-plan.md](./workspace-team-full-plan.md) — Phase W8 roadmap
- **Database Schema**: `supabase/migrations/20260506193000_app_workspace_foundation.sql`
- **User Billing Schema**: `supabase/migrations/20260404000000_app_user_profile.sql`

---

## Revision History

| Date | Author | Change |
|------|--------|--------|
| 2025-01-XX | Kiro (AI Agent) | Initial ADR creation for Task 0.3 |
