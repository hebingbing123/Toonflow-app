# Billing Reconciliation System

**Task 4.3**: Reconciliation hook comparing legacy vs workspace-derived state during shadow period.

## Quick Reference

### Components

| Component | Location | Purpose |
|-----------|----------|---------|
| Core functions | `ingest/reconciliation.rs` | Compare user vs workspace billing |
| Nightly worker | `reconciliation_worker.rs` | Automated periodic checks |
| CLI tool | `src/bin/reconcile_billing.rs` | Manual on-demand checks |
| Metrics | `../metrics.rs` | Emit mismatch counters |

### Running Reconciliation

**Automatic (nightly worker)**:
- Runs every 24 hours by default
- Started automatically with backend server
- Configure interval: `RECONCILIATION_INTERVAL_HOURS=12`

**Manual (CLI)**:
```bash
# From backend directory
cargo run --bin reconcile-billing

# With custom database
DATABASE_URL=postgresql://... cargo run --bin reconcile-billing
```

### What Gets Checked

For each user with a personal workspace, compares:

| Field | User Source | Workspace Source |
|-------|-------------|------------------|
| `plan_tier` | `app_user_profile.plan_tier` | `app_workspace.plan_tier` |
| `billing_currency` | `app_user_profile.billing_currency` | `app_workspace.billing_currency` |
| `billing_provider` | `app_user_profile.billing_provider` | `app_workspace.billing_provider` |

### Output

**No mismatches**:
```
✓ No billing mismatches found
```

**Mismatches found**:
```
✗ Found 3 billing mismatch(es)
  Check logs above for details
```

**Log format**:
```
WARN user_id=... workspace_id=... field="plan_tier" user_value="free" workspace_value="pro"
  Billing reconciliation mismatch detected
```

### Metrics

**Emitted metric**: `billing_reconciliation_mismatch_total{field="..."}`

**Query examples**:
```
# Count mismatches by field
sum by (field) (billing_reconciliation_mismatch_total)

# Mismatch rate
rate(billing_reconciliation_mismatch_total[1h])
```

### Integration Points

**Webhook handler** (`ingest/mod.rs`):
- Dual-writes to both user profile and workspace billing
- Mismatches detected by reconciliation indicate dual-write issues

**Cutover readiness**:
- Zero mismatches for 7 days = ready for cutover
- See: `docs/plans/workspace-billing-cutover-runbook.md`

### Testing

**Unit tests**:
```bash
cargo test -p openflow-server reconciliation
```

**Integration test**:
1. Create test user with mismatched billing data
2. Run `cargo run --bin reconcile-billing`
3. Verify mismatch is detected and logged

### Troubleshooting

**Worker not running**:
- Check backend logs for "Billing reconciliation worker started"
- Verify no panic in worker task
- Run manual CLI as fallback

**High mismatch count**:
- Check webhook handler for errors
- Verify dual-write code is active
- Review recent database migrations

**Persistent mismatches**:
- Query specific user's billing history
- Check webhook events for missed updates
- May require manual correction

### Related Documentation

- **Full guide**: `docs/plans/billing-reconciliation-guide.md`
- **Requirements**: `.kiro/specs/workspace-scope-billing/requirements.md` (R5.3)
- **Design**: `.kiro/specs/workspace-scope-billing/design.md`
- **Cutover runbook**: `docs/plans/workspace-billing-cutover-runbook.md`

### API

**Public functions** (exported from `billing` module):

```rust
// Check single user
pub async fn check_personal_workspace_billing_consistency(
    pool: &PgPool,
    user_id: Uuid,
) -> Result<Vec<BillingMismatch>, sqlx::Error>

// Check all users
pub async fn reconcile_all_personal_workspaces(
    pool: &PgPool,
) -> Result<usize, sqlx::Error>

// Start worker (called from main.rs)
pub async fn run_reconciliation_worker(state: AppState)
```

**BillingMismatch struct**:

```rust
pub struct BillingMismatch {
    pub user_id: Uuid,
    pub workspace_id: Uuid,
    pub field: String,
    pub user_value: Option<String>,
    pub workspace_value: Option<String>,
}
```

### Configuration

| Environment Variable | Default | Description |
|---------------------|---------|-------------|
| `RECONCILIATION_INTERVAL_HOURS` | 24 | Hours between checks |
| `DATABASE_URL` | (required) | PostgreSQL connection |

### Shadow Period Workflow

1. **Enable dual-write**: Webhook handler writes to both sources
2. **Start monitoring**: Nightly worker detects mismatches
3. **Investigate**: Review logs, fix systematic issues
4. **Validate**: Zero mismatches for 7 days
5. **Cutover**: Switch read paths to workspace-scope
6. **Continue monitoring**: Keep reconciliation running for 30 days post-cutover

### Exit Codes (CLI)

- `0`: Success (regardless of mismatch count)
- `1`: Failure (database error, connection issue, etc.)

Note: Finding mismatches is not a failure - it's the expected behavior during shadow period.
