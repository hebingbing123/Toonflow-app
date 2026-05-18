import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../shell/navigation_controller.dart';

/// Top-bar utility actions: notifications, settings, help.
class StudioAppBarActions extends StatelessWidget {
  const StudioAppBarActions({
    super.key,
    required this.selectedPane,
    required this.unreadNotifications,
    required this.onSelectPane,
  });

  final ProductWorkspacePane selectedPane;
  final int unreadNotifications;
  final ValueChanged<ProductWorkspacePane> onSelectPane;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        _UtilityIconButton(
          tooltip: l10n.studioAppBarNotifications,
          icon: Icons.notifications_outlined,
          selected: selectedPane == ProductWorkspacePane.notifications,
          badge: unreadNotifications > 0 ? unreadNotifications : null,
          onPressed: () => onSelectPane(ProductWorkspacePane.notifications),
        ),
        _UtilityIconButton(
          tooltip: l10n.studioAppBarSettings,
          icon: Icons.settings_outlined,
          selected: selectedPane == ProductWorkspacePane.account,
          onPressed: () => onSelectPane(ProductWorkspacePane.account),
        ),
        _UtilityIconButton(
          tooltip: l10n.studioAppBarHelp,
          icon: Icons.help_outline,
          selected: selectedPane == ProductWorkspacePane.helpHub,
          onPressed: () => onSelectPane(ProductWorkspacePane.helpHub),
        ),
        const SizedBox(width: 4),
        VerticalDivider(
          width: 1,
          thickness: 1,
          indent: 14,
          endIndent: 14,
          color: theme.dividerColor.withValues(alpha: 0.35),
        ),
        const SizedBox(width: 4),
      ],
    );
  }
}

class _UtilityIconButton extends StatelessWidget {
  const _UtilityIconButton({
    required this.tooltip,
    required this.icon,
    required this.selected,
    required this.onPressed,
    this.badge,
  });

  final String tooltip;
  final IconData icon;
  final bool selected;
  final VoidCallback onPressed;
  final int? badge;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final iconWidget = Icon(
      icon,
      size: 21,
      color: selected ? colorScheme.primary : null,
    );

    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      constraints: const BoxConstraints.tightFor(width: 44, height: 44),
      style: selected
          ? IconButton.styleFrom(
              backgroundColor: colorScheme.primary.withValues(alpha: 0.12),
            )
          : null,
      icon: badge == null
          ? iconWidget
          : Badge(label: Text('$badge'), child: iconWidget),
    );
  }
}
