import 'package:flutter/material.dart';

import '../rust_api.dart';

class QualityReviewsSection extends StatelessWidget {
  const QualityReviewsSection({
    super.key,
    required this.loadingQualityReviews,
    required this.loadingQualityBadCases,
    required this.loadingQualityStats,
    required this.loadingQualityStagePassRate,
    required this.creatingQualityReview,
    required this.loadingQualityReviewById,
    required this.qualityReviewIdController,
    required this.qualityReviews,
    required this.qualityStatsLine,
    required this.qualityStagePassRateLine,
    required this.qualityReviewByIdLine,
    required this.onQualityReviewIdChanged,
    required this.onLoadQualityReviews,
    required this.onLoadQualityBadCases,
    required this.onLoadQualityStats,
    required this.onLoadQualityStagePassRate,
    required this.onCreateQualityReviewProbe,
    required this.onFetchQualityReviewById,
    required this.onSelectQualityReview,
  });

  final bool loadingQualityReviews;
  final bool loadingQualityBadCases;
  final bool loadingQualityStats;
  final bool loadingQualityStagePassRate;
  final bool creatingQualityReview;
  final bool loadingQualityReviewById;
  final TextEditingController qualityReviewIdController;
  final List<QualityReview>? qualityReviews;
  final String? qualityStatsLine;
  final String? qualityStagePassRateLine;
  final String? qualityReviewByIdLine;
  final ValueChanged<String> onQualityReviewIdChanged;
  final VoidCallback onLoadQualityReviews;
  final VoidCallback onLoadQualityBadCases;
  final VoidCallback onLoadQualityStats;
  final VoidCallback onLoadQualityStagePassRate;
  final VoidCallback onCreateQualityReviewProbe;
  final VoidCallback onFetchQualityReviewById;
  final ValueChanged<QualityReview> onSelectQualityReview;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        Text('Quality reviews', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FilledButton.tonal(
              onPressed: loadingQualityReviews ? null : onLoadQualityReviews,
              child: Text(
                loadingQualityReviews ? '…' : 'GET /api/v1/quality/reviews',
              ),
            ),
            FilledButton.tonal(
              onPressed: loadingQualityBadCases ? null : onLoadQualityBadCases,
              child: Text(
                loadingQualityBadCases
                    ? '…'
                    : 'GET …/quality/reviews?isBadCase=true',
              ),
            ),
            FilledButton.tonal(
              onPressed: loadingQualityStats ? null : onLoadQualityStats,
              child: Text(
                loadingQualityStats ? '…' : 'GET /api/v1/quality/stats',
              ),
            ),
            FilledButton.tonal(
              onPressed: loadingQualityStagePassRate
                  ? null
                  : onLoadQualityStagePassRate,
              child: Text(
                loadingQualityStagePassRate
                    ? '…'
                    : 'GET …/quality/stage-pass-rate',
              ),
            ),
            FilledButton.tonal(
              onPressed: creatingQualityReview
                  ? null
                  : onCreateQualityReviewProbe,
              child: Text(
                creatingQualityReview ? '…' : 'POST quality review probe',
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        TextField(
          controller: qualityReviewIdController,
          onChanged: onQualityReviewIdChanged,
          decoration: const InputDecoration(
            labelText: 'Quality review id (tap a row below to paste)',
          ),
        ),
        const SizedBox(height: 8),
        FilledButton.tonal(
          onPressed:
              (loadingQualityReviewById ||
                  qualityReviewIdController.text.trim().isEmpty)
              ? null
              : onFetchQualityReviewById,
          child: Text(
            loadingQualityReviewById ? '…' : 'GET /api/v1/quality/reviews/{id}',
          ),
        ),
        if (qualityReviewByIdLine != null) ...[
          const SizedBox(height: 8),
          SelectableText('review by id: $qualityReviewByIdLine'),
        ],
        if (qualityStatsLine != null) ...[
          const SizedBox(height: 8),
          SelectableText('stats: $qualityStatsLine'),
        ],
        if (qualityStagePassRateLine != null) ...[
          const SizedBox(height: 8),
          SelectableText('stage-pass-rate: $qualityStagePassRateLine'),
        ],
        if (qualityReviews != null) ...[
          const SizedBox(height: 8),
          Text(
            '${qualityReviews!.length} review(s)',
            style: Theme.of(context).textTheme.labelLarge,
          ),
          ...qualityReviews!
              .take(8)
              .map(
                (review) => ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    '${review.targetType} · ${review.source} · score=${review.overallScore ?? "n/a"}',
                  ),
                  subtitle: Text(
                    [
                      review.id,
                      if (review.targetId != null &&
                          review.targetId!.isNotEmpty)
                        'target=${review.targetId}',
                      if (review.passed != null) 'passed=${review.passed}',
                      if (review.isBadCase) 'bad_case',
                    ].join(' · '),
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => onSelectQualityReview(review),
                ),
              ),
        ],
      ],
    );
  }
}
