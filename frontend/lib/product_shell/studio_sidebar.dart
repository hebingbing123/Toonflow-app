import 'package:flutter/material.dart';

import '../design_system/components/openflow_brand.dart';
import '../design_system/components/studio_text_styles.dart';
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
              extended ? 20 : 12,
              20,
              extended ? 20 : 12,
              16,
            ),
            child: extended
                ? _BrandHeader(appTitle: appTitle)
                : const Center(child: OpenFlowBrandMark(size: 36)),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              itemCount: destinations.length,
              itemBuilder: (context, index) {
                final dest = destinations[index];
                final selected = index == selectedIndex;
                final isNotifications =
                    dest.pane == ProductWorkspacePane.notifications;
                final badge = isNotifications && unreadNotifications > 0
                    ? unreadNotifications
                    : null;
                return _SidebarTile(
                  extended: extended,
                  selected: selected,
                  icon: selected ? dest.selectedIcon : dest.icon,
                  label: dest.label(AppLocalizations.of(context)!),
                  badge: badge,
                  onTap: () => onSelect(index),
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
    return Row(
      children: <Widget>[
        const OpenFlowBrandMark(size: 40),
        const SizedBox(width: 12),
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
                )?.copyWith(color: Colors.white, fontWeight: FontWeight.w700),
              ),
              Text(
                'Studio',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Colors.white.withValues(alpha: 0.5),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SidebarTile extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final bg = selected
        ? const Color(0xFF6C5CE7).withValues(alpha: 0.22)
        : Colors.transparent;
    final fg = selected ? Colors.white : Colors.white.withValues(alpha: 0.58);

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Material(
        color: bg,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: extended ? 12 : 8,
              vertical: 10,
            ),
            child: extended
                ? Row(
                    children: <Widget>[
                      Icon(icon, color: fg, size: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.labelMedium
                              ?.copyWith(
                                color: fg,
                                fontWeight: selected
                                    ? FontWeight.w600
                                    : FontWeight.w500,
                              ),
                        ),
                      ),
                      if (badge != null)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFF6B6B),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            badge! > 99 ? '99+' : '$badge',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                    ],
                  )
                : Tooltip(
                    message: label,
                    child: Icon(icon, color: fg, size: 22),
                  ),
          ),
        ),
      ),
    );
  }
}
