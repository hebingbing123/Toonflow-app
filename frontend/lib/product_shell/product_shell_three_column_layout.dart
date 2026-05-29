import 'package:flutter/material.dart';

import '../design_system/studio_responsive_layout.dart';
import '../l10n/app_localizations.dart';
import '../shell/navigation_controller.dart';
import 'product_shell_sidebar_destinations.dart';
import 'studio_sidebar.dart';

/// Desktop three-column product shell: sidebar rail | center workspace | optional trailing preview.
class ProductShellThreeColumnLayout extends StatelessWidget {
  const ProductShellThreeColumnLayout({
    super.key,
    required this.contentWidth,
    required this.appTitle,
    required this.selectedPane,
    required this.unreadNotifications,
    required this.jobsPaneEnabled,
    required this.qualityPaneEnabled,
    required this.useFourItemShell,
    required this.onSelectPane,
    required this.center,
    this.trailingPreview,
  });

  final double contentWidth;
  final String appTitle;
  final ProductWorkspacePane selectedPane;
  final int unreadNotifications;
  final bool jobsPaneEnabled;
  final bool qualityPaneEnabled;
  final bool useFourItemShell;
  final ValueChanged<ProductWorkspacePane> onSelectPane;
  final Widget center;
  final Widget? trailingPreview;

  bool get _useSidebar => studioUseThreePaneLayout(contentWidth);

  @override
  Widget build(BuildContext context) {
    if (!_useSidebar) {
      return center;
    }

    final destinations = productShellSidebarDestinations(
      l10n: AppLocalizations.of(context)!,
      jobsPaneEnabled: jobsPaneEnabled,
      qualityPaneEnabled: qualityPaneEnabled,
      useFourItemShell: useFourItemShell,
    );
    final selectedIndex = productShellSidebarSelectedIndex(
      destinations,
      selectedPane,
    ).clamp(-1, destinations.length - 1);

    final extended = contentWidth >= 1240;
    final sidebar = StudioSidebar(
      extended: extended,
      destinations: destinations,
      selectedIndex: selectedIndex < 0 ? 0 : selectedIndex,
      appTitle: appTitle,
      unreadNotifications: unreadNotifications,
      onSelect: (index) {
        if (index >= 0 && index < destinations.length) {
          onSelectPane(destinations[index].pane);
        }
      },
    );

    if (trailingPreview == null) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          sidebar,
          Expanded(child: center),
        ],
      );
    }

    final trailingWidth = studioClampedPaneWidth(
      contentWidth,
      fraction: 0.26,
      min: 280,
      max: 420,
    );
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        sidebar,
        Expanded(child: center),
        SizedBox(width: trailingWidth, child: trailingPreview),
      ],
    );
  }
}
