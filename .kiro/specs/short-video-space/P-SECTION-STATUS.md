# P Section Implementation Status

## Overview
This document tracks the production-grade feature closure tasks (P1-P12) for the short-video-space spec.

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

---

## Remaining Tasks (P3-P12)

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

---

### 🔴 P5: 低表现预警升级为平台差异阈值（项目级覆盖）

**Requirements**:
- Extend threshold configuration to support per-platform overrides
- Update alert logic to use platform-specific thresholds
- Add UI for configuring platform-specific thresholds
- Migrate existing project-level thresholds

---

### 🔴 P6: 预警后进入运营闭环

**Requirements**:
- Add "create rewrite task" action from alert
- Add "reschedule" action from alert
- Add "republish" action from alert
- Link new tasks back to original publish draft/job
- Add UI for these actions in the alert panel

---

### 🔴 P7: 导出质量门禁从占位升级为 off/warn/block

**Requirements**:
- Implement gate evaluation logic with three modes
- Add `block` mode that prevents export job from queuing
- Return structured blocking reasons
- Add rework entry points in blocking response
- Add configuration UI for gate mode

---

### 🔴 P8: 发布面板支持多草稿主流程

**Requirements**:
- Add draft selector UI component
- Implement batch operations (schedule, publish, archive)
- Add batch blocking summary view
- Update default flow to support multiple drafts
- Add draft comparison view

---

### 🔴 P9: 自动化模式按平台真实能力生效

**Requirements**:
- Add UI for selecting automation_mode per platform
- Display platform capabilities in UI
- Add backend validation of automation_mode against platform capabilities
- Update adapter routing to respect selected mode

---

### 🔴 P10: 发布状态机补全生产语义

**Requirements**:
- Add new states: `manual_pending`, `callback_timeout`, `compensating`
- Implement timeout detection and compensation logic
- Add state transition tests
- Update migration to support new states
- Update UI to display new states

---

### 🔴 P11: 发布/表现数据看板口径统一

**Requirements**:
- Add delivery_mode indicator in Space overview
- Add delivery_mode indicator in task center
- Distinguish "real publish" vs "sandbox publish" in metrics
- Distinguish "real metrics" vs "mock metrics" in performance data
- Add filtering by delivery_mode in dashboards

---

### 🔴 P12: 生产级验收（九平台矩阵按真实能力重新验收全绿）

**Requirements**:
- For each of 9 platforms, demonstrate at least one successful:
  - `live` delivery (if full_auto supported), OR
  - `manual_bridge` delivery (if manual_assisted)
- Document successful sample for each platform
- Update acceptance test suite
- Create platform capability matrix showing real status

---

## Recommendations

### Immediate Actions Needed

1. **Platform API Access**: Obtain API credentials for all 9 platforms
   - Developer accounts
   - API keys / OAuth credentials
   - Sandbox/test environments where available

2. **Prioritization**: Based on requirements, suggested order:
   - **Phase 1**: P7, P8, P9, P10, P11 (can be done without real platform APIs)
   - **Phase 2**: P3 (start with 1-2 platforms as proof of concept)
   - **Phase 3**: P4, P5, P6 (depends on P3)
   - **Phase 4**: P12 (final validation)

3. **Technical Decisions**:
   - Choose HTTP client library (reqwest is already in use)
   - Decide on OAuth library (oauth2 crate recommended)
   - Design credential storage strategy (encrypted in database vs external secret manager)
   - Define platform adapter interface contract

### Next Steps

**Option A: Complete P7-P11 first (no platform APIs needed)**
- These tasks improve the UI and workflow
- Can be tested with sandbox mode
- Provides value even before real platform integration

**Option B: Start P3 with one platform as POC**
- Choose easiest platform (e.g., YouTube Shorts with OAuth2)
- Implement end-to-end for one platform
- Use as template for other platforms

**Option C: Parallel approach**
- One developer on P7-P11 (UI/workflow)
- Another developer on P3 (platform integration)

## Questions for Product/Engineering

1. Do we have API access for all 9 platforms?
2. What is the priority order for platform integration?
3. Should we use a secrets management service (AWS Secrets Manager, HashiCorp Vault) or store encrypted credentials in the database?
4. What is the acceptable timeline for completing P3-P12?
5. Do we need to support platform-specific features (e.g., TikTok duets, YouTube Shorts remixing)?

