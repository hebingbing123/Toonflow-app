import '../l10n/app_localizations.dart';
import '../project_studio/studio_overlay_mode.dart';
import '../shell/navigation_controller.dart';

String resolveStudioShellHeaderTitle({
  required AppLocalizations l10n,
  required StudioOverlayMode overlayMode,
  required String? projectName,
  required int? studioProjectNumericId,
  required int? productScopedProjectNumericId,
  required ProductWorkspacePane currentPane,
}) {
  if (overlayMode != StudioOverlayMode.none) {
    final trimmedName = projectName?.trim();
    if (trimmedName != null && trimmedName.isNotEmpty) {
      return trimmedName;
    }
    final id = studioProjectNumericId ?? productScopedProjectNumericId;
    if (id != null) {
      return l10n.projectsUnnamedProject(id);
    }
  }

  return switch (currentPane) {
    ProductWorkspacePane.notifications => l10n.productNavNotifications,
    ProductWorkspacePane.account => l10n.productNavAccount,
    ProductWorkspacePane.helpHub => l10n.productNavHelp,
    ProductWorkspacePane.shortVideoSpace => l10n.productNavShortVideoSpace,
    ProductWorkspacePane.tasks => l10n.productNavTasks,
    ProductWorkspacePane.jobs => l10n.productNavJobs,
    ProductWorkspacePane.quality => l10n.productNavQuality,
    ProductWorkspacePane.scriptWorkspace => l10n.productNavScriptWorkspace,
    ProductWorkspacePane.productionWorkspace =>
      l10n.productNavProductionWorkspace,
    ProductWorkspacePane.teamWorkspaces => l10n.productNavTeamWorkspaces,
    ProductWorkspacePane.contentCompliance => l10n.productNavContentCompliance,
    ProductWorkspacePane.platformStatus => l10n.productNavPlatformStatus,
    ProductWorkspacePane.platformConfig => l10n.productNavPlatformConfig,
    ProductWorkspacePane.apiKeys => l10n.productNavApiKeys,
    ProductWorkspacePane.workspaceActivity => l10n.productNavWorkspaceActivity,
    ProductWorkspacePane.benchmark => l10n.productNavBenchmark,
    ProductWorkspacePane.projects => l10n.productNavProjects,
  };
}
