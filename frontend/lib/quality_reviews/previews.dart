import 'package:flutter/material.dart';

import '../design_system/components/studio_empty_state.dart';
import '../design_system/components/studio_filter_row.dart';
import '../design_system/ix/studio_api_error_callout.dart';
import '../design_system/ix/studio_freshness_banner.dart';
import '../platform/studio_load_state.dart';
import '../rust_api.dart';
import 'enum_labels.dart';

/// Groups the section-level review actions above the detailed workbench flow.
class QualityReviewsActionsBar extends StatelessWidget {
  const QualityReviewsActionsBar({
    super.key,
    this.studioPresentation = false,
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

  final bool studioPresentation;
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
    final l10n = resolveAppLocalizationsForErrors(context);
    final actionButtons = <Widget>[
      FilledButton.tonal(
        onPressed: onOpenWorkbench,
        child: Text(l10n.qualityReviewsOpenWorkbench),
      ),
      if (showDashboardControls)
        (studioPresentation
            ? FilledButton.tonal(
                onPressed: loadingQualityDashboard
                    ? null
                    : onLoadQualityDashboard,
                child: Text(
                  loadingQualityDashboard
                      ? l10n.projectsBusyProcessing
                      : l10n.qualityReviewsFreshnessRefresh,
                ),
              )
            : FilledButton(
                onPressed: loadingQualityDashboard
                    ? null
                    : onLoadQualityDashboard,
                child: Text(
                  loadingQualityDashboard
                      ? l10n.projectsBusyProcessing
                      : l10n.qualityReviewsLoadCurrentDashboard,
                ),
              )),
      if (!studioPresentation && showDashboardControls && showRefreshControls)
        FilledButton.tonal(
          onPressed: refreshingQualityDashboardReadModel
              ? null
              : onRefreshQualityDashboardReadModel,
          child: Text(
            refreshingQualityDashboardReadModel
                ? l10n.projectsBusyProcessing
                : l10n.qualityReviewsRefreshReadModel,
          ),
        ),
      FilledButton.tonal(
        onPressed: loadingQualityReviews ? null : onLoadQualityReviews,
        child: Text(
          loadingQualityReviews
              ? l10n.projectsBusyProcessing
              : l10n.qualityReviewsLoadReviewList,
        ),
      ),
      if (!studioPresentation)
        FilledButton.tonal(
          onPressed: loadingQualityBadCases ? null : onLoadQualityBadCases,
          child: Text(
            loadingQualityBadCases
                ? l10n.projectsBusyProcessing
                : l10n.qualityReviewsViewBadCases,
          ),
        ),
      if (!studioPresentation)
        FilledButton.tonal(
          onPressed: loadingQualityStats ? null : onLoadQualityStats,
          child: Text(
            loadingQualityStats
                ? l10n.projectsBusyProcessing
                : l10n.qualityReviewsViewStats,
          ),
        ),
      if (!studioPresentation)
        FilledButton.tonal(
          onPressed: loadingQualityStagePassRate
              ? null
              : onLoadQualityStagePassRate,
          child: Text(
            loadingQualityStagePassRate
                ? l10n.projectsBusyProcessing
                : l10n.qualityReviewsViewStagePassRate,
          ),
        ),
    ];
    return StudioFilterRow(
      wideBreakpoint: studioPresentation ? 620 : 760,
      children: actionButtons,
    );
  }
}

class QualityReviewsOpsDashboardPreview extends StatelessWidget {
  const QualityReviewsOpsDashboardPreview({
    super.key,
    required this.mutedColor,
    required this.dashboardSummary,
    required this.refreshControlsEnabled,
    required this.refreshSummary,
    this.freshnessMeta,
    this.dashboardLoadState = StudioLoadState.initial,
    this.dashboardLoadError,
    this.loadingDashboard = false,
    this.onRefreshDashboard,
    required this.qualityStatsRows,
    required this.stageGradeRows,
    required this.scopeInsightRows,
    required this.tokenEfficiencyRows,
    required this.badCaseStats,
  });

  final Color mutedColor;
  final String? dashboardSummary;
  final bool refreshControlsEnabled;
  final String? refreshSummary;
  final QualityDashboardMeta? freshnessMeta;
  final StudioLoadState dashboardLoadState;
  final Object? dashboardLoadError;
  final bool loadingDashboard;
  final VoidCallback? onRefreshDashboard;
  final List<QualityDashboardTargetStat>? qualityStatsRows;
  final List<QualityDashboardStageGradeItem>? stageGradeRows;
  final List<QualityDashboardScopeInsightItem>? scopeInsightRows;
  final List<QualityDashboardTokenEfficiencyItem>? tokenEfficiencyRows;
  final List<BadCaseStatItem>? badCaseStats;

  @override
  Widget build(BuildContext context) {
    final l10n = resolveAppLocalizationsForErrors(context);
    if (dashboardLoadState == StudioLoadState.error &&
        dashboardLoadError != null) {
      return StudioApiErrorCallout(
        error: dashboardLoadError!,
        onRetry: onRefreshDashboard,
      );
    }

    final hasAnything =
        dashboardSummary != null ||
        refreshSummary != null ||
        freshnessMeta != null ||
        (qualityStatsRows?.isNotEmpty ?? false) ||
        (stageGradeRows?.isNotEmpty ?? false) ||
        (scopeInsightRows?.isNotEmpty ?? false) ||
        (tokenEfficiencyRows?.isNotEmpty ?? false) ||
        (badCaseStats?.isNotEmpty ?? false);
    if (!hasAnything) {
      if (dashboardLoadState == StudioLoadState.loading || loadingDashboard) {
        return const Center(child: CircularProgressIndicator());
      }
      return StudioEmptyState(
        title: l10n.qualityReviewsOpsDashboardTitle,
        subtitle: refreshControlsEnabled
            ? l10n.qualityReviewsDashboardNotLoadedRefreshEnabled
            : l10n.qualityReviewsDashboardNotLoadedRefreshDisabled,
        icon: Icons.analytics_outlined,
        actionLabel: onRefreshDashboard != null
            ? l10n.qualityReviewsFreshnessRefresh
            : null,
        onAction: onRefreshDashboard,
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
            ).textTheme.bodySmall?.copyWith(color: mutedColor),
          ),
          const SizedBox(height: 8),
        ],
        if (freshnessMeta != null)
          StudioFreshnessBanner(
            meta: freshnessMeta!,
            onRefresh: onRefreshDashboard,
            loading: loadingDashboard,
          ),
        if (dashboardSummary != null) ...[
          SelectableText(
            dashboardSummary!,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 8),
        ],
        if (qualityStatsRows?.isNotEmpty == true) ...[
          Text(
            l10n.qualityReviewsTargetType,
            style: Theme.of(context).textTheme.labelLarge,
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: qualityStatsRows!
                .take(4)
                .map(
                  (row) => Chip(
                    label: Text(
                      l10n.qualityReviewsTargetTypeChip(
                        qualityTargetTypeLabel(row.targetType, l10n),
                        row.passRatePercent.toStringAsFixed(1),
                        row.totalReviews,
                      ),
                    ),
                    visualDensity: VisualDensity.compact,
                  ),
                )
                .toList(growable: false),
          ),
          const SizedBox(height: 8),
        ],
        if (stageGradeRows?.isNotEmpty == true) ...[
          Text(
            l10n.qualityReviewsStageGrade,
            style: Theme.of(context).textTheme.labelLarge,
          ),
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
          Text(
            l10n.qualityReviewsBadCaseHotspots,
            style: Theme.of(context).textTheme.labelLarge,
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: badCaseStats!
                .take(4)
                .map(
                  (row) => Chip(
                    label: Text(
                      l10n.qualityReviewsBadCaseChip(
                        row.badCaseCategory ?? l10n.qualityReviewsUncategorized,
                        row.count,
                      ),
                    ),
                    visualDensity: VisualDensity.compact,
                  ),
                )
                .toList(growable: false),
          ),
          const SizedBox(height: 8),
        ],
        if (scopeInsightRows?.isNotEmpty == true) ...[
          Text(
            l10n.qualityReviewsScopeLeaderboard,
            style: Theme.of(context).textTheme.labelLarge,
          ),
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
          Text(
            l10n.qualityReviewsTokenEfficiency,
            style: Theme.of(context).textTheme.labelLarge,
          ),
          const SizedBox(height: 6),
          ...tokenEfficiencyRows!
              .take(3)
              .map(
                (row) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    '${qualityTargetTypeLabel(row.targetType, l10n)} · prompt=${row.avgPromptChars.toStringAsFixed(0)} · memory=${row.avgMemoryStyleChars.toStringAsFixed(0)} · action=${row.memoryAction}',
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
    required this.mutedColor,
    required this.reviewSummary,
  });

  final Color mutedColor;
  final String reviewSummary;

  @override
  Widget build(BuildContext context) {
    return SelectableText(
      reviewSummary,
      style: Theme.of(
        context,
      ).textTheme.bodySmall?.copyWith(color: mutedColor, height: 1.35),
    );
  }
}

/// Keeps the quality review regression entry isolated from the main flow.
class QualityReviewsCompatibilityPanel extends StatelessWidget {
  const QualityReviewsCompatibilityPanel({
    super.key,
    required this.mutedColor,
    required this.creatingQualityReview,
    required this.onCreateQualityReviewProbe,
  });

  final Color mutedColor;
  final bool creatingQualityReview;
  final VoidCallback onCreateQualityReviewProbe;

  @override
  Widget build(BuildContext context) {
    final l10n = resolveAppLocalizationsForErrors(context);
    return ExpansionTile(
      tilePadding: EdgeInsets.zero,
      childrenPadding: EdgeInsets.zero,
      title: Text(l10n.qualityReviewsCompatibilityCheck),
      subtitle: Text(
        l10n.qualityReviewsCompatibilityCheckIntro,
        style: Theme.of(
          context,
        ).textTheme.bodySmall?.copyWith(color: mutedColor),
      ),
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: Text(
            l10n.qualityReviewsReadProbeLabel,
            style: Theme.of(
              context,
            ).textTheme.labelSmall?.copyWith(color: mutedColor),
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
              child: Text(
                creatingQualityReview
                    ? l10n.projectsBusyProcessing
                    : l10n.qualityReviewsRunReadOnlyRegressionCheck,
              ),
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
    final l10n = resolveAppLocalizationsForErrors(context);
    final compact = MediaQuery.sizeOf(context).width < 520;
    final detailStyle = Theme.of(context).textTheme.bodySmall?.copyWith(
      color: Theme.of(context).colorScheme.onSurfaceVariant,
      height: 1.35,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        Text(
          l10n.qualityReviewsCount(reviews.length),
          style: Theme.of(context).textTheme.labelLarge,
        ),
        ...reviews.take(8).map((review) {
          final detailLines = <String>[
            review.id,
            if (review.targetId != null && review.targetId!.isNotEmpty)
              l10n.qualityReviewsPreviewDetailTarget(review.targetId!),
            if (review.passed != null)
              l10n.qualityReviewsPreviewDetailPassed(review.passed!.toString()),
            if (review.isBadCase) l10n.qualityReviewsPreviewDetailBadCase,
          ];
          return ListTile(
            dense: !compact,
            contentPadding: EdgeInsets.zero,
            minVerticalPadding: compact ? 10 : 6,
            title: Text(
              l10n.qualityReviewsPreviewListTitle(
                qualityTargetTypeLabel(review.targetType, l10n),
                qualitySourceLabel(review.source, l10n),
                review.overallScore?.toString() ??
                    l10n.qualityReviewsAbbrevNotAvailable,
              ),
              maxLines: compact ? 2 : 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  for (var i = 0; i < detailLines.length; i++) ...[
                    if (i > 0) const SizedBox(height: 4),
                    Text(
                      detailLines[i],
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: detailStyle,
                    ),
                  ],
                ],
              ),
            ),
            trailing: compact ? null : const Icon(Icons.chevron_right),
            onTap: () => onSelectQualityReview(review),
          );
        }),
      ],
    );
  }
}
