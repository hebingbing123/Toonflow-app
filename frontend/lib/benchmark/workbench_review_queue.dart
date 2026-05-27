import 'package:flutter/material.dart';
import 'package:openflow_app/design_system/components/studio_empty_state.dart';
import 'package:openflow_app/design_system/components/studio_surfaces.dart';
import 'package:openflow_app/design_system/tokens.dart';

import '../rust_api.dart';
import 'package:openflow_app/design_system/ix/studio_context_menu.dart';

/// Widget for managing benchmark review queue
class BenchmarkReviewQueueWorkbench extends StatelessWidget {
  const BenchmarkReviewQueueWorkbench({
    super.key,
    required this.reviewQueue,
    required this.reviewQueueIdController,
    required this.reviewScoreJsonController,
    required this.reviewSkipReasonController,
    required this.busy,
    required this.onFetchReviewQueue,
    required this.onSubmitReview,
    required this.onSkipReview,
    required this.onReviewSelected,
  });

  final List<ReviewQueueItemV1> reviewQueue;
  final TextEditingController reviewQueueIdController;
  final TextEditingController reviewScoreJsonController;
  final TextEditingController reviewSkipReasonController;
  final bool busy;
  final VoidCallback onFetchReviewQueue;
  final VoidCallback onSubmitReview;
  final VoidCallback onSkipReview;
  final ValueChanged<String> onReviewSelected;

  @override
  Widget build(BuildContext context) {
    final l10n = resolveAppLocalizationsForErrors(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(StudioSpacing.sm),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    l10n.benchmarkReviewCardTitle,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
                FilledButton.tonal(
                  style: studioFormTonalButtonStyle(context),
                  onPressed: busy ? null : onFetchReviewQueue,
                  child: Text(l10n.benchmarkActionFetchReviewQueue),
                ),
              ],
            ),
            const SizedBox(height: StudioSpacing.xs),
            TextField(
              controller: reviewQueueIdController,
              decoration: InputDecoration(
                labelText: l10n.benchmarkLabelReviewQueueId,
              ),
            ),
            const SizedBox(height: StudioSpacing.xs),
            TextField(
              controller: reviewScoreJsonController,
              maxLines: 6,
              decoration: InputDecoration(
                labelText: l10n.benchmarkLabelSubmittedScoreJson,
              ),
            ),
            const SizedBox(height: StudioSpacing.xs),
            FilledButton.tonal(
              style: studioFormTonalButtonStyle(context),
              onPressed: busy || reviewQueueIdController.text.trim().isEmpty
                  ? null
                  : onSubmitReview,
              child: Text(l10n.benchmarkActionSubmitReview),
            ),
            const SizedBox(height: StudioSpacing.sm),
            TextField(
              controller: reviewSkipReasonController,
              decoration: InputDecoration(
                labelText: l10n.benchmarkLabelSkipReasonOptional,
              ),
            ),
            const SizedBox(height: StudioSpacing.xs),
            FilledButton.tonal(
              style: studioFormTonalButtonStyle(context),
              onPressed: busy || reviewQueueIdController.text.trim().isEmpty
                  ? null
                  : onSkipReview,
              child: Text(l10n.benchmarkActionSkipReview),
            ),
            const SizedBox(height: StudioSpacing.sm),
            if (reviewQueue.isEmpty)
              StudioEmptyState.emptyData(
                title: l10n.benchmarkSummaryReviewQueueEmpty,
                icon: Icons.fact_check_outlined,
                actionLabel: l10n.benchmarkActionFetchReviewQueue,
                onAction: busy ? null : onFetchReviewQueue,
              )
            else ...[
              Text(
                l10n.benchmarkSummaryReviewQueue(
                  reviewQueue.length,
                  reviewQueue.where((item) => item.status == 'pending').length,
                ),
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: StudioSpacing.xs),
              ...reviewQueue.take(5).map(
                    (item) => StudioListRow(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        '${item.reviewType} · ${item.status} · P${item.priority}',
                      ),
                      subtitle: Text(
                        item.prompt,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      onTap: () => onReviewSelected(item.id),
                    ),
                  ),
            ],
          ],
        ),
      ),
    );
  }
}
