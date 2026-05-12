import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'controller.dart';
import 'previews.dart';
import 'support.dart';
import 'workbench_view.dart';
import '../../rust_api.dart';
import '../local_prefs/risky_operation_confirm_prefs.dart';
import '../config.dart';
import '../l10n/app_localizations.dart';

part 'section_workbench.dart';
part 'section_workbench_controllers.dart';

class QualityReviewsSection extends StatelessWidget {
  const QualityReviewsSection({
    super.key,
    required this.accessToken,
    required this.controller,
    required this.initialProjectNumericId,
    this.initialProjectUuid,
    required this.platformConfig,
    this.fetchProjectsOverride,
  });

  final String? accessToken;
  final QualityReviewsController controller;
  final int? initialProjectNumericId;
  final String? initialProjectUuid;
  final PlatformConfigToggleSetV1 platformConfig;
  final Future<List<ProjectRow>> Function(String accessToken)?
  fetchProjectsOverride;

  String? _buildInitialProjectScopeSummary({
    required int? resolvedProjectNumericId,
  }) {
    final projectUuid = initialProjectUuid?.trim();
    if (projectUuid != null && projectUuid.isNotEmpty) {
      if (resolvedProjectNumericId != null && resolvedProjectNumericId > 0) {
        return 'projectUuid=$projectUuid -> projectId=$resolvedProjectNumericId';
      }
      return 'projectUuid=$projectUuid';
    }
    if (resolvedProjectNumericId != null && resolvedProjectNumericId > 0) {
      return 'projectId=$resolvedProjectNumericId';
    }
    return null;
  }

  Future<int?> _resolveInitialProjectNumericId() async {
    if (initialProjectNumericId != null && initialProjectNumericId! > 0) {
      return initialProjectNumericId;
    }
    final token = accessToken;
    final projectUuid = initialProjectUuid?.trim();
    if (token == null ||
        token.isEmpty ||
        projectUuid == null ||
        projectUuid.isEmpty) {
      return null;
    }
    final rows = await (fetchProjectsOverride ?? fetchProjects)(token);
    for (final row in rows) {
      if (row.id == projectUuid) {
        return row.numericId;
      }
    }
    return null;
  }

  Future<void> _openQualityWorkbench(BuildContext context) async {
    final l10n = AppLocalizations.of(context)!;
    final token = accessToken;
    if (token == null || token.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.qualityReviewsErrNotLoggedIn)),
      );
      return;
    }
    final resolvedProjectNumericId = await _resolveInitialProjectNumericId();
    if (!context.mounted) {
      return;
    }
    await showDialog<void>(
      context: context,
      builder: (dialogCtx) => _QualityReviewsWorkbenchDialog(
        accessToken: token,
        initialProjectNumericId: resolvedProjectNumericId,
        initialProjectScopeSummary: _buildInitialProjectScopeSummary(
          resolvedProjectNumericId: resolvedProjectNumericId,
        ),
        initialReviews: controller.qualityReviews ?? const <QualityReview>[],
        initialReviewDetails: controller.qualityReviewByIdLine,
        initialStatsSummary: controller.qualityStatsLine,
        initialStagePassRateSummary: controller.qualityStagePassRateLine,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final outline = Theme.of(context).colorScheme.outline;
    final reviewSummary = controller.qualityReviews == null
        ? l10n.qualityReviewsSummaryNotLoaded
        : summarizeQualityReviews(controller.qualityReviews!, l10n: l10n);
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
                    l10n.productNavQuality,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
                RiskyOperationConfirmPrefsOverflowMenu(
                  tooltip: l10n.taskCenterLocalClientPrefs,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              l10n.qualityReviewsSectionIntro,
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
              loadingQualityStagePassRate:
                  controller.loadingQualityStagePassRate,
              onOpenWorkbench: () => _openQualityWorkbench(context),
              onLoadQualityDashboard: () async {
                final projectId = await _resolveInitialProjectNumericId();
                await controller.loadQualityDashboard(projectId: projectId);
              },
              onRefreshQualityDashboardReadModel: () async {
                final projectId = await _resolveInitialProjectNumericId();
                await controller.loadQualityDashboard(
                  projectId: projectId,
                  refreshReadModel: true,
                );
              },
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
              Text(
                l10n.qualityReviewsOpsDashboardTitle,
                style: Theme.of(context).textTheme.titleSmall,
              ),
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
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            l10n.qualityReviewsCopiedDashboardSummary,
                          ),
                        ),
                      );
                    },
                    child: Text(l10n.qualityReviewsCopyDashboardSummary),
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
              decoration: InputDecoration(
                labelText: l10n.qualityReviewsFieldReviewId,
              ),
            ),
            const SizedBox(height: 8),
            FilledButton.tonal(
              onPressed:
                  (controller.loadingQualityReviewById ||
                      controller.qualityReviewIdController.text.trim().isEmpty)
                  ? null
                  : controller.fetchSelectedQualityReview,
              child: Text(
                controller.loadingQualityReviewById
                    ? l10n.projectsBusyProcessing
                    : l10n.qualityReviewsViewReviewDetails,
              ),
            ),
            if (controller.qualityReviewByIdLine != null) ...[
              const SizedBox(height: 8),
              SelectableText(
                l10n.qualityReviewsSummaryReviewDetails(
                  controller.qualityReviewByIdLine!,
                ),
              ),
            ],
            if (controller.qualityStatsLine != null) ...[
              const SizedBox(height: 8),
              SelectableText(
                l10n.qualityReviewsSummaryStats(controller.qualityStatsLine!),
              ),
            ],
            if (controller.qualityStagePassRateLine != null) ...[
              const SizedBox(height: 8),
              SelectableText(
                l10n.qualityReviewsSummaryStagePassRate(
                  controller.qualityStagePassRateLine!,
                ),
              ),
            ],
            if (controller.qualityStageGradeLine != null) ...[
              const SizedBox(height: 8),
              SelectableText(
                l10n.qualityReviewsSummaryStageGrade(
                  controller.qualityStageGradeLine!,
                ),
              ),
            ],
            if (controller.qualityScopeInsightsLine != null) ...[
              const SizedBox(height: 8),
              SelectableText(
                l10n.qualityReviewsSummaryScopeInsights(
                  controller.qualityScopeInsightsLine!,
                ),
              ),
            ],
            if (controller.qualityTokenEfficiencyLine != null) ...[
              const SizedBox(height: 8),
              SelectableText(
                l10n.qualityReviewsSummaryTokenEfficiency(
                  controller.qualityTokenEfficiencyLine!,
                ),
              ),
            ],
            if (controller.qualityBadCaseStatsLine != null) ...[
              const SizedBox(height: 8),
              SelectableText(
                l10n.qualityReviewsSummaryBadCaseHotspots(
                  controller.qualityBadCaseStatsLine!,
                ),
              ),
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
