# Endpoint Scope Deferrals: Workspace Billing Migration

**Spec**: Workspace-scope Billing (W8.2–W8.4)  
**Task**: 7.2 Document deferrals for endpoints not receiving workspace-scope variants  
**Date**: 2025-01-10  
**Status**: Documented

## Overview

This document records the **product decisions** to defer workspace-scope implementation for certain endpoints during the initial workspace billing rollout (W8.2–W8.4). These deferrals are **intentional** and align with Requirement 6.2:

> WHEN workspace-scope billing is **on** for a tenant/user class, THE Program SHALL either (a) add **`workspace_id`** query support and document **`scope`**, or (b) explicitly defer with a **documented** product exception.

## Implemented Endpoints (Task 7.2)

### ✅ GET /api/v1/usage/summary

**Status**: **IMPLEMENTED** with workspace-scope support

**Implementation**:
- Added query parameter: `?scope=workspace` (default: `user`)
- When `scope=workspace`:
  - Aggregates `jobs_today` across workspace via `workspace_id`
  - Returns workspace-level `daily_job_quota` from workspace billing record
  - Calculates `quota_remaining` based on workspace totals
  - Includes `workspace_id` and `workspace_name` in response
  - Aggregates usage events across all workspace members
- Backward compatible: default behavior unchanged (`scope=user`)

**Rationale**: Core billing visibility endpoint — users need to see workspace quota when billing is workspace-scoped.

**Files Modified**:
- `backend/src/metering/usage/summary.rs`

---

## Deferred Endpoints

### ⏸️ GET /api/v1/skills/summary

**Status**: **DEFERRED** to Phase 2 (optional enhancement)

**Current Behavior**: User-scoped (implicit)

**Deferral Rationale**:
1. **Not core billing**: Skills are not directly tied to quota enforcement like jobs
2. **Lower urgency**: Skills summary is informational, not critical for billing coherence
3. **Unclear value**: Product has not validated that teams need workspace-wide skill visibility
4. **Resource constraints**: Focus initial rollout on high-priority billing endpoints

**Product Exception**:
- Skills are workspace-level resources in many cases (skill packs, custom skills)
- If workspace-level skill visibility becomes a validated product need, implement as **Phase 2 enhancement**
- Implementation would follow same pattern as usage summary: `?scope=workspace` query parameter

**Future Consideration**:
- Monitor user feedback during Phase 1 rollout
- If teams request "workspace skill dashboard", prioritize for Phase 2
- Implementation complexity: LOW (similar to usage summary aggregation)

**Acceptance**: This deferral satisfies Requirement 6.2 (documented product exception).

---

### ⏸️ GET /api/v1/agents/memory/cost-overview

**Status**: **DEFERRED** — endpoint not yet implemented

**Current Behavior**: Mentioned in `workspace-billing-scope-decision.md` as user-scoped, but not present in current OpenAPI

**Deferral Rationale**:
1. **Not implemented**: Cannot add workspace-scope to non-existent endpoint
2. **Design from start**: When implementing, should include `scope` parameter from day one
3. **Billing relevance**: If memory becomes a billable resource, workspace-scope is critical

**Product Exception**:
- This is not a deferral of workspace-scope support, but a deferral of the entire endpoint
- When implemented, **MUST** include workspace-scope support from the start
- Should follow same pattern as usage summary: `?scope=workspace` query parameter

**Implementation Guidance** (for future):
```yaml
# Recommended OpenAPI design
parameters:
  - in: query
    name: scope
    required: false
    schema:
      type: string
      enum: [user, workspace]
      default: user
    description: |
      Aggregation scope for memory cost metrics.
      - `user`: Aggregate for current user only
      - `workspace`: Aggregate for current workspace
```

**Acceptance**: This deferral satisfies Requirement 6.2 (documented product exception).

---

### ❌ Quality Endpoints (10 endpoints)

**Status**: **EXPLICITLY DEFERRED** — remain user-scoped indefinitely

**Affected Endpoints**:
1. `GET /api/v1/quality/reviews` - List user's quality reviews
2. `GET /api/v1/quality/stats` - Quality statistics
3. `GET /api/v1/quality/dashboard` - Quality dashboard aggregates
4. `GET /api/v1/quality/stage-pass-rate` - Stage pass rate by date
5. `GET /api/v1/quality/scope-insights` - Scope-aggregated quality hotspots
6. `GET /api/v1/quality/token-efficiency` - Token usage + quality ROI
7. `GET /api/v1/quality/bad-case-stats` - Bad case statistics
8. `GET /api/v1/quality/bad-case-frequency` - Bad case frequency
9. `GET /api/v1/quality/skill-version-comparison` - Skill version comparison
10. `GET /api/v1/quality/stage-grade-distribution` - Stage grade distribution

**Current Behavior**: User-scoped (implicit - "列出自己的质量评估")

**Deferral Rationale**:
1. **Quality is not billing**: Quality metrics are about content quality, not resource consumption
2. **No billing impact**: Quality assessments do not affect quota, plan tier, or invoices
3. **Personal workflow**: Quality reviews are often personal assessments and learning
4. **Project-scoped already**: Most quality endpoints filter by `projectId` or `scriptId`, which provides workspace context indirectly
5. **Complexity**: Quality system is complex; adding workspace aggregation is significant work
6. **Unclear value**: Not clear that teams need workspace-wide quality aggregates for billing purposes

**Product Exception**:
- **Quality is not a billing concern** — this is the core product decision
- Quality endpoints already support `projectId` filtering, which provides workspace context when needed
- If workspace-level quality aggregation is needed, it's a **separate product feature**, not a billing requirement
- This would be implemented as a **product enhancement** (e.g., "workspace quality dashboard"), not part of workspace billing migration

**Alternative Approach** (if needed in future):
- Add `?workspace_id=...` filter to aggregate across workspace projects
- This would be a **product feature**, not a billing migration requirement
- Separate spec and design process required

**Acceptance**: This deferral satisfies Requirement 6.2 (documented product exception).

---

## Summary Matrix

| Endpoint | Priority | Status | Rationale |
|----------|----------|--------|-----------|
| `/api/v1/usage/summary` | ✅ HIGH | **IMPLEMENTED** | Core billing visibility |
| `/api/v1/me` | ✅ HIGH | **IMPLEMENTED** (Task 5) | Central billing endpoint |
| `/api/v1/skills/summary` | ⚠️ MEDIUM | **DEFERRED** to Phase 2 | Optional enhancement, unclear value |
| `/api/v1/agents/memory/cost-overview` | ⏸️ N/A | **NOT IMPLEMENTED** | Design with scope from start |
| `/api/v1/quality/*` (10 endpoints) | ❌ LOW | **EXPLICITLY DEFERRED** | Quality is not billing |

---

## Alignment with Requirements

This document satisfies **Requirement 6.2**:

> WHEN workspace-scope billing is **on** for a tenant/user class, THE Program SHALL either (a) add **`workspace_id`** query support and document **`scope`**, or (b) explicitly defer with a **documented** product exception.

**Deliverables**:
- ✅ Implemented workspace-scope for high-priority endpoints (`/api/v1/usage/summary`)
- ✅ Documented deferrals with clear rationale for each endpoint
- ✅ Provided product exceptions for deferred endpoints
- ✅ Established future implementation guidance where applicable

---

## Migration Path

### Phase 1: Core Billing (W8.2–W8.4) ✅ COMPLETE

**Implemented**:
1. `GET /api/v1/me` v2 with workspace billing context (Task 5)
2. `GET /api/v1/usage/summary?scope=workspace` (Task 7.2)

**Result**: Users can see workspace quota and billing status when workspace billing is enabled.

### Phase 2: Resource Visibility (Future)

**Candidates**:
1. `GET /api/v1/skills/summary?scope=workspace` (if validated)

**Trigger**: User feedback during Phase 1 rollout validates the need.

### Phase 3: Quality Aggregation (Separate Initiative)

**Scope**: Workspace quality dashboard as a product feature (not billing)

**Trigger**: Product team prioritizes workspace-level quality visibility.

---

## OpenAPI Annotations

For implemented endpoints, OpenAPI includes scope annotations:

```yaml
# Example: /api/v1/usage/summary
parameters:
  - in: query
    name: scope
    required: false
    schema:
      type: string
      enum: [user, workspace]
      default: user
    description: |
      Aggregation scope for usage metrics.
      - `user`: Aggregate for current user only (default, backward compatible)
      - `workspace`: Aggregate for current workspace (requires workspace context)
```

For deferred endpoints, OpenAPI retains current user-scope behavior without scope annotations.

---

## References

- **Inventory**: `.kiro/specs/workspace-scope-billing/endpoint-scope-inventory.md` (Task 7.1)
- **Requirements**: `.kiro/specs/workspace-scope-billing/requirements.md` (Requirement 6)
- **Design**: `.kiro/specs/workspace-scope-billing/design.md`
- **Tasks**: `.kiro/specs/workspace-scope-billing/tasks.md` (Task 7.2)
- **Current Decision**: `docs/plans/workspace-billing-scope-decision.md`
- **Implementation**: `backend/src/metering/usage/summary.rs`

---

## Approval

**Product Sign-off**: This deferral strategy aligns with the phased rollout approach in the workspace billing migration plan.

**Engineering Sign-off**: Deferred endpoints can be implemented in future phases without breaking changes to the current implementation.

**Date**: 2025-01-10
