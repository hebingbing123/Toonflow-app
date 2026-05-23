import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'controller.dart';
import 'field_styling.dart';
import 'previews.dart';
import 'support.dart';
import 'workbench_view.dart';
import '../l10n/app_localizations.dart';
import '../rust_api.dart';
import '../design_system/components/studio_collapsible_filter_panel.dart';
import '../design_system/components/studio_pane_header.dart';
import '../design_system/components/studio_pane_scaffold.dart';
import '../design_system/components/studio_empty_state.dart';
import '../design_system/components/studio_skeleton.dart';
import '../design_system/components/studio_surfaces.dart';
import '../design_system/components/studio_text_styles.dart';
import '../design_system/tokens.dart';
import '../design_system/ix/studio_api_error_callout.dart';
import '../local_prefs/risky_operation_confirm_prefs.dart';
import '../config.dart';
import '../platform/studio_load_state.dart';
import '../task_center/support.dart';
import 'enum_labels.dart';
import 'package:openflow_app/design_system/components/studio_dialog_shell.dart';

part 'section_workbench.dart';
part 'section_workbench_controllers.dart';

class QualityReviewsSection extends StatefulWidget {
  const QualityReviewsSection({
    super.key,
    required this.accessToken,
    required this.controller,
    required this.initialProjectNumericId,
    this.initialProjectUuid,
    required this.platformConfig,
    this.fetchProjectsOverride,
    this.onNavigateDomainDeepLink,
    this.studioPresentation = false,
  });

  final String? accessToken;
  final bool studioPresentation;
  final QualityReviewsController controller;
  final int? initialProjectNumericId;
  final String? initialProjectUuid;
  final PlatformConfigToggleSetV1 platformConfig;
  final Future<List<ProjectRow>> Function(String accessToken)?
  fetchProjectsOverride;
  final void Function(TaskCenterDomainDeepLink link)? onNavigateDomainDeepLink;

  @override
  State<QualityReviewsSection> createState() => _QualityReviewsSectionState();
}

class _QualityReviewsSectionState extends State<QualityReviewsSection> {
  @override
  void initState() {
    super.initState();
    if (!widget.studioPresentation) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      _bootstrapStudioPane();
    });
  }

  Future<void> _bootstrapStudioPane() async {
    final projectId = await _resolveInitialProjectNumericId();
    if (!mounted) {
      return;
    }
    if (widget.controller.qualityReviewsLoadState == StudioLoadState.initial) {
      await widget.controller.loadQualityReviews();
    }
    if (!mounted || !widget.platformConfig.qualityDashboardEnabled) {
      return;
    }
    if (widget.controller.qualityDashboardLoadState ==
        StudioLoadState.initial) {
      await widget.controller.loadQualityDashboard(projectId: projectId);
    }
  }

  String? _buildInitialProjectScopeSummary({
    required int? resolvedProjectNumericId,
  }) {
    final projectUuid = widget.initialProjectUuid?.trim();
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
    if (widget.initialProjectNumericId != null &&
        widget.initialProjectNumericId! > 0) {
      return widget.initialProjectNumericId;
    }
    final token = widget.accessToken;
    final projectUuid = widget.initialProjectUuid?.trim();
    if (token == null ||
        token.isEmpty ||
        projectUuid == null ||
        projectUuid.isEmpty) {
      return null;
    }
    final rows = await (widget.fetchProjectsOverride ?? fetchProjects)(token);
    for (final row in rows) {
      if (row.id == projectUuid) {
        return row.numericId;
      }
    }
    return null;
  }

  Future<void> _openQualityWorkbench(BuildContext context) async {
    final l10n = resolveAppLocalizationsForErrors(context);
    final token = widget.accessToken;
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
    await showStudioDialog<void>(
      context: context,
      builder: (dialogCtx) => _QualityReviewsWorkbenchDialog(
        accessToken: token,
        initialProjectNumericId: resolvedProjectNumericId,
        initialProjectUuid: widget.initialProjectUuid,
        initialProjectScopeSummary: _buildInitialProjectScopeSummary(
          resolvedProjectNumericId: resolvedProjectNumericId,
        ),
        initialReviews:
            widget.controller.qualityReviews ?? const <QualityReview>[],
        initialReviewDetails: widget.controller.qualityReviewByIdLine,
        initialStatsSummary: widget.controller.qualityStatsLine,
        initialStagePassRateSummary: widget.controller.qualityStagePassRateLine,
        onNavigateDomainDeepLink: widget.onNavigateDomainDeepLink,
      ),
    );
  }

  Future<void> _loadQualityDashboard() async {
    final projectId = await _resolveInitialProjectNumericId();
    await widget.controller.loadQualityDashboard(projectId: projectId);
  }

  Future<void> _refreshQualityDashboardReadModel() async {
    final projectId = await _resolveInitialProjectNumericId();
    await widget.controller.loadQualityDashboard(
      projectId: projectId,
      refreshReadModel: true,
    );
  }

  Widget _buildStudioLoadingBody(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: DecoratedBox(
          decoration: studioInsetPanelDecoration(context),
          child: const Padding(
            padding: EdgeInsets.all(StudioLayoutSpacing.insetComfortable),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                StudioSkeleton(height: 18),
                SizedBox(height: StudioSpacing.sm),
                StudioSkeleton(height: 56),
                SizedBox(height: StudioSpacing.sm),
                StudioSkeleton(height: 56),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStudioHeader(
    BuildContext context,
    AppLocalizations l10n,
    QualityReviewsActionsBar actionsBar,
  ) {
    final tokens = StudioTokens.of(context);
    return DecoratedBox(
      decoration:
          studioInsetPanelDecoration(
            context,
            backgroundColor: tokens.bgSurface.withValues(alpha: 0.96),
          ).copyWith(
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.12),
                blurRadius: 10,
                spreadRadius: -8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
      child: Padding(
        padding: const EdgeInsets.all(StudioLayoutSpacing.insetComfortable),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            StudioPaneHeader(
              title: l10n.productNavQuality,
              subtitle: l10n.qualityReviewsSectionIntro,
              showBack: false,
              trailing: RiskyOperationConfirmPrefsOverflowMenu(
                tooltip: l10n.taskCenterLocalClientPrefs,
              ),
            ),
            const SizedBox(height: StudioLayoutSpacing.section - 6),
            StudioCollapsibleFilterPanel(
              title: l10n.qualityReviewsFilterAndReadSection,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  actionsBar,
                  const SizedBox(height: 8),
                  _buildReviewIdLookupRow(context),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _wrapStudioInsetBody(BuildContext context, {required Widget child}) {
    return DecoratedBox(
      decoration: studioInsetPanelDecoration(context),
      child: Padding(
        padding: const EdgeInsets.all(StudioLayoutSpacing.cardInner),
        child: child,
      ),
    );
  }

  Widget _buildReviewIdLookupRow(BuildContext context) {
    final l10n = resolveAppLocalizationsForErrors(context);
    return QualityReviewIdLookupRow(
      controller: widget.controller.qualityReviewIdController,
      onChanged: widget.controller.onQualityReviewIdChanged,
      loading: widget.controller.loadingQualityReviewById,
      onSubmit: widget.controller.fetchSelectedQualityReview,
      fieldLabel: l10n.qualityReviewsFieldReviewId,
      actionLabel: l10n.qualityReviewsViewReviewDetails,
      busyLabel: l10n.projectsBusyProcessing,
    );
  }

  Widget _buildStudioMainBody(BuildContext context) {
    final l10n = resolveAppLocalizationsForErrors(context);
    final muted = qualityReviewsMutedColor(context);
    final c = widget.controller;
    final showDashboard = widget.platformConfig.qualityDashboardEnabled;

    if (c.qualityReviewsLoadState == StudioLoadState.error &&
        c.qualityReviewsLastError != null) {
      return const SizedBox.shrink();
    }
    if (c.qualityReviewsLoadState == StudioLoadState.initial ||
        c.qualityReviewsLoadState == StudioLoadState.loading ||
        c.loadingQualityReviews) {
      return _buildStudioLoadingBody(context);
    }

    final reviews = c.qualityReviews ?? const <QualityReview>[];
    Widget buildDashboardBlock() {
      if (!showDashboard) {
        return const SizedBox.shrink();
      }
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            l10n.qualityReviewsOpsDashboardTitle,
            style: studioPaneTitleStyle(context),
          ),
          const SizedBox(height: StudioLayoutSpacing.titleSubtitle),
          QualityReviewsOpsDashboardPreview(
            mutedColor: muted,
            studioPresentation: true,
            dashboardSummary: c.qualityDashboardLine,
            refreshControlsEnabled:
                widget.platformConfig.qualityRefreshControlsEnabled,
            refreshSummary: widget.platformConfig.qualityRefreshControlsEnabled
                ? c.qualityDashboardRefreshLine
                : null,
            freshnessMeta: c.qualityDashboardMeta,
            dashboardLoadState: c.qualityDashboardLoadState,
            dashboardLoadError: c.qualityDashboardLastError,
            loadingDashboard: c.loadingQualityDashboard,
            onRefreshDashboard: _loadQualityDashboard,
            qualityStatsRows: c.qualityStatsRows,
            stageGradeRows: c.qualityStageGradeRows,
            scopeInsightRows: c.qualityScopeInsightRows,
            tokenEfficiencyRows: c.qualityTokenEfficiencyRows,
            badCaseStats: c.qualityBadCaseStatItems,
          ),
        ],
      );
    }

    if (reviews.isEmpty) {
      return SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            _wrapStudioInsetBody(context, child: buildDashboardBlock()),
            const SizedBox(height: StudioLayoutSpacing.stackMedium),
            Center(
              child: StudioEmptyState.emptyData(
                title: l10n.qualityReviewsEmptyForCurrentFilters,
                subtitle: l10n.qualityReviewsSectionIntro,
                icon: Icons.fact_check_outlined,
                actionLabel: l10n.qualityReviewsLoadReviewList,
                onAction: c.loadQualityReviews,
              ),
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          _wrapStudioInsetBody(context, child: buildDashboardBlock()),
          const SizedBox(height: StudioLayoutSpacing.stackMedium),
          _wrapStudioInsetBody(
            context,
            child: QualityReviewsListPreview(
              reviews: reviews,
              showCountHeader: false,
              onSelectQualityReview: c.selectQualityReview,
            ),
          ),
        ],
      ),
    );
  }

  Widget? _buildStudioFooter(BuildContext context) {
    final c = widget.controller;
    if (c.qualityReviewsLoadState == StudioLoadState.initial ||
        c.qualityReviewsLoadState == StudioLoadState.loading ||
        c.qualityReviewsLoadState == StudioLoadState.error) {
      return null;
    }
    final l10n = resolveAppLocalizationsForErrors(context);
    final count = c.qualityReviews?.length ?? 0;
    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 8),
      child: Center(
        child: Text(
          l10n.qualityReviewsCount(count),
          style: studioHintStyle(context)?.copyWith(
            color: StudioTokens.of(context).textSecondary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = resolveAppLocalizationsForErrors(context);
    final muted = qualityReviewsMutedColor(context);
    final c = widget.controller;
    final reviewSummary = c.qualityReviews == null
        ? l10n.qualityReviewsSummaryNotLoaded
        : summarizeQualityReviews(c.qualityReviews!, l10n: l10n);

    return AnimatedBuilder(
      animation: c,
      builder: (context, _) {
        final actionsBar = QualityReviewsActionsBar(
          studioPresentation: widget.studioPresentation,
          showDashboardControls:
              widget.platformConfig.qualityDashboardEnabled,
          showRefreshControls:
              widget.platformConfig.qualityRefreshControlsEnabled,
          loadingQualityDashboard: c.loadingQualityDashboard,
          refreshingQualityDashboardReadModel:
              c.refreshingQualityDashboardReadModel,
          loadingQualityReviews: c.loadingQualityReviews,
          loadingQualityBadCases: c.loadingQualityBadCases,
          loadingQualityStats: c.loadingQualityStats,
          loadingQualityStagePassRate: c.loadingQualityStagePassRate,
          onOpenWorkbench: () => _openQualityWorkbench(context),
          onLoadQualityDashboard: _loadQualityDashboard,
          onRefreshQualityDashboardReadModel:
              _refreshQualityDashboardReadModel,
          onLoadQualityReviews: c.loadQualityReviews,
          onLoadQualityBadCases: c.loadQualityBadCases,
          onLoadQualityStats: c.loadQualityStats,
          onLoadQualityStagePassRate: c.loadQualityStagePassRate,
        );

        final header = <Widget>[
          StudioPaneHeader(
            title: l10n.productNavQuality,
            subtitle: l10n.qualityReviewsSectionIntro,
            showBack: false,
            trailing: RiskyOperationConfirmPrefsOverflowMenu(
              tooltip: l10n.taskCenterLocalClientPrefs,
            ),
          ),
          if (!widget.studioPresentation) ...<Widget>[
            const SizedBox(height: 8),
            actionsBar,
          ],
        ];

        if (widget.studioPresentation) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              _buildStudioHeader(context, l10n, actionsBar),
              if (c.qualityReviewByIdLine != null) ...<Widget>[
                const SizedBox(height: 8),
                SelectableText(
                  l10n.qualityReviewsSummaryReviewDetails(
                    c.qualityReviewByIdLine!,
                  ),
                ),
              ],
              const SizedBox(height: 8),
              if (c.qualityReviewsLoadState == StudioLoadState.error &&
                  c.qualityReviewsLastError != null)
                StudioApiErrorCallout(
                  error: c.qualityReviewsLastError!,
                  onRetry: c.loadQualityReviews,
                )
              else
                StudioPaneScaffold(
                  body: _buildStudioMainBody(context),
                  footer: _buildStudioFooter(context),
                ),
            ],
          );
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.only(top: 16, bottom: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              ...header,
              const SizedBox(height: 8),
              QualityReviewsSummaryPreview(
                mutedColor: muted,
                reviewSummary: reviewSummary,
              ),
              if (widget.platformConfig.qualityDashboardEnabled) ...<Widget>[
                const SizedBox(height: 8),
                Text(
                  l10n.qualityReviewsOpsDashboardTitle,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: StudioSpacing.xs),
                if (c.qualityDashboardLine != null)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: OutlinedButton(
                      onPressed: () async {
                        await Clipboard.setData(
                          ClipboardData(text: c.qualityDashboardLine!),
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
                  mutedColor: muted,
                  dashboardSummary: c.qualityDashboardLine,
                  refreshControlsEnabled:
                      widget.platformConfig.qualityRefreshControlsEnabled,
                  refreshSummary:
                      widget.platformConfig.qualityRefreshControlsEnabled
                      ? c.qualityDashboardRefreshLine
                      : null,
                  freshnessMeta: c.qualityDashboardMeta,
                  dashboardLoadState: c.qualityDashboardLoadState,
                  dashboardLoadError: c.qualityDashboardLastError,
                  loadingDashboard: c.loadingQualityDashboard,
                  onRefreshDashboard: _loadQualityDashboard,
                  qualityStatsRows: c.qualityStatsRows,
                  stageGradeRows: c.qualityStageGradeRows,
                  scopeInsightRows: c.qualityScopeInsightRows,
                  tokenEfficiencyRows: c.qualityTokenEfficiencyRows,
                  badCaseStats: c.qualityBadCaseStatItems,
                ),
              ],
              const SizedBox(height: 12),
              _buildReviewIdLookupRow(context),
              if (c.qualityReviewByIdLine != null) ...<Widget>[
                const SizedBox(height: 8),
                SelectableText(
                  l10n.qualityReviewsSummaryReviewDetails(
                    c.qualityReviewByIdLine!,
                  ),
                ),
              ],
              if (c.qualityStatsLine != null) ...<Widget>[
                const SizedBox(height: 8),
                SelectableText(
                  l10n.qualityReviewsSummaryStats(c.qualityStatsLine!),
                ),
              ],
              if (c.qualityStagePassRateLine != null) ...<Widget>[
                const SizedBox(height: 8),
                SelectableText(
                  l10n.qualityReviewsSummaryStagePassRate(
                    c.qualityStagePassRateLine!,
                  ),
                ),
              ],
              if (c.qualityStageGradeLine != null) ...<Widget>[
                const SizedBox(height: 8),
                SelectableText(
                  l10n.qualityReviewsSummaryStageGrade(
                    c.qualityStageGradeLine!,
                  ),
                ),
              ],
              if (c.qualityScopeInsightsLine != null) ...<Widget>[
                const SizedBox(height: 8),
                SelectableText(
                  l10n.qualityReviewsSummaryScopeInsights(
                    c.qualityScopeInsightsLine!,
                  ),
                ),
              ],
              if (c.qualityTokenEfficiencyLine != null) ...<Widget>[
                const SizedBox(height: 8),
                SelectableText(
                  l10n.qualityReviewsSummaryTokenEfficiency(
                    c.qualityTokenEfficiencyLine!,
                  ),
                ),
              ],
              if (c.qualityBadCaseStatsLine != null) ...<Widget>[
                const SizedBox(height: 8),
                SelectableText(
                  l10n.qualityReviewsSummaryBadCaseHotspots(
                    c.qualityBadCaseStatsLine!,
                  ),
                ),
              ],
              if (c.qualityReviews != null) ...<Widget>[
                QualityReviewsListPreview(
                  reviews: c.qualityReviews!,
                  onSelectQualityReview: c.selectQualityReview,
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}
