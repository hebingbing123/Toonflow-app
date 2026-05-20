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
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: tokens.bgInset,
          borderRadius: BorderRadius.circular(10),
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
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            height: 1.35,
          ),
        ),
      ),
    );
  }
}
