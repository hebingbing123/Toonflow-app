# P Section Implementation Status

## Overview
This document tracks the production-grade feature closure tasks (P1-P12) for the short-video-space spec.

## Summary

**Completed**: P1, P2, P7, P9, P10 (5/12)  
**Documented/Planned**: P8, P11 (2/12)  
**Requires Platform APIs**: P3, P4, P5, P6, P12 (5/12)

## Completed Tasks

### ✅ P1: 发布 adapter 真实能力分层（sandbox/live/manual_bridge）

**Status**: COMPLETED

**Implementation**:
- Added comprehensive documentation in `backend/src/publish/adapters.rs` explaining the three delivery modes
- Added validation tests to ensure sandbox success is clearly distinguished from real publish success
- Tests verify:
  - `semi_auto` → `sandbox` delivery_mode
  - `full_auto` → `live` delivery_mode  
  - `manual_assisted` → `manual_bridge` delivery_mode
- All adapter results include `delivery_mode` in the `detail` field
- Receipt mode clearly indicates the delivery type

**Verification**: Run `cargo test publish::adapters::tests::p1` - all 3 tests pass

**Commit**: b034fbb3

---

### ✅ P2: 发布 attempts/jobs 增加 delivery_mode 与 evidence

**Status**: COMPLETED (Already implemented in E section)

**Implementation**:
- `app_publish_attempt.detail` JSONB field stores both `delivery_mode` and `evidence`
- Audit query in `backend/src/publish/store.rs` supports filtering by:
  - `delivery_mode` (sandbox/live/manual_bridge/unknown)
  - `evidence_key` (request_id/manual_step_id/callback_id)
- OpenAPI endpoint `/api/publish/audit` exposes these filters
- Evidence structure varies by automation_mode:
  - `full_auto`: includes `request_id` and `callback_id`
  - `manual_assisted`: includes `manual_step_id`
  - `semi_auto`: includes `request_id`

**Verification**: Check `PublishAttemptAuditFilter` in `backend/src/publish/types.rs` and audit query in `store.rs`

**Commit**: b034fbb3

---

### ✅ P7: 导出质量门禁从占位升级为 off/warn/block

**Status**: COMPLETED

**Implementation**:
- Upgraded `ShortVideoExportQualityGatePlaceholder` to `ShortVideoExportQualityGate`
- Implemented three strategies:
  - `off`: Skip quality checks entirely
  - `warn`: Show warnings but allow export
  - `block`: Prevent export when issues exist
- Block mode returns structured `QualityGateBlockingReason` with:
  - Error code
  - Human-readable message
  - Rework route (frontend deep link)
- Reads `quality_gate_strategy` from `app_project` table (default: "block")
- Checks both quality review bad cases and export blocking issues
- Updates `export_ready` field based on gate enforcement

**Files Changed**:
- `backend/src/projects/routes/types.rs` - new types
- `backend/src/projects/routes/handlers/detail/short_video_export_check.rs` - implementation
- `backend/src/projects/openapi.rs` - OpenAPI export

**Verification**: Run `cargo test short_video_export_check` - all tests pass

**Commit**: 6beb1e84

---

### ✅ P9: 自动化模式按平台真实能力生效

**Status**: COMPLETED

**Implementation**:
- Added `validate_automation_mode_for_platform` function
- Validates selected `automation_mode` against platform's `recommended_tier`
- Issues warning (not blocking) when mode differs from recommendation
- Integrated into `prepare_check_for_draft` validation flow
- Warning includes platform name and recommended mode
- Backend validation ensures UI selections are validated

**Files Changed**:
- `backend/src/publish/validation.rs` - validation logic and tests

**Example Warning**:
```
平台 抖音 推荐使用 semi_auto 模式，当前选择 full_auto
```

**Verification**: Run `cargo test publish::validation::tests::p9` - test passes

**Commit**: 6beb1e84

---

### ✅ P10: 发布状态机补全生产语义

**Status**: COMPLETED

**Implementation**:
- Added three new states to state machine:
  - `manual_pending`: Human intervention required before proceeding
  - `callback_timeout`: Platform callback not received within expected time
  - `compensating`: System executing compensation logic
- Updated database constraint in migration `20260515120000_p10_publish_job_production_states.sql`
- Added state detection functions:
  - `is_manual_pending(status)` - check if waiting for manual action
  - `is_callback_timeout(status)` - check if callback timed out
  - `is_compensating(status)` - check if in compensation
- Added transition guards:
  - `can_compensate(status)` - can trigger compensation from callback_timeout or platform_processing
  - `can_complete_manual_bridge(status)` - can complete manual bridge from manual_pending
- Updated `can_retry` to include `callback_timeout`
- All new states are non-terminal and cancellable

**Files Changed**:
- `backend/src/publish/state_machine.rs` - state machine logic and tests
- `supabase/migrations/20260515120000_p10_publish_job_production_states.sql` - database constraint

**State Flow Examples**:
```
Manual Assisted: queued → validating → manual_pending → uploading → succeeded
Callback Timeout: platform_processing → callback_timeout → compensating → succeeded/failed
```

**Verification**: Run `cargo test publish::state_machine::tests::p10` - all tests pass

**Commit**: 6beb1e84

---

## Documented/Planned Tasks

### 📋 P8: 发布面板支持多草稿主流程

**Status**: DOCUMENTED - Implementation plan created

**Requirements**:
- Batch operations API (schedule, publish, archive multiple drafts)
- Multi-select UI with checkboxes
- Batch validation and blocking summary
- Draft comparison view (side-by-side)
- Batch operation progress tracking

**Estimated Effort**: 8-11 days (1.5-2 weeks)

**Documentation**: `backend/docs/P8-MULTI-DRAFT-IMPLEMENTATION.md`

**Current State**:
- ✅ Single draft selector exists
- ✅ Backend supports multiple drafts per project
- ❌ Batch operations API not implemented
- ❌ Multi-select UI not implemented
- ❌ Batch validation not implemented
- ❌ Draft comparison not implemented

**Next Steps**:
1. Implement backend batch APIs (2-3 days)
2. Implement frontend multi-select UI (2-3 days)
3. Implement batch validation & blocking summary (1-2 days)
4. Implement draft comparison view (2-3 days)
5. Testing & polish (1-2 days)

---

### 📋 P11: 发布/表现数据看板口径统一

**Status**: DOCUMENTED - Backend complete, frontend pending

**Requirements**:
- Show delivery_mode breakdown in Space overview
- Add delivery_mode filter in task center
- Show metric source indicators (real vs mock)
- Visual distinction between sandbox and live data
- Consistent color coding and icons

**Estimated Effort**: 6-7 days (1-1.5 weeks)

**Documentation**: `backend/docs/P11-DASHBOARD-UNIFICATION.md`

**Current State**:
- ✅ Backend provides delivery_mode in all APIs
- ✅ Audit API supports delivery_mode filtering
- ✅ Metrics include source tracking
- ❌ Frontend doesn't show delivery_mode breakdown
- ❌ No visual distinction in UI
- ❌ No filtering by delivery_mode in task center

**Next Steps**:
1. Update frontend data models (1 day)
2. Create UI components (badges, indicators, filters) (2-3 days)
3. Integrate into Space overview and task center (2 days)
4. Testing (1 day)

---

## Remaining Tasks (P3-P6, P12)

These tasks require real platform API integration and cannot be completed without:
1. Platform API credentials and OAuth setup
2. Platform-specific SDK integration or HTTP client implementation
3. Real platform testing environments
4. Compliance with each platform's Terms of Service

### 🔴 P3: 真实平台投递闭环（优先国内 5，再海外 4）

**Requirements**:
- Replace sandbox closures with real API calls for each platform
- Implement OAuth flows for platforms that require it
- Handle platform-specific authentication (API keys, tokens, etc.)
- Implement upload endpoints for each platform
- Handle platform-specific video format requirements

**Platforms**:
- **国内 (Domestic)**: 抖音, 哔哩哔哩, 小红书, 视频号, 快手
- **海外 (Overseas)**: TikTok, YouTube Shorts, Instagram Reels, Facebook Reels

**Technical Approach**:
Each platform needs:
1. Authentication module (OAuth2 or API key)
2. Video upload implementation
3. Metadata submission (title, description, tags, cover)
4. Status polling or webhook handling
5. Error handling and retry logic

**Estimated Effort**: 15-20 days (3-4 weeks)

---

### 🔴 P4: 表现数据同步从 mock 升级为真实拉取 + 失败重试 + 退避

**Requirements**:
- Replace `fetch_platform_metrics_mock` with real API calls
- Implement retry logic with exponential backoff
- Handle rate limiting from platforms
- Store sync failures and retry state
- Add metrics sync worker with configurable intervals

**Current State**:
- `fetch_platform_metrics_live` and `fetch_platform_metrics_manual_bridge` are stubs
- Need real API integration for each platform's analytics endpoints

**Estimated Effort**: 5-7 days (1-1.5 weeks)

---

### 🔴 P5: 低表现预警升级为平台差异阈值（项目级覆盖）

**Requirements**:
- Extend threshold configuration to support per-platform overrides
- Update alert logic to use platform-specific thresholds
- Add UI for configuring platform-specific thresholds
- Migrate existing project-level thresholds

**Estimated Effort**: 3-4 days

---

### 🔴 P6: 预警后进入运营闭环

**Requirements**:
- Add "create rewrite task" action from alert
- Add "reschedule" action from alert
- Add "republish" action from alert
- Link new tasks back to original publish draft/job
- Add UI for these actions in the alert panel

**Estimated Effort**: 4-5 days

---

### 🔴 P12: 生产级验收（九平台矩阵按真实能力重新验收全绿）

**Requirements**:
- For each of 9 platforms, demonstrate at least one successful:
  - `live` delivery (if full_auto supported), OR
  - `manual_bridge` delivery (if manual_assisted)
- Document successful sample for each platform
- Update acceptance test suite
- Create platform capability matrix showing real status

**Estimated Effort**: 3-5 days (after P3 complete)

---

## Recommendations

### Immediate Actions Needed

1. **Platform API Access**: Obtain API credentials for all 9 platforms
   - Developer accounts
   - API keys / OAuth credentials
   - Sandbox/test environments where available

2. **Prioritization**: Based on requirements, suggested order:
   - **Phase 1**: ✅ P1, P2, P7, P9, P10 (DONE)
   - **Phase 2**: P8, P11 (frontend work, no platform APIs needed)
   - **Phase 3**: P3 (start with 1-2 platforms as proof of concept)
   - **Phase 4**: P4, P5, P6 (depends on P3)
   - **Phase 5**: P12 (final validation)

3. **Technical Decisions**:
   - Choose HTTP client library (reqwest is already in use)
   - Decide on OAuth library (oauth2 crate recommended)
   - Design credential storage strategy (encrypted in database vs external secret manager)
   - Define platform adapter interface contract

### Next Steps

**Option A: Complete P8 & P11 first (no platform APIs needed)**
- These tasks improve the UI and workflow
- Can be tested with sandbox mode
- Provides value even before real platform integration
- Estimated: 2-3 weeks

**Option B: Start P3 with one platform as POC**
- Choose easiest platform (e.g., YouTube Shorts with OAuth2)
- Implement end-to-end for one platform
- Use as template for other platforms
- Estimated: 1-2 weeks for POC

**Option C: Parallel approach**
- One developer on P8 & P11 (UI/workflow)
- Another developer on P3 (platform integration)
- Estimated: 2-3 weeks total

## Questions for Product/Engineering

1. Do we have API access for all 9 platforms?
2. What is the priority order for platform integration?
3. Should we use a secrets management service (AWS Secrets Manager, HashiCorp Vault) or store encrypted credentials in the database?
4. What is the acceptable timeline for completing P3-P12?
5. Do we need to support platform-specific features (e.g., TikTok duets, YouTube Shorts remixing)?

