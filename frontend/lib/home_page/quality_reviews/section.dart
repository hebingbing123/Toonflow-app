import 'package:flutter/material.dart';

import 'previews.dart';
import 'support.dart';
import '../../rust_api.dart';

part 'workbench.dart';

class QualityReviewsSection extends StatelessWidget {
  const QualityReviewsSection({
    super.key,
    required this.accessToken,
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

  final String? accessToken;
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

  Future<void> _openQualityWorkbench(BuildContext context) async {
    final token = accessToken;
    if (token == null || token.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('当前未登录，无法读取质量评审')));
      return;
    }
    await showDialog<void>(
      context: context,
      builder: (dialogCtx) => _QualityReviewsWorkbenchDialog(
        accessToken: token,
        initialReviews: qualityReviews ?? const <QualityReview>[],
        initialReviewDetails: qualityReviewByIdLine,
        initialStatsSummary: qualityStatsLine,
        initialStagePassRateSummary: qualityStagePassRateLine,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final outline = Theme.of(context).colorScheme.outline;
    final reviewSummary = qualityReviews == null
        ? '尚未加载评审列表'
        : summarizeQualityReviews(qualityReviews!);
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
        QualityReviewsActionsBar(
          loadingQualityReviews: loadingQualityReviews,
          loadingQualityBadCases: loadingQualityBadCases,
          loadingQualityStats: loadingQualityStats,
          loadingQualityStagePassRate: loadingQualityStagePassRate,
          onOpenWorkbench: () => _openQualityWorkbench(context),
          onLoadQualityReviews: onLoadQualityReviews,
          onLoadQualityBadCases: onLoadQualityBadCases,
          onLoadQualityStats: onLoadQualityStats,
          onLoadQualityStagePassRate: onLoadQualityStagePassRate,
        ),
        const SizedBox(height: 8),
        QualityReviewsSummaryPreview(
          outlineColor: outline,
          reviewSummary: reviewSummary,
        ),
        const SizedBox(height: 8),
        QualityReviewsCompatibilityPanel(
          outlineColor: outline,
          creatingQualityReview: creatingQualityReview,
          onCreateQualityReviewProbe: onCreateQualityReviewProbe,
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
          QualityReviewsListPreview(
            reviews: qualityReviews!,
            onSelectQualityReview: onSelectQualityReview,
          ),
        ],
      ],
    );
  }
}
