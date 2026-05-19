# Client Migration Notice: Workspace-Scope Billing (W8.2–W8.4)

**Status**: DRAFT — Pending Product/Finance Sign-off  
**Effective Date**: TBD (See [ADR: Workspace Billing Attribution](./adr-workspace-billing-attribution.md))  
**Last Updated**: 2025-01-15 (Task 0.2 — Workspace-Scope Billing Spec)  
**Related Documents**:
- [Workspace Billing Scope Decision (W8.1)](./workspace-billing-scope-decision.md)
- [Workspace-Scope Billing Spec](../../.kiro/specs/workspace-scope-billing/)
- [Workspace Team Full Plan](./workspace-team-full-plan.md) Phase W8
- [ADR: Workspace Billing Attribution](./adr-workspace-billing-attribution.md) (Task 0.1)
- [ADR: Workspace Billing Storage Model](./adr-workspace-billing-storage-model.md) (Task 0.3)

---

## Purpose

This document informs API consumers, client developers, and operations teams about the **transition from user-scope to workspace-scope billing** for Openflow. This migration affects how subscriptions, quotas, and usage are attributed and enforced.

**IMPORTANT**: This migration is **GATED** and will NOT proceed until explicit sign-off is obtained per [ADR: Workspace Billing Attribution](./adr-workspace-billing-attribution.md). Current production behavior remains **user-scope billing**.

### Gate Requirements (Requirement 0)

Before ANY workspace-scope billing implementation may proceed, the following preconditions MUST be met:

1. **Written Sign-off** (Requirement 0.1):
   - Product/Finance Lead must approve billing attribution decision
   - Effective date must be established
   - Sign-off documented in [ADR: Workspace Billing Attribution](./adr-workspace-billing-attribution.md)

2. **Client Migration Policy** (Requirement 0.2):
   - This document serves as the client migration policy
   - Must be published and communicated to all API consumers before enabling workspace-scope read paths
   - Includes timeline, behavioral changes, API versioning, and rollback procedures

3. **Schema Preservation** (Requirement 0.3):
   - `app_user_profile` billing columns MUST NOT be removed or repurposed
   - All schema changes MUST be additive (nullable columns/tables only)
   - User-scope billing paths remain functional during entire transition

**Current Status**: All three gate requirements are documented but NOT YET APPROVED. Implementation is blocked pending sign-off.

---

## 1. What Changes

### 1.1 Billing Attribution Model

**Before (User-Scope — Current)**:
- Subscriptions belong to individual users
- Each user has their own `plan_tier`, `daily_job_quota`, and `jobs_today` counter
- Multi-user workspace collaboration does NOT share quota pools
- Billing is tied to `app_user_profile`

**After (Workspace-Scope — Future)**:
- Subscriptions belong to workspaces
- Workspace has a shared `plan_tier`, `daily_job_quota`, and `jobs_today` counter
- All workspace members share the same quota pool
- Billing is tied to `app_workspace` or `app_workspace_billing`

### 1.2 Affected APIs

| API Endpoint | Change |
|--------------|--------|
| `GET /api/v1/me` | **v1** (default): Backward-compatible, adds optional `billing_scope` field<br>**v2** (opt-in): Nested structure with `user` + `current_workspace_billing` |
| Job creation endpoints | Quota checks use workspace aggregates when `billing_scope = workspace` |
| Billing webhooks | Dual-write to both user profile and workspace billing during transition |
| Usage/quota APIs | May add `workspace_id` query parameter (see Requirement 6) |

### 1.3 Data Model Approach (Requirement 1)

**Storage Model**: The implementation will follow the decision documented in [ADR: Workspace Billing Storage Model](./adr-workspace-billing-storage-model.md), which chooses between:
- **Option A**: Nullable billing columns on `app_workspace` table
- **Option B**: Separate `app_workspace_billing` table keyed by `workspace_id`

**Migration Strategy** (Requirement 1.2):
- **Phase 1**: Additive only — new nullable columns/tables, NO drops
- **Phase 2**: Backfill workspace billing data from user profiles
- **Phase 3**: Dual-write period with reconciliation
- **Phase 4**: Cutover to workspace-scope reads
- **Phase 5**: Optional deprecation of user-scope columns (requires separate sign-off)

**Personal Workspace Support** (Requirement 1.3):
- Personal workspaces use the same structural fields as enterprise workspaces
- Product rules distinguish behavior based on `workspace_type` and `billing_scope`
- No separate schema for personal vs enterprise billing

### 1.4 Timeline Phases

| Phase | Description | Client Action Required |
|-------|-------------|------------------------|
| **Phase 0: Gate** | Sign-off and migration notice published | Review this document |
| **Phase 1: Schema** | Additive database migrations (no behavior change) | None |
| **Phase 2: Dual-Write** | Backend writes to both user and workspace billing | None (shadow period) |
| **Phase 3: v2 API** | `/api/v1/me?v=2` available for opt-in testing | Test v2 integration |
| **Phase 4: Cutover** | New clients default to workspace-scope billing | Update to v2 API |
| **Phase 5: Deprecation** | User-scope billing deprecated (timeline TBD) | Complete migration to v2 |

---

## 2. API Versioning Strategy

### 2.1 `/api/v1/me` Response Shapes

#### v1 (Backward-Compatible — Default)

**Request**: `GET /api/v1/me` (no version parameter)

**Response** (existing fields preserved):
```json
{
  "id": "user-uuid",
  "email": "user@example.com",
  "plan_tier": "pro",
  "billing_currency": "usd",
  "daily_job_quota": 100,
  "jobs_today": 42,
  "billing_scope": "user"  // NEW: optional field, defaults to "user"
}
```

**Compatibility**: Existing clients continue to work without changes. The optional `billing_scope` field indicates the effective billing model.

#### v2 (Workspace-Aware — Opt-In)

**Request**: `GET /api/v1/me?v=2`

**Response** (nested structure):
```json
{
  "billing_scope": "workspace",
  "user": {
    "id": "user-uuid",
    "email": "user@example.com",
    "plan_tier": "pro",
    "jobs_today": 0
  },
  "current_workspace_billing": {
    "workspace_id": "workspace-uuid",
    "workspace_type": "enterprise",
    "workspace_name": "Acme Corp",
    "plan_tier": "enterprise",
    "daily_job_quota": 1000,
    "jobs_today": 42,
    "billing_provider": "stripe",
    "subscription_status": "active"
  }
}
```

**Notes**:
- `current_workspace_billing` is `null` or omitted when:
  - User is in a personal workspace AND billing remains user-scope
  - User is not a member of the current workspace (authorization failure)
- `user.jobs_today` may be `0` or omitted when `billing_scope = workspace` (workspace counter is authoritative)

### 2.2 Version Negotiation

Clients MUST use the query parameter to request v2:

- **Query Parameter**: `GET /api/v1/me?v=2`

**Default Behavior**: Omitting version parameters returns v1 response.

Accept-header negotiation is not implemented for `/me`; see
[`adr-me-api-version-negotiation.md`](./adr-me-api-version-negotiation.md).

---

## 3. Client Migration Checklist

### 3.1 Minimum Requirements for v2 Adoption

Before adopting workspace-scope billing, clients MUST:

- [ ] **Parse `billing_scope` field** to determine effective billing model
- [ ] **Handle nested `current_workspace_billing` object** (may be null)
- [ ] **Display workspace quota** when `billing_scope = workspace`
- [ ] **Gracefully degrade** when `current_workspace_billing` is unavailable
- [ ] **Update quota UI** to show "Team Quota" vs "Personal Quota" based on scope
- [ ] **Handle 403 errors** for workspace billing access (non-member scenarios)
- [ ] **Test with both personal and enterprise workspaces**

### 3.2 Recommended Testing Scenarios

| Scenario | Expected Behavior |
|----------|-------------------|
| **Personal workspace user** | `billing_scope = user`, `current_workspace_billing = null` |
| **Enterprise workspace member** | `billing_scope = workspace`, `current_workspace_billing` populated |
| **Enterprise workspace owner** | Same as member, plus billing management permissions |
| **User removed from workspace** | Backend auto-reverts to personal workspace, `billing_scope` changes |
| **Workspace archived** | Backend auto-reverts to personal workspace |
| **Job creation near quota limit** | Quota check uses workspace aggregate, not user aggregate |

### 3.3 Flutter-Specific Guidance

**rust_api Integration**:
```dart
// Phase 3: Add v2 support behind feature flag
final meResponse = await api.getMe(version: 2);

if (meResponse.billingScope == BillingScope.workspace) {
  // Display workspace quota
  final workspaceBilling = meResponse.currentWorkspaceBilling;
  if (workspaceBilling != null) {
    showWorkspaceQuota(
      workspaceBilling.planTier,
      workspaceBilling.jobsToday,
      workspaceBilling.dailyJobQuota,
    );
  }
} else {
  // Display user quota (legacy path)
  showUserQuota(
    meResponse.user.planTier,
    meResponse.user.jobsToday,
  );
}
```

**Feature Flag**:
- Use `kEnableWorkspaceBilling` constant from `frontend/lib/config.dart` to gate v2 API calls
- Override via build-time flag: `flutter run --dart-define=ENABLE_WORKSPACE_BILLING=true`
- Default: `false` (user-scope billing, v1 API only)
- Coordinate with backend deployment timeline per cutover runbook phases

---

## 4. Behavioral Changes

### 4.1 Quota Enforcement

**User-Scope (Current)**:
- Each user has independent `jobs_today` counter
- User A and User B in the same workspace have separate quotas
- Job creation checks `app_generation_job.owner_user_id = current_user`

**Workspace-Scope (Future)**:
- Workspace has shared `jobs_today` counter
- User A and User B in the same workspace share the same quota pool
- Job creation checks workspace-scope attribution against the current workspace billing context
- **Risk**: One user can exhaust the entire workspace quota

### 4.2 Job Attribution

**Current**:
- Jobs are attributed to `owner_user_id`
- Metering aggregates by user

**Future**:
- Jobs are attributed to workspace billing scope (for example persisted `workspace_id` or an equivalent stable workspace billing view, per the final W8.2 storage decision)
- Metering aggregates by workspace
- `owner_user_id` still tracked for audit/notification purposes

### 4.3 Subscription Management

**Current**:
- Users manage their own subscriptions via Stripe
- Workspace membership does not affect billing

**Future**:
- Workspace owners/admins manage workspace subscriptions
- Workspace members inherit workspace billing tier
- Personal workspaces may retain user-scope billing (product decision TBD)

---

## 5. Error Handling

### 5.1 New Error Scenarios

| Error Code | Scenario | Client Action |
|------------|----------|---------------|
| `403 Forbidden` | User requests `current_workspace_billing` for workspace they're not a member of | Fall back to user billing display |
| `403 Forbidden` | Non-admin user attempts workspace billing management | Show "Contact workspace admin" message |
| `409 Conflict` | Workspace quota exhausted by another member | Show "Team quota exceeded" message |
| `422 Unprocessable Entity` | Job creation without valid `workspace_id` during cutover | Retry with workspace context |

### 5.2 Graceful Degradation

Clients MUST handle the following gracefully:

1. **`current_workspace_billing` is null**: Fall back to user billing display
2. **`billing_scope` field missing**: Assume `user` (backward compatibility)
3. **v2 API returns 404**: Fall back to v1 API (backend not yet upgraded)
4. **Workspace auto-revert**: Detect `current_workspace_id` change in `/me` response and refresh UI

---

## 6. Rollback Plan

### 6.1 Rollback Triggers

Rollback to user-scope billing may occur if:
- Critical authorization bugs expose billing data to non-members
- Quota enforcement errors cause widespread service disruption
- Data reconciliation shows >5% mismatch between user and workspace billing

### 6.2 Rollback Procedure

**Backend**:
1. Disable v2 API responses (return 404 for `?v=2` requests)
2. Revert quota enforcement to user-scope aggregates
3. Preserve workspace billing data (no destructive rollback)

**Clients**:
1. Detect v2 API unavailability (404 response)
2. Automatically fall back to v1 API
3. Display user-scope quota UI

**No client update required** if clients implement graceful degradation per Section 5.2.

---

## 7. Operations and Monitoring

### 7.1 Key Metrics

| Metric | Purpose |
|--------|---------|
| `billing_webhook_dual_write_mismatch_total` | Detect reconciliation issues during dual-write phase |
| `quota_denied_total{scope=workspace}` | Monitor workspace quota exhaustion events |
| `me_v2_requests_total` | Track v2 API adoption rate |
| `workspace_billing_403_total` | Detect authorization issues |

### 7.2 Ops Billing View (W8.3)

Internal operations tools will support:
- Filter subscriptions by `workspace_id`
- View workspace-level usage aggregates
- Export workspace billing events (PII-scrubbed)

**Access Control**: Internal-only tokens, no customer-facing exposure.

---

## 8. Security and Authorization

### 8.1 Data Access Rules

| Data | Access Rule |
|------|-------------|
| `current_workspace_billing` | User MUST be a member of `current_workspace_id` |
| Workspace billing management | User MUST have `manage_billing` role on workspace |
| Historical billing data | Workspace owners/admins only |
| Ops billing views | Internal staff only (RBAC-protected) |

### 8.2 Personal Workspace Handling

**Product Decision TBD**: Personal workspaces may:
1. **Option A**: Remain user-scope billing (hybrid model)
2. **Option B**: Adopt workspace-scope billing (unified model)

Clients MUST check `billing_scope` field rather than assuming based on `workspace_type`.

---

## 9. FAQ

### Q1: Will existing API clients break?

**A**: No. The default `/api/v1/me` response (v1) remains backward-compatible. Clients that do not opt into v2 will continue to work.

### Q2: When should clients migrate to v2?

**A**: Clients should begin testing v2 during **Phase 3** (v2 API available) and complete migration before **Phase 5** (user-scope deprecation). Exact timeline TBD based on sign-off.

### Q3: What happens to personal workspace users?

**A**: Product decision pending. Personal workspaces may retain user-scope billing or adopt workspace-scope billing. Clients MUST check `billing_scope` field.

### Q4: Can a user be in multiple workspaces with different billing?

**A**: Yes. `current_workspace_billing` reflects the **current** workspace context. Switching workspaces changes the effective billing scope.

### Q5: What if a workspace is archived during a job?

**A**: Backend auto-reverts user to personal workspace. Job attribution remains stable according to the final workspace-scope billing storage model (for example persisted `workspace_id` or equivalent workspace billing attribution). Quota enforcement switches to user-scope or personal workspace scope.

### Q6: How do I test v2 API before cutover?

**A**: Use `GET /api/v1/me?v=2` in staging/development environments during Phase 3. Backend will dual-write but continue enforcing user-scope quotas until Phase 4.

---

## 10. Related Documentation

- **Current Decision**: [workspace-billing-scope-decision.md](./workspace-billing-scope-decision.md) (W8.1)
- **Future Implementation**: [workspace-billing-future-workspace-scope.md](./workspace-billing-future-workspace-scope.md) (W8.2–W8.4)
- **Complete Spec**: [.kiro/specs/workspace-scope-billing/](../../.kiro/specs/workspace-scope-billing/) (requirements, design, tasks)
- **ADR**: [adr-workspace-billing-attribution.md](./adr-workspace-billing-attribution.md) (sign-off gate)
- **Workspace Team Plan**: [workspace-team-full-plan.md](./workspace-team-full-plan.md) Phase W8
- **Workspace Collaboration Migration**: [workspace-migration-notice.md](./workspace-migration-notice.md) (W11.3 — separate concern)

---

## 12. Feature Flag Configuration

### 12.1 Flutter Build-Time Flag

The workspace billing feature is controlled by a **build-time constant** defined in `frontend/lib/config.dart`:

```dart
/// Feature flag for workspace-scope billing (Task 6.3).
/// Override: `flutter run --dart-define=ENABLE_WORKSPACE_BILLING=true`
/// Default: false (user-scope billing)
const bool kEnableWorkspaceBilling = bool.fromEnvironment(
  'ENABLE_WORKSPACE_BILLING',
  defaultValue: false,
);
```

### 12.2 Usage in Code

The flag gates v2 API calls and workspace billing UI:

```dart
// In home_page.dart (Task 6.2 implementation)
MeV2Response? meV2;
if (kEnableWorkspaceBilling) {
  try {
    meV2 = await fetchMeV2(token);
  } catch (_) {
    // V2 might not be available yet; fall back to v1 only
  }
}
```

### 12.3 Enabling the Feature

**Development/Testing**:
```bash
# Enable for local development
flutter run --dart-define=ENABLE_WORKSPACE_BILLING=true

# Enable for debug builds
flutter build apk --debug --dart-define=ENABLE_WORKSPACE_BILLING=true
```

**Production Builds**:
```bash
# Enable for release builds (coordinate with backend Phase 3+)
flutter build apk --release --dart-define=ENABLE_WORKSPACE_BILLING=true
flutter build ios --release --dart-define=ENABLE_WORKSPACE_BILLING=true
```

### 12.4 Alignment with Cutover Phases

| Cutover Phase | Flag State | Behavior |
|---------------|------------|----------|
| **Phase 0-2** (Pre-flight, Dual-Write, Shadow) | `false` (default) | v1 API only, user-scope billing UI |
| **Phase 3** (v2 Opt-In) | `true` for internal/beta builds | v2 API calls, workspace billing UI shown |
| **Phase 4** (Read Cutover) | `true` for all production builds | Full workspace-scope billing experience |
| **Phase 5** (Deprecation) | `true` (mandatory) | v1 API deprecated |

### 12.5 Rollback Support

The feature flag supports graceful rollback:

1. **Client-side rollback**: Rebuild with `ENABLE_WORKSPACE_BILLING=false`
2. **Backend rollback**: v2 API returns 404, client automatically falls back to v1
3. **No data loss**: Flag only controls read paths, not data persistence

### 12.6 CI/CD Integration

**GitHub Actions** (example):
```yaml
# .github/workflows/build-flutter.yml
- name: Build with workspace billing enabled
  run: |
    flutter build apk --release \
      --dart-define=ENABLE_WORKSPACE_BILLING=${{ secrets.ENABLE_WORKSPACE_BILLING }}
```

**Environment Variables**:
- `ENABLE_WORKSPACE_BILLING=false` → Default for all builds until Phase 3
- `ENABLE_WORKSPACE_BILLING=true` → Enable for Phase 3+ production builds

---

## 13. Contact and Support

**For Product/Business Questions**:
- Review [ADR: Workspace Billing Attribution](./adr-workspace-billing-attribution.md)
- Contact Product Lead (sign-off required)

**For Technical Integration Questions**:
- Review [Workspace-Scope Billing Spec](../../.kiro/specs/workspace-scope-billing/)
- Contact Engineering Lead

**For Operations/Billing Questions**:
- Review [workspace-billing-future-workspace-scope.md](./workspace-billing-future-workspace-scope.md) Section 3
- Contact Finance/Business Lead

---

**Document Status**: DRAFT — This migration is GATED and will not proceed until sign-off is obtained per [ADR: Workspace Billing Attribution](./adr-workspace-billing-attribution.md). Current production behavior remains user-scope billing per [workspace-billing-scope-decision.md](./workspace-billing-scope-decision.md).

**Requirement Coverage**: This document satisfies Requirements 0.1, 0.2, and 1.1 from [Workspace-Scope Billing Requirements](../../.kiro/specs/workspace-scope-billing/requirements.md).

**Last Updated**: 2025-01-15 (Task 0.2 — Workspace-Scope Billing Spec)
