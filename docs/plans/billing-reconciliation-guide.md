# Billing Reconciliation Guide

**Task 4.3**: Reconciliation hook comparing legacy vs workspace-derived state during shadow period.

**Boundary**: this guide applies only during the gated future workspace-billing migration shadow period. It should not be read as evidence that current production has already entered dual-write or workspace-scope billing mode.

## Overview

During the workspace-scope billing migration, the system operates in a **dual-write shadow period** where billing data is written to both:
- **Legacy**: `app_user_profile` billing fields (user-scope)
- **New**: `app_workspace` billing fields (workspace-scope)

The reconciliation system detects and reports mismatches between these two sources, ensuring data consistency before cutover.

## Components

### 1. Core Reconciliation Functions

**Location**: `backend/src/billing/ingest/reconciliation.rs`

#### `check_personal_workspace_billing_consistency(pool, user_id)`

Compares billing state for a single user's personal workspace.

**Checks**:
- `plan_tier`: User vs workspace plan tier
- `billing_currency`: User vs workspace currency
- `billing_provider`: User vs workspace provider (e.g., "stripe")

**Returns**: `Vec<BillingMismatch>` with details of any discrepancies.

#### `reconcile_all_personal_workspaces(pool)`

Runs reconciliation for all users with personal workspaces.

**Behavior**:
- Queries all users with personal workspaces
- Checks each user's billing consistency
- Logs each mismatch with structured fields
- Emits metrics for ops monitoring
- Returns total mismatch count

### 2. Nightly Worker

**Location**: `backend/src/billing/reconciliation_worker.rs`

**Behavior**:
- Runs automatically when backend starts (spawned in `main.rs`)
- Default interval: **24 hours** (configurable via `RECONCILIATION_INTERVAL_HOURS`)
- Logs results at INFO level (no mismatches) or WARN level (mismatches found)
- Continues running even if individual checks fail

**Configuration**:

```bash
# Set custom interval (hours)
RECONCILIATION_INTERVAL_HOURS=12 cargo run
```

### 3. Manual CLI Tool

**Location**: `backend/src/bin/reconcile_billing.rs`

**Usage**:

```bash
# Run reconciliation check
cargo run --bin reconcile-billing

# With custom database URL
DATABASE_URL=postgresql://user:pass@host/db cargo run --bin reconcile-billing
```

**Output**:
- Structured logs for each mismatch
- Summary: "✓ No billing mismatches found" or "✗ Found N billing mismatch(es)"
- Exit code 0 on success, 1 on failure

### 4. Metrics

**Location**: `backend/src/metrics.rs`

**Function**: `record_billing_reconciliation_mismatch(field)`

**Behavior**:
- Emits structured log with target `toonflow.metrics.billing_reconciliation`
- Includes field name (e.g., "plan_tier", "billing_currency")
- Can be aggregated by ops monitoring systems

## Monitoring

### Log Queries

**Find all mismatches in last 24 hours**:

```bash
# If using structured logging
grep "Billing reconciliation mismatch detected" logs/backend.log | jq
```

**Expected log format**:

```json
{
  "level": "WARN",
  "target": "toonflow_backend::billing::ingest::reconciliation",
  "user_id": "uuid",
  "workspace_id": "uuid",
  "field": "plan_tier",
  "user_value": "free",
  "workspace_value": "pro",
  "message": "Billing reconciliation mismatch detected"
}
```

### Metrics Queries

**Count mismatches by field** (if using metrics aggregation):

```
sum by (field) (rate(billing_reconciliation_mismatch_total[24h]))
```

### Alert Thresholds

**Recommended alerts**:

1. **High mismatch rate**: > 5% of users have mismatches
   - Indicates systematic dual-write issue
   - Action: Investigate webhook handler

2. **Persistent mismatches**: Same user_id appears in multiple checks
   - Indicates stuck state
   - Action: Manual investigation and correction

3. **New field mismatches**: Mismatches in fields not seen before
   - Indicates new dual-write path not covered
   - Action: Review recent webhook changes

## Operational Procedures

### During Shadow Period

**Daily**:
1. Check reconciliation worker logs for mismatch count
2. If mismatches found, review specific cases
3. Determine if mismatches are:
   - **Transient**: Webhook processing lag (acceptable)
   - **Systematic**: Bug in dual-write logic (requires fix)
   - **Historical**: Pre-dual-write data (requires backfill)

**Weekly**:
1. Run manual reconciliation check: `cargo run --bin reconcile-billing`
2. Export mismatch summary for trend analysis
3. Update cutover readiness dashboard

### Before Cutover

**Validation checklist**:

- [ ] Zero mismatches for 7 consecutive days
- [ ] Manual reconciliation check passes
- [ ] All known historical mismatches documented and accepted
- [ ] Webhook dual-write tested with Stripe test events
- [ ] Rollback procedure tested in staging

### After Cutover

**Monitoring**:
- Continue running reconciliation worker for 30 days
- Mismatches should remain at zero (workspace is now source of truth)
- If mismatches appear, indicates:
  - Bug in read path (still reading user-scope somewhere)
  - Manual database edits bypassing application logic

## Troubleshooting

### High Mismatch Count

**Symptoms**: Reconciliation reports many mismatches

**Diagnosis**:
1. Check webhook handler logs for errors
2. Verify dual-write code is active
3. Check database for manual edits

**Resolution**:
- Fix webhook handler if broken
- Run backfill script if historical data issue
- Document accepted exceptions if intentional

### Reconciliation Worker Not Running

**Symptoms**: No reconciliation logs in 24+ hours

**Diagnosis**:
1. Check backend process is running
2. Check for worker panic in logs
3. Verify database connectivity

**Resolution**:
- Restart backend if worker crashed
- Fix database connection issues
- Run manual check as temporary measure

### Specific User Mismatch

**Symptoms**: Same user_id appears repeatedly

**Diagnosis**:
1. Query user's billing history
2. Check webhook events for this user
3. Review user's workspace state

**Resolution**:
- Manual correction if data corruption
- Webhook replay if event was missed
- Document if intentional override

## Testing

### Unit Tests

**Location**: `backend/src/billing/ingest/reconciliation.rs`

```bash
cargo test -p toonflow-backend reconciliation
```

### Integration Test

**Setup test data**:

```sql
-- Create user with mismatch
INSERT INTO app_user_profile (user_id, plan_tier, billing_currency)
VALUES ('test-user-id', 'free', 'USD');

INSERT INTO app_workspace (id, owner_user_id, workspace_type, plan_tier, billing_currency)
VALUES ('test-workspace-id', 'test-user-id', 'personal', 'pro', 'USD');
```

**Run reconciliation**:

```bash
cargo run --bin reconcile-billing
```

**Expected**: Reports 1 mismatch for `plan_tier` field.

### Webhook Dual-Write Test

**Send test Stripe event**:

```bash
stripe trigger customer.subscription.updated
```

**Verify**:
1. User profile updated
2. Workspace billing updated
3. No mismatch reported in next reconciliation

## Related Documentation

- **Requirements**: `.kiro/specs/workspace-scope-billing/requirements.md` (Requirement 5.3)
- **Design**: `.kiro/specs/workspace-scope-billing/design.md`
- **Webhook Handler**: `backend/src/billing/ingest/mod.rs`
- **Cutover Runbook**: `docs/plans/workspace-billing-cutover-runbook.md`

## Configuration Reference

| Environment Variable | Default | Description |
|---------------------|---------|-------------|
| `RECONCILIATION_INTERVAL_HOURS` | 24 | Hours between reconciliation checks |
| `DATABASE_URL` | (required) | PostgreSQL connection string |

## Metrics Reference

| Metric | Type | Labels | Description |
|--------|------|--------|-------------|
| `billing_reconciliation_mismatch_total` | Counter | `field` | Count of mismatches by field name |
| `billing_reconciliation_check_duration_seconds` | Histogram | - | Time to complete reconciliation |
| `billing_reconciliation_users_checked_total` | Counter | - | Total users checked |

## FAQ

**Q: Why do we need reconciliation?**

A: During migration, we dual-write to both user and workspace billing. Reconciliation ensures both writes succeed and data stays consistent.

**Q: What happens if mismatches are found?**

A: Mismatches are logged and metrics emitted. Ops team investigates and determines if correction is needed. System continues operating.

**Q: Can reconciliation fix mismatches automatically?**

A: No. Reconciliation is read-only. It detects mismatches but does not modify data. This prevents automatic "corrections" that might be wrong.

**Q: When can we stop reconciliation?**

A: After cutover is complete and stable for 30 days with zero mismatches. At that point, workspace is the single source of truth.

**Q: Does reconciliation affect performance?**

A: Minimal impact. Runs once per 24 hours by default, queries are indexed, and worker runs in background task.

**Q: What if reconciliation check fails?**

A: Worker logs error and continues. Next check runs after interval. Manual CLI tool can be used for immediate retry.
