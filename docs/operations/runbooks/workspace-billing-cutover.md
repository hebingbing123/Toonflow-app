# Workspace-Scope Billing Cutover Runbook

**Status**: Draft (not yet executed)  
**Owner**: Engineering + Finance  
**Related Spec**: [`.kiro/specs/workspace-scope-billing/`](../../.kiro/specs/workspace-scope-billing/)  
**Prerequisites**: W8.1 decision overturned; current decision is **user-scope** per [`workspace-billing-scope-decision.md`](./workspace-billing-scope-decision.md)

## Overview

This runbook describes the **phased cutover** from **user-scope billing** (`app_user_profile` as source of truth) to **workspace-scope billing** (workspace-level subscription, quota, and usage attribution). The migration follows a **dual-write → validation → read cutover → deprecation** pattern to minimize risk.

**Key Principle**: Each phase is **reversible** without destructive database rollback until the final deprecation phase.

## PII Handling Guidelines

**IMPORTANT**: Workspace billing implementation handles sensitive billing data. Follow these guidelines:

### Data Classification

- **Workspace IDs, UUIDs**: Identifiers (not PII) - safe to log and expose in ops endpoints
- **Plan tiers, quotas, usage counts**: Aggregates (not PII) - safe to log and expose
- **Webhook payloads**: **MAY CONTAIN PII** (customer email, name, address, phone) - restricted access

### Access Controls

- ✅ Ops endpoints (`/api/v1/ops/billing/*`) expose **aggregates only** (no PII)
- ✅ Reconciliation logs include **UUIDs only** (no email, name, or address)
- ✅ Quota denial logs include **UUIDs and aggregates only**
- ⚠️  Webhook event table (`app_billing_webhook_event.payload`) contains **full webhook JSON** - access restricted to ops role

### Retention Policy

See [`billing-webhook-retention-policy.md`](./billing-webhook-retention-policy.md) for details:
- **0-90 days**: Full payload retained for audit (ops access only)
- **91-365 days**: PII scrubbed or encrypted (compliance/legal access only)
- **365+ days**: Records purged or anonymized

### Compliance

- **GDPR**: Right to erasure requires manual scrubbing of webhook payloads
- **CCPA**: Data retention documented; no sale of personal information
- **PCI DSS**: Webhook payloads may contain last 4 digits of card (not full PAN)

### Ops Team Training

Before cutover, ensure ops team understands:
1. Never export raw webhook payloads to external systems
2. Use ops endpoints for billing queries (aggregates only)
3. Follow retention policy for webhook data
4. Document any manual access to webhook payloads

---

## Phases

### Phase 0: Pre-flight Checks

**Duration**: 1-2 days  
**Reversibility**: N/A (read-only validation)

#### Checklist

- [ ] **Sign-off obtained**: Program lead confirms workspace-scope billing decision with effective date
- [ ] **Client migration notice published**: [`workspace-migration-notice.md`](./workspace-migration-notice.md) updated with timeline
- [ ] **ADRs finalized**:
  - [ ] [ADR: Workspace Billing Attribution](./adr-workspace-billing-attribution.md)
  - [ ] [ADR: Workspace Billing Storage Model](./adr-workspace-billing-storage-model.md)
- [ ] **Schema migrations deployed**: Additive workspace billing columns/table in production
- [ ] **Backfill script validated**: `--dry-run` mode executed against production replica
- [ ] **Monitoring dashboards ready**:
  - [ ] `billing_webhook_dual_write_mismatch_total`
  - [ ] `quota_denied_total{scope=user|workspace}`
  - [ ] `me_v2_requests_total`
  - [ ] `billing_reconciliation_mismatch_total{field=...}`

#### Validation Queries

```sql
-- Check workspace billing storage exists
SELECT COUNT(*) FROM app_workspace WHERE plan_tier IS NOT NULL;
-- OR (if Option B)
SELECT COUNT(*) FROM app_workspace_billing;

-- Check job workspace_id coverage
SELECT 
  COUNT(*) as total_jobs,
  COUNT(workspace_id) as jobs_with_workspace,
  ROUND(100.0 * COUNT(workspace_id) / COUNT(*), 2) as coverage_pct
FROM app_generation_job
WHERE created_at > NOW() - INTERVAL '7 days';
-- Target: >95% coverage before proceeding
```

#### Rollback

No rollback needed (read-only checks).

---

### Phase 1: Dual-Write Enablement

**Duration**: 1-2 hours (deployment + smoke test)  
**Reversibility**: High (feature flag disable)

#### Actions

1. **Deploy backend with dual-write code**:
   - Webhook handler writes to **both** `app_user_profile` and workspace billing storage
   - Job creation persists `workspace_id` on `app_generation_job`
   - Quota checks still use **user-scope** (no behavior change yet)

2. **Enable feature flag**:
   ```bash
   # Example environment variable or feature flag
   export OPENFLOW_BILLING_DUAL_WRITE_ENABLED=true
   ```

3. **Smoke test**:
   - Trigger test webhook event (Stripe test mode or staging)
   - Verify both user profile and workspace billing updated
   - Check idempotency: replay same event, confirm no duplicates

#### Validation

```sql
-- After 1 hour of dual-write, check consistency
SELECT 
  u.id as user_id,
  u.plan_tier as user_plan,
  w.plan_tier as workspace_plan,
  CASE 
    WHEN u.plan_tier = w.plan_tier THEN 'consistent'
    ELSE 'MISMATCH'
  END as status
FROM app_user_profile u
JOIN app_workspace w ON w.id = u.current_workspace_id
WHERE w.workspace_type = 'personal'
  AND u.updated_at > NOW() - INTERVAL '1 hour'
LIMIT 100;
```

#### Rollback

```bash
# Disable dual-write flag
export OPENFLOW_BILLING_DUAL_WRITE_ENABLED=false
# Redeploy or restart services
```

**Impact**: No user-facing changes; writes revert to user-scope only.

---

### Phase 2: Shadow Period & Reconciliation

**Duration**: 7-14 days (configurable `N` days)  
**Reversibility**: High (monitoring only, no behavior change)

#### Actions

1. **Monitor reconciliation metrics**:
   - Alert on `billing_webhook_dual_write_mismatch_total > 0`
   - Daily reconciliation job compares user vs workspace derived state
   - Log discrepancies to structured logs with `user_id`, `workspace_id`, `field`, `user_value`, `workspace_value`

2. **Investigate mismatches**:
   - Webhook replay failures
   - Race conditions in dual-write
   - Historical data inconsistencies

3. **Backfill historical jobs**:
   ```bash
   # Preview the backfill first
   cargo run --bin backfill-job-workspace-id -- \
     --dry-run \
     --batch-size 1000

   # Apply the backfill after reviewing the dry-run output
   cargo run --bin backfill-job-workspace-id -- \
     --batch-size 1000
   ```

#### Success Criteria

- [ ] **Zero reconciliation alerts** for `N` consecutive days (recommend N=7)
- [ ] **Job `workspace_id` coverage** ≥99% for jobs created in last 30 days
- [ ] **Webhook dual-write success rate** ≥99.9%

#### Rollback

Same as Phase 1 (disable dual-write flag). No user-facing impact.

---

### Phase 3: Enable `/me` v2 for Opt-In Clients

**Duration**: 1-2 weeks (gradual rollout)  
**Reversibility**: High (client-side opt-in)

#### Actions

1. **Deploy `/me` v2 handler**:
   - `GET /api/v1/me?v=2` returns nested `user` + `current_workspace_billing`
   - `billing_scope` field added to response
   - v1 remains default (no breaking changes)

2. **Enable for internal builds**:
   - Flutter internal/staging builds request `?v=2` via `kEnableWorkspaceBilling` flag
   - Build command: `flutter build apk --debug --dart-define=ENABLE_WORKSPACE_BILLING=true`
   - Validate UI displays workspace quota correctly
   - See [Feature Flag Guide](./workspace-billing-feature-flag-guide.md) for details

3. **Gradual rollout**:
   - Week 1: Internal builds only (`--dart-define=ENABLE_WORKSPACE_BILLING=true`)
   - Week 2: Beta users (if applicable)
   - Week 3+: All clients via app update with flag enabled in release builds
   - See [Feature Flag Guide](./workspace-billing-feature-flag-guide.md) for build commands

#### Validation

```bash
# Test v1 unchanged
curl -H "Authorization: Bearer $TOKEN" \
  https://api.openflow.com/api/v1/me | jq '.plan_tier'

# Test v2 structure
curl -H "Authorization: Bearer $TOKEN" \
  'https://api.openflow.com/api/v1/me?v=2' | jq '.billing_scope, .current_workspace_billing'
```

#### Rollback

- Clients revert to v1 (remove `?v=2` query parameter or rebuild with `ENABLE_WORKSPACE_BILLING=false`)
- Backend keeps v2 code deployed but unused
- No data loss or corruption risk
- See [Feature Flag Guide](./workspace-billing-feature-flag-guide.md) for rollback procedures

---

### Phase 4: Cut Read Path to Workspace-Scope

**Duration**: 1-2 hours (deployment)  
**Reversibility**: Medium (requires redeployment, but no data loss)

#### Actions

1. **Deploy quota enforcement changes**:
   - Quota checks read from workspace billing storage when `billing_scope=workspace`
   - `jobs_today` aggregates by `workspace_id` instead of `user_id`
   - User-scope path remains for `billing_scope=user` (if hybrid model)

2. **Enable workspace-scope for new workspaces**:
   - New enterprise workspaces default to `billing_scope=workspace`
   - Personal workspaces remain `billing_scope=user` (or migrate per product decision)

3. **Monitor quota denials**:
   - Check `quota_denied_total{scope=workspace}` for unexpected spikes
   - Validate workspace quota limits match subscription tier

#### Validation

```sql
-- Check quota enforcement using workspace aggregates
SELECT 
  w.id as workspace_id,
  w.plan_tier,
  w.daily_job_quota,
  COUNT(j.id) as jobs_today
FROM app_workspace w
LEFT JOIN app_generation_job j ON j.workspace_id = w.id
  AND j.created_at >= DATE_TRUNC('day', NOW() AT TIME ZONE 'UTC')
WHERE w.workspace_type = 'enterprise'
GROUP BY w.id, w.plan_tier, w.daily_job_quota
HAVING COUNT(j.id) > 0
LIMIT 20;
```

#### Rollback Procedure

See **[Rollback Runbook](#rollback-runbook)** below.

**Impact**: Users in workspace-scope workspaces now subject to workspace quota limits. Requires communication if limits differ from previous user-scope.

---

### Phase 5: Deprecate User-Scope Reads (Optional)

**Duration**: 3-6 months (long deprecation window)  
**Reversibility**: Low (requires code restoration)

#### Actions

1. **Announce deprecation**:
   - Update API documentation: v1 `/me` marked deprecated
   - Email notification to API consumers
   - Deprecation timeline: 6 months minimum

2. **Remove user-scope billing columns** (final phase):
   - Only after **all** workspaces migrated to workspace-scope
   - Requires separate migration and sign-off
   - **Not covered in this runbook** (future decision)

#### Success Criteria

- [ ] All active workspaces using workspace-scope billing
- [ ] Zero v1 `/me` requests from production clients (monitored via `me_v1_requests_total`)
- [ ] Finance confirms billing reconciliation complete

---

## Rollback Runbook

### Rollback from Phase 4 (Read Path Cutover)

**Scenario**: Workspace-scope quota enforcement causing issues (incorrect limits, performance problems, user complaints).

#### Steps

1. **Disable workspace-scope quota enforcement**:
   ```bash
   # Set feature flag to revert quota reads to user-scope
   export OPENFLOW_BILLING_WORKSPACE_SCOPE_ENABLED=false
   ```

2. **Redeploy backend**:
   ```bash
   # Deploy previous version or with flag disabled
   git checkout <previous-commit>
   # OR
   # Redeploy current version with flag disabled
   ```

3. **Verify rollback**:
   ```bash
   # Check quota enforcement uses user-scope
   curl -H "Authorization: Bearer $TOKEN" \
     https://api.openflow.com/api/v1/me | jq '.jobs_today'
   # Should match user-scope aggregate, not workspace
   ```

4. **Disable v2 responses** (optional):
   ```bash
   # If v2 responses causing confusion
   export OPENFLOW_ME_V2_ENABLED=false
   ```

5. **Communicate to users**:
   - "We've temporarily reverted to user-based quota limits while we investigate an issue."
   - Provide timeline for re-enabling workspace-scope

#### Data Integrity

- **No data loss**: Workspace billing columns/table remain populated via dual-write
- **User billing columns intact**: Never dropped during Phases 1-4
- **Jobs retain `workspace_id`**: Historical attribution preserved for future retry

#### Recovery Time

- **Estimated RTO**: 15-30 minutes (feature flag + redeploy)
- **Estimated RPO**: 0 (no data loss)

---

### Rollback from Phase 2 (Shadow Period)

**Scenario**: Dual-write causing performance issues or excessive mismatches.

#### Steps

1. **Disable dual-write**:
   ```bash
   export OPENFLOW_BILLING_DUAL_WRITE_ENABLED=false
   ```

2. **Investigate root cause**:
   - Check webhook handler logs for errors
   - Review reconciliation mismatch patterns
   - Validate workspace billing schema constraints

3. **Fix and retry**:
   - Deploy fix for dual-write logic
   - Re-enable with monitoring
   - Extend shadow period if needed

---

## Monitoring & Alerts

### Key Metrics

| Metric | Threshold | Action |
|--------|-----------|--------|
| `billing_webhook_dual_write_mismatch_total` | > 0 | Investigate within 1 hour |
| `quota_denied_total{scope=workspace}` spike | > 2x baseline | Check workspace quota config |
| `billing_reconciliation_mismatch_total{field=...}` | > 10/day | Review reconciliation job logs |
| `me_v2_requests_total` | Track adoption | Inform rollout pacing |

### Dashboards

- **Billing Cutover Dashboard**: Grafana/Datadog with all metrics above
- **Quota Enforcement by Scope**: User vs workspace quota denials over time
- **Webhook Dual-Write Health**: Success rate, latency, mismatch rate

---

## Communication Plan

### Internal

- **Engineering**: Runbook review, on-call rotation briefed
- **Finance**: Reconciliation process, expected timeline
- **Support**: FAQ for workspace quota questions

### External

- **API Changelog**: `/me` v2 availability, deprecation timeline for v1
- **Email to Enterprise Customers**: Workspace-scope billing benefits, timeline
- **In-App Notification**: "Your workspace now has team-based quota limits"

---

## Appendix: Validation Queries

### Check Dual-Write Consistency

```sql
-- Personal workspaces: user plan should match workspace plan
SELECT 
  u.id,
  u.email,
  u.plan_tier as user_plan,
  w.plan_tier as workspace_plan
FROM app_user_profile u
JOIN app_workspace w ON w.id = u.current_workspace_id
WHERE w.workspace_type = 'personal'
  AND u.plan_tier != w.plan_tier;
-- Expected: 0 rows after dual-write stabilizes
```

### Check Job Workspace Attribution

```sql
-- Jobs without workspace_id (should be minimal)
SELECT 
  COUNT(*) as orphan_jobs,
  MIN(created_at) as oldest,
  MAX(created_at) as newest
FROM app_generation_job
WHERE workspace_id IS NULL
  AND created_at > NOW() - INTERVAL '30 days';
```

### Check Workspace Quota Aggregates

```sql
-- Compare user vs workspace jobs_today
WITH user_jobs AS (
  SELECT owner_user_id, COUNT(*) as count
  FROM app_generation_job
  WHERE created_at >= DATE_TRUNC('day', NOW() AT TIME ZONE 'UTC')
  GROUP BY owner_user_id
),
workspace_jobs AS (
  SELECT workspace_id, COUNT(*) as count
  FROM app_generation_job
  WHERE created_at >= DATE_TRUNC('day', NOW() AT TIME ZONE 'UTC')
    AND workspace_id IS NOT NULL
  GROUP BY workspace_id
)
SELECT 
  u.id as user_id,
  u.current_workspace_id,
  COALESCE(uj.count, 0) as user_jobs_today,
  COALESCE(wj.count, 0) as workspace_jobs_today,
  CASE 
    WHEN w.workspace_type = 'personal' AND COALESCE(uj.count, 0) != COALESCE(wj.count, 0) 
    THEN 'MISMATCH'
    ELSE 'ok'
  END as status
FROM app_user_profile u
LEFT JOIN user_jobs uj ON uj.owner_user_id = u.id
LEFT JOIN workspace_jobs wj ON wj.workspace_id = u.current_workspace_id
LEFT JOIN app_workspace w ON w.id = u.current_workspace_id
WHERE u.current_workspace_id IS NOT NULL
LIMIT 50;
```

---

## Sign-off

- [ ] **Engineering Lead**: Runbook reviewed, rollback tested in staging
- [ ] **Finance Lead**: Billing reconciliation process approved
- [ ] **Product Lead**: User communication plan approved
- [ ] **SRE**: Monitoring and alerts configured

**Date**: ___________  
**Approved by**: ___________

---

*Maintained by: Engineering + Finance*  
*Last updated: 2025-01-XX*
