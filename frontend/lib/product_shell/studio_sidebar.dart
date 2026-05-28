import 'package:flutter/material.dart';

import '../design_system/components/openflow_brand.dart';
import '../design_system/components/studio_text_styles.dart';
import '../design_system/components/studio_entrance_motion.dart';
import '../design_system/tokens.dart';
import '../l10n/app_localizations.dart';
import '../shell/navigation_controller.dart';
import 'navigation.dart';
import 'studio_theme.dart';

/// Dark studio sidebar with brand header (product shell only).
class StudioSidebar extends StatelessWidget {
  const StudioSidebar({
    super.key,
    required this.extended,
    required this.destinations,
    required this.selectedIndex,
    required this.onSelect,
    required this.appTitle,
    this.unreadNotifications = 0,
  });

  final bool extended;
  final List<ProductShellDestination> destinations;
  final int selectedIndex;
  final ValueChanged<int> onSelect;
  final String appTitle;
  final int unreadNotifications;

  @override
  Widget build(BuildContext context) {
    final studio = StudioColors.of(context);
    final width = extended ? 220.0 : 72.0;

    return Container(
      width: width,
      decoration: BoxDecoration(
        color: studio.sidebar,
        border: Border(right: BorderSide(color: studio.sidebarBorder)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Padding(
            padding: EdgeInsets.fromLTRB(
              extended ? StudioSpacing.sm : StudioSpacing.xs + 4,
              StudioSpacing.sm,
              extended ? StudioSpacing.sm : StudioSpacing.xs + 4,
              StudioSpacing.sm,
            ),
            child: extended
                ? _BrandHeader(appTitle: appTitle)
                : const Center(child: OpenFlowBrandMark(size: 36)),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: StudioSpacing.xs),
              itemCount: destinations.length,
              itemBuilder: (context, index) {
                final dest = destinations[index];
                final selected = index == selectedIndex;
                final isNotifications =
                    dest.pane == ProductWorkspacePane.notifications;
                final badge = isNotifications && unreadNotifications > 0
                    ? unreadNotifications
                    : null;
                return studioStaggeredItem(
                  index,
                  child: _SidebarTile(
                    extended: extended,
                    selected: selected,
                    icon: selected ? dest.selectedIcon : dest.icon,
                    label: dest.label(AppLocalizations.of(context)!),
                    badge: badge,
                    onTap: () => onSelect(index),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _BrandHeader extends StatelessWidget {
  const _BrandHeader({required this.appTitle});

  final String appTitle;

  @override
  Widget build(BuildContext context) {
    final tokens = StudioTokens.of(context);
    return Row(
      children: <Widget>[
        const OpenFlowBrandMark(size: 40),
        const SizedBox(width: StudioSpacing.xs + 4),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                appTitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: studioChromeTitleStyle(
                  context,
                )?.copyWith(color: tokens.textPrimary, fontWeight: FontWeight.w700),
              ),
              Text(
                'Studio',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: tokens.textMuted,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SidebarTile extends StatefulWidget {
  const _SidebarTile({
    required this.extended,
    required this.selected,
    required this.icon,
    required this.label,
    required this.onTap,
    this.badge,
  });

  final bool extended;
  final bool selected;
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final int? badge;

  @override
  State<_SidebarTile> createState() => _SidebarTileState();
}

class _SidebarTileState extends State<_SidebarTile> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final tokens = StudioTokens.of(context);
    final fg = widget.selected
        ? tokens.textPrimary
        : (_hovered ? tokens.textSecondary : tokens.textMuted);
    final bg = widget.selected
        ? tokens.primarySoft.withValues(alpha: 0.72)
        : (_hovered
              ? tokens.primary.withValues(alpha: 0.08)
              : StudioPrimitives.transparent);
    final border = widget.selected
        ? Border(
            left: BorderSide(color: tokens.primary, width: 3),
          )
        : (_hovered && !widget.extended
              ? Border.all(
                  color: tokens.primary.withValues(alpha: 0.35),
                  width: 1,
                )
              : null);

    return Padding(
      padding: const EdgeInsets.only(bottom: StudioSpacing.chromeActionGap),
      child: Material(
        color: bg,
        borderRadius: BorderRadius.circular(StudioSpacing.radiusButton),
        child: InkWell(
          onTap: widget.onTap,
          onHover: (hovered) {
            if (_hovered != hovered) {
              setState(() => _hovered = hovered);
            }
          },
          borderRadius: BorderRadius.circular(StudioSpacing.radiusButton),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(StudioSpacing.radiusButton),
              border: border,
            ),
            constraints: widget.extended
                ? null
                : const BoxConstraints(
                    minWidth: StudioSpacing.navItemTouchTarget,
                    minHeight: StudioSpacing.navItemTouchTarget,
                  ),
            padding: EdgeInsets.symmetric(
              horizontal: widget.extended ? StudioSpacing.sm : 0,
              vertical: widget.extended ? StudioSpacing.xs : 0,
            ),
            child: widget.extended
                ? Row(
                    children: <Widget>[
                      Icon(widget.icon, color: fg, size: StudioIconSize.md),
                      const SizedBox(width: StudioSpacing.sm),
                      Expanded(
                        child: Text(
                          widget.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.labelMedium
                              ?.copyWith(
                                color: fg,
                                fontWeight: widget.selected
                                    ? FontWeight.w600
                                    : FontWeight.w500,
                              ),
                        ),
                      ),
                      if (widget.badge != null)
                        _SidebarBadge(count: widget.badge!),
                    ],
                  )
                : Tooltip(
                    message: widget.label,
                    child: Center(
                      child: Icon(widget.icon, color: fg, size: StudioIconSize.xl),
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

class _SidebarBadge extends StatelessWidget {
  const _SidebarBadge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final tokens = StudioTokens.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: StudioSpacing.xs, vertical: StudioSpacing.chromeActionGap),
      decoration: BoxDecoration(
        color: tokens.danger,
        borderRadius: BorderRadius.circular(StudioSpacing.radiusButton),
      ),
      child: Text(
        count > 99 ? '99+' : '$count',
        style: studioBadgeTextStyle(context),
      ),
    );
  }
}
