import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'controller.dart';
import 'previews.dart';
import 'support.dart';
import 'workbench_view.dart';
import '../../rust_api.dart';
import '../local_prefs/risky_operation_confirm_prefs.dart';
import '../config.dart';

part 'section_workbench.dart';
part 'section_workbench_controllers.dart';

class QualityReviewsSection extends StatelessWidget {
  const QualityReviewsSection({
    super.key,
    required this.accessToken,
    required this.controller,
    required this.initialProjectNumericId,
    required this.platformConfig,
  });

  final String? accessToken;
  final QualityReviewsController controller;
  final int? initialProjectNumericId;
  final PlatformConfigToggleSetV1 platformConfig;

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
        initialProjectNumericId: initialProjectNumericId,
        initialReviews: controller.qualityReviews ?? const <QualityReview>[],
        initialReviewDetails: controller.qualityReviewByIdLine,
        initialStatsSummary: controller.qualityStatsLine,
        initialStagePassRateSummary: controller.qualityStagePassRateLine,
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
      builder: (context, _) => SingleChildScrollView(
        padding: const EdgeInsets.only(top: 16, bottom: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    '质量评审',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
                const RiskyOperationConfirmPrefsOverflowMenu(
                  tooltip: '本机客户端偏好',
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '查看评审列表、坏例与阶段通过率；低分坏例会回写负向记忆，高分通过会晋升正向记忆。',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: outline),
            ),
            const SizedBox(height: 8),
            QualityReviewsActionsBar(
              showDashboardControls: platformConfig.qualityDashboardEnabled,
              showRefreshControls: platformConfig.qualityRefreshControlsEnabled,
              loadingQualityDashboard: controller.loadingQualityDashboard,
              refreshingQualityDashboardReadModel:
                  controller.refreshingQualityDashboardReadModel,
              loadingQualityReviews: controller.loadingQualityReviews,
              loadingQualityBadCases: controller.loadingQualityBadCases,
              loadingQualityStats: controller.loadingQualityStats,
              loadingQualityStagePassRate: controller.loadingQualityStagePassRate,
              onOpenWorkbench: () => _openQualityWorkbench(context),
              onLoadQualityDashboard: () => controller.loadQualityDashboard(
                projectId: initialProjectNumericId,
              ),
              onRefreshQualityDashboardReadModel: () =>
                  controller.loadQualityDashboard(
                    projectId: initialProjectNumericId,
                    refreshReadModel: true,
                  ),
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
            if (platformConfig.qualityDashboardEnabled) ...[
              const SizedBox(height: 8),
              Text('质量运营看板', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 6),
              if (controller.qualityDashboardLine != null)
                Align(
                  alignment: Alignment.centerLeft,
                  child: OutlinedButton(
                    onPressed: () async {
                      await Clipboard.setData(
                        ClipboardData(text: controller.qualityDashboardLine!),
                      );
                      if (!context.mounted) {
                        return;
                      }
                      ScaffoldMessenger.of(
                        context,
                      ).showSnackBar(const SnackBar(content: Text('已复制质量看板摘要')));
                    },
                    child: const Text('复制看板摘要'),
                  ),
                ),
              QualityReviewsOpsDashboardPreview(
                outlineColor: outline,
                dashboardSummary: controller.qualityDashboardLine,
                refreshControlsEnabled:
                    platformConfig.qualityRefreshControlsEnabled,
                refreshSummary: platformConfig.qualityRefreshControlsEnabled
                    ? controller.qualityDashboardRefreshLine
                    : null,
                freshnessSummary: controller.qualityDashboardFreshnessLine,
                qualityStatsRows: controller.qualityStatsRows,
                stageGradeRows: controller.qualityStageGradeRows,
                scopeInsightRows: controller.qualityScopeInsightRows,
                tokenEfficiencyRows: controller.qualityTokenEfficiencyRows,
                badCaseStats: controller.qualityBadCaseStatItems,
              ),
            ],
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
            if (controller.qualityStageGradeLine != null) ...[
              const SizedBox(height: 8),
              SelectableText('阶段等级分布：${controller.qualityStageGradeLine}'),
            ],
            if (controller.qualityScopeInsightsLine != null) ...[
              const SizedBox(height: 8),
              SelectableText('Scope榜单：${controller.qualityScopeInsightsLine}'),
            ],
            if (controller.qualityTokenEfficiencyLine != null) ...[
              const SizedBox(height: 8),
              SelectableText('Token效率：${controller.qualityTokenEfficiencyLine}'),
            ],
            if (controller.qualityBadCaseStatsLine != null) ...[
              const SizedBox(height: 8),
              SelectableText('坏例热点：${controller.qualityBadCaseStatsLine}'),
            ],
            if (controller.qualityReviews != null) ...[
              QualityReviewsListPreview(
                reviews: controller.qualityReviews!,
                onSelectQualityReview: controller.selectQualityReview,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
