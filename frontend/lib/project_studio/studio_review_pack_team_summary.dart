import 'package:flutter/material.dart';

import '../design_system/tokens.dart';
import '../l10n/app_localizations.dart';
import 'studio_review_pack_feedback.dart';

/// Rollup of team review-pack feedback across storyboard rows.
class StudioReviewPackTeamSummary extends StatelessWidget {
  const StudioReviewPackTeamSummary({
    super.key,
    required this.rollup,
  });

  final ReviewPackFeedbackRollup rollup;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final tokens = StudioTokens.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(StudioSpacing.sm, 0, StudioSpacing.sm, StudioSpacing.xs),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: StudioLayoutSpacing.insetDense, vertical: StudioLayoutSpacing.inlineGap),
        decoration: BoxDecoration(
          color: tokens.bgInset,
          borderRadius: BorderRadius.circular(StudioSpacing.radiusButton),
          border: Border.all(color: tokens.borderSubtle),
        ),
        child: Text(
          l10n.studioReviewPackTeamSummaryLine(
            rollup.approved,
            rollup.needsChanges,
            rollup.flagged,
            rollup.pending,
          ),
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: StudioTokens.of(context).textSecondary,
            height: 1.35,
          ),
        ),
      ),
    );
  }
}
