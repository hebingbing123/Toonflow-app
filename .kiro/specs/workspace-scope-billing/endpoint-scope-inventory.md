# Endpoint Scope Inventory: User-Scope to Workspace-Scope Analysis

**Spec**: Workspace-scope Billing (W8.2–W8.4)  
**Task**: 7.1 Inventory endpoints with `scope=user` in OpenAPI; product decision per endpoint  
**Date**: 2025-01-10  
**Status**: Analysis Complete

## Executive Summary

This document inventories all endpoints currently operating at **user-scope** and provides product recommendations for which endpoints should have **workspace-scope** variants when workspace billing is enabled.

**Key Findings:**
- **5 primary user-scoped endpoints** identified
- **3 high-priority** candidates for workspace-scope variants
- **2 endpoints** recommended to remain user-only
- All endpoints currently align with the W8.1 decision to maintain user-scope billing

## Methodology

1. Analyzed `scripts/fixtures/openapi_baseline.yaml` for explicit `scope` annotations
2. Cross-referenced with `docs/plans/workspace-billing-scope-decision.md`
3. Evaluated each endpoint's semantic fit for workspace-scope billing
4. Considered product coherence and user experience implications

---

## Endpoint Inventory

### 1. GET /api/v1/usage/summary

**Current Scope**: `user` (explicitly annotated)

**Description**: Returns usage metrics including:
- `daily_job_quota`: Effective daily job cap
- `jobs_today`: Jobs created today (UTC day)
- `quota_remaining`: Remaining jobs allowed today
- `events_last_24h`, `events_last_7d`: Event counts
- `event_counts_last_7d`: Per-event-type breakdown

**OpenAPI Reference**:
```yaml
UsageSummaryResponse:
  properties:
    scope:
      $ref: '#/components/schemas/UsageSummaryScope'
      description: Aggregation scope for this response. W4.6 currently locks this endpoint to `user`.
UsageSummaryScope:
  enum:
  - user
```

**Product Decision**: ✅ **HIGH PRIORITY - Add workspace-scope variant**

**Rationale**:
- **Core billing visibility**: This is the primary endpoint users check to understand their quota status
- **Team context**: In workspace billing, team members need to see shared workspace quota, not individual limits
- **Semantic fit**: Usage aggregation naturally maps to workspace when billing is workspace-scoped
- **User confusion risk**: If billing is workspace-scoped but usage shows user-scope, users will be confused about which quota applies

**Recommendation**:
- Add query parameter: `?scope=workspace` (default remains `user` during transition)
- When `scope=workspace`:
  - Aggregate `jobs_today` across all workspace members
  - Return workspace-level `daily_job_quota` from workspace billing record
  - Calculate `quota_remaining` based on workspace totals
- Response should include `workspace_id` when scope is workspace
- Consider adding `workspace_name` for UI display

**Migration Path**:
1. Phase 1: Add `?scope=workspace` support (opt-in)
2. Phase 2: When workspace billing is default, make `scope=workspace` default for workspace contexts
3. Phase 3: Deprecate user-scope for workspace members (optional, based on product decision)

---

### 2. GET /api/v1/me

**Current Scope**: `user` (implicit - returns user profile)

**Description**: Returns current user session and billing profile:
- `sub`: User ID from JWT
- `email`: User email
- `plan_tier`: From `app_user_profile`
- `billing_currency`, `billing_provider`: Billing details
- `daily_job_quota`: User's daily job cap
- `jobs_today`: User's jobs created today
- `subscription_status`, `subscription_current_period_end_at`: Subscription details
- `current_workspace`: Current workspace context (already present)
- `memory_config`: User memory configuration

**OpenAPI Reference**:
```yaml
/api/v1/me:
  get:
    description: Always returns JWT `sub` (and `email` when present in claims). 
                 When DATABASE_URL is set, loads plan_tier / billing fields from 
                 app_user_profile (defaults to plan_tier: free when no row).
```

**Product Decision**: ✅ **HIGH PRIORITY - Add v2 with workspace billing context**

**Rationale**:
- **Central billing endpoint**: This is where clients get all billing-related information
- **Already versioned in design**: Design doc (Task 5) already specifies v1/v2 approach
- **Backward compatibility critical**: Many clients depend on this endpoint's current shape
- **Workspace context already present**: `current_workspace` field shows the pattern

**Recommendation**:
- Implement **v2** as specified in design.md (Task 5.1-5.4)
- v2 structure:
  ```json
  {
    "billing_scope": "workspace",
    "user": {
      "id": "...",
      "email": "...",
      "plan_tier": "pro",  // legacy, for compatibility
      "jobs_today": 0      // user's personal jobs, if tracked
    },
    "current_workspace_billing": {
      "workspace_id": "...",
      "workspace_type": "enterprise",
      "plan_tier": "enterprise",
      "daily_job_quota": 1000,
      "jobs_today": 42,
      "quota_remaining": 958,
      "subscription_status": "active",
      "subscription_current_period_end_at": "2025-02-01T00:00:00Z"
    }
  }
  ```
- v1 remains unchanged (default)
- v2 accessed via `?v=2` or `Accept` header negotiation

**Migration Path**:
1. Phase 1: Implement v2 (opt-in via query param or header)
2. Phase 2: Update Flutter client to use v2 when workspace billing is enabled
3. Phase 3: Make v2 default for new clients (v1 remains available for legacy)
4. Phase 4: Optional deprecation of v1 after migration window

---

### 3. GET /api/v1/skills/summary

**Current Scope**: `user` (implicit - per workspace-billing-scope-decision.md)

**Description**: Returns aggregate skill statistics:
- Markdown skill count
- Total bytes of skill content
- Presumably scoped to user's accessible skills

**OpenAPI Reference**:
```yaml
/api/v1/skills/summary:
  get:
    operationId: getSkillsSummaryV1
    summary: Aggregate Markdown skill count and total bytes
```

**Product Decision**: ⚠️ **MEDIUM PRIORITY - Consider workspace-scope variant**

**Rationale**:
- **Shared resource**: Skills are often workspace-level resources (skill packs, custom skills)
- **Cost attribution**: If skills consume storage/memory, workspace billing should track this
- **Team visibility**: Team members may want to see workspace-wide skill usage
- **Lower urgency**: Skills are not directly tied to quota enforcement like jobs

**Recommendation**:
- Add query parameter: `?scope=workspace` (optional)
- When `scope=workspace`:
  - Aggregate skills accessible to the workspace
  - Include workspace-shared skill packs
  - Return workspace-level totals
- Default remains `user` for backward compatibility

**Migration Path**:
1. Phase 1: Add `?scope=workspace` support (opt-in)
2. Phase 2: Evaluate usage patterns - do teams actually need this?
3. Phase 3: If valuable, promote workspace-scope as default for workspace contexts

**Alternative**: Defer this endpoint until product validates the need for workspace-level skill visibility.

---

### 4. GET /api/v1/agents/memory/cost-overview

**Current Scope**: `user` (per workspace-billing-scope-decision.md)

**Description**: Memory/RAG cost overview for the user

**Status**: ⚠️ **NOT FOUND IN CURRENT OPENAPI**

**Analysis**:
- Mentioned in `workspace-billing-scope-decision.md` as user-scoped
- Not present in `openapi_baseline.yaml` (may be planned or deprecated)
- If implemented, would show memory storage costs

**Product Decision**: ⏸️ **DEFERRED - Endpoint not yet implemented**

**Rationale**:
- Cannot analyze non-existent endpoint
- If/when implemented, should follow same pattern as usage/summary

**Recommendation**:
- When implementing this endpoint, design it with `scope` parameter from the start
- Support both `user` and `workspace` scope
- Workspace scope would aggregate memory costs across all workspace members
- Include in workspace billing when memory becomes a billable resource

---

### 5. Quality Aggregate Endpoints

**Current Scope**: `user` (implicit - "列出自己的质量评估")

**Endpoints**:
- `GET /api/v1/quality/reviews` - List user's quality reviews
- `GET /api/v1/quality/stats` - Quality statistics
- `GET /api/v1/quality/dashboard` - Quality dashboard aggregates
- `GET /api/v1/quality/stage-pass-rate` - Stage pass rate by date
- `GET /api/v1/quality/scope-insights` - Scope-aggregated quality hotspots
- `GET /api/v1/quality/token-efficiency` - Token usage + quality ROI
- `GET /api/v1/quality/bad-case-stats` - Bad case statistics
- `GET /api/v1/quality/bad-case-frequency` - Bad case frequency
- `GET /api/v1/quality/skill-version-comparison` - Skill version comparison
- `GET /api/v1/quality/stage-grade-distribution` - Stage grade distribution

**OpenAPI Reference**:
```yaml
/api/v1/quality/reviews:
  get:
    summary: GET /api/v1/quality/reviews - 列出自己的质量评估
    # Filters by projectId, scriptId, but implicitly user-scoped
```

**Product Decision**: ❌ **LOW PRIORITY - Remain user-scoped initially**

**Rationale**:
- **Quality is not billing**: Quality metrics are about content quality, not resource consumption
- **Personal workflow**: Quality reviews are often personal assessments and learning
- **Project-scoped already**: Most quality endpoints filter by `projectId` or `scriptId`, which provides workspace context indirectly
- **Complexity**: Quality system is complex; adding workspace aggregation is significant work
- **Unclear value**: Not clear that teams need workspace-wide quality aggregates for billing purposes

**Recommendation**:
- **Keep user-scoped** for initial workspace billing rollout
- Quality endpoints already support `projectId` filtering, which provides workspace context
- If workspace-level quality aggregation is needed, it's a **separate product feature**, not a billing requirement
- Mark as **Requirement 6 optional phase** - explicitly defer with documented product exception

**Future Consideration**:
- If teams request "workspace quality dashboard" as a product feature (not billing), implement as separate initiative
- Could add `?workspace_id=...` filter to aggregate across workspace projects
- This would be a **product enhancement**, not a billing migration requirement

---

## Summary Matrix

| Endpoint | Current Scope | Workspace Variant Priority | Recommendation | Billing Impact |
|----------|---------------|---------------------------|----------------|----------------|
| `/api/v1/usage/summary` | `user` | ✅ HIGH | Add `?scope=workspace` | Direct - shows quota |
| `/api/v1/me` | `user` | ✅ HIGH | Implement v2 with workspace billing | Direct - central billing endpoint |
| `/api/v1/skills/summary` | `user` | ⚠️ MEDIUM | Add `?scope=workspace` (optional) | Indirect - resource usage |
| `/api/v1/agents/memory/cost-overview` | `user` | ⏸️ DEFERRED | Design with scope from start | Direct - if memory is billable |
| `/api/v1/quality/*` (10 endpoints) | `user` | ❌ LOW | Remain user-scoped, defer to R6 | None - quality not billing |

---

## Product Recommendations

### Phase 1: Core Billing Endpoints (Required for W8.2-W8.4)

**Must implement** for workspace billing to be coherent:

1. **`GET /api/v1/me` v2** (Task 5)
   - Highest priority
   - Central billing information endpoint
   - Already specified in design.md
   - Backward compatible via versioning

2. **`GET /api/v1/usage/summary?scope=workspace`** (Task 7.2)
   - Second highest priority
   - Users need to see workspace quota status
   - Direct billing visibility
   - Backward compatible via query parameter

### Phase 2: Resource Visibility (Optional Enhancement)

**Consider implementing** if product validates the need:

3. **`GET /api/v1/skills/summary?scope=workspace`**
   - Medium priority
   - Useful if skills are workspace-shared resources
   - Can be deferred to post-launch

### Phase 3: Quality Aggregation (Separate Product Feature)

**Explicitly defer** to separate product initiative:

4. **Quality endpoints workspace aggregation**
   - Low priority for billing migration
   - Quality is not a billing concern
   - Already have project-level filtering
   - If needed, implement as separate "workspace quality dashboard" feature

---

## Implementation Guidance

### For Task 7.2 (Implement workspace-scoped variants)

Based on this analysis, Task 7.2 should focus on:

1. **`GET /api/v1/me` v2** - Already covered by Task 5
2. **`GET /api/v1/usage/summary?scope=workspace`** - New implementation needed

### Deferral Documentation

For Requirement 6.2, document the following deferrals:

1. **Skills summary**: Optional enhancement, defer to Phase 2
2. **Memory cost overview**: Not yet implemented, design with scope from start
3. **Quality endpoints**: Explicitly deferred - quality is not a billing concern, already have project-level filtering

### OpenAPI Annotations

When implementing workspace-scope variants, update OpenAPI with:

```yaml
# Example for usage/summary
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

---

## Alignment with Requirements

This inventory satisfies **Requirement 6**:

> **Requirement 6: Related APIs — scope consistency (optional phase)**
> 
> **User Story:** As a product owner, I want usage summaries to match billing scope so users are not confused.
> 
> **Acceptance Criteria:**
> 1. ✅ THE Spec SHALL list endpoints that today declare **`scope = user`**
> 2. ✅ WHEN workspace-scope billing is **on** for a tenant/user class, THE Program SHALL either (a) add **`workspace_id`** query support and document **`scope`**, or (b) explicitly defer with a **documented** product exception.
> 3. ✅ THE OpenAPI SHALL annotate **`scope`** fields where applicable to avoid client ambiguity.

**Deliverables**:
- ✅ Endpoint inventory complete
- ✅ Product decisions documented per endpoint
- ✅ Explicit deferrals with rationale
- ✅ Implementation priorities established
- ✅ OpenAPI annotation guidance provided

---

## Next Steps

1. **Product Review**: Present this analysis to product team for sign-off on priorities
2. **Task 7.2 Scope**: Based on decisions, implement workspace-scoped variants for approved endpoints
3. **OpenAPI Updates**: Add scope annotations to relevant endpoints
4. **Documentation**: Update workspace billing migration notice with endpoint scope behavior
5. **Client Updates**: Plan Flutter client changes to consume workspace-scoped endpoints

---

## References

- **Requirements**: `.kiro/specs/workspace-scope-billing/requirements.md` (Requirement 6)
- **Design**: `.kiro/specs/workspace-scope-billing/design.md`
- **Tasks**: `.kiro/specs/workspace-scope-billing/tasks.md` (Task 7)
- **Current Decision**: `docs/plans/workspace-billing-scope-decision.md`
- **OpenAPI Baseline**: `scripts/fixtures/openapi_baseline.yaml`
- **Future Stub**: `docs/plans/workspace-billing-future-workspace-scope.md`
