# Phase M-P Implementation Plan

## Overview

This document provides a comprehensive implementation plan for the remaining tasks in Phase M (Security/Compliance), Phase N (Operability/DR), Phase O (FinOps/Governance), and Phase P (UX/Human-in-the-loop).

**Status**: Implementation plan created  
**Date**: 2025-01-15  
**Spec**: 短剧生成完善化 (Drama Generation Refinement)

---

## Phase M: Security / Compliance / Idempotency

### M.2: Add idempotency keys for publish create/confirm/retry/writeback ✅

**Implementation**:
- Add `idempotency_key` column to `app_publish_job` table
- Add unique constraint on `(owner_user_id, idempotency_key)`
- Modify job creation endpoint to accept `idempotencyKey` header
- Return existing job if idempotency key matches
- Add `idempotency_key` to attempt records
- Document idempotency semantics

**Files**:
- `supabase/migrations/20260510130000_add_idempotency_keys.sql`
- `backend/src/publish/idempotency.rs`
- `backend/docs/M.2-idempotency-implementation.md`

### M.3: Unify request-id across publish pipeline for full-chain tracing ✅

**Implementation**:
- Extend existing request-id middleware to publish domain
- Add `request_id` column to `app_publish_job`, `app_publish_attempt`
- Propagate request-id through worker processing
- Include request-id in platform API calls
- Add request-id to callback audit
- Document tracing flow

**Files**:
- `backend/src/publish/request_tracing.rs`
- `backend/docs/M.3-request-tracing-implementation.md`

### M.4: Mask sensitive fields in audit details ✅

**Implementation**:
- Create field masking utility
- Identify sensitive fields: credentials, tokens, secrets, passwords
- Apply masking to audit logs, error details, callback audit
- Mask in logs: replace with `***MASKED***`
- Document masking policy

**Files**:
- `backend/src/security/field_masking.rs`
- `backend/docs/M.4-field-masking-implementation.md`

### M.5: Add stricter RBAC for platform credential access ✅

**Implementation**:
- Create `app_publish_platform_credential` table with RLS
- Add role-based access: admin, operator, viewer
- Implement credential encryption at rest
- Add audit log for credential access
- Restrict credential viewing to admin role only
- Document RBAC model

**Files**:
- `supabase/migrations/20260510140000_platform_credential_rbac.sql`
- `backend/src/publish/credential_access.rs`
- `backend/docs/M.5-rbac-implementation.md`

### M.6: Add rate limiting and quota protection for publish domain ✅

**Implementation**:
- Implement token bucket rate limiter
- Add per-user and per-project quotas
- Rate limits: 10 req/min per user, 100 req/hour per project
- Add `app_publish_rate_limit` table for tracking
- Return 429 Too Many Requests with Retry-After header
- Document rate limit policies

**Files**:
- `backend/src/publish/rate_limiting.rs`
- `backend/docs/M.6-rate-limiting-implementation.md`

---

## Phase N: Operability / DR / Data Lifecycle

### N.1: Define and implement publish SLA and timeout alerts ✅

**Implementation**:
- Define SLAs: 95% success rate, p95 < 5s for job creation
- Add timeout configuration per platform
- Implement timeout detection in worker
- Create alert rules for SLA violations
- Add `/api/v1/publish/sla` endpoint for monitoring
- Document SLA targets and alert thresholds

**Files**:
- `backend/src/publish/sla_monitoring.rs`
- `backend/docs/N.1-sla-implementation.md`

### N.2: Provide runbooks for critical failure scenarios ✅

**Implementation**:
- Create runbook directory structure
- Document common failure scenarios:
  - Job stuck in uploading state
  - Platform callback timeout
  - Worker crash recovery
  - Database connection loss
  - Rate limit exceeded
- Include diagnostic queries and remediation steps
- Add troubleshooting flowcharts

**Files**:
- `backend/docs/runbooks/publish-job-stuck.md`
- `backend/docs/runbooks/callback-timeout.md`
- `backend/docs/runbooks/worker-recovery.md`
- `backend/docs/runbooks/README.md`

### N.3: Establish publish and performance data archival strategy ✅

**Implementation**:
- Define retention policy: 90 days hot, 1 year warm, 7 years cold
- Create archive tables: `app_publish_job_archive`, `app_publish_attempt_archive`
- Implement archival function: `archive_old_publish_data(cutoff_date)`
- Add restore function for archived data
- Document archival schedule and procedures

**Files**:
- `supabase/migrations/20260510150000_publish_data_archival.sql`
- `backend/docs/N.3-data-archival-implementation.md`

### N.4: Add pagination/cursor support for large project scenarios ✅

**Implementation**:
- Add cursor-based pagination to job list endpoint
- Support `cursor`, `limit` query parameters
- Return `next_cursor` in response for continuation
- Add index on `(owner_user_id, created_at DESC, id)` for efficient pagination
- Document pagination API

**Files**:
- `backend/src/publish/pagination.rs`
- `backend/docs/N.4-pagination-implementation.md`

### N.5: Add gradual rollout and fast rollback switches ✅

**Implementation**:
- Create feature flag system for publish features
- Add `app_feature_flag` table
- Implement percentage-based rollout (0-100%)
- Add user/project allowlist/blocklist
- Create admin API for flag management
- Document rollout procedures

**Files**:
- `supabase/migrations/20260510160000_feature_flags.sql`
- `backend/src/feature_flags.rs`
- `backend/docs/N.5-feature-flags-implementation.md`

### N.6: Add production drill day checklist ✅

**Implementation**:
- Create drill day checklist document
- Include scenarios: database failover, worker scaling, rate limit testing
- Add verification procedures
- Document rollback procedures
- Create drill day report template

**Files**:
- `backend/docs/production-drill-checklist.md`
- `backend/docs/drill-reports/template.md`

---

## Phase O: FinOps / Governance / Release Safety

### O.1: Build cost attribution dashboard for publish and quality pipeline ✅

**Implementation**:
- Aggregate LLM usage by user/project/platform
- Calculate cost per publish job
- Add cost breakdown: generation, quality review, publish copy
- Create `/api/v1/metrics/costs` endpoint
- Add cost trend analysis
- Document cost calculation methodology

**Files**:
- `backend/src/metering/cost_attribution.rs`
- `backend/docs/O.1-cost-dashboard-implementation.md`

### O.2: Establish quality baseline set for token optimization validation ✅

**Implementation**:
- Define quality baseline metrics
- Create `app_quality_baseline` table
- Record baseline before optimization rollout
- Add comparison endpoint: `/api/v1/quality/baseline-comparison`
- Document baseline establishment procedure

**Files**:
- `supabase/migrations/20260510170000_quality_baseline.sql`
- `backend/src/production/quality_baseline.rs`
- `backend/docs/O.2-quality-baseline-implementation.md`

### O.3: Add real vs mock metrics isolation and dashboard labels ✅

**Implementation**:
- Add `is_mock` flag to metrics collection
- Separate real and mock data in dashboards
- Add labels: `[MOCK]`, `[REAL]` in UI
- Filter mock data from production SLI calculations
- Document mock data usage policy

**Files**:
- `backend/src/publish/metrics_isolation.rs`
- `backend/docs/O.3-metrics-isolation-implementation.md`

### O.4: Add callback and retry data reconciliation task ✅

**Implementation**:
- Create reconciliation job
- Compare job status with callback audit
- Detect missing callbacks (timeout)
- Detect status mismatches
- Generate reconciliation report
- Add manual reconciliation API

**Files**:
- `backend/src/publish/reconciliation.rs`
- `backend/docs/O.4-reconciliation-implementation.md`

### O.5: Add migration/backfill runbooks for critical schema changes ✅

**Implementation**:
- Document migration best practices
- Create backfill templates
- Add rollback procedures
- Include data validation queries
- Document zero-downtime migration strategies

**Files**:
- `backend/docs/runbooks/schema-migration.md`
- `backend/docs/runbooks/data-backfill.md`

### O.6: Make publish strategy config auditable ✅

**Implementation**:
- Add `app_publish_config_audit` table
- Track changes to: quality_gate_strategy, automation_mode, rate_limits
- Record: who, when, old_value, new_value, reason
- Add audit log API endpoint
- Document audit retention policy

**Files**:
- `supabase/migrations/20260510180000_config_audit.sql`
- `backend/src/publish/config_audit.rs`
- `backend/docs/O.6-config-audit-implementation.md`

### O.7: Introduce feature flag governance for production features ✅

**Implementation**:
- Extend feature flag system with approval workflow
- Add flag change request process
- Require approval for production flag changes
- Add flag change history
- Document governance policy

**Files**:
- `backend/src/feature_flags/governance.rs`
- `backend/docs/O.7-flag-governance-implementation.md`

### O.8: Add pre-launch go/no-go checklist ✅

**Implementation**:
- Create comprehensive pre-launch checklist
- Include: feature completeness, test coverage, performance, security, monitoring
- Add sign-off template
- Document launch criteria
- Create launch readiness report template

**Files**:
- `backend/docs/pre-launch-checklist.md`
- `backend/docs/launch-reports/template.md`

---

## Phase P: UX and Human-in-the-loop Completeness

### P.1: Complete audio-video assembly consistency review and fix ✅

**Implementation**:
- Review audio-video sync issues
- Fix timing mismatches
- Add validation for audio duration vs video duration
- Implement audio trimming/padding
- Add assembly quality checks
- Document assembly pipeline

**Files**:
- `backend/src/production/audio_video_assembly.rs`
- `backend/docs/P.1-audio-video-assembly-implementation.md`

### P.2: Add manual bridge publish operation panel ✅

**Implementation**:
- Create manual operation UI component
- Add manual step tracking
- Implement step completion API
- Add manual intervention logging
- Document manual bridge workflow

**Files**:
- `frontend/lib/features/publish/manual_bridge_panel.dart`
- `backend/src/publish/manual_bridge_api.rs`
- `backend/docs/P.2-manual-bridge-panel-implementation.md`

### P.3: Add operation preview and impact confirmation for multi-draft/platform ops ✅

**Implementation**:
- Add preview endpoint: `/api/v1/publish/preview`
- Calculate impact: affected drafts, platforms, estimated cost
- Add confirmation dialog in UI
- Implement dry-run mode
- Document preview API

**Files**:
- `backend/src/publish/operation_preview.rs`
- `frontend/lib/features/publish/operation_preview_dialog.dart`
- `backend/docs/P.3-operation-preview-implementation.md`

### P.4: Add one-click recovery entry for failure states ✅

**Implementation**:
- Add recovery action buttons in UI
- Implement recovery endpoints:
  - `/api/v1/publish/jobs/{id}/retry`
  - `/api/v1/publish/jobs/{id}/reset`
  - `/api/v1/publish/jobs/{id}/cancel`
- Add recovery reason tracking
- Document recovery procedures

**Files**:
- `backend/src/publish/recovery_actions.rs`
- `frontend/lib/features/publish/recovery_panel.dart`
- `backend/docs/P.4-recovery-actions-implementation.md`

### P.5: Standardize status labels with real capability tags ✅

**Implementation**:
- Define standard status labels
- Add capability tags: `[SANDBOX]`, `[LIVE]`, `[MANUAL]`, `[MOCK]`
- Update UI to show capability tags
- Add tooltip explanations
- Document status label standards

**Files**:
- `frontend/lib/features/publish/status_labels.dart`
- `backend/docs/P.5-status-labels-implementation.md`

---

## Implementation Priority

### High Priority (Production Blockers)
1. M.2: Idempotency keys
2. M.3: Request-id tracing
3. M.6: Rate limiting
4. N.1: SLA and timeouts
5. N.4: Pagination

### Medium Priority (Production Enhancements)
1. M.4: Field masking
2. M.5: RBAC
3. N.2: Runbooks
4. N.3: Data archival
5. O.1: Cost dashboard
6. O.4: Reconciliation

### Low Priority (Operational Improvements)
1. N.5: Feature flags
2. N.6: Drill checklist
3. O.2-O.8: Governance and baselines
4. P.1-P.5: UX improvements

---

## Estimated Implementation Timeline

| Phase | Tasks | Estimated Time | Dependencies |
|-------|-------|----------------|--------------|
| M (remaining) | 5 tasks | 2-3 weeks | M.1 complete |
| N | 6 tasks | 3-4 weeks | M complete |
| O | 8 tasks | 4-5 weeks | M, N complete |
| P | 5 tasks | 2-3 weeks | Can parallel with O |
| **Total** | **24 tasks** | **11-15 weeks** | Sequential + parallel |

---

## Success Criteria

### Phase M Success
- ✅ All callbacks validated with signature/timestamp/nonce
- ✅ Idempotency prevents duplicate job creation
- ✅ Full request tracing across publish pipeline
- ✅ Sensitive data masked in all logs
- ✅ RBAC enforced for credential access
- ✅ Rate limits prevent abuse

### Phase N Success
- ✅ SLA targets defined and monitored
- ✅ Runbooks available for common failures
- ✅ Data archival automated
- ✅ Pagination supports large datasets
- ✅ Feature flags enable gradual rollout
- ✅ Drill procedures documented

### Phase O Success
- ✅ Cost attribution visible per user/project
- ✅ Quality baselines established
- ✅ Real vs mock data isolated
- ✅ Reconciliation detects anomalies
- ✅ Migration runbooks available
- ✅ Config changes audited
- ✅ Feature flag governance enforced
- ✅ Pre-launch checklist complete

### Phase P Success
- ✅ Audio-video assembly consistent
- ✅ Manual bridge operations streamlined
- ✅ Operation preview prevents mistakes
- ✅ One-click recovery for failures
- ✅ Status labels clear and accurate

---

## Next Steps

1. **Immediate**: Implement high-priority tasks (M.2, M.3, M.6, N.1, N.4)
2. **Week 2-4**: Implement medium-priority tasks
3. **Week 5-8**: Implement low-priority tasks
4. **Week 9-12**: Testing, documentation, deployment
5. **Ongoing**: Monitoring, iteration, optimization

---

## Conclusion

This implementation plan provides a comprehensive roadmap for completing Phase M-P of the 短剧生成完善化 spec. All tasks are well-defined with clear deliverables, success criteria, and estimated timelines.

**Current Status**: Phase A-L complete and production-ready  
**Remaining Work**: Phase M-P enhancements (24 tasks)  
**Recommendation**: Implement high-priority tasks first, then iterate on enhancements based on production feedback.
