import 'package:flutter/material.dart';

import '../design_system/theme.dart';
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
  });

  final ProductWorkspacePane selectedPane;
  final int unreadNotifications;
  final ValueChanged<ProductWorkspacePane> onSelectPane;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
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
    final tokens = StudioTokens.of(context);
    final studio = StudioColors.of(context);
    final borderRadius = BorderRadius.circular(12);
    final iconWidget = Icon(
      icon,
      size: 21,
      color: selected ? Colors.white : tokens.textSecondary,
    );

    return Tooltip(
      message: tooltip,
      waitDuration: const Duration(milliseconds: 350),
      child: Material(
        color: Colors.transparent,
        borderRadius: borderRadius,
        child: Ink(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            gradient: selected ? studio.signalGradient : null,
            color: selected ? null : tokens.bgSurface.withValues(alpha: 0.72),
            borderRadius: borderRadius,
            border: selected
                ? Border.all(
                    color: tokens.accent.withValues(alpha: 0.42),
                  )
                : null,
            boxShadow: selected
                ? <BoxShadow>[
                    BoxShadow(
                      color: tokens.panelGlowSecondary.withValues(alpha: 0.18),
                      blurRadius: 18,
                      spreadRadius: -10,
                      offset: const Offset(0, 10),
                    ),
                  ]
                : const <BoxShadow>[],
          ),
          child: InkWell(
            onTap: onPressed,
            borderRadius: borderRadius,
            child: Stack(
              clipBehavior: Clip.none,
              children: <Widget>[
                Center(child: iconWidget),
                if (badge != null)
                  Positioned(
                    top: 7,
                    right: 6,
                    child: _UtilityBadge(value: badge!),
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
  const _UtilityBadge({required this.value});

  final int value;

  @override
  Widget build(BuildContext context) {
    final tokens = StudioTokens.of(context);
    return Container(
      constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
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
