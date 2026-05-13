# PII Hygiene Audit: Workspace Billing Implementation

**Task**: 8.2 PII hygiene: aggregates only in exports/logs  
**Date**: 2025-01-XX  
**Status**: ✅ COMPLIANT with recommendations

## Executive Summary

The workspace billing implementation maintains **good PII hygiene** with aggregates-only exposure in ops endpoints and logs. However, the `app_billing_webhook_event` table stores **full webhook payloads** which may contain PII from billing providers (Stripe, Alipay, Paddle). This is acceptable for audit purposes but requires access controls and retention policies.

## Audit Scope

Reviewed all workspace billing code for PII exposure:
- ✅ Internal ops endpoints (`/api/v1/ops/billing/*`)
- ✅ Reconciliation logs and metrics
- ✅ Quota denial logs
- ✅ Webhook event storage
- ✅ Billing event audit endpoint

## Findings

### ✅ COMPLIANT: Ops Billing Endpoints

**File**: `backend/src/billing/ops_view.rs`

**Endpoints**:
- `GET /api/v1/ops/billing/workspace-subscription`
- `GET /api/v1/ops/billing/workspace-job-aggregates`

**PII Exposure**: **NONE** - Aggregates only

**Data Exposed**:
```rust
WorkspaceSubscriptionSnapshot {
    workspace_id: Uuid,           // ✅ Not PII
    workspace_type: String,       // ✅ Not PII
    plan_tier: Option<String>,    // ✅ Not PII
    daily_job_quota: Option<i64>, // ✅ Not PII
    billing_provider: Option<String>,    // ✅ Not PII (e.g., "stripe")
    billing_customer_id: Option<String>, // ⚠️  Provider ID (not direct PII)
    billing_currency: Option<String>,    // ✅ Not PII
    created_at: DateTime<Utc>,    // ✅ Not PII
}

WorkspaceJobAggregates {
    workspace_id: Uuid,           // ✅ Not PII
    total_jobs: i64,              // ✅ Aggregate
    jobs_today: i64,              // ✅ Aggregate
    jobs_last_7_days: i64,        // ✅ Aggregate
    jobs_last_30_days: i64,       // ✅ Aggregate
    jobs_by_status: Value,        // ✅ Aggregate counts
}
```

**Access Control**: ✅ Protected by `TOONFLOW_INTERNAL_OPS_TOKEN` header

**Recommendation**: ✅ **PASS** - No changes needed. These endpoints expose only workspace IDs and aggregates.

---

### ✅ COMPLIANT: Reconciliation Logs

**File**: `backend/src/billing/ingest/reconciliation.rs`

**Function**: `reconcile_all_personal_workspaces()`

**PII Exposure**: **user_id and workspace_id only** (identifiers, not personal data)

**Log Example**:
```rust
tracing::warn!(
    user_id = %mismatch.user_id,           // ⚠️  UUID identifier
    workspace_id = %mismatch.workspace_id, // ⚠️  UUID identifier
    field = %mismatch.field,               // ✅ Field name
    user_value = ?mismatch.user_value,     // ✅ Billing field value
    workspace_value = ?mismatch.workspace_value, // ✅ Billing field value
    "Billing reconciliation mismatch detected"
);
```

**Fields Compared**:
- `plan_tier` (e.g., "free", "pro", "enterprise")
- `billing_currency` (e.g., "USD", "CNY")
- `billing_provider` (e.g., "stripe", "alipay")

**Recommendation**: ✅ **PASS** - UUIDs are identifiers, not PII. No email, name, or address exposed.

---

### ✅ COMPLIANT: Quota Denial Logs

**File**: `backend/src/metering/quota.rs`

**Function**: `check_daily_job_quota_with_context()`

**PII Exposure**: **user_id and workspace_id only**

**Log Example**:
```rust
tracing::warn!(
    user_id = %user_id,                    // ⚠️  UUID identifier
    workspace_id = %workspace_id,          // ⚠️  UUID identifier
    billing_scope = ?context.billing_scope, // ✅ "user" or "workspace"
    plan_tier = %context.plan_tier,        // ✅ Plan name
    limit = limit,                         // ✅ Quota limit
    used = used,                           // ✅ Usage count
    "Daily job quota exceeded"
);
```

**Recommendation**: ✅ **PASS** - No PII beyond identifiers. Aggregates only.

---

### ⚠️  ATTENTION REQUIRED: Webhook Event Storage

**File**: `backend/src/billing/ingest/webhook_ingest.rs`

**Table**: `app_billing_webhook_event`

**Schema**:
```sql
CREATE TABLE public.app_billing_webhook_event (
  id BIGSERIAL PRIMARY KEY,
  provider_event_id TEXT NOT NULL UNIQUE,
  payload JSONB NOT NULL,  -- ⚠️  FULL WEBHOOK PAYLOAD
  provider TEXT,
  raw_event_id TEXT,
  event_type TEXT,
  event_created_at TIMESTAMPTZ,
  is_informational_event BOOLEAN NOT NULL DEFAULT FALSE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
```

**PII Risk**: **HIGH** - The `payload` column stores the **full webhook JSON** from billing providers.

**Potential PII in Payloads**:
- Stripe webhooks may include:
  - `customer.email`
  - `customer.name`
  - `customer.address`
  - `customer.phone`
  - `billing_details.email`
  - `billing_details.name`
  - `billing_details.address`
- Alipay/Paddle webhooks may include similar customer data

**Current Mitigation**:
- ✅ Table is **server-only** (not exposed via PostgREST)
- ✅ No direct API endpoint exposes raw payloads
- ✅ Audit endpoint (`/api/v1/webhooks/billing/events`) returns **metadata only**, not full payload

**Audit Endpoint Response** (`backend/src/billing/events_list/mod.rs`):
```rust
BillingWebhookEventItem {
    id: i64,
    provider_event_id: String,
    provider: Option<String>,
    raw_event_id: Option<String>,
    event_type: Option<String>,
    event_created_at: Option<DateTime<Utc>>,
    is_informational_event: bool,
    created_at: DateTime<Utc>,
    // ✅ NO payload field exposed
}
```

**Recommendation**: ⚠️  **ACCEPTABLE with conditions**:

1. ✅ **Already implemented**: Audit endpoint does not expose `payload` field
2. ⚠️  **Action required**: Document retention policy for webhook events
3. ⚠️  **Action required**: Add database-level access controls (RLS or role restrictions)
4. ⚠️  **Action required**: Consider PII scrubbing for long-term storage (optional)

---

### ✅ COMPLIANT: Billing Event Audit Endpoint

**File**: `backend/src/billing/events_list/mod.rs`

**Endpoint**: `GET /api/v1/webhooks/billing/events`

**PII Exposure**: **NONE** - Metadata only

**Access Control**: 
- ✅ Requires authentication (`require_user_uuid`)
- ✅ Gated by `BILLING_WEBHOOK_EVENTS_LIST_ENABLED=1` env var

**Response Fields**:
- `id`, `provider_event_id`, `provider`, `raw_event_id`, `event_type`, `event_created_at`, `is_informational_event`, `created_at`
- ✅ **NO** `payload` field
- ✅ **NO** customer email, name, or address

**Recommendation**: ✅ **PASS** - No changes needed.

---

## Summary Table

| Component | PII Exposure | Status | Action Required |
|-----------|--------------|--------|-----------------|
| Ops subscription endpoint | None (aggregates only) | ✅ PASS | None |
| Ops job aggregates endpoint | None (aggregates only) | ✅ PASS | None |
| Reconciliation logs | UUIDs only | ✅ PASS | None |
| Quota denial logs | UUIDs only | ✅ PASS | None |
| Webhook event storage | Full payload (may contain PII) | ⚠️  ACCEPTABLE | Document retention + access controls |
| Billing event audit endpoint | Metadata only | ✅ PASS | None |

---

## Recommendations

### Immediate Actions (Task 8.2 Completion)

1. ✅ **Document webhook payload retention policy**
   - Create: `docs/plans/billing-webhook-retention-policy.md`
   - Define retention period (e.g., 90 days for audit, then purge or anonymize)
   - Document legal/compliance requirements (GDPR, CCPA, etc.)

2. ✅ **Add database access controls**
   - Restrict `app_billing_webhook_event.payload` column access to ops/admin roles only
   - Consider PostgreSQL RLS or role-based column permissions
   - Document in migration or ops runbook

3. ✅ **Update ops documentation**
   - Add PII handling guidelines to `docs/plans/workspace-billing-cutover-runbook.md`
   - Document that webhook payloads may contain PII and require special handling

### Optional Enhancements (Future)

4. ⚠️  **PII scrubbing for long-term storage** (optional)
   - Implement background job to scrub PII from webhook payloads after N days
   - Keep only billing-relevant fields (plan_tier, subscription_status, amounts)
   - Preserve event_id for audit trail

5. ⚠️  **Webhook payload encryption** (optional)
   - Encrypt `payload` column at rest using PostgreSQL pgcrypto
   - Decrypt only when needed for debugging/audit

---

## Compliance Assessment

### GDPR Considerations

- ✅ **Data minimization**: Ops endpoints expose only aggregates
- ⚠️  **Storage limitation**: Webhook payloads stored indefinitely (needs retention policy)
- ✅ **Access control**: Ops endpoints protected by internal token
- ⚠️  **Right to erasure**: Need process to purge webhook payloads on user deletion

### CCPA Considerations

- ✅ **No sale of personal information**: Webhook data not shared with third parties
- ✅ **Access control**: Limited to internal ops team
- ⚠️  **Data retention**: Need documented retention policy

---

## Validation Checklist

- [x] Audit all workspace billing endpoints for PII exposure
- [x] Review reconciliation logs for PII leakage
- [x] Review quota denial logs for PII leakage
- [x] Review webhook event storage for PII
- [x] Review billing event audit endpoint for PII exposure
- [ ] Document webhook payload retention policy
- [ ] Implement database access controls for webhook payloads
- [ ] Update ops runbook with PII handling guidelines

---

## Conclusion

The workspace billing implementation **maintains good PII hygiene** with aggregates-only exposure in all ops endpoints and logs. The only PII concern is the `app_billing_webhook_event.payload` column, which stores full webhook JSON for audit purposes. This is **acceptable** with proper access controls and retention policies.

**Task 8.2 Status**: ✅ **COMPLIANT** - Ready to mark complete after documenting retention policy and access controls.

---

## References

- Requirements: `.kiro/specs/workspace-scope-billing/requirements.md` (Requirement 7.2)
- Design: `.kiro/specs/workspace-scope-billing/design.md` (Ops billing view)
- Tasks: `.kiro/specs/workspace-scope-billing/tasks.md` (Task 8.2)
- Ops endpoints: `backend/src/billing/ops_view.rs`
- Reconciliation: `backend/src/billing/ingest/reconciliation.rs`
- Quota logs: `backend/src/metering/quota.rs`
- Webhook storage: `backend/src/billing/ingest/webhook_ingest.rs`
- Event audit: `backend/src/billing/events_list/mod.rs`
