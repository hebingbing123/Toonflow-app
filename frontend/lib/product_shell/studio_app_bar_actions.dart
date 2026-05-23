import 'package:flutter/material.dart';

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
          _UtilityIconButton(
            key: const Key('studio-app-bar-notifications'),
            dense: true,
            tooltip: l10n.studioAppBarNotifications,
            icon: Icons.notifications_rounded,
            selected: selectedPane == ProductWorkspacePane.notifications,
            badge: unreadNotifications > 0 ? unreadNotifications : null,
            onPressed: () => onSelectPane(ProductWorkspacePane.notifications),
          ),
          _UtilityIconButton(
            dense: true,
            tooltip: l10n.studioAppBarSettings,
            icon: Icons.settings_rounded,
            selected: selectedPane == ProductWorkspacePane.account,
            onPressed: () => onSelectPane(ProductWorkspacePane.account),
          ),
          _UtilityIconButton(
            dense: true,
            tooltip: l10n.studioAppBarHelp,
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
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: tokens.surfaceHighlight),
      ),
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            _UtilityIconButton(
              key: const Key('studio-app-bar-notifications'),
              tooltip: l10n.studioAppBarNotifications,
              icon: Icons.notifications_outlined,
              selected: selectedPane == ProductWorkspacePane.notifications,
              badge: unreadNotifications > 0 ? unreadNotifications : null,
              onPressed: () => onSelectPane(ProductWorkspacePane.notifications),
            ),
            const SizedBox(width: StudioSpacing.chromeActionGap),
            _UtilityIconButton(
              tooltip: l10n.studioAppBarSettings,
              icon: Icons.settings_outlined,
              selected: selectedPane == ProductWorkspacePane.account,
              onPressed: () => onSelectPane(ProductWorkspacePane.account),
            ),
            const SizedBox(width: StudioSpacing.chromeActionGap),
            _UtilityIconButton(
              tooltip: l10n.studioAppBarHelp,
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

class _UtilityIconButton extends StatelessWidget {
  const _UtilityIconButton({
    super.key,
    required this.tooltip,
    required this.icon,
    required this.onPressed,
    required this.selected,
    this.dense = false,
    this.badge,
  });

  final String tooltip;
  final IconData icon;
  final bool selected;
  final bool dense;
  final VoidCallback onPressed;
  final int? badge;

  @override
  Widget build(BuildContext context) {
    final tokens = StudioTokens.of(context);
    final borderRadius = BorderRadius.circular(dense ? 4 : 12);
    final iconSize = dense ? 17.0 : 21.0;
    final boxSize = dense ? 28.0 : StudioSpacing.iconTouchTarget + 8.0;
    final iconWidget = Icon(
      icon,
      size: iconSize,
      fill: dense ? 0.35 : 0.0,
      weight: dense ? 500 : 400,
      semanticLabel: tooltip,
      color: selected
          ? tokens.primary
          : tokens.textSecondary.withValues(alpha: dense ? 0.86 : 1.0),
    );

    return Tooltip(
      message: tooltip,
      waitDuration: const Duration(milliseconds: 350),
      child: Material(
        color: Colors.transparent,
        borderRadius: borderRadius,
        child: Ink(
          width: boxSize,
          height: boxSize,
          decoration: dense
              ? null
              : BoxDecoration(
                  color: selected
                      ? tokens.primarySoft.withValues(alpha: 0.92)
                      : tokens.bgSurface.withValues(alpha: 0.72),
                  borderRadius: borderRadius,
                  border: selected
                      ? Border.all(color: tokens.primary.withValues(alpha: 0.45))
                      : null,
                ),
          child: InkWell(
            onTap: onPressed,
            borderRadius: borderRadius,
            hoverColor: dense
                ? tokens.bgInset.withValues(alpha: 0.65)
                : null,
            child: Stack(
              clipBehavior: Clip.none,
              children: <Widget>[
                Center(child: iconWidget),
                if (badge != null)
                  Positioned(
                    top: dense ? 2 : 7,
                    right: dense ? 2 : 6,
                    child: _UtilityBadge(value: badge!, dense: dense),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _UtilityBadge extends StatelessWidget {
  const _UtilityBadge({required this.value, this.dense = false});

  final int value;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final tokens = StudioTokens.of(context);
    return Container(
      constraints: BoxConstraints(
        minWidth: dense ? 12 : 16,
        minHeight: dense ? 12 : 16,
      ),
      padding: EdgeInsets.symmetric(
        horizontal: dense ? 2 : 4,
        vertical: dense ? 0 : 1,
      ),
      decoration: BoxDecoration(
        color: tokens.accent,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: tokens.bgInset.withValues(alpha: 0.92)),
      ),
      child: Center(
        child: Text(
          '$value',
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: Colors.black,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}
