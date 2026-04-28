import 'package:flutter/material.dart';

import 'controller.dart';
import 'previews.dart';
import 'support.dart';
import 'workbench_view.dart';
import '../../rust_api.dart';

part 'section_workbench.dart';
part 'section_workbench_controllers.dart';

class QualityReviewsSection extends StatelessWidget {
  const QualityReviewsSection({
    super.key,
    required this.accessToken,
    required this.controller,
  });

  final String? accessToken;
  final QualityReviewsController controller;

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
        initialReviews: controller.qualityReviews ?? const <QualityReview>[],
        initialReviewDetails: controller.qualityReviewByIdLine,
        initialStatsSummary: controller.qualityStatsLine,
        initialStagePassRateSummary: controller.qualityStagePassRateLine,
        initialTokenEfficiencySummary: null,
        initialTokenEfficiencySampleSummary: null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final outline = Theme.of(context).colorScheme.outline;
    final reviewSummary = controller.qualityReviews == null
        ? '尚未加载评审列表'
        : summarizeQualityReviews(controller.qualityReviews!);
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) => Column(
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
            loadingQualityReviews: controller.loadingQualityReviews,
            loadingQualityBadCases: controller.loadingQualityBadCases,
            loadingQualityStats: controller.loadingQualityStats,
            loadingQualityStagePassRate: controller.loadingQualityStagePassRate,
            onOpenWorkbench: () => _openQualityWorkbench(context),
            onLoadQualityReviews: controller.loadQualityReviews,
            onLoadQualityBadCases: controller.loadQualityBadCases,
            onLoadQualityStats: controller.loadQualityStats,
            onLoadQualityStagePassRate: controller.loadQualityStagePassRate,
          ),
          const SizedBox(height: 8),
          QualityReviewsSummaryPreview(
            outlineColor: outline,
            reviewSummary: reviewSummary,
          ),
          const SizedBox(height: 8),
          QualityReviewsCompatibilityPanel(
            outlineColor: outline,
            creatingQualityReview: controller.creatingQualityReview,
            onCreateQualityReviewProbe: controller.createQualityReviewProbe,
          ),
          const SizedBox(height: 8),
          TextField(
            controller: controller.qualityReviewIdController,
            onChanged: controller.onQualityReviewIdChanged,
            decoration: const InputDecoration(labelText: '评审 ID（点下方列表可自动填入）'),
          ),
          const SizedBox(height: 8),
          FilledButton.tonal(
            onPressed:
                (controller.loadingQualityReviewById ||
                    controller.qualityReviewIdController.text.trim().isEmpty)
                ? null
                : controller.fetchSelectedQualityReview,
            child: Text(controller.loadingQualityReviewById ? '…' : '查看评审详情'),
          ),
          if (controller.qualityReviewByIdLine != null) ...[
            const SizedBox(height: 8),
            SelectableText('评审详情：${controller.qualityReviewByIdLine}'),
          ],
          if (controller.qualityStatsLine != null) ...[
            const SizedBox(height: 8),
            SelectableText('质量统计：${controller.qualityStatsLine}'),
          ],
          if (controller.qualityStagePassRateLine != null) ...[
            const SizedBox(height: 8),
            SelectableText('阶段通过率：${controller.qualityStagePassRateLine}'),
          ],
          if (controller.qualityReviews != null) ...[
            QualityReviewsListPreview(
              reviews: controller.qualityReviews!,
              onSelectQualityReview: controller.selectQualityReview,
            ),
          ],
        ],
      ),
    );
  }
}
