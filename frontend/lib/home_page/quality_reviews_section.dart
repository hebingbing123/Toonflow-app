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
    final outline = Theme.of(context).colorScheme.outline;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        Text('质量评审', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        Text(
          '查看评审列表、坏例与阶段通过率，并按 ID 打开单条记录。',
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: outline),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
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
        ),
        const SizedBox(height: 8),
        ExpansionTile(
          tilePadding: EdgeInsets.zero,
          childrenPadding: EdgeInsets.zero,
          title: const Text('兼容性检查'),
          subtitle: Text(
            '保留质量评审回归创建入口，默认折叠',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: outline),
          ),
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Legacy review probe',
                style: Theme.of(
                  context,
                ).textTheme.labelSmall?.copyWith(color: outline),
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.tonal(
                  onPressed: creatingQualityReview
                      ? null
                      : onCreateQualityReviewProbe,
                  child: Text(creatingQualityReview ? '…' : '创建回归评审'),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 8),
        TextField(
          controller: qualityReviewIdController,
          onChanged: onQualityReviewIdChanged,
          decoration: const InputDecoration(labelText: '评审 ID（点下方列表可自动填入）'),
        ),
        const SizedBox(height: 8),
        FilledButton.tonal(
          onPressed:
              (loadingQualityReviewById ||
                  qualityReviewIdController.text.trim().isEmpty)
              ? null
              : onFetchQualityReviewById,
          child: Text(loadingQualityReviewById ? '…' : '查看评审详情'),
        ),
        if (qualityReviewByIdLine != null) ...[
          const SizedBox(height: 8),
          SelectableText('评审详情：$qualityReviewByIdLine'),
        ],
        if (qualityStatsLine != null) ...[
          const SizedBox(height: 8),
          SelectableText('质量统计：$qualityStatsLine'),
        ],
        if (qualityStagePassRateLine != null) ...[
          const SizedBox(height: 8),
          SelectableText('阶段通过率：$qualityStagePassRateLine'),
        ],
        if (qualityReviews != null) ...[
          const SizedBox(height: 8),
          Text(
            '${qualityReviews!.length} 条评审',
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
