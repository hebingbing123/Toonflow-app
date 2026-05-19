# Workspace-Scope Billing Staging Validation Checklist

**Status**: Ready for use  
**Owner**: QA + Engineering  
**Environment**: Staging  
**Related**: [Cutover Runbook](./workspace-billing-cutover-runbook.md)  
**Spec**: [`.kiro/specs/workspace-scope-billing/`](../../.kiro/specs/workspace-scope-billing/)

## Overview

This checklist validates the **workspace-scope billing migration** in staging before production deployment. It covers **dual-write consistency**, **quota enforcement**, **API contracts**, and **rollback procedures**.

**Prerequisites**:
- [ ] Staging database has workspace billing schema deployed
- [ ] Staging backend deployed with workspace billing code
- [ ] Test users and workspaces created
- [ ] Monitoring dashboards configured

---

## Phase 1: Schema & Data Validation

### 1.1 Workspace Billing Storage

- [ ] **Verify workspace billing table/columns exist**
  ```sql
  -- Option A: Columns on app_workspace
  \d app_workspace
  -- Should show: plan_tier, daily_job_quota, billing_provider, billing_customer_id
  
  -- Option B: Separate table
  \d app_workspace_billing
  -- Should show: workspace_id, plan_tier, daily_job_quota, etc.
  ```

- [ ] **Verify indexes created**
  ```sql
  SELECT indexname, indexdef 
  FROM pg_indexes 
  WHERE tablename IN ('app_workspace', 'app_workspace_billing')
  ORDER BY indexname;
  ```

- [ ] **Verify constraints**
  ```sql
  SELECT conname, contype, pg_get_constraintdef(oid)
  FROM pg_constraint
  WHERE conrelid = 'app_workspace'::regclass
     OR conrelid = 'app_workspace_billing'::regclass;
  ```

### 1.2 Job Workspace Attribution

- [ ] **Verify `workspace_id` column on `app_generation_job`**
  ```sql
  \d app_generation_job
  -- Should show: workspace_id UUID (nullable initially)
  ```

- [ ] **Verify index on `workspace_id`**
  ```sql
  SELECT indexname, indexdef 
  FROM pg_indexes 
  WHERE tablename = 'app_generation_job' 
    AND indexdef LIKE '%workspace_id%';
  ```

### 1.3 Migration Rollback Scripts

- [ ] **Verify rollback migration exists**
  ```bash
  ls -la supabase/migrations/*workspace*billing*rollback*
  ```

- [ ] **Test rollback in isolated staging DB**
  ```bash
  # Create test database
  createdb openflow_staging_rollback_test
  
  # Apply migrations
  supabase db push --db-url postgresql://...
  
  # Apply rollback
  psql openflow_staging_rollback_test < supabase/migrations/XXXXXX_rollback_workspace_billing.sql
  
  # Verify rollback successful
  psql openflow_staging_rollback_test -c "\d app_workspace"
  ```

---

## Phase 2: Dual-Write Validation

### 2.1 Webhook Dual-Write

- [ ] **Enable dual-write in staging**
  ```bash
  export OPENFLOW_BILLING_DUAL_WRITE_ENABLED=true
  # Restart staging backend
  ```

- [ ] **Trigger test webhook (Stripe test mode)**
  ```bash
  # Use Stripe CLI or test webhook endpoint
  stripe trigger customer.subscription.updated
  ```

- [ ] **Verify both user and workspace updated**
  ```sql
  -- Check user profile updated
  SELECT id, email, plan_tier, updated_at 
  FROM app_user_profile 
  WHERE email = 'test@example.com';
  
  -- Check workspace billing updated
  SELECT workspace_id, plan_tier, updated_at 
  FROM app_workspace 
  WHERE id = (SELECT current_workspace_id FROM app_user_profile WHERE email = 'test@example.com');
  ```

- [ ] **Verify idempotency (replay webhook)**
  ```bash
  # Replay same webhook event
  stripe trigger customer.subscription.updated --event-id evt_test_123
  ```

- [ ] **Check no duplicate writes**
  ```sql
  -- Should have same updated_at timestamp
  SELECT 
    u.updated_at as user_updated,
    w.updated_at as workspace_updated,
    u.updated_at = w.updated_at as consistent
  FROM app_user_profile u
  JOIN app_workspace w ON w.id = u.current_workspace_id
  WHERE u.email = 'test@example.com';
  ```

### 2.2 Dual-Write Consistency

- [ ] **Create test scenarios**:
  - [ ] New subscription (free → pro)
  - [ ] Upgrade (pro → enterprise)
  - [ ] Downgrade (enterprise → pro)
  - [ ] Cancellation (pro → free)
  - [ ] Quota override

- [ ] **For each scenario, verify**:
  ```sql
  SELECT 
    u.plan_tier as user_plan,
    w.plan_tier as workspace_plan,
    u.daily_job_quota as user_quota,
    w.daily_job_quota as workspace_quota,
    CASE 
      WHEN u.plan_tier = w.plan_tier AND u.daily_job_quota = w.daily_job_quota 
      THEN 'CONSISTENT' 
      ELSE 'MISMATCH' 
    END as status
  FROM app_user_profile u
  JOIN app_workspace w ON w.id = u.current_workspace_id
  WHERE w.workspace_type = 'personal';
  ```

### 2.3 Reconciliation Monitoring

- [ ] **Verify reconciliation metrics exist**
  ```bash
  curl http://staging-api.openflow.com/metrics | grep billing_webhook_dual_write_mismatch_total
  ```

- [ ] **Trigger intentional mismatch (if possible)**
  - Manually update user profile without workspace
  - Check reconciliation alert fires

- [ ] **Verify reconciliation job runs**
  ```bash
  # Check logs for reconciliation job
  kubectl logs -l app=openflow-backend --tail=100 | grep reconciliation
  ```

---

## Phase 3: Job Workspace Attribution

**Note**: Job creation examples below should follow the active jobs API contract for the target branch/environment. For project scope, prefer UUID-first fields (for example `project_uuid`); only include legacy numeric project scope if that environment still requires it for compatibility validation.

### 3.1 Job Creation

- [ ] **Create job in personal workspace**
  ```bash
  curl -X POST https://staging-api.openflow.com/api/v1/jobs \
    -H "Authorization: Bearer $USER_TOKEN" \
    -d '{"project_uuid": "...", "type": "video_generation"}'
  ```

- [ ] **Verify `workspace_id` set**
  ```sql
  SELECT id, owner_user_id, workspace_id, created_at 
  FROM app_generation_job 
  ORDER BY created_at DESC 
  LIMIT 5;
  ```

- [ ] **Create job in enterprise workspace**
  - Switch to enterprise workspace
  - Create job
  - Verify `workspace_id` matches enterprise workspace

### 3.2 Backfill Script

- [ ] **Run backfill in dry-run mode**
  ```bash
  cargo run --bin backfill-job-workspace-id -- \
    --dry-run \
    --batch-size 100
  ```

- [ ] **Review dry-run output**
  - Check jobs without `workspace_id`
  - Verify resolution logic (project → workspace)
  - Check orphan job handling

- [ ] **Run backfill for real (small batch)**
  ```bash
  cargo run --bin backfill-job-workspace-id -- \
    --batch-size 10
  ```

- [ ] **Verify backfill results**
  ```sql
  SELECT 
    COUNT(*) as total,
    COUNT(workspace_id) as with_workspace,
    ROUND(100.0 * COUNT(workspace_id) / COUNT(*), 2) as coverage_pct
  FROM app_generation_job
  WHERE created_at BETWEEN '2024-01-01' AND '2024-01-31';
  ```

---

## Phase 4: Quota Enforcement

### 4.1 User-Scope Quota (Baseline)

- [ ] **Verify user-scope quota works (before cutover)**
  ```bash
  # Create jobs until quota exceeded
  for i in {1..10}; do
    curl -X POST https://staging-api.openflow.com/api/v1/jobs \
      -H "Authorization: Bearer $USER_TOKEN" \
      -d '{"project_uuid": "...", "type": "video_generation"}'
  done
  ```

- [ ] **Verify quota denial**
  - Check response: `429 Too Many Requests`
  - Check error message mentions user quota

- [ ] **Verify `jobs_today` aggregate**
  ```sql
  SELECT 
    owner_user_id,
    COUNT(*) as jobs_today
  FROM app_generation_job
  WHERE created_at >= DATE_TRUNC('day', NOW() AT TIME ZONE 'UTC')
  GROUP BY owner_user_id;
  ```

### 4.2 Workspace-Scope Quota (After Cutover)

- [ ] **Enable workspace-scope quota**
  ```bash
  export OPENFLOW_BILLING_WORKSPACE_SCOPE_ENABLED=true
  # Restart staging backend
  ```

- [ ] **Set workspace quota lower than user quota**
  ```sql
  UPDATE app_workspace 
  SET daily_job_quota = 5 
  WHERE id = '<test-workspace-id>';
  ```

- [ ] **Create jobs until workspace quota exceeded**
  ```bash
  for i in {1..10}; do
    curl -X POST https://staging-api.openflow.com/api/v1/jobs \
      -H "Authorization: Bearer $USER_TOKEN" \
      -d '{"project_uuid": "...", "type": "video_generation"}'
  done
  ```

- [ ] **Verify workspace quota denial**
  - Check response: `429 Too Many Requests`
  - Check error message mentions workspace quota

- [ ] **Verify workspace `jobs_today` aggregate**
  ```sql
  SELECT 
    workspace_id,
    COUNT(*) as jobs_today
  FROM app_generation_job
  WHERE created_at >= DATE_TRUNC('day', NOW() AT TIME ZONE 'UTC')
    AND workspace_id IS NOT NULL
  GROUP BY workspace_id;
  ```

### 4.3 Quota Metrics

- [ ] **Verify quota denial metrics**
  ```bash
  curl http://staging-api.openflow.com/metrics | grep quota_denied_total
  # Should show: quota_denied_total{scope="user"}
  # Should show: quota_denied_total{scope="workspace"}
  ```

- [ ] **Verify quota check logs**
  ```bash
  kubectl logs -l app=openflow-backend --tail=100 | grep quota
  # Should include: user_id, workspace_id, billing_scope
  ```

---

## Phase 5: API Contract Validation

### 5.1 `/me` v1 (Backward Compatibility)

- [ ] **Verify v1 response unchanged**
  ```bash
  curl -H "Authorization: Bearer $USER_TOKEN" \
    https://staging-api.openflow.com/api/v1/me | jq '.'
  ```

- [ ] **Check v1 fields present**:
  - [ ] `id`
  - [ ] `email`
  - [ ] `plan_tier`
  - [ ] `daily_job_quota`
  - [ ] `jobs_today`
  - [ ] `current_workspace` (nested object)

- [ ] **Verify v1 OpenAPI schema**
  ```bash
  curl https://staging-api.openflow.com/openapi.json | jq '.paths["/api/v1/me"].get.responses["200"]'
  ```

### 5.2 `/me` v2 (New Contract)

- [ ] **Verify v2 response structure**
  ```bash
  curl -H "Authorization: Bearer $USER_TOKEN" \
    'https://staging-api.openflow.com/api/v1/me?v=2' | jq '.'
  ```

- [ ] **Check v2 fields present**:
  - [ ] `billing_scope` (`"user"` or `"workspace"`)
  - [ ] `user` (nested object with user billing info)
  - [ ] `current_workspace_billing` (nested object, nullable)

- [ ] **Test v2 scenarios**:
  - [ ] Personal workspace: `billing_scope=user`, `current_workspace_billing` may be null
  - [ ] Enterprise workspace: `billing_scope=workspace`, `current_workspace_billing` populated
  - [ ] No current workspace: `current_workspace_billing` null

- [ ] **Verify v2 OpenAPI schema**
  ```bash
  curl https://staging-api.openflow.com/openapi.json | jq '.paths["/api/v1/me"].get.parameters'
  # Should show: v query parameter
  ```

### 5.3 Contract Tests

- [ ] **Run backend contract tests**
  ```bash
  cd backend
  cargo test --test pg_contract -- me_v1_v2
  ```

- [ ] **Run integration tests**
  ```bash
  cargo test --test integration -- workspace_billing
  ```

---

## Phase 6: Flutter Client Validation

### 6.1 `rust_api` Models

- [ ] **Verify `rust_api` updated**
  ```bash
  cd frontend
  grep -r "billing_scope" lib/rust_api/
  grep -r "current_workspace_billing" lib/rust_api/
  ```

- [ ] **Run Flutter tests**
  ```bash
  flutter test test/rust_api/me_test.dart
  ```

### 6.2 UI Validation

- [ ] **Personal workspace UI**:
  - [ ] User quota displayed correctly
  - [ ] `jobs_today` count accurate
  - [ ] No workspace billing info shown (or grayed out)

- [ ] **Enterprise workspace UI**:
  - [ ] Workspace quota displayed
  - [ ] Workspace `jobs_today` count accurate
  - [ ] Plan tier matches workspace subscription

- [ ] **Quota exceeded UI**:
  - [ ] Error message clear (user vs workspace quota)
  - [ ] Upgrade prompt shown (if applicable)

### 6.3 Workspace Switching

- [ ] **Switch from personal to enterprise**
  - [ ] Quota display updates
  - [ ] `jobs_today` resets to workspace count

- [ ] **Switch from enterprise to personal**
  - [ ] Quota display updates
  - [ ] `jobs_today` resets to user count

---

## Phase 7: Rollback Validation

### 7.1 Rollback Dual-Write

- [ ] **Disable dual-write**
  ```bash
  export OPENFLOW_BILLING_DUAL_WRITE_ENABLED=false
  # Restart staging backend
  ```

- [ ] **Trigger webhook**
  ```bash
  stripe trigger customer.subscription.updated
  ```

- [ ] **Verify only user profile updated**
  ```sql
  SELECT 
    u.updated_at as user_updated,
    w.updated_at as workspace_updated
  FROM app_user_profile u
  JOIN app_workspace w ON w.id = u.current_workspace_id
  WHERE u.email = 'test@example.com';
  -- workspace_updated should be older than user_updated
  ```

- [ ] **Re-enable dual-write**
  ```bash
  export OPENFLOW_BILLING_DUAL_WRITE_ENABLED=true
  # Restart staging backend
  ```

### 7.2 Rollback Workspace-Scope Quota

- [ ] **Disable workspace-scope quota**
  ```bash
  export OPENFLOW_BILLING_WORKSPACE_SCOPE_ENABLED=false
  # Restart staging backend
  ```

- [ ] **Create job**
  ```bash
  curl -X POST https://staging-api.openflow.com/api/v1/jobs \
    -H "Authorization: Bearer $USER_TOKEN" \
    -d '{"project_uuid": "...", "type": "video_generation"}'
  ```

- [ ] **Verify user-scope quota enforced**
  - Check quota denial uses user `jobs_today`
  - Check error message mentions user quota

- [ ] **Re-enable workspace-scope quota**
  ```bash
  export OPENFLOW_BILLING_WORKSPACE_SCOPE_ENABLED=true
  # Restart staging backend
  ```

### 7.3 Rollback `/me` v2

- [ ] **Disable v2 endpoint**
  ```bash
  export OPENFLOW_ME_V2_ENABLED=false
  # Restart staging backend
  ```

- [ ] **Test v2 request**
  ```bash
  curl -H "Authorization: Bearer $USER_TOKEN" \
    'https://staging-api.openflow.com/api/v1/me?v=2'
  # Should return 400 or fall back to v1
  ```

- [ ] **Re-enable v2**
  ```bash
  export OPENFLOW_ME_V2_ENABLED=true
  # Restart staging backend
  ```

---

## Phase 8: Shadow Period Validation

### 8.1 Reconciliation Monitoring

- [ ] **Run shadow period for N days** (recommend N=7)
  - [ ] Day 1: Enable dual-write, monitor for 24 hours
  - [ ] Day 2-6: Continue monitoring, check for mismatches
  - [ ] Day 7: Review reconciliation metrics

- [ ] **Check reconciliation metrics daily**
  ```bash
  curl http://staging-api.openflow.com/metrics | grep billing_webhook_dual_write_mismatch_total
  # Target: 0 mismatches
  ```

- [ ] **Review reconciliation logs**
  ```bash
  kubectl logs -l app=openflow-backend --since=24h | grep reconciliation
  ```

### 8.2 Data Consistency Checks

- [ ] **Run consistency query daily**
  ```sql
  SELECT 
    COUNT(*) as total_personal_workspaces,
    COUNT(CASE WHEN u.plan_tier = w.plan_tier THEN 1 END) as consistent,
    COUNT(CASE WHEN u.plan_tier != w.plan_tier THEN 1 END) as mismatches
  FROM app_user_profile u
  JOIN app_workspace w ON w.id = u.current_workspace_id
  WHERE w.workspace_type = 'personal';
  ```

- [ ] **Investigate any mismatches**
  - Check webhook logs
  - Verify dual-write logic
  - Fix and re-test

### 8.3 Performance Monitoring

- [ ] **Monitor database write latency**
  ```bash
  # Check p99 latency for webhook handler
  curl http://staging-api.openflow.com/metrics | grep http_request_duration_seconds
  ```

- [ ] **Monitor quota check latency**
  ```bash
  # Check p99 latency for quota checks
  curl http://staging-api.openflow.com/metrics | grep quota_check_duration_seconds
  ```

- [ ] **Check for slow queries**
  ```sql
  SELECT 
    query,
    mean_exec_time,
    calls
  FROM pg_stat_statements
  WHERE query LIKE '%app_workspace%' OR query LIKE '%app_generation_job%'
  ORDER BY mean_exec_time DESC
  LIMIT 10;
  ```

---

## Phase 9: Production Readiness

### 9.1 Documentation Review

- [ ] **Cutover runbook complete**: [workspace-billing-cutover-runbook.md](./workspace-billing-cutover-runbook.md)
- [ ] **Rollback procedures complete**: [workspace-billing-rollback-procedures.md](./workspace-billing-rollback-procedures.md)
- [ ] **ADRs published**:
  - [ ] [ADR: Workspace Billing Attribution](./adr-workspace-billing-attribution.md)
  - [ ] [ADR: Workspace Billing Storage Model](./adr-workspace-billing-storage-model.md)
- [ ] **Migration notice published**: [workspace-migration-notice.md](./workspace-migration-notice.md)

### 9.2 Monitoring & Alerts

- [ ] **Dashboards created**:
  - [ ] Billing Cutover Dashboard (Grafana/Datadog)
  - [ ] Quota Enforcement by Scope
  - [ ] Webhook Dual-Write Health

- [ ] **Alerts configured**:
  - [ ] `billing_webhook_dual_write_mismatch_total > 0`
  - [ ] `quota_denied_total{scope=workspace}` spike (>2x baseline)
  - [ ] `billing_reconciliation_mismatch_total{field=...} > 10/day`

### 9.3 Team Readiness

- [ ] **Engineering team briefed** on cutover plan
- [ ] **On-call rotation updated** with runbook links
- [ ] **Support team trained** on workspace quota FAQs
- [ ] **Finance team aligned** on reconciliation process

### 9.4 Final Checks

- [ ] **`yarn refactor:check` passes**
  ```bash
  cd <repo-root>
  yarn refactor:check
  ```

- [ ] **All staging tests pass**
  ```bash
  cd backend
  cargo test
  
  cd ../frontend
  flutter test
  ```

- [ ] **OpenAPI spec valid**
  ```bash
  cd backend
  cargo run --bin export-openapi
  ruby -ryaml -e "YAML.load_file('openapi_spec/generated/openapi.yaml')"
  ```

---

## Sign-off

### Staging Validation Complete

- [ ] **QA Lead**: All test scenarios passed
- [ ] **Engineering Lead**: Code review complete, rollback tested
- [ ] **SRE**: Monitoring and alerts validated
- [ ] **Product Lead**: User communication plan approved

**Date**: ___________  
**Approved by**: ___________

### Ready for Production

- [ ] **Shadow period complete** (N days, zero mismatches)
- [ ] **Rollback procedures tested** in staging
- [ ] **Team trained** and on-call briefed
- [ ] **Go/No-Go meeting scheduled**

**Production Deployment Date**: ___________

---

## Appendix: Test Data Setup

### Create Test Users

```sql
-- Personal workspace user
INSERT INTO app_user_profile (id, email, plan_tier, daily_job_quota)
VALUES (gen_random_uuid(), 'test-personal@example.com', 'pro', 100);

-- Enterprise workspace user
INSERT INTO app_user_profile (id, email, plan_tier, daily_job_quota)
VALUES (gen_random_uuid(), 'test-enterprise@example.com', 'enterprise', 1000);
```

### Create Test Workspaces

```sql
-- Personal workspace
INSERT INTO app_workspace (id, workspace_type, name, owner_user_id)
VALUES (gen_random_uuid(), 'personal', 'Personal', '<user-id>');

-- Enterprise workspace
INSERT INTO app_workspace (id, workspace_type, name, owner_user_id, plan_tier, daily_job_quota)
VALUES (gen_random_uuid(), 'enterprise', 'Test Corp', '<user-id>', 'enterprise', 500);
```

### Create Test Projects

```sql
INSERT INTO app_project (id, name, workspace_id, owner_user_id)
VALUES (gen_random_uuid(), 'Test Project', '<workspace-id>', '<user-id>');
```

---

*Maintained by: QA + Engineering*  
*Last updated: 2025-01-XX*
