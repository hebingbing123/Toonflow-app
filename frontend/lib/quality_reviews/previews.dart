import 'package:flutter/material.dart';

import '../../rust_api.dart';

/// Groups the section-level review actions above the detailed workbench flow.
class QualityReviewsActionsBar extends StatelessWidget {
  const QualityReviewsActionsBar({
    super.key,
    required this.showDashboardControls,
    required this.showRefreshControls,
    required this.loadingQualityDashboard,
    required this.refreshingQualityDashboardReadModel,
    required this.loadingQualityReviews,
    required this.loadingQualityBadCases,
    required this.loadingQualityStats,
    required this.loadingQualityStagePassRate,
    required this.onOpenWorkbench,
    required this.onLoadQualityDashboard,
    required this.onRefreshQualityDashboardReadModel,
    required this.onLoadQualityReviews,
    required this.onLoadQualityBadCases,
    required this.onLoadQualityStats,
    required this.onLoadQualityStagePassRate,
  });

  final bool showDashboardControls;
  final bool showRefreshControls;
  final bool loadingQualityDashboard;
  final bool refreshingQualityDashboardReadModel;
  final bool loadingQualityReviews;
  final bool loadingQualityBadCases;
  final bool loadingQualityStats;
  final bool loadingQualityStagePassRate;
  final VoidCallback onOpenWorkbench;
  final VoidCallback onLoadQualityDashboard;
  final VoidCallback onRefreshQualityDashboardReadModel;
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
        if (showDashboardControls)
          FilledButton(
            onPressed: loadingQualityDashboard ? null : onLoadQualityDashboard,
            child: Text(loadingQualityDashboard ? '…' : '读取当前看板'),
          ),
        if (showDashboardControls && showRefreshControls)
          FilledButton.tonal(
            onPressed: refreshingQualityDashboardReadModel
                ? null
                : onRefreshQualityDashboardReadModel,
            child: Text(refreshingQualityDashboardReadModel ? '…' : '刷新底层读模型'),
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

class QualityReviewsOpsDashboardPreview extends StatelessWidget {
  const QualityReviewsOpsDashboardPreview({
    super.key,
    required this.outlineColor,
    required this.dashboardSummary,
    required this.refreshSummary,
    required this.freshnessSummary,
    required this.qualityStatsRows,
    required this.stageGradeRows,
    required this.scopeInsightRows,
    required this.tokenEfficiencyRows,
    required this.badCaseStats,
  });

  final Color outlineColor;
  final String? dashboardSummary;
  final String? refreshSummary;
  final String? freshnessSummary;
  final List<QualityDashboardTargetStat>? qualityStatsRows;
  final List<QualityDashboardStageGradeItem>? stageGradeRows;
  final List<QualityDashboardScopeInsightItem>? scopeInsightRows;
  final List<QualityDashboardTokenEfficiencyItem>? tokenEfficiencyRows;
  final List<BadCaseStatItem>? badCaseStats;

  @override
  Widget build(BuildContext context) {
    final hasAnything =
        dashboardSummary != null ||
        refreshSummary != null ||
        freshnessSummary != null ||
        (qualityStatsRows?.isNotEmpty ?? false) ||
        (stageGradeRows?.isNotEmpty ?? false) ||
        (scopeInsightRows?.isNotEmpty ?? false) ||
        (tokenEfficiencyRows?.isNotEmpty ?? false) ||
        (badCaseStats?.isNotEmpty ?? false);
    if (!hasAnything) {
      return Text(
        '质量看板尚未加载。可直接刷新聚合统计、坏例热点、阶段分布与 token 效率。',
        style: Theme.of(
          context,
        ).textTheme.bodySmall?.copyWith(color: outlineColor),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (refreshSummary != null) ...[
          Text(
            refreshSummary!,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: outlineColor),
          ),
          const SizedBox(height: 8),
        ],
        if (freshnessSummary != null) ...[
          SelectableText(
            freshnessSummary!,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: outlineColor),
          ),
          const SizedBox(height: 8),
        ],
        if (dashboardSummary != null) ...[
          SelectableText(
            dashboardSummary!,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 8),
        ],
        if (qualityStatsRows?.isNotEmpty == true) ...[
          Text('目标类型', style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: qualityStatsRows!
                .take(4)
                .map(
                  (row) => Chip(
                    label: Text(
                      '${row.targetType} ${row.passRatePercent.toStringAsFixed(1)}% · ${row.totalReviews}条',
                    ),
                    visualDensity: VisualDensity.compact,
                  ),
                )
                .toList(growable: false),
          ),
          const SizedBox(height: 8),
        ],
        if (stageGradeRows?.isNotEmpty == true) ...[
          Text('阶段等级', style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: stageGradeRows!
                .take(4)
                .map(
                  (row) => Chip(
                    label: Text(
                      '${row.stage} A${row.gradeACount}/B${row.gradeBCount}/C${row.gradeCCount}/D${row.gradeDCount}',
                    ),
                    visualDensity: VisualDensity.compact,
                  ),
                )
                .toList(growable: false),
          ),
          const SizedBox(height: 8),
        ],
        if (badCaseStats?.isNotEmpty == true) ...[
          Text('坏例热点', style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: badCaseStats!
                .take(4)
                .map(
                  (row) => Chip(
                    label: Text('${row.badCaseCategory ?? "未分类"} ${row.count}'),
                    visualDensity: VisualDensity.compact,
                  ),
                )
                .toList(growable: false),
          ),
          const SizedBox(height: 8),
        ],
        if (scopeInsightRows?.isNotEmpty == true) ...[
          Text('Scope 榜单', style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 6),
          ...scopeInsightRows!
              .take(3)
              .map(
                (row) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    '${row.scopeLabel} · pass=${row.passRatePercent.toStringAsFixed(1)}% · total=${row.totalReviews} · bad_case=${row.badCaseCount}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ),
          const SizedBox(height: 8),
        ],
        if (tokenEfficiencyRows?.isNotEmpty == true) ...[
          Text('Token 效率', style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 6),
          ...tokenEfficiencyRows!
              .take(3)
              .map(
                (row) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    '${row.targetType} · prompt=${row.avgPromptChars.toStringAsFixed(0)} · memory=${row.avgMemoryStyleChars.toStringAsFixed(0)} · action=${row.memoryAction}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ),
        ],
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
      style: Theme.of(
        context,
      ).textTheme.bodySmall?.copyWith(color: outlineColor),
    );
  }
}

/// Keeps the quality review regression entry isolated from the main flow.
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
        '保留只读回归入口，确认评审列表与详情查询仍可正常工作',
        style: Theme.of(
          context,
        ).textTheme.bodySmall?.copyWith(color: outlineColor),
      ),
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: Text(
            'Quality review read probe',
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
              onPressed: creatingQualityReview
                  ? null
                  : onCreateQualityReviewProbe,
              child: Text(creatingQualityReview ? '…' : '运行只读回归检查'),
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
        Text(
          '${reviews.length} 条评审',
          style: Theme.of(context).textTheme.labelLarge,
        ),
        ...reviews
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
