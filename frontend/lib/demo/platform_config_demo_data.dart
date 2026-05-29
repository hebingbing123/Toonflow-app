import '../rust_api.dart';

/// Preloaded platform config API response for demo mode.
PlatformConfigResponseV1 buildDemoPlatformConfigResponse() {
  final l10n = rustApiLookupL10nFromPlatform();
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
    currentWorkspace: PlatformConfigWorkspaceContextV1(
      id: 'workspace-demo',
      name: l10n.demoWorkspaceDisplayName,
      workspaceType: 'team',
      role: 'owner',
      canManageOverride: true,
    ),
  );
}
