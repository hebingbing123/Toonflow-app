import 'package:flutter/material.dart';

import '../design_system/components/studio_toolbar_button.dart';
import '../design_system/tokens.dart';
import '../l10n/app_localizations.dart';

/// Step ⑥ primary CTA: merge & preview (opens short-video assembly focus).
class StudioMergeDeliverBar extends StatelessWidget {
  const StudioMergeDeliverBar({
    super.key,
    required this.onMergeAndPreview,
    this.onOpenReviewPack,
    this.busy = false,
  });

  final VoidCallback? onMergeAndPreview;
  final VoidCallback? onOpenReviewPack;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final tokens = StudioTokens.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: StudioSpacing.xs),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: StudioLayoutSpacing.insetDense, vertical: StudioLayoutSpacing.inlineGap),
        decoration: BoxDecoration(
          color: tokens.bgSurface,
          borderRadius: BorderRadius.circular(StudioSpacing.radiusButton),
          border: Border.all(color: tokens.borderSubtle),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            LayoutBuilder(
              builder: (context, constraints) {
                final stacked = constraints.maxWidth < 760;
                final summary = Text(
                  l10n.studioDeliverTabAssembly,
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                );
                final action = StudioToolbarButton(
                  label: l10n.studioMergeAndPreview,
                  icon: Icons.movie_filter_outlined,
                  busy: busy,
                  primary: true,
                  onPressed: busy ? null : onMergeAndPreview,
                );
                if (stacked) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      summary,
                      const SizedBox(height: StudioLayoutSpacing.inlineGap),
                      action,
                    ],
                  );
                }
                return Row(
                  children: <Widget>[
                    Expanded(child: summary),
                    const SizedBox(width: StudioSpacing.sm),
                    Flexible(child: action),
                  ],
                );
              },
            ),
            if (onOpenReviewPack != null) ...<Widget>[
              const SizedBox(height: StudioSpacing.xs),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  onPressed: onOpenReviewPack,
                  child: Text(l10n.studioReviewPackFromDeliverLink),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
