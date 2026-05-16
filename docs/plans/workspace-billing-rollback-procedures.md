# Workspace-Scope Billing Rollback Procedures

**Status**: Ready for use  
**Owner**: SRE + Engineering  
**Related**: [Cutover Runbook](./workspace-billing-cutover-runbook.md)  
**Spec**: [`.kiro/specs/workspace-scope-billing/`](../../.kiro/specs/workspace-scope-billing/)

**Boundary**: these procedures are for the future workspace-scope billing migration path. Unless that migration has actually been enabled, current production behavior remains user-scope and these rollback steps are preparatory runbooks rather than active operational instructions.

## Overview

This document provides **detailed rollback procedures** for each phase of the workspace-scope billing migration. Each procedure is designed to **restore user-scope billing behavior** with minimal downtime and **zero data loss**.

**Key Principles**:
- **Non-destructive**: Workspace billing data retained during rollback
- **Fast recovery**: Feature flags enable quick reversion
- **Auditable**: All rollback actions logged and tracked

---

## Rollback Decision Matrix

| Phase | Rollback Complexity | Data Loss Risk | Estimated RTO | When to Rollback |
|-------|---------------------|----------------|---------------|------------------|
| Phase 1: Dual-Write | **Low** | None | 5-15 min | Webhook failures, performance degradation |
| Phase 2: Shadow Period | **Low** | None | 5-15 min | Excessive reconciliation errors |
| Phase 3: `/me` v2 | **Low** | None | 0 min (client-side) | Client compatibility issues |
| Phase 4: Read Cutover | **Medium** | None | 15-30 min | Incorrect quota enforcement, user complaints |
| Phase 5: Deprecation | **High** | Potential | Hours-Days | Not covered (requires re-implementation) |

---

## Procedure 1: Rollback Dual-Write (Phase 1-2)

### Trigger Conditions

- Webhook processing errors > 5% of events
- Database write latency spike (p99 > 500ms)
- Dual-write mismatch rate > 1%
- On-call engineer judgment

### Pre-Rollback Checklist

- [ ] Confirm issue is related to dual-write (check logs, metrics)
- [ ] Notify engineering team in Slack/incident channel
- [ ] Create incident ticket with symptoms and metrics

### Rollback Steps

#### Step 1: Disable Dual-Write Feature Flag

```bash
# SSH to backend instances or use deployment tool
export TOONFLOW_BILLING_DUAL_WRITE_ENABLED=false

# If using environment variable management system
aws ssm put-parameter \
  --name /toonflow/prod/billing/dual-write-enabled \
  --value "false" \
  --overwrite

# Restart services to pick up new config
kubectl rollout restart deployment/toonflow-backend
# OR
systemctl restart toonflow-backend
```

**Expected Result**: Webhook handler stops writing to workspace billing storage; only updates `app_user_profile`.

#### Step 2: Verify Rollback

```bash
# Check recent webhook events only update user profile
psql $DATABASE_URL -c "
SELECT 
  id, 
  email, 
  plan_tier, 
  updated_at 
FROM app_user_profile 
WHERE updated_at > NOW() - INTERVAL '5 minutes' 
ORDER BY updated_at DESC 
LIMIT 5;
"

# Verify workspace billing NOT updated recently
psql $DATABASE_URL -c "
SELECT 
  workspace_id, 
  plan_tier, 
  updated_at 
FROM app_workspace 
WHERE updated_at > NOW() - INTERVAL '5 minutes' 
ORDER BY updated_at DESC 
LIMIT 5;
"
# Expected: No recent updates (or only from non-webhook sources)
```

#### Step 3: Monitor for Stability

- Watch webhook success rate: should return to baseline (>99%)
- Check database write latency: should decrease
- Verify no new dual-write mismatch alerts

#### Step 4: Post-Rollback Actions

- [ ] Update incident ticket with rollback completion time
- [ ] Analyze root cause (slow queries, lock contention, logic bugs)
- [ ] Plan fix and re-enable timeline
- [ ] Communicate to stakeholders

### Rollback Impact

- **User-facing**: None (behavior reverts to pre-migration state)
- **Data**: Workspace billing data frozen at rollback time; no loss
- **Future migration**: Can re-enable after fix; existing workspace data reused

---

## Procedure 2: Rollback `/me` v2 (Phase 3)

### Trigger Conditions

- Client parsing errors with v2 response
- Unexpected `null` values in `current_workspace_billing`
- Performance issues with nested queries

### Rollback Steps

#### Step 1: Client-Side Rollback (Preferred)

```dart
// Flutter: Remove v2 query parameter
// Before:
final response = await api.get('/api/v1/me?v=2');

// After (rollback):
final response = await api.get('/api/v1/me');
```

**Impact**: Immediate for clients; no backend changes needed.

#### Step 2: Server-Side Disable (If Needed)

```bash
# Disable v2 endpoint entirely
export TOONFLOW_ME_V2_ENABLED=false

# Redeploy or restart
kubectl rollout restart deployment/toonflow-backend
```

**Result**: `GET /api/v1/me?v=2` returns 400 or falls back to v1 response.

#### Step 3: Verify Rollback

```bash
# Test v1 still works
curl -H "Authorization: Bearer $TOKEN" \
  https://api.toonflow.com/api/v1/me | jq '.plan_tier'

# Test v2 disabled (should return v1 or error)
curl -H "Authorization: Bearer $TOKEN" \
  'https://api.toonflow.com/api/v1/me?v=2' | jq '.'
```

### Rollback Impact

- **User-facing**: Clients see user-scope billing info only
- **Data**: No changes (v2 is read-only)
- **Future migration**: Can re-enable after client fixes

---

## Procedure 3: Rollback Read Path Cutover (Phase 4)

### Trigger Conditions

- Quota enforcement errors (users blocked incorrectly)
- Workspace quota limits not matching subscription tier
- Performance degradation in quota checks
- User complaints about unexpected quota denials

### Pre-Rollback Checklist

- [ ] Confirm quota enforcement is the issue (check `quota_denied_total` metrics)
- [ ] Identify affected workspaces/users
- [ ] Prepare user communication (if needed)

### Rollback Steps

#### Step 1: Disable Workspace-Scope Quota Enforcement

```bash
# Revert quota checks to user-scope
export TOONFLOW_BILLING_WORKSPACE_SCOPE_ENABLED=false

# If using feature flag service
curl -X POST https://feature-flags.internal/api/flags/workspace-billing-scope \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -d '{"enabled": false}'

# Redeploy or restart
kubectl rollout restart deployment/toonflow-backend
```

**Expected Result**: Quota checks read from `app_user_profile` instead of workspace billing storage.

#### Step 2: Verify User-Scope Quota Active

```bash
# Test quota check uses user-scope
psql $DATABASE_URL -c "
SELECT 
  u.id,
  u.email,
  u.plan_tier,
  u.daily_job_quota,
  COUNT(j.id) as jobs_today
FROM app_user_profile u
LEFT JOIN app_generation_job j ON j.owner_user_id = u.id
  AND j.created_at >= DATE_TRUNC('day', NOW() AT TIME ZONE 'UTC')
WHERE u.id = '<test-user-id>'
GROUP BY u.id, u.email, u.plan_tier, u.daily_job_quota;
"
```

#### Step 3: Test Job Creation

```bash
# Create test job as affected user
curl -X POST https://api.toonflow.com/api/v1/jobs \
  -H "Authorization: Bearer $USER_TOKEN" \
  -d '{"project_id": "...", "type": "video_generation"}'

# Should succeed if under user quota (not workspace quota)
```

#### Step 4: Monitor Quota Denials

- Check `quota_denied_total{scope=user}` increases (expected)
- Check `quota_denied_total{scope=workspace}` stops increasing
- Verify no spike in support tickets

#### Step 5: Communicate to Users

**Template**:
> "We've temporarily reverted to user-based quota limits while we investigate an issue with workspace quotas. Your personal quota limits are now active. We'll notify you when workspace quotas are re-enabled."

### Rollback Impact

- **User-facing**: Quota limits revert to user-scope (may be higher or lower than workspace)
- **Data**: No loss; workspace billing data retained
- **Billing**: User-scope billing remains source of truth for invoices
- **Future migration**: Can re-enable after fixing quota calculation logic

---

## Procedure 4: Emergency Full Rollback (All Phases)

### Trigger Conditions

- Critical production incident related to billing migration
- Data integrity concerns
- Executive decision to halt migration

### Rollback Steps

#### Step 1: Disable All Workspace Billing Features

```bash
# Disable all feature flags
export TOONFLOW_BILLING_DUAL_WRITE_ENABLED=false
export TOONFLOW_BILLING_WORKSPACE_SCOPE_ENABLED=false
export TOONFLOW_ME_V2_ENABLED=false

# Redeploy to last known good version
git checkout <pre-migration-commit>
./deploy.sh production
```

#### Step 2: Verify Complete Rollback

```bash
# Check all billing reads from user profile
psql $DATABASE_URL -c "
SELECT 
  'user_profile' as source,
  COUNT(*) as recent_updates
FROM app_user_profile
WHERE updated_at > NOW() - INTERVAL '10 minutes'
UNION ALL
SELECT 
  'workspace_billing' as source,
  COUNT(*) as recent_updates
FROM app_workspace
WHERE updated_at > NOW() - INTERVAL '10 minutes';
"
# Expected: Only user_profile has recent updates
```

#### Step 3: Incident Response

- [ ] Notify all stakeholders (engineering, finance, product, support)
- [ ] Create post-mortem document
- [ ] Analyze root cause
- [ ] Plan remediation and re-migration timeline

### Rollback Impact

- **User-facing**: All billing behavior reverts to pre-migration state
- **Data**: Workspace billing data frozen but retained
- **Timeline**: Migration delayed; requires re-planning

---

## Data Preservation During Rollback

### What is Retained

- **Workspace billing columns/table**: All data preserved
- **Job `workspace_id`**: Attribution retained for future use
- **Audit logs**: All webhook events and quota decisions logged
- **User billing profile**: Never modified during rollback

### What is Lost

- **None**: Rollback procedures are non-destructive

### Data Validation After Rollback

```sql
-- Verify user billing data intact
SELECT COUNT(*) FROM app_user_profile WHERE plan_tier IS NOT NULL;

-- Verify workspace billing data preserved
SELECT COUNT(*) FROM app_workspace WHERE plan_tier IS NOT NULL;

-- Verify job attribution preserved
SELECT COUNT(*) FROM app_generation_job WHERE workspace_id IS NOT NULL;
```

---

## Rollback Testing

### Staging Validation

Before production rollback, test in staging:

1. **Enable workspace billing features** in staging
2. **Generate test data**: webhooks, jobs, quota checks
3. **Execute rollback procedure**
4. **Verify**:
   - User-scope billing active
   - No data loss
   - Quota enforcement correct
   - `/me` returns v1 response

### Rollback Drill

Quarterly drill to practice rollback:

- [ ] Simulate Phase 4 rollback in staging
- [ ] Measure RTO (target: <30 minutes)
- [ ] Document any issues or improvements
- [ ] Update runbook based on learnings

---

## Monitoring During Rollback

### Key Metrics to Watch

| Metric | Expected After Rollback | Alert If |
|--------|-------------------------|----------|
| `billing_webhook_success_rate` | >99% | <95% |
| `quota_denied_total{scope=user}` | Baseline | Spike >2x |
| `quota_denied_total{scope=workspace}` | 0 | >0 |
| `me_v1_requests_total` | All requests | Unexpected drop |
| `database_write_latency_p99` | <200ms | >500ms |

### Logs to Check

```bash
# Check for rollback confirmation in logs
kubectl logs -l app=toonflow-backend --tail=100 | grep -i "workspace.*billing.*disabled"

# Check for quota enforcement using user-scope
kubectl logs -l app=toonflow-backend --tail=100 | grep -i "quota.*user.*scope"

# Check for webhook processing (should only update user profile)
kubectl logs -l app=toonflow-backend --tail=100 | grep -i "webhook.*user_profile"
```

---

## Communication Templates

### Internal (Engineering)

**Subject**: [INCIDENT] Workspace Billing Rollback Initiated

**Body**:
```
We've initiated a rollback of workspace-scope billing (Phase X) due to [reason].

Status: In Progress / Complete
Affected Systems: Billing webhooks / Quota enforcement / /me API
User Impact: [None / Minimal / Moderate]
ETA for Resolution: [time]

Actions Taken:
- [Step 1]
- [Step 2]

Next Steps:
- [Plan]

Incident Ticket: [link]
```

### External (Users, if needed)

**Subject**: Temporary Change to Quota Limits

**Body**:
```
Hi [User],

We've temporarily reverted to user-based quota limits while we improve our workspace billing system. 

What this means for you:
- Your personal quota limits are now active
- Workspace-level quotas are temporarily disabled
- No action needed on your part

We'll notify you when workspace quotas are re-enabled.

Questions? Contact support@toonflow.com

Thanks,
The Toonflow Team
```

---

## Post-Rollback Checklist

- [ ] Verify all feature flags disabled
- [ ] Confirm user-scope billing active
- [ ] Check no data loss (run validation queries)
- [ ] Monitor metrics for 1 hour (no anomalies)
- [ ] Update incident ticket with resolution
- [ ] Schedule post-mortem meeting
- [ ] Document root cause and fix plan
- [ ] Communicate timeline to stakeholders

---

## Appendix: Feature Flag Reference

| Flag | Purpose | Default | Rollback Value |
|------|---------|---------|----------------|
| `TOONFLOW_BILLING_DUAL_WRITE_ENABLED` | Enable webhook dual-write | `false` | `false` |
| `TOONFLOW_BILLING_WORKSPACE_SCOPE_ENABLED` | Enable workspace quota enforcement | `false` | `false` |
| `TOONFLOW_ME_V2_ENABLED` | Enable `/me` v2 endpoint | `false` | `false` |

---

## Contact

- **On-Call Engineer**: [PagerDuty rotation]
- **Engineering Lead**: [Name/Email]
- **SRE Lead**: [Name/Email]
- **Incident Channel**: `#incidents` (Slack)

---

*Maintained by: SRE + Engineering*  
*Last updated: 2025-01-XX*  
*Next review: Quarterly*
