import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openflow_app/l10n/app_localizations_zh.dart';
import 'package:openflow_app/product_shell/navigation.dart';
import 'package:openflow_app/product_shell/studio_shell_navigation.dart';
import 'package:openflow_app/shell/navigation_controller.dart';

void main() {
  final l10n = AppLocalizationsZh();

  test('groupProductShellMoreMenuDestinations splits workflow and platform', () {
    final destinations = studioShellSecondaryDestinations(
      l10n,
      jobsPaneEnabled: true,
      qualityPaneEnabled: true,
    );
    final grouping = groupProductShellMoreMenuDestinations(destinations);

    expect(grouping.workflow.map((d) => d.pane), contains(ProductWorkspacePane.tasks));
    expect(grouping.platform.map((d) => d.pane), contains(ProductWorkspacePane.apiKeys));
    expect(
      grouping.workflow.any((d) => d.pane == ProductWorkspacePane.platformConfig),
      isFalse,
    );
    expect(
      grouping.platform.any((d) => d.pane == ProductWorkspacePane.shortVideoSpace),
      isFalse,
    );
    expect(grouping.tileCount, destinations.length);
  });

  test('quick-access panes stay in quickAccess bucket', () {
    final quick = <ProductShellDestination>[
      ProductShellDestination(
        pane: ProductWorkspacePane.notifications,
        icon: Icons.notifications_outlined,
        selectedIcon: Icons.notifications,
        label: (_) => l10n.productNavNotifications,
      ),
    ];
    final grouping = groupProductShellMoreMenuDestinations(
      const <ProductShellDestination>[],
      quickAccess: quick,
    );

    expect(grouping.quickAccess, hasLength(1));
    expect(grouping.workflow, isEmpty);
    expect(grouping.platform, isEmpty);
  });
}
