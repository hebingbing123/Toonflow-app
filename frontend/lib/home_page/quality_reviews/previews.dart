import 'package:flutter/material.dart';

import '../../rust_api.dart';

/// Groups the section-level review actions above the detailed workbench flow.
class QualityReviewsActionsBar extends StatelessWidget {
  const QualityReviewsActionsBar({
    super.key,
    required this.loadingQualityReviews,
    required this.loadingQualityBadCases,
    required this.loadingQualityStats,
    required this.loadingQualityStagePassRate,
    required this.onOpenWorkbench,
    required this.onLoadQualityReviews,
    required this.onLoadQualityBadCases,
    required this.onLoadQualityStats,
    required this.onLoadQualityStagePassRate,
  });

  final bool loadingQualityReviews;
  final bool loadingQualityBadCases;
  final bool loadingQualityStats;
  final bool loadingQualityStagePassRate;
  final VoidCallback onOpenWorkbench;
  final VoidCallback onLoadQualityReviews;
  final VoidCallback onLoadQualityBadCases;
  final VoidCallback onLoadQualityStats;
  final VoidCallback onLoadQualityStagePassRate;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        FilledButton.tonal(
          onPressed: onOpenWorkbench,
          child: const Text('打开质量工作台'),
        ),
        FilledButton.tonal(
          onPressed: loadingQualityReviews ? null : onLoadQualityReviews,
          child: Text(loadingQualityReviews ? '…' : '加载评审列表'),
        ),
        FilledButton.tonal(
          onPressed: loadingQualityBadCases ? null : onLoadQualityBadCases,
          child: Text(loadingQualityBadCases ? '…' : '查看坏例'),
        ),
        FilledButton.tonal(
          onPressed: loadingQualityStats ? null : onLoadQualityStats,
          child: Text(loadingQualityStats ? '…' : '查看质量统计'),
        ),
        FilledButton.tonal(
          onPressed: loadingQualityStagePassRate
              ? null
              : onLoadQualityStagePassRate,
          child: Text(loadingQualityStagePassRate ? '…' : '查看阶段通过率'),
        ),
      ],
    );
  }
}

/// Renders the compact review summary lines shown before drill-down details.
class QualityReviewsSummaryPreview extends StatelessWidget {
  const QualityReviewsSummaryPreview({
    super.key,
    required this.outlineColor,
    required this.reviewSummary,
  });

  final Color outlineColor;
  final String reviewSummary;

  @override
  Widget build(BuildContext context) {
    return Text(
      reviewSummary,
      style: Theme.of(context).textTheme.bodySmall?.copyWith(color: outlineColor),
    );
  }
}

/// Keeps the legacy quality review regression entry isolated from the main flow.
class QualityReviewsCompatibilityPanel extends StatelessWidget {
  const QualityReviewsCompatibilityPanel({
    super.key,
    required this.outlineColor,
    required this.creatingQualityReview,
    required this.onCreateQualityReviewProbe,
  });

  final Color outlineColor;
  final bool creatingQualityReview;
  final VoidCallback onCreateQualityReviewProbe;

  @override
  Widget build(BuildContext context) {
    return ExpansionTile(
      tilePadding: EdgeInsets.zero,
      childrenPadding: EdgeInsets.zero,
      title: const Text('兼容性检查'),
      subtitle: Text(
        '保留质量评审回归创建入口，默认折叠',
        style: Theme.of(
          context,
        ).textTheme.bodySmall?.copyWith(color: outlineColor),
      ),
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: Text(
            'Legacy review probe',
            style: Theme.of(
              context,
            ).textTheme.labelSmall?.copyWith(color: outlineColor),
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FilledButton.tonal(
              onPressed: creatingQualityReview ? null : onCreateQualityReviewProbe,
              child: Text(creatingQualityReview ? '…' : '创建回归评审'),
            ),
          ],
        ),
      ],
    );
  }
}

/// Displays a short, tappable slice of review results for the section overview.
class QualityReviewsListPreview extends StatelessWidget {
  const QualityReviewsListPreview({
    super.key,
    required this.reviews,
    required this.onSelectQualityReview,
  });

  final List<QualityReview> reviews;
  final ValueChanged<QualityReview> onSelectQualityReview;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        Text('${reviews.length} 条评审', style: Theme.of(context).textTheme.labelLarge),
        ...reviews.take(8).map(
          (review) => ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            title: Text(
              '${review.targetType} · ${review.source} · score=${review.overallScore ?? "n/a"}',
            ),
            subtitle: Text(
              [
                review.id,
                if (review.targetId != null && review.targetId!.isNotEmpty)
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
    );
  }
}
