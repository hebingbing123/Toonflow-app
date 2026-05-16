# API Scope Inventory (Task 7.1 & 7.2)

## Overview

This document inventories endpoints that currently operate with **user-scope** semantics and documents the product decision for each regarding workspace-scope support.

## Current State

As of the workspace-scope billing implementation (W8.2–W8.4), the following endpoints are **user-scoped** by default:

### Billing & Quota Endpoints

| Endpoint | Current Scope | Workspace Support | Decision |
|----------|---------------|-------------------|----------|
| `GET /api/v1/me` | user | v2 available (`?v=2`) | ✅ **Implemented** - v2 response includes `billing_scope` and `current_workspace_billing` |
| `PATCH /api/v1/me/current-workspace` | user | N/A | No change needed - switches user's current workspace context |

### Usage & Metrics Endpoints

| Endpoint | Current Scope | Workspace Support | Decision |
|----------|---------------|-------------------|----------|
| `GET /api/v1/usage` | user | Not yet | **Deferred** - See backlog item below |
| `GET /api/v1/agents/memory` | user | Not yet | **Deferred** - Memory is user-scoped by design |
| `GET /api/v1/skills` | user | Not yet | **Deferred** - Skills are user-scoped by design |

### Job & Generation Endpoints

| Endpoint | Current Scope | Workspace Support | Decision |
|----------|---------------|-------------------|----------|
| `GET /api/v1/jobs` | user | Partial | **In Progress** - Jobs now have `workspace_id` (Task 2.1-2.3), but listing endpoint still filters by `owner_user_id` |
| `POST /api/v1/jobs/*` (creation) | user | ✅ Implemented | Jobs now persist `workspace_id` and quota checks use effective billing context (Task 3.1-3.3) |

### Settings Endpoints

| Endpoint | Current Scope | Workspace Support | Decision |
|----------|---------------|-------------------|----------|
| `GET /api/v1/settings/account/exports` | user | N/A | No change needed - account exports are inherently user-scoped |
| `POST /api/v1/settings/account/export` | user | N/A | No change needed - account exports are inherently user-scoped |
| `DELETE /api/v1/settings/account/delete` | user | N/A | No change needed - account deletion is inherently user-scoped |
| `GET /api/v1/settings/notifications` | user | Not yet | **Deferred** - Notifications may need workspace context in future |

## Deferred Items (Backlog)

The following items are explicitly deferred to future phases per Requirement 6:

### 1. Usage Summary Endpoint (`GET /api/v1/usage`)

**Current Behavior:** Returns usage aggregates for the authenticated user only.

**Workspace-Scope Requirement:** When `billing_scope=workspace`, should support filtering by `workspace_id` to show workspace-level usage.

**Deferral Reason:** Usage summaries are not critical for initial workspace billing rollout. User-scope usage remains accurate for personal workspaces.

**Backlog Item:** Add `?workspace_id=<uuid>` query parameter to `GET /api/v1/usage` and aggregate by workspace when provided. Requires authorization check (user must be workspace member).

### 2. Job Listing Endpoint (`GET /api/v1/jobs`)

**Current Behavior:** Returns jobs owned by the authenticated user (`owner_user_id`).

**Workspace-Scope Requirement:** When `billing_scope=workspace`, should support filtering by `workspace_id` to show all workspace jobs.

**Deferral Reason:** Job creation and quota enforcement are workspace-aware (Tasks 2-3). Listing can remain user-scoped initially without breaking billing.

**Backlog Item:** Add `?workspace_id=<uuid>` query parameter to `GET /api/v1/jobs` and filter by workspace when provided. Requires authorization check (user must be workspace member).

### 3. Notifications Endpoint (`GET /api/v1/settings/notifications`)

**Current Behavior:** Returns notifications for the authenticated user.

**Workspace-Scope Requirement:** Notifications may need workspace context for team collaboration features.

**Deferral Reason:** Notifications are not directly related to billing. Current user-scope behavior is acceptable.

**Backlog Item:** Consider adding workspace-scoped notifications in future team collaboration phases.

## Implementation Notes

### OpenAPI Annotations

Endpoints that support both user and workspace scope should document the `scope` parameter in their OpenAPI descriptions:

```yaml
parameters:
  - name: workspace_id
    in: query
    required: false
    schema:
      type: string
      format: uuid
    description: |
      Filter by workspace (requires workspace membership).
      When omitted, defaults to user-scope filtering.
```

### Authorization Rules

All workspace-scoped queries must verify:
1. User is authenticated
2. User is a member of the requested workspace
3. Workspace exists and is not deleted

### Backward Compatibility

All deferred endpoints maintain backward compatibility:
- Existing clients continue to work with user-scope filtering
- New clients can opt into workspace-scope by providing `workspace_id` parameter
- No breaking changes to existing response schemas

## References

- Requirements: `.kiro/specs/workspace-scope-billing/requirements.md` (Requirement 6)
- Design: `.kiro/specs/workspace-scope-billing/design.md`
- Workspace billing decision: `docs/plans/workspace-billing-scope-decision.md`
