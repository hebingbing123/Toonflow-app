import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../shell/navigation_controller.dart';
import 'navigation.dart';

/// Studio shell: ≤4 primary destinations (Wave 1).
List<ProductShellDestination> studioShellPrimaryDestinations({
  required int unreadNotifications,
}) {
  return <ProductShellDestination>[
    ProductShellDestination(
      pane: ProductWorkspacePane.projects,
      icon: Icons.folder_special_outlined,
      selectedIcon: Icons.folder_special,
      label: (l10n) => l10n.productNavProjects,
    ),
    ProductShellDestination(
      pane: ProductWorkspacePane.notifications,
      icon: Icons.notifications_outlined,
      selectedIcon: Icons.notifications,
      label: (l10n) => l10n.productNavNotifications,
    ),
    ProductShellDestination(
      pane: ProductWorkspacePane.account,
      icon: Icons.settings_outlined,
      selectedIcon: Icons.settings,
      label: (l10n) => l10n.productNavAccount,
    ),
    ProductShellDestination(
      pane: ProductWorkspacePane.helpHub,
      icon: Icons.help_outline,
      selectedIcon: Icons.help,
      label: (l10n) => l10n.productNavHelp,
    ),
  ];
}

/// Secondary panes reachable from settings «更多» or command palette.
List<ProductShellDestination> studioShellSecondaryDestinations(
  AppLocalizations l10n, {
  required bool jobsPaneEnabled,
  required bool qualityPaneEnabled,
}) {
  return <ProductShellDestination>[
    ProductShellDestination(
      pane: ProductWorkspacePane.shortVideoSpace,
      icon: Icons.ios_share_outlined,
      selectedIcon: Icons.ios_share,
      label: (_) => l10n.productNavShortVideoSpace,
    ),
    ProductShellDestination(
      pane: ProductWorkspacePane.scriptWorkspace,
      icon: Icons.menu_book_outlined,
      selectedIcon: Icons.menu_book,
      label: (_) => l10n.productNavScriptWorkspace,
    ),
    ProductShellDestination(
      pane: ProductWorkspacePane.productionWorkspace,
      icon: Icons.theaters_outlined,
      selectedIcon: Icons.theaters,
      label: (_) => l10n.productNavProductionWorkspace,
    ),
    ProductShellDestination(
      pane: ProductWorkspacePane.tasks,
      icon: Icons.task_alt_outlined,
      selectedIcon: Icons.task_alt,
      label: (_) => l10n.productNavTasks,
    ),
    if (qualityPaneEnabled)
      ProductShellDestination(
        pane: ProductWorkspacePane.quality,
        icon: Icons.verified_outlined,
        selectedIcon: Icons.verified,
        label: (_) => l10n.productNavQuality,
      ),
    if (jobsPaneEnabled)
      ProductShellDestination(
        pane: ProductWorkspacePane.jobs,
        icon: Icons.cloud_queue_outlined,
        selectedIcon: Icons.cloud_queue,
        label: (_) => l10n.productNavJobs,
      ),
    ProductShellDestination(
      pane: ProductWorkspacePane.teamWorkspaces,
      icon: Icons.groups_outlined,
      selectedIcon: Icons.groups,
      label: (_) => l10n.productNavTeamWorkspaces,
    ),
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
  ];
}

/// Grouped destinations for the product-shell «更多» overlay.
class ProductShellMoreMenuGrouping {
  const ProductShellMoreMenuGrouping({
    this.quickAccess = const <ProductShellDestination>[],
    this.workflow = const <ProductShellDestination>[],
    this.platform = const <ProductShellDestination>[],
  });

  final List<ProductShellDestination> quickAccess;
  final List<ProductShellDestination> workflow;
  final List<ProductShellDestination> platform;

  int get tileCount =>
      quickAccess.length + workflow.length + platform.length;
}

const Set<ProductWorkspacePane> _kMoreMenuWorkflowPanes = <ProductWorkspacePane>{
  ProductWorkspacePane.shortVideoSpace,
  ProductWorkspacePane.scriptWorkspace,
  ProductWorkspacePane.productionWorkspace,
  ProductWorkspacePane.tasks,
  ProductWorkspacePane.quality,
  ProductWorkspacePane.jobs,
};

const Set<ProductWorkspacePane> _kMoreMenuPlatformPanes = <ProductWorkspacePane>{
  ProductWorkspacePane.teamWorkspaces,
  ProductWorkspacePane.apiKeys,
  ProductWorkspacePane.contentCompliance,
  ProductWorkspacePane.platformStatus,
  ProductWorkspacePane.platformConfig,
};

ProductShellMoreMenuGrouping groupProductShellMoreMenuDestinations(
  List<ProductShellDestination> destinations, {
  List<ProductShellDestination> quickAccess = const <ProductShellDestination>[],
}) {
  final workflow = <ProductShellDestination>[];
  final platform = <ProductShellDestination>[];
  final other = <ProductShellDestination>[];
  for (final dest in destinations) {
    if (_kMoreMenuWorkflowPanes.contains(dest.pane)) {
      workflow.add(dest);
    } else if (_kMoreMenuPlatformPanes.contains(dest.pane)) {
      platform.add(dest);
    } else {
      other.add(dest);
    }
  }
  return ProductShellMoreMenuGrouping(
    quickAccess: <ProductShellDestination>[...quickAccess, ...other],
    workflow: workflow,
    platform: platform,
  );
}
