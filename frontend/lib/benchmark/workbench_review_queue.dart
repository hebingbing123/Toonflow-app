import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../rust_api.dart';

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
    final l10n = AppLocalizations.of(context)!;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.benchmarkReviewCardTitle,
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: reviewQueueIdController,
              decoration: InputDecoration(
                labelText: l10n.benchmarkLabelReviewQueueId,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: reviewScoreJsonController,
              maxLines: 6,
              decoration: InputDecoration(
                labelText: l10n.benchmarkLabelSubmittedScoreJson,
              ),
            ),
            const SizedBox(height: 8),
            FilledButton.tonal(
              onPressed: busy || reviewQueueIdController.text.trim().isEmpty
                  ? null
                  : onSubmitReview,
              child: Text(l10n.benchmarkActionSubmitReview),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: reviewSkipReasonController,
              decoration: InputDecoration(
                labelText: l10n.benchmarkLabelSkipReasonOptional,
              ),
            ),
            const SizedBox(height: 8),
            FilledButton.tonal(
              onPressed: busy || reviewQueueIdController.text.trim().isEmpty
                  ? null
                  : onSkipReview,
              child: Text(l10n.benchmarkActionSkipReview),
            ),
            const SizedBox(height: 12),
            if (reviewQueue.isNotEmpty) ...[
              Text(
                l10n.benchmarkSummaryReviewQueue(
                  reviewQueue.length,
                  reviewQueue.where((item) => item.status == 'pending').length,
                ),
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 8),
              ...reviewQueue.take(5).map(
                    (item) => ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        '${item.reviewType} · ${item.status} · P${item.priority}',
                      ),
                      subtitle: Text(item.prompt),
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
