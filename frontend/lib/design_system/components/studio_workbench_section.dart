import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../tokens.dart';
import '../studio_motion.dart';
import 'studio_surfaces.dart';
import 'studio_text_styles.dart';

/// Collapsible secondary block on dense workbench pages.
///
/// Keeps the primary editor/list in focus; diagnostics, starters, and
/// checklists expand on demand.
class StudioWorkbenchSection extends StatefulWidget {
  const StudioWorkbenchSection({
    super.key,
    required this.title,
    this.subtitle,
    required this.child,
    this.initiallyExpanded = false,
    this.expandTooltip,
    this.collapseTooltip,
  });

  final String title;
  final String? subtitle;
  final Widget child;

  /// Secondary panels default collapsed so content area wins (workbench IA).
  final bool initiallyExpanded;
  final String? expandTooltip;
  final String? collapseTooltip;

  @override
  State<StudioWorkbenchSection> createState() => _StudioWorkbenchSectionState();
}

class _StudioWorkbenchSectionState extends State<StudioWorkbenchSection> {
  late bool _expanded;

  @override
  void initState() {
    super.initState();
    _expanded = widget.initiallyExpanded;
  }

  @override
  void didUpdateWidget(covariant StudioWorkbenchSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initiallyExpanded != widget.initiallyExpanded &&
        !widget.initiallyExpanded) {
      _expanded = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = StudioTokens.of(context);
    final l10n = AppLocalizations.of(context)!;
    final expandTip = widget.expandTooltip ?? l10n.studioCockpitExpand;
    final collapseTip = widget.collapseTooltip ?? l10n.studioCockpitCollapse;

    return DecoratedBox(
      decoration: studioInsetPanelDecoration(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(StudioSpacing.radiusCard),
              onTap: () => setState(() => _expanded = !_expanded),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: StudioLayoutSpacing.insetDense,
                  vertical: StudioLayoutSpacing.inlineGap,
                ),
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            widget.title,
                            style: studioControlLabelStyle(context)?.copyWith(
                              color: tokens.textPrimary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          if (widget.subtitle != null &&
                              widget.subtitle!.trim().isNotEmpty) ...<Widget>[
                            const SizedBox(height: StudioSpacing.xs),
                            Text(
                              widget.subtitle!,
                              maxLines: _expanded ? 3 : 1,
                              overflow: TextOverflow.ellipsis,
                              style: studioHintStyle(context),
                            ),
                          ],
                        ],
                      ),
                    ),
                    IconButton(
                      key: const Key('studio_workbench_section_toggle'),
                      style: studioUtilityIconButtonStyle(context),
                      tooltip: _expanded ? collapseTip : expandTip,
                      onPressed: () => setState(() => _expanded = !_expanded),
                      icon: Icon(
                        _expanded ? Icons.expand_less : Icons.expand_more,
                        color: tokens.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          AnimatedCrossFade(
            firstChild: const SizedBox(width: double.infinity),
            secondChild: Padding(
              padding: const EdgeInsets.fromLTRB(
                StudioLayoutSpacing.insetDense,
                0,
                StudioLayoutSpacing.insetDense,
                StudioLayoutSpacing.insetDense,
              ),
              child: widget.child,
            ),
            crossFadeState: _expanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: studioAnimationDuration(
              context,
              const Duration(milliseconds: 180),
            ),
            sizeCurve: studioAnimationCurve(context, Curves.easeOut),
          ),
        ],
      ),
    );
  }
}
