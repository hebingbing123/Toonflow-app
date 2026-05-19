# Billing Webhook Retention Policy

**Related**: Workspace-scope billing Task 8.2 (PII hygiene); [`billing-webhook-pii-runbook.md`](./billing-webhook-pii-runbook.md)  
**Status**: Policy draft; runbook baseline documented  
**Owner**: Ops/Compliance Team

**Boundary**: this policy is written against the future billing-workstream because webhook payload hygiene matters regardless of the final attribution model; unless a separate migration is approved, current product billing semantics still remain user-scope.

## Purpose

This document defines the retention and access policy for billing webhook event data stored in `app_billing_webhook_event`, which may contain PII from billing providers (Stripe, Alipay, Paddle).

## Data Classification

### Webhook Event Data

**Table**: `public.app_billing_webhook_event`

**Sensitive Fields**:
- `payload` (JSONB): **HIGH SENSITIVITY** - May contain customer PII:
  - Email addresses
  - Names
  - Billing addresses
  - Phone numbers
  - Payment method details (last 4 digits, brand)

**Non-Sensitive Fields**:
- `id`, `provider_event_id`, `provider`, `raw_event_id`, `event_type`, `event_created_at`, `is_informational_event`, `created_at`

## Retention Policy

### Phase 1: Active Audit Period (0-90 days)

**Duration**: 90 days from `created_at`

**Purpose**: 
- Billing reconciliation
- Dispute resolution
- Fraud investigation
- Compliance audit

**Access**: 
- Internal ops team only
- Requires `OPENFLOW_INTERNAL_OPS_TOKEN` authentication
- Database access restricted to ops/admin roles

**Data Retention**: Full webhook payload retained

### Phase 2: Archived Period (91-365 days)

**Duration**: 91-365 days from `created_at`

**Purpose**:
- Long-term audit trail
- Legal compliance (tax records, etc.)

**Access**:
- Restricted to compliance/legal team
- Requires explicit approval for access

**Data Retention**: 
- **Option A** (Recommended): Scrub PII from `payload`, retain only:
  - `plan_tier`, `subscription_status`, `amount`, `currency`
  - Event metadata (type, timestamp, provider)
- **Option B**: Retain full payload with encryption

### Phase 3: Purge (365+ days)

**Duration**: After 365 days from `created_at`

**Action**: 
- Delete webhook event records
- OR anonymize by removing `payload` column data

**Exception**: 
- Records involved in active disputes/investigations may be retained longer with documented justification

## Access Controls

### Database-Level Restrictions

```sql
-- Restrict payload column access to ops role
REVOKE SELECT (payload) ON public.app_billing_webhook_event FROM authenticated;
GRANT SELECT (payload) ON public.app_billing_webhook_event TO ops_role;

-- Allow metadata access for audit endpoint
GRANT SELECT (id, provider_event_id, provider, raw_event_id, event_type, 
              event_created_at, is_informational_event, created_at) 
ON public.app_billing_webhook_event TO authenticated;
```

### Application-Level Restrictions

- ✅ Ops endpoints (`/api/v1/ops/billing/*`) require `OPENFLOW_INTERNAL_OPS_TOKEN`
- ✅ Audit endpoint (`/api/v1/webhooks/billing/events`) does NOT expose `payload` field
- ✅ No PostgREST access to `app_billing_webhook_event` table

## PII Scrubbing Procedure (Optional)

### Automated Scrubbing Job

**Schedule**: Daily at 02:00 UTC

**Target**: Records where `created_at < NOW() - INTERVAL '90 days'`

**Process**:
1. Identify records older than 90 days
2. Extract billing-relevant fields from `payload`:
   - `plan_tier`, `subscription_status`, `amount`, `currency`, `interval`
3. Replace `payload` with scrubbed version:
   ```json
   {
     "scrubbed": true,
     "scrubbed_at": "2025-01-15T02:00:00Z",
     "plan_tier": "pro",
     "subscription_status": "active",
     "amount": 2900,
     "currency": "usd",
     "interval": "month"
   }
   ```
4. Log scrubbing action for audit

### Manual Scrubbing (On-Demand)

**Use Case**: User deletion / GDPR erasure request

**Process**:
1. Identify all webhook events for user (via `user_id` in payload)
2. Scrub PII from `payload` immediately (don't wait for 90-day period)
3. Document erasure request and completion

## Compliance Mapping

### GDPR (EU)

- ✅ **Article 5(1)(e) - Storage limitation**: 90-day active retention, then scrub/purge
- ✅ **Article 17 - Right to erasure**: Manual scrubbing process for user deletion
- ✅ **Article 32 - Security**: Access controls, encryption at rest (PostgreSQL default)

### CCPA (California)

- ✅ **Data retention**: Documented retention period
- ✅ **Right to deletion**: Manual scrubbing process
- ✅ **No sale**: Webhook data not shared with third parties

### PCI DSS (Payment Card Industry)

- ✅ **Requirement 3.1**: Retain cardholder data only as long as needed
- ⚠️  **Note**: Webhook payloads may contain last 4 digits of card (not full PAN)
- ✅ **Requirement 7**: Restrict access to cardholder data (ops role only)

## Implementation Checklist

- [x] Deploy database access controls (RLS or role-based) — see `supabase/migrations/20260410000000_billing_webhook_payload_access_control.sql`
- [ ] Implement automated scrubbing job (optional)
- [x] Document manual scrubbing procedure for user deletion — baseline guidance in [`billing-webhook-pii-runbook.md`](./billing-webhook-pii-runbook.md) §4
- [x] Add retention policy to ops runbook — see [`billing-webhook-pii-runbook.md`](./billing-webhook-pii-runbook.md) §2
- [ ] Train ops team on PII handling
- [ ] Schedule annual policy review

## Exceptions and Overrides

### Legal Hold

If webhook events are subject to legal hold (litigation, investigation):
- Retention period extended indefinitely
- Document legal hold request and approval
- Notify compliance team when hold is lifted

### Regulatory Audit

If regulatory audit requires access to historical webhook data:
- Grant temporary access to auditors
- Log all access for audit trail
- Revoke access after audit completion

## Review and Updates

**Review Frequency**: Annually or when regulations change

**Next Review**: 2026-01-XX

**Approval Required**: Legal, Compliance, Engineering leads

---

## References

- PII Hygiene Audit: `.kiro/specs/workspace-scope-billing/pii-hygiene-audit.md`
- Ops Runbook: `docs/plans/billing-webhook-pii-runbook.md`
- Workspace Billing Requirements: `.kiro/specs/workspace-scope-billing/requirements.md` (Requirement 7.2)
- Cutover Runbook: `docs/plans/workspace-billing-cutover-runbook.md`
