import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import 'studio_text_styles.dart';

/// Collapsible filter / action toolbar for Studio list panes.
///
/// Defaults collapsed so list content stays primary; expands on tap (PC / web).
/// Set [collapsible] to false for harness layouts that need filters always visible.
class StudioCollapsibleFilterPanel extends StatelessWidget {
  const StudioCollapsibleFilterPanel({
    super.key,
    required this.child,
    this.title,
    this.subtitle,
    this.initiallyExpanded = false,
    this.collapsible = true,
  });

  final Widget child;
  final String? title;
  final String? subtitle;

  /// Filter panels stay collapsed until the user expands them.
  final bool initiallyExpanded;

  /// When false, [child] is shown inline (non-Studio / QA harness).
  final bool collapsible;

  @override
  Widget build(BuildContext context) {
    if (!collapsible) {
      return child;
    }
    final l10n = AppLocalizations.of(context)!;
    final panelTitle = title ?? l10n.studioFilterToolbarTitle;
    final summary = subtitle?.trim();
    // Flutter 3.44+: ListTile needs a Material ancestor before any colored DecoratedBox.
    return Material(
      type: MaterialType.transparency,
      child: ExpansionTile(
        key: const Key('studio_collapsible_filter_panel'),
        initiallyExpanded: initiallyExpanded,
        tilePadding: EdgeInsets.zero,
        childrenPadding: const EdgeInsets.only(bottom: 8),
        title: Text(panelTitle),
        subtitle: summary != null && summary.isNotEmpty
            ? Text(
                summary,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: studioHintStyle(context),
              )
            : null,
        children: <Widget>[child],
      ),
    );
  }
}
