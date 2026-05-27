import '../rust_api.dart';

/// Preloaded platform config API response for demo mode.
PlatformConfigResponseV1 buildDemoPlatformConfigResponse() {
  const effective = PlatformConfigToggleSetV1.defaults;
  return PlatformConfigResponseV1(
    scope: 'workspace',
    schemaVersion: 1,
    effective: effective,
    planTier: 'pro',
    planOverride: null,
    hasPlanOverride: false,
    userOverride: effective,
    hasUserOverride: true,
    workspaceOverride: effective,
    hasWorkspaceOverride: true,
    currentWorkspace: const PlatformConfigWorkspaceContextV1(
      id: 'workspace-demo',
      name: '演示工作区',
      workspaceType: 'team',
      role: 'owner',
      canManageOverride: true,
    ),
  );
}
