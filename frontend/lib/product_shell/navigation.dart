import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../shell/navigation_controller.dart';

/// Primary studio navigation (waoowaoo-style sidebar), not the harness chip grid.
class ProductShellDestination {
  const ProductShellDestination({
    required this.pane,
    required this.icon,
    required this.selectedIcon,
    required this.label,
  });

  final ProductWorkspacePane pane;
  final IconData icon;
  final IconData selectedIcon;
  final String Function(AppLocalizations l10n) label;
}

List<ProductShellDestination> primaryProductShellDestinations({
  required bool jobsPaneEnabled,
  required bool qualityPaneEnabled,
}) {
  return <ProductShellDestination>[
    ProductShellDestination(
      pane: ProductWorkspacePane.projects,
      icon: Icons.folder_special_outlined,
      selectedIcon: Icons.folder_special,
      label: (l10n) => l10n.productNavProjects,
    ),
    ProductShellDestination(
      pane: ProductWorkspacePane.shortVideoSpace,
      icon: Icons.movie_creation_outlined,
      selectedIcon: Icons.movie_creation,
      label: (l10n) => l10n.productNavShortVideoSpace,
    ),
    ProductShellDestination(
      pane: ProductWorkspacePane.scriptWorkspace,
      icon: Icons.menu_book_outlined,
      selectedIcon: Icons.menu_book,
      label: (l10n) => l10n.productNavScriptWorkspace,
    ),
    ProductShellDestination(
      pane: ProductWorkspacePane.productionWorkspace,
      icon: Icons.theaters_outlined,
      selectedIcon: Icons.theaters,
      label: (l10n) => l10n.productNavProductionWorkspace,
    ),
    ProductShellDestination(
      pane: ProductWorkspacePane.tasks,
      icon: Icons.task_alt_outlined,
      selectedIcon: Icons.task_alt,
      label: (l10n) => l10n.productNavTasks,
    ),
    if (qualityPaneEnabled)
      ProductShellDestination(
        pane: ProductWorkspacePane.quality,
        icon: Icons.verified_outlined,
        selectedIcon: Icons.verified,
        label: (l10n) => l10n.productNavQuality,
      ),
    if (jobsPaneEnabled)
      ProductShellDestination(
        pane: ProductWorkspacePane.jobs,
        icon: Icons.cloud_queue_outlined,
        selectedIcon: Icons.cloud_queue,
        label: (l10n) => l10n.productNavJobs,
      ),
    ProductShellDestination(
      pane: ProductWorkspacePane.notifications,
      icon: Icons.notifications_outlined,
      selectedIcon: Icons.notifications,
      label: (l10n) => l10n.productNavNotifications,
    ),
    ProductShellDestination(
      pane: ProductWorkspacePane.teamWorkspaces,
      icon: Icons.groups_outlined,
      selectedIcon: Icons.groups,
      label: (l10n) => l10n.productNavTeamWorkspaces,
    ),
    ProductShellDestination(
      pane: ProductWorkspacePane.account,
      icon: Icons.person_outline,
      selectedIcon: Icons.person,
      label: (l10n) => l10n.productNavAccount,
    ),
  ];
}

List<ProductShellDestination> secondaryProductShellDestinations(
  AppLocalizations l10n,
) {
  return <ProductShellDestination>[
    ProductShellDestination(
      pane: ProductWorkspacePane.apiKeys,
      icon: Icons.key_outlined,
      selectedIcon: Icons.key,
      label: (_) => l10n.productNavApiKeys,
    ),
    ProductShellDestination(
      pane: ProductWorkspacePane.contentCompliance,
      icon: Icons.policy_outlined,
      selectedIcon: Icons.policy,
      label: (_) => l10n.productNavContentCompliance,
    ),
    ProductShellDestination(
      pane: ProductWorkspacePane.platformStatus,
      icon: Icons.monitor_heart_outlined,
      selectedIcon: Icons.monitor_heart,
      label: (_) => l10n.productNavPlatformStatus,
    ),
    ProductShellDestination(
      pane: ProductWorkspacePane.platformConfig,
      icon: Icons.tune_outlined,
      selectedIcon: Icons.tune,
      label: (_) => l10n.productNavPlatformConfig,
    ),
    ProductShellDestination(
      pane: ProductWorkspacePane.helpHub,
      icon: Icons.help_outline,
      selectedIcon: Icons.help,
      label: (_) => l10n.productNavHelp,
    ),
  ];
}
