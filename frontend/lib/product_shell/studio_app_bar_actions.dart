import 'package:flutter/material.dart';

import '../design_system/components/studio_icon_button.dart';
import '../design_system/tokens.dart';
import '../l10n/app_localizations.dart';
import '../shell/navigation_controller.dart';

/// Top-bar utility actions: notifications, settings, help.
class StudioAppBarActions extends StatelessWidget {
  const StudioAppBarActions({
    super.key,
    required this.selectedPane,
    required this.unreadNotifications,
    required this.onSelectPane,
    this.dense = false,
  });

  final ProductWorkspacePane selectedPane;
  final int unreadNotifications;
  final ValueChanged<ProductWorkspacePane> onSelectPane;
  /// macOS title-bar row: flat icons ~15px, no pill container.
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    if (dense) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          StudioUtilityIconButton(
            key: const Key('studio-app-bar-notifications'),
            dense: true,
            label: l10n.studioAppBarNotifications,
            icon: Icons.notifications_rounded,
            selected: selectedPane == ProductWorkspacePane.notifications,
            badge: unreadNotifications > 0 ? unreadNotifications : null,
            onPressed: () => onSelectPane(ProductWorkspacePane.notifications),
          ),
          StudioUtilityIconButton(
            dense: true,
            label: l10n.studioAppBarSettings,
            icon: Icons.settings_rounded,
            selected: selectedPane == ProductWorkspacePane.account,
            onPressed: () => onSelectPane(ProductWorkspacePane.account),
          ),
          StudioUtilityIconButton(
            dense: true,
            label: l10n.studioAppBarHelp,
            icon: Icons.help_rounded,
            selected: selectedPane == ProductWorkspacePane.helpHub,
            onPressed: () => onSelectPane(ProductWorkspacePane.helpHub),
          ),
        ],
      );
    }

    final tokens = StudioTokens.of(context);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: tokens.bgInset.withValues(alpha: 0.58),
        borderRadius: BorderRadius.circular(StudioSpacing.radiusCard),
        border: Border.all(color: tokens.surfaceHighlight),
      ),
      child: Padding(
        padding: const EdgeInsets.all(StudioSpacing.xs),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            StudioUtilityIconButton(
              key: const Key('studio-app-bar-notifications'),
              label: l10n.studioAppBarNotifications,
              icon: Icons.notifications_outlined,
              selected: selectedPane == ProductWorkspacePane.notifications,
              badge: unreadNotifications > 0 ? unreadNotifications : null,
              onPressed: () => onSelectPane(ProductWorkspacePane.notifications),
            ),
            const SizedBox(width: StudioSpacing.chromeActionGap),
            StudioUtilityIconButton(
              label: l10n.studioAppBarSettings,
              icon: Icons.settings_outlined,
              selected: selectedPane == ProductWorkspacePane.account,
              onPressed: () => onSelectPane(ProductWorkspacePane.account),
            ),
            const SizedBox(width: StudioSpacing.chromeActionGap),
            StudioUtilityIconButton(
              label: l10n.studioAppBarHelp,
              icon: Icons.help_outline,
              selected: selectedPane == ProductWorkspacePane.helpHub,
              onPressed: () => onSelectPane(ProductWorkspacePane.helpHub),
            ),
          ],
        ),
      ),
    );
  }
}
