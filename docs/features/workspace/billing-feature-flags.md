# Workspace Billing Feature Flag Guide

**Status**: Active  
**Feature Flag**: `kEnableWorkspaceBilling`  
**Location**: `frontend/lib/config.dart`  
**Task**: 6.3 (Workspace-Scope Billing Spec)  
**Related Documents**:
- [Workspace Billing Migration Notice](./workspace-billing-migration-notice.md)
- [Workspace Billing Cutover Runbook](./workspace-billing-cutover-runbook.md)
- [Workspace-Scope Billing Spec](../../.kiro/specs/workspace-scope-billing/)

**Boundary**: this guide belongs to the gated future billing migration path. The existence of `kEnableWorkspaceBilling` does not by itself mean current production billing semantics have switched; unless a rollout is explicitly approved, current behavior remains user-scope.

---

## Overview

The `kEnableWorkspaceBilling` feature flag controls whether the Flutter frontend uses **workspace-scope billing** (v2 API) or **user-scope billing** (v1 API). This flag enables gradual rollout of workspace billing features aligned with backend deployment phases.

**Key Characteristics**:
- **Build-time constant**: Set via `--dart-define` at compile time
- **Default**: `false` (user-scope billing)
- **Scope**: Controls v2 API calls and workspace billing UI display
- **Rollback-friendly**: Can be toggled without code changes

---

## Implementation

### Definition

```dart
// frontend/lib/config.dart

/// Feature flag for workspace-scope billing (Task 6.3).
/// Override: `flutter run --dart-define=ENABLE_WORKSPACE_BILLING=true`
/// Default: false (user-scope billing)
const bool kEnableWorkspaceBilling = bool.fromEnvironment(
  'ENABLE_WORKSPACE_BILLING',
  defaultValue: false,
);
```

### Usage Pattern

```dart
// frontend/lib/home_page.dart (Task 6.2 implementation)

// Fetch v1 response (always available)
final me = await fetchMeV1(token);

// Conditionally fetch v2 response when flag is enabled
MeV2Response? meV2;
if (kEnableWorkspaceBilling) {
  try {
    meV2 = await fetchMeV2(token);
  } catch (_) {
    // V2 might not be available yet; fall back to v1 only
  }
}

// Store both responses
setState(() {
  _sessionMe = me;
  _sessionMeV2 = meV2;
});
```

### UI Conditional Rendering

```dart
// Display workspace quota when flag is enabled and v2 data available
if (kEnableWorkspaceBilling && _sessionMeV2?.currentWorkspaceBilling != null) {
  // Show workspace billing UI
  final workspaceBilling = _sessionMeV2!.currentWorkspaceBilling!;
  return WorkspaceQuotaWidget(
    planTier: workspaceBilling.planTier,
    jobsToday: workspaceBilling.jobsToday,
    dailyJobQuota: workspaceBilling.dailyJobQuota,
  );
} else {
  // Show user billing UI (legacy)
  return UserQuotaWidget(
    planTier: _sessionMe.planTier,
    jobsToday: _sessionMe.jobsToday,
  );
}
```

---

## Build Commands

### Development

```bash
# Default: flag disabled (user-scope billing)
flutter run

# Enable workspace billing for testing
flutter run --dart-define=ENABLE_WORKSPACE_BILLING=true

# Enable with specific API base URL
flutter run \
  --dart-define=ENABLE_WORKSPACE_BILLING=true \
  --dart-define=API_BASE_URL=https://staging.openflow.com
```

### Debug Builds

```bash
# Android debug APK with flag enabled
flutter build apk --debug --dart-define=ENABLE_WORKSPACE_BILLING=true

# iOS debug build with flag enabled
flutter build ios --debug --dart-define=ENABLE_WORKSPACE_BILLING=true
```

### Release Builds

```bash
# Android release APK (default: flag disabled)
flutter build apk --release

# Android release APK with workspace billing enabled
flutter build apk --release --dart-define=ENABLE_WORKSPACE_BILLING=true

# iOS release build with workspace billing enabled
flutter build ios --release --dart-define=ENABLE_WORKSPACE_BILLING=true
```

---

## Deployment Timeline

### Phase 0-2: Pre-flight, Dual-Write, Shadow Period

**Flag State**: `false` (default)  
**Duration**: ~2-3 weeks  
**Behavior**:
- v1 API only (`GET /api/v1/me` without version parameter)
- User-scope billing UI
- Backend dual-writes to workspace billing storage (shadow mode)

**Build Command**:
```bash
flutter build apk --release  # No flag override needed
```

### Phase 3: v2 API Opt-In

**Flag State**: `true` for internal/beta builds, `false` for production  
**Duration**: 1-2 weeks  
**Behavior**:
- Internal builds: v2 API calls, workspace billing UI
- Production builds: v1 API, user-scope billing UI
- Backend serves both v1 and v2 responses

**Build Commands**:
```bash
# Internal/staging builds
flutter build apk --debug --dart-define=ENABLE_WORKSPACE_BILLING=true

# Production builds (still disabled)
flutter build apk --release
```

### Phase 4: Read Cutover

**Flag State**: `true` for all production builds  
**Duration**: Ongoing  
**Behavior**:
- All builds use v2 API
- Workspace billing UI shown when applicable
- Backend enforces workspace-scope quotas

**Build Command**:
```bash
# All production builds now enable the flag
flutter build apk --release --dart-define=ENABLE_WORKSPACE_BILLING=true
```

### Phase 5: Deprecation (Future)

**Flag State**: `true` (mandatory)  
**Duration**: 3-6 months deprecation window  
**Behavior**:
- v1 API marked deprecated
- Flag may be removed from codebase (always-on)

---

## CI/CD Integration

### GitHub Actions Example

```yaml
# .github/workflows/build-flutter.yml
name: Build Flutter App

on:
  push:
    branches: [main, develop]
  pull_request:

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      
      - name: Setup Flutter
        uses: subosito/flutter-action@v2
        with:
          flutter-version: '3.x'
      
      - name: Build Debug APK (workspace billing disabled)
        run: |
          cd frontend
          flutter build apk --debug
      
      - name: Build Debug APK (workspace billing enabled)
        run: |
          cd frontend
          flutter build apk --debug \
            --dart-define=ENABLE_WORKSPACE_BILLING=true
      
      - name: Build Release APK
        env:
          ENABLE_WORKSPACE_BILLING: ${{ secrets.ENABLE_WORKSPACE_BILLING }}
        run: |
          cd frontend
          flutter build apk --release \
            --dart-define=ENABLE_WORKSPACE_BILLING=${ENABLE_WORKSPACE_BILLING}
```

### Environment Variables

**GitHub Secrets** (recommended):
- `ENABLE_WORKSPACE_BILLING`: `"false"` (Phase 0-2), `"true"` (Phase 4+)

**Branch-Specific**:
```yaml
# Enable for develop branch, disable for main (during Phase 3)
- name: Set feature flag
  run: |
    if [[ "${{ github.ref }}" == "refs/heads/develop" ]]; then
      echo "ENABLE_WORKSPACE_BILLING=true" >> $GITHUB_ENV
    else
      echo "ENABLE_WORKSPACE_BILLING=false" >> $GITHUB_ENV
    fi

- name: Build with flag
  run: |
    flutter build apk --release \
      --dart-define=ENABLE_WORKSPACE_BILLING=${ENABLE_WORKSPACE_BILLING}
```

---

## Testing

### Manual Testing Checklist

- [ ] **Flag disabled** (`false`):
  - [ ] App builds successfully
  - [ ] `/me` v1 API called (check network logs)
  - [ ] User-scope quota displayed in UI
  - [ ] No v2 API calls attempted
  - [ ] No workspace billing UI elements visible

- [ ] **Flag enabled** (`true`):
  - [ ] App builds successfully
  - [ ] `/me` v2 API called with `?v=2` parameter
  - [ ] Workspace billing UI displayed when `current_workspace_billing` present
  - [ ] Graceful fallback to v1 if v2 API unavailable (404 response)
  - [ ] Personal workspace users see appropriate UI

- [ ] **Backend unavailable scenarios**:
  - [ ] v2 API returns 404 → app falls back to v1 display
  - [ ] v2 API returns 403 (non-member) → app shows user-scope billing
  - [ ] Network error → app shows cached data or error state

### Automated Testing

```dart
// test/config_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/config.dart';

void main() {
  test('kEnableWorkspaceBilling defaults to false', () {
    // In test environment without --dart-define
    expect(kEnableWorkspaceBilling, false);
  });
}
```

```bash
# Run tests with flag enabled
flutter test --dart-define=ENABLE_WORKSPACE_BILLING=true
```

---

## Rollback Procedures

### Scenario 1: Backend v2 API Issues

**Symptoms**: v2 API errors, incorrect workspace billing data, performance issues

**Client Action**: None required (automatic fallback)

**Behavior**:
```dart
if (kEnableWorkspaceBilling) {
  try {
    meV2 = await fetchMeV2(token);
  } catch (_) {
    // Automatic fallback: v2 unavailable, use v1 only
  }
}
```

### Scenario 2: Client-Side Rollback

**Symptoms**: UI bugs, incorrect quota display, user complaints

**Action**: Rebuild with flag disabled

```bash
# Rebuild production APK with flag disabled
flutter build apk --release  # Omit --dart-define flag

# Or explicitly disable
flutter build apk --release --dart-define=ENABLE_WORKSPACE_BILLING=false
```

**Timeline**: ~1-2 hours (rebuild + deploy)

### Scenario 3: Emergency Rollback via CI/CD

**Action**: Update GitHub secret

```bash
# In GitHub repository settings → Secrets
ENABLE_WORKSPACE_BILLING = "false"

# Trigger rebuild via GitHub Actions
git commit --allow-empty -m "Trigger rebuild with workspace billing disabled"
git push
```

**Timeline**: ~10-20 minutes (CI build + deploy)

---

## Monitoring

### Key Metrics

| Metric | Source | Purpose |
|--------|--------|---------|
| `me_v2_requests_total` | Backend | Track v2 API adoption rate |
| `me_v1_requests_total` | Backend | Monitor v1 API usage (should decrease) |
| `workspace_billing_ui_shown` | Frontend analytics | Confirm UI rendering |
| `workspace_billing_fallback_total` | Frontend analytics | Track v2 → v1 fallback events |

### Client-Side Logging

```dart
// Log feature flag state on app start
void logFeatureFlagState() {
  print('Feature Flags:');
  print('  kEnableWorkspaceBilling: $kEnableWorkspaceBilling');
  
  // Send to analytics
  analytics.logEvent(
    name: 'feature_flag_state',
    parameters: {
      'workspace_billing_enabled': kEnableWorkspaceBilling,
    },
  );
}
```

### Backend Correlation

```rust
// backend/src/app/handlers/me.rs

if version == MeVersion::V2 {
    metrics::increment_counter!("me_v2_requests_total");
    // Log client info for correlation
    tracing::info!(
        user_id = %user_id,
        workspace_id = ?current_workspace_id,
        "Serving /me v2 response"
    );
}
```

---

## Troubleshooting

### Issue: Flag not taking effect

**Symptoms**: App still uses v1 API despite `--dart-define=ENABLE_WORKSPACE_BILLING=true`

**Causes**:
1. Typo in flag name (case-sensitive)
2. Flag set at `flutter run` but not `flutter build`
3. Cached build artifacts

**Solutions**:
```bash
# Clean build cache
flutter clean

# Rebuild with flag
flutter build apk --release --dart-define=ENABLE_WORKSPACE_BILLING=true

# Verify flag in compiled app (check logs on app start)
```

### Issue: v2 API always fails

**Symptoms**: App always falls back to v1, even with flag enabled

**Causes**:
1. Backend not deployed with v2 handler
2. API base URL pointing to old backend
3. Network/CORS issues

**Solutions**:
```bash
# Check backend version
curl https://api.openflow.com/api/v1/me?v=2

# Check API base URL in app
flutter run --dart-define=API_BASE_URL=https://staging.openflow.com

# Check backend logs for v2 requests
```

### Issue: Workspace billing UI not showing

**Symptoms**: Flag enabled, v2 API succeeds, but UI still shows user-scope billing

**Causes**:
1. `current_workspace_billing` is `null` (personal workspace or non-member)
2. UI conditional logic incorrect
3. State not updated after v2 fetch

**Solutions**:
```dart
// Add debug logging
if (kEnableWorkspaceBilling) {
  print('v2 response: ${meV2?.toJson()}');
  print('current_workspace_billing: ${meV2?.currentWorkspaceBilling}');
}

// Check state update
setState(() {
  _sessionMeV2 = meV2;  // Ensure this is called
});
```

---

## FAQ

### Q1: Can I enable the flag for specific users?

**A**: No, this is a **build-time constant**. All users of a given build have the same flag state. For user-specific rollout, use backend-side feature flags or A/B testing.

### Q2: What happens if I enable the flag before backend is ready?

**A**: The app gracefully falls back to v1 API. The `try-catch` block around `fetchMeV2()` ensures no crashes.

### Q3: Can I change the flag without rebuilding?

**A**: No, `bool.fromEnvironment()` is evaluated at compile time. Runtime feature flags require a different implementation (e.g., remote config).

### Q4: Should I enable the flag for debug builds?

**A**: Yes, during Phase 3+ for internal testing. Use separate build commands for debug (flag enabled) and release (flag disabled until Phase 4).

### Q5: How do I test both flag states in CI?

**A**: Build twice with different flag values (see CI/CD Integration section above).

---

## Related Documentation

- **Migration Notice**: [workspace-billing-migration-notice.md](./workspace-billing-migration-notice.md) (Section 12)
- **Cutover Runbook**: [workspace-billing-cutover-runbook.md](./workspace-billing-cutover-runbook.md) (Phase 3-4)
- **Implementation Spec**: [.kiro/specs/workspace-scope-billing/](../../.kiro/specs/workspace-scope-billing/)
- **Task 6.2**: Flutter UI implementation (uses this flag)
- **Task 6.3**: This document (feature flag documentation)

---

**Maintained by**: Engineering (Frontend)  
**Last Updated**: 2025-01-15 (Task 6.3 completion)  
**Status**: Active (aligned with cutover phases)
