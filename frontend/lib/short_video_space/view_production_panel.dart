part of 'view.dart';

/// Current project overview + suggested migration order (side-by-side on wide screens).
class _OverviewMigrationPanel extends StatelessWidget {
  const _OverviewMigrationPanel({
    required this.spaceOverviewSummary,
    required this.overviewMetrics,
    required this.qualitySummaryLine,
    required this.badCaseMetrics,
    required this.recentTaskLines,
    required this.migrationSummary,
    required this.onOpenProjects,
    required this.onOpenScriptWorkspace,
    required this.onOpenProductionWorkspace,
    required this.onOpenTasks,
    required this.onOpenQuality,
    required this.runningJobCount,
  });

  final String spaceOverviewSummary;
  final List<ShortVideoMetricData> overviewMetrics;
  final String qualitySummaryLine;
  final List<ShortVideoMetricData> badCaseMetrics;
  final List<String> recentTaskLines;
  final String migrationSummary;
  final VoidCallback onOpenProjects;
  final VoidCallback onOpenScriptWorkspace;
  final VoidCallback onOpenProductionWorkspace;
  final VoidCallback onOpenTasks;
  final VoidCallback onOpenQuality;
  final int runningJobCount;

  @override
  Widget build(BuildContext context) {
    final overview = _ProjectOverviewSection(
      spaceOverviewSummary: spaceOverviewSummary,
      overviewMetrics: overviewMetrics,
      qualitySummaryLine: qualitySummaryLine,
      badCaseMetrics: badCaseMetrics,
      recentTaskLines: recentTaskLines,
    );
    final migration = _MigrationOrderSection(
      migrationSummary: migrationSummary,
      onOpenProjects: onOpenProjects,
      onOpenScriptWorkspace: onOpenScriptWorkspace,
      onOpenProductionWorkspace: onOpenProductionWorkspace,
      onOpenTasks: onOpenTasks,
      onOpenQuality: onOpenQuality,
      runningJobCount: runningJobCount,
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        final sideBySide = constraints.maxWidth >= kStudioTwoColumnMinWidth;
        if (sideBySide) {
          return IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Expanded(flex: 11, child: overview),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: StudioSpacing.md,
                  ),
                  child: VerticalDivider(
                    width: 1,
                    color: studioPanelBorderColor(context).withValues(
                      alpha: 0.65,
                    ),
                  ),
                ),
                Expanded(flex: 9, child: migration),
              ],
            ),
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            overview,
            Padding(
              padding: const EdgeInsets.symmetric(vertical: StudioSpacing.md),
              child: Divider(
                height: 1,
                color: studioPanelBorderColor(context).withValues(alpha: 0.65),
              ),
            ),
            migration,
          ],
        );
      },
    );
  }
}

class _ProjectOverviewSection extends StatelessWidget {
  const _ProjectOverviewSection({
    required this.spaceOverviewSummary,
    required this.overviewMetrics,
    required this.qualitySummaryLine,
    required this.badCaseMetrics,
    required this.recentTaskLines,
  });

  final String spaceOverviewSummary;
  final List<ShortVideoMetricData> overviewMetrics;
  final String qualitySummaryLine;
  final List<ShortVideoMetricData> badCaseMetrics;
  final List<String> recentTaskLines;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = studioMutedTextColor(context);
    final l10n = resolveAppLocalizationsForErrors(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.shortVideoSpaceCurrentProjectOverview,
          style: theme.textTheme.titleSmall,
        ),
        const SizedBox(height: StudioSpacing.xs),
        Text(
          spaceOverviewSummary,
          style: theme.textTheme.bodyMedium?.copyWith(color: muted),
        ),
        const SizedBox(height: StudioSpacing.sm),
        StudioResponsiveChipGrid(
          entranceKey: overviewMetrics.length,
          children: overviewMetrics
              .map((item) => _MetricChip(label: item.label, value: item.value))
              .toList(growable: false),
        ),
        const SizedBox(height: StudioSpacing.sm),
        Text(
          qualitySummaryLine,
          style: theme.textTheme.bodySmall?.copyWith(color: muted),
        ),
        if (badCaseMetrics.isNotEmpty) ...[
          const SizedBox(height: StudioSpacing.radiusComfort),
          Text(
            l10n.shortVideoSpaceRecentBadCaseTrends,
            style: theme.textTheme.labelLarge,
          ),
          const SizedBox(height: StudioSpacing.xs),
          StudioResponsiveChipGrid(
            entranceKey: badCaseMetrics.length,
            children: badCaseMetrics
                .map(
                  (item) => _MetricChip(label: item.label, value: item.value),
                )
                .toList(growable: false),
          ),
        ],
        if (recentTaskLines.isNotEmpty) ...[
          const SizedBox(height: StudioSpacing.sm),
          Text(
            l10n.shortVideoSpaceRecentTaskFlow,
            style: theme.textTheme.labelLarge,
          ),
          const SizedBox(height: StudioSpacing.xs),
          for (final (index, line) in recentTaskLines.indexed)
            studioStaggeredItem(
              index,
              entranceKey: recentTaskLines.length,
              child: Padding(
                padding: const EdgeInsets.only(bottom: StudioSpacing.xs),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.fiber_manual_record,
                      size: 10,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: StudioSpacing.xs),
                    Expanded(
                      child: Text(line, style: theme.textTheme.bodySmall),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ],
    );
  }
}

class _MigrationOrderSection extends StatelessWidget {
  const _MigrationOrderSection({
    required this.migrationSummary,
    required this.onOpenProjects,
    required this.onOpenScriptWorkspace,
    required this.onOpenProductionWorkspace,
    required this.onOpenTasks,
    required this.onOpenQuality,
    required this.runningJobCount,
  });

  final String migrationSummary;
  final VoidCallback onOpenProjects;
  final VoidCallback onOpenScriptWorkspace;
  final VoidCallback onOpenProductionWorkspace;
  final VoidCallback onOpenTasks;
  final VoidCallback onOpenQuality;
  final int runningJobCount;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = studioMutedTextColor(context);
    final l10n = resolveAppLocalizationsForErrors(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.shortVideoSpaceSectionMigrationOrder,
          style: theme.textTheme.titleSmall,
        ),
        const SizedBox(height: StudioSpacing.xs),
        Text(
          migrationSummary,
          style: theme.textTheme.bodyMedium?.copyWith(color: muted),
        ),
        const SizedBox(height: StudioSpacing.sm),
        Wrap(
          spacing: StudioSpacing.xs,
          runSpacing: StudioSpacing.xs,
          children: [
            OutlinedButton.icon(
              onPressed: onOpenProjects,
              icon: const Icon(Icons.folder_open_outlined),
              label: Text(l10n.shortVideoSpaceNavProjects),
            ),
            OutlinedButton.icon(
              onPressed: onOpenScriptWorkspace,
              icon: const Icon(Icons.edit_note_outlined),
              label: Text(l10n.shortVideoSpaceNavScriptWorkspace),
            ),
            OutlinedButton.icon(
              onPressed: onOpenProductionWorkspace,
              icon: const Icon(Icons.movie_creation_outlined),
              label: Text(l10n.shortVideoSpaceNavProductionWorkspace),
            ),
            OutlinedButton.icon(
              onPressed: onOpenTasks,
              icon: const Icon(Icons.checklist_outlined),
              label: Text(
                runningJobCount > 0
                    ? '${l10n.shortVideoSpaceNavTaskCenter} ($runningJobCount)'
                    : l10n.shortVideoSpaceNavTaskCenter,
              ),
            ),
            OutlinedButton.icon(
              onPressed: onOpenQuality,
              icon: const Icon(Icons.fact_check_outlined),
              label: Text(l10n.shortVideoSpaceNavQualityReviews),
            ),
          ],
        ),
      ],
    );
  }
}

/// Production overview and stats panel widget
class _ProductionPanel extends StatelessWidget {
  const _ProductionPanel({
    this.dense = false,
    required this.assetsOverviewPanelUi,
    required this.assemblyPanelUi,
    required this.assemblyInputPanelUi,
    required this.exportCheckPanelUi,
    required this.latestExportUi,
    required this.onStartExport,
    required this.onStartPreAssembly,
    this.onFixAssemblyStoryboard,
    this.onFixAssemblyProduction,
    this.onFixAssemblyClipDesk,
    this.onOpenAssemblyTaskCenter,
    this.onCancelAssemblyJob,
    this.onRetryAssemblyJob,
    this.onCreateDraftFromAssemblyJob,
    this.preAssemblyBlockedTooltip,
    required this.onOpenExportHistory,
    this.onDownloadLatestExport,
    this.onCancelLatestExportTask,
    this.onRetryLatestExportTask,
    required this.exportActionBusy,
    required this.preAssemblyActionBusy,
    this.localAssemblyBlockedHint,
    required this.onOpenProductionForAssemblyExport,
    this.onOpenDesktopDownloads,
    required this.onOpenAssemblyClipDeskOps,
    required this.onOpenAssemblyDefaultsEditor,
    this.assemblyVersionManagerPanel,
    this.assemblyInputPanelKey,
    this.onRefreshExportCheck,
  });

  final bool dense;
  final ShortVideoAssetsOverviewPanelUi assetsOverviewPanelUi;
  final ShortVideoAssemblyPanelUi assemblyPanelUi;
  final AssemblyInputPanelUi assemblyInputPanelUi;
  final ShortVideoExportCheckPanelUi exportCheckPanelUi;
  final ShortVideoLatestExportUi latestExportUi;
  final VoidCallback? onStartExport;
  final VoidCallback? onStartPreAssembly;
  final VoidCallback? onFixAssemblyStoryboard;
  final VoidCallback? onFixAssemblyProduction;
  final VoidCallback? onFixAssemblyClipDesk;
  final VoidCallback? onOpenAssemblyTaskCenter;
  final VoidCallback? onCancelAssemblyJob;
  final VoidCallback? onRetryAssemblyJob;
  final VoidCallback? onCreateDraftFromAssemblyJob;
  final String? preAssemblyBlockedTooltip;
  final VoidCallback? onOpenExportHistory;
  final VoidCallback? onDownloadLatestExport;
  final VoidCallback? onCancelLatestExportTask;
  final VoidCallback? onRetryLatestExportTask;
  final bool exportActionBusy;
  final bool preAssemblyActionBusy;
  final String? localAssemblyBlockedHint;
  final VoidCallback? onOpenProductionForAssemblyExport;
  final VoidCallback? onOpenDesktopDownloads;
  final VoidCallback? onOpenAssemblyClipDeskOps;
  final VoidCallback? onOpenAssemblyDefaultsEditor;
  final Widget? assemblyVersionManagerPanel;
  final Key? assemblyInputPanelKey;
  final VoidCallback? onRefreshExportCheck;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = studioMutedTextColor(context);
    final l10n = resolveAppLocalizationsForErrors(context);
    final sectionSpacing =
        dense ? StudioSpacing.radiusComfort : StudioLayoutSpacing.cardInner;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (assetsOverviewPanelUi.visible) ...[
          SizedBox(height: sectionSpacing),
          _Panel(
            dense: dense,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.shortVideoSpaceAssetsOverview,
                  style: theme.textTheme.titleSmall,
                ),
                const SizedBox(height: StudioSpacing.xs),
                if (assetsOverviewPanelUi.loading)
                  Text(
                    assetsOverviewPanelUi.headline,
                    style: theme.textTheme.bodyMedium?.copyWith(color: muted),
                  )
                else if (assetsOverviewPanelUi.unavailable)
                  Text(
                    assetsOverviewPanelUi.headline,
                    style: theme.textTheme.bodyMedium?.copyWith(color: muted),
                  )
                else ...[
                  Text(
                    assetsOverviewPanelUi.headline,
                    style: theme.textTheme.bodyMedium?.copyWith(color: muted),
                  ),
                  if (assetsOverviewPanelUi.typeLines.isNotEmpty) ...[
                    const SizedBox(height: StudioSpacing.radiusComfort),
                    for (final line in assetsOverviewPanelUi.typeLines)
                      Padding(
                        padding: const EdgeInsets.only(bottom: StudioSpacing.xs),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.category_outlined,
                              size: StudioIconSize.xs,
                              color: theme.colorScheme.primary,
                            ),
                            const SizedBox(width: StudioSpacing.xs),
                            Expanded(
                              child: Text(
                                line,
                                style: theme.textTheme.bodySmall,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ],
                const SizedBox(height: StudioSpacing.xs),
                Text(
                  assetsOverviewPanelUi.detail,
                  style: theme.textTheme.bodySmall?.copyWith(color: muted),
                ),
              ],
            ),
          ),
        ],
        _buildAssemblyAndExportSections(context),
      ],
    );
  }
  Widget _buildAssemblyAndExportSections(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = StudioTokens.of(context);
    final muted = studioMutedTextColor(context);
    final l10n = resolveAppLocalizationsForErrors(context);
    final latestExportCardFill = latestExportUi.isWarning
        ? theme.colorScheme.errorContainer.withValues(alpha: 0.72)
        : StudioTokens.of(context).primarySoft.withValues(alpha: 0.4);
    final latestExportCardBorder = latestExportUi.isWarning
        ? theme.colorScheme.error.withValues(alpha: 0.22)
        : theme.colorScheme.primary.withValues(alpha: 0.18);
    final latestExportCardTextColor = latestExportUi.isWarning
        ? theme.colorScheme.onErrorContainer
        : theme.colorScheme.onPrimaryContainer;
    final sectionSpacing =
        dense ? StudioSpacing.radiusComfort : StudioLayoutSpacing.cardInner;

    List<Widget> assemblyInputWidgets() {
    if (!(assemblyInputPanelUi.visible)) {
      return const <Widget>[];
    }
    return <Widget>[
          SizedBox(height: sectionSpacing),
          _Panel(
            key: assemblyInputPanelKey,
            dense: dense,
            child: AssemblyInputPanel(
              ui: assemblyInputPanelUi,
              l10n: l10n,
              onFixStoryboard: onFixAssemblyStoryboard,
              onFixProduction: onFixAssemblyProduction,
              onFixClipDesk: onFixAssemblyClipDesk,
              onOpenTaskCenter: onOpenAssemblyTaskCenter,
              onCancelJob: onCancelAssemblyJob,
              onRetryJob: onRetryAssemblyJob,
              onCreateDraftFromJob: onCreateDraftFromAssemblyJob,
            ),
          ),
    ];
  }

    List<Widget> assemblySnapshotWidgets() {
    if (!(assemblyPanelUi.visible)) {
      return const <Widget>[];
    }
    return <Widget>[
          SizedBox(height: sectionSpacing),
          _Panel(
            dense: dense,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.shortVideoSpaceAssemblySnapshot,
                  style: theme.textTheme.titleSmall,
                ),
                const SizedBox(height: StudioSpacing.xs),
                if (assemblyPanelUi.loading)
                  Text(
                    assemblyPanelUi.headline,
                    style: theme.textTheme.bodyMedium?.copyWith(color: muted),
                  )
                else if (assemblyPanelUi.unavailable)
                  Text(
                    assemblyPanelUi.headline,
                    style: theme.textTheme.bodyMedium?.copyWith(color: muted),
                  )
                else ...[
                  Text(
                    assemblyPanelUi.headline,
                    style: theme.textTheme.bodyMedium?.copyWith(color: muted),
                  ),
                  if (assemblyPanelUi.defaultsLine.trim().isNotEmpty) ...[
                    const SizedBox(height: StudioSpacing.chromeActionGap),
                    Text(
                      assemblyPanelUi.defaultsLine,
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                  if (assemblyPanelUi.qualityLines.isNotEmpty) ...[
                    const SizedBox(height: StudioSpacing.radiusComfort),
                    Text(
                      l10n.shortVideoSpaceQualityReview,
                      style: theme.textTheme.labelMedium,
                    ),
                    const SizedBox(height: StudioSpacing.chromeActionGap),
                    for (final line in assemblyPanelUi.qualityLines)
                      Padding(
                        padding: const EdgeInsets.only(
                          bottom: StudioSpacing.chromeActionGap,
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.fact_check_outlined,
                              size: StudioIconSize.xs,
                              color: theme.colorScheme.tertiary,
                            ),
                            const SizedBox(width: StudioSpacing.xs),
                            Expanded(
                              child: Text(
                                line,
                                style: theme.textTheme.bodySmall,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                  if (assemblyPanelUi.scriptLines.isNotEmpty) ...[
                    const SizedBox(height: StudioSpacing.radiusComfort),
                    for (final line in assemblyPanelUi.scriptLines)
                      Padding(
                        padding: const EdgeInsets.only(bottom: StudioSpacing.xs),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.movie_filter_outlined,
                              size: StudioIconSize.xs,
                              color: theme.colorScheme.primary,
                            ),
                            const SizedBox(width: StudioSpacing.xs),
                            Expanded(
                              child: Text(
                                line,
                                style: theme.textTheme.bodySmall,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                  if (assemblyPanelUi.multiTrackDecisionLines.isNotEmpty) ...[
                    const SizedBox(height: StudioSpacing.radiusComfort),
                    Text(
                      l10n.shortVideoSpaceMultiTrackExportDecision,
                      style: theme.textTheme.labelMedium,
                    ),
                    const SizedBox(height: StudioSpacing.chromeActionGap),
                    for (final line in assemblyPanelUi.multiTrackDecisionLines)
                      Padding(
                        padding: const EdgeInsets.only(
                          bottom: StudioSpacing.chromeActionGap,
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.alt_route_outlined,
                              size: StudioIconSize.xs,
                              color: theme.colorScheme.secondary,
                            ),
                            const SizedBox(width: StudioSpacing.xs),
                            Expanded(
                              child: Text(
                                line,
                                style: theme.textTheme.bodySmall,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ],
                const SizedBox(height: StudioSpacing.xs),
                Text(
                  assemblyPanelUi.detail,
                  style: theme.textTheme.bodySmall?.copyWith(color: muted),
                ),
                if (onOpenProductionForAssemblyExport != null &&
                    assemblyPanelUi.visible &&
                    !assemblyPanelUi.loading &&
                    !assemblyPanelUi.unavailable) ...[
                  const SizedBox(height: StudioSpacing.radiusComfort),
                  Wrap(
                    spacing: StudioSpacing.xs,
                    runSpacing: StudioSpacing.xs,
                    children: [
                      OutlinedButton.icon(
                        onPressed: onOpenProductionForAssemblyExport,
                        icon: const Icon(Icons.movie_creation_outlined),
                        label: Text(
                          l10n.shortVideoSpaceOpenProductionWorkspace,
                        ),
                      ),
                      if (onOpenAssemblyClipDeskOps != null)
                        OutlinedButton.icon(
                          onPressed: onOpenAssemblyClipDeskOps,
                          icon: const Icon(Icons.tune_outlined),
                          label: Text(l10n.shortVideoSpaceBasicShotOperations),
                        ),
                      if (onOpenAssemblyDefaultsEditor != null)
                        OutlinedButton.icon(
                          onPressed: onOpenAssemblyDefaultsEditor,
                          icon: const Icon(Icons.subtitles_outlined),
                          label: Text(
                            l10n.shortVideoSpaceAssemblyStyleAdjustment,
                          ),
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
    ];
  }

    List<Widget> assemblyVersionWidgets() {
    if (!(assemblyVersionManagerPanel != null)) {
      return const <Widget>[];
    }
    return <Widget>[
          SizedBox(height: sectionSpacing),
          assemblyVersionManagerPanel!,
    ];
  }

    List<Widget> exportCheckWidgets() {
    if (!(exportCheckPanelUi.visible)) {
      return const <Widget>[];
    }
    return <Widget>[
          SizedBox(height: sectionSpacing),
          _Panel(
            dense: dense,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.shortVideoSpaceExportPreCheck,
                  style: theme.textTheme.titleSmall,
                ),
                const SizedBox(height: StudioSpacing.xs),
                if (exportCheckPanelUi.loading)
                  Text(
                    exportCheckPanelUi.headline,
                    style: theme.textTheme.bodyMedium?.copyWith(color: muted),
                  )
                else if (exportCheckPanelUi.unavailable) ...<Widget>[
                  Text(
                    exportCheckPanelUi.headline,
                    style: theme.textTheme.bodyMedium?.copyWith(color: muted),
                  ),
                  if (onRefreshExportCheck != null) ...<Widget>[
                    const SizedBox(height: StudioSpacing.xs),
                    OutlinedButton.icon(
                      onPressed: onRefreshExportCheck,
                      icon: const Icon(Icons.refresh, size: StudioIconSize.sm),
                      label: Text(l10n.shortVideoSpaceExportCheckRefreshButton),
                    ),
                  ],
                ] else ...[
                  Text(
                    exportCheckPanelUi.headline,
                    style: theme.textTheme.bodyMedium?.copyWith(color: muted),
                  ),
                  if (exportCheckPanelUi.metrics.isNotEmpty) ...[
                    const SizedBox(height: StudioSpacing.radiusComfort),
                    StudioResponsiveChipGrid(
                      entranceKey: exportCheckPanelUi.metrics.length,
                      children: exportCheckPanelUi.metrics
                          .map(
                            (m) => _MetricChip(
                              label: m.label,
                              value: m.value,
                            ),
                          )
                          .toList(growable: false),
                    ),
                  ],
                  if (exportCheckPanelUi.qualityGateLine.trim().isNotEmpty) ...[
                    const SizedBox(height: StudioSpacing.radiusComfort),
                    Text(
                      exportCheckPanelUi.qualityGateLine,
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                  if (exportCheckPanelUi
                      .qualityGateBlockingLines
                      .isNotEmpty) ...[
                    const SizedBox(height: StudioSpacing.xs),
                    Text(
                      l10n.shortVideoSpaceQualityGateBlockingReasons,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: muted,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: StudioSpacing.chromeActionGap),
                    for (final line
                        in exportCheckPanelUi.qualityGateBlockingLines)
                      Padding(
                        padding: const EdgeInsets.only(
                          bottom: StudioSpacing.chromeActionGap,
                        ),
                        child: Text(
                          line,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.error,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                  ],
                  if (exportCheckPanelUi.publishPlatformGapEntries.isNotEmpty ||
                      exportCheckPanelUi.publishBlockingLines.isNotEmpty ||
                      exportCheckPanelUi.publishWarningLines.isNotEmpty) ...[
                    const SizedBox(height: StudioSpacing.xs),
                    Text(
                      l10n.shortVideoSpacePublishExportCheckPublishSectionTitle,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: muted,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: StudioSpacing.xs),
                    for (final gap
                        in exportCheckPanelUi.publishPlatformGapEntries)
                      Padding(
                        padding: const EdgeInsets.only(
                          bottom: StudioSpacing.chromeActionGap,
                        ),
                        child: Text(
                          '${gap.title}: ${gap.facetSummary}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: gap.hasBlocking
                                ? tokens.danger
                                : tokens.warning,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    for (final line in exportCheckPanelUi.publishBlockingLines)
                      Padding(
                        padding: const EdgeInsets.only(
                          bottom: StudioSpacing.chromeActionGap,
                        ),
                        child: Text(
                          line,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.error,
                          ),
                        ),
                      ),
                    for (final line in exportCheckPanelUi.publishWarningLines)
                      Padding(
                        padding: const EdgeInsets.only(
                          bottom: StudioSpacing.chromeActionGap,
                        ),
                        child: Text(
                          line,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: tokens.warning,
                          ),
                        ),
                      ),
                  ],
                  if (exportCheckPanelUi.storyboardGapEntries.isNotEmpty) ...[
                    const SizedBox(height: StudioSpacing.xs),
                    Text(
                      l10n.shortVideoSpacePublishExportCheckStoryboardGapsTitle,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: muted,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: StudioSpacing.xs),
                    for (final gap in exportCheckPanelUi.storyboardGapEntries)
                      Theme(
                        data: theme.copyWith(
                          dividerColor: StudioPrimitives.transparent,
                        ),
                        child: ExpansionTile(
                          initiallyExpanded: false,
                          tilePadding: EdgeInsets.zero,
                          childrenPadding: const EdgeInsets.only(
                            left: StudioSpacing.xs,
                            bottom: StudioSpacing.xs,
                          ),
                          title: Text(
                            gap.title,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: gap.hasBlocking
                                  ? tokens.danger
                                  : tokens.warning,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          subtitle: Text(
                            gap.facetSummary,
                            style: theme.textTheme.bodySmall,
                          ),
                          children: [
                            for (final label in gap.codeLabels)
                              Align(
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  '· $label',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: muted,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                  ] else if (exportCheckPanelUi.blockingLines.isNotEmpty) ...[
                    const SizedBox(height: StudioSpacing.xs),
                    Text(
                      l10n.shortVideoSpaceBlockingItems,
                      style: theme.textTheme.labelSmall?.copyWith(color: muted),
                    ),
                    const SizedBox(height: StudioSpacing.chromeActionGap),
                    for (final line in exportCheckPanelUi.blockingLines)
                      Padding(
                        padding: const EdgeInsets.only(
                          bottom: StudioSpacing.chromeActionGap,
                        ),
                        child: Text(
                          line,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.error,
                          ),
                        ),
                      ),
                  ],
                  if (exportCheckPanelUi.warningLines.isNotEmpty) ...[
                    const SizedBox(height: StudioSpacing.xs),
                    Text(
                      l10n.shortVideoSpaceWarningItems,
                      style: theme.textTheme.labelSmall?.copyWith(color: muted),
                    ),
                    const SizedBox(height: StudioSpacing.chromeActionGap),
                    for (final line in exportCheckPanelUi.warningLines)
                      Padding(
                        padding: const EdgeInsets.only(
                          bottom: StudioSpacing.chromeActionGap,
                        ),
                        child: Text(
                          line,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: tokens.warning,
                          ),
                        ),
                      ),
                  ],
                ],
                const SizedBox(height: StudioSpacing.xs),
                Text(
                  exportCheckPanelUi.detail,
                  style: theme.textTheme.bodySmall?.copyWith(color: muted),
                ),
                if (latestExportUi.visible) ...[
                  const SizedBox(height: StudioSpacing.radiusComfort),
                  Container(
                    padding: const EdgeInsets.all(StudioSpacing.radiusComfort),
                    decoration: BoxDecoration(
                      color: latestExportCardFill,
                      borderRadius: BorderRadius.circular(StudioSpacing.radiusDense),
                      border: Border.all(color: latestExportCardBorder),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              latestExportUi.isWarning
                                  ? Icons.warning_amber_rounded
                                  : Icons.task_alt,
                              size: StudioIconSize.sm,
                              color: latestExportCardTextColor,
                            ),
                            const SizedBox(width: StudioSpacing.xs),
                            Expanded(
                              child: Text(
                                latestExportUi.title,
                                style: theme.textTheme.titleSmall?.copyWith(
                                  color: latestExportCardTextColor,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                        if ((latestExportUi.statusLine ?? '')
                            .trim()
                            .isNotEmpty) ...[
                          const SizedBox(height: StudioSpacing.chromeActionGap),
                          Text(
                            latestExportUi.statusLine!,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: latestExportCardTextColor,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                        if ((latestExportUi.activeTaskTitle ?? '')
                            .trim()
                            .isNotEmpty) ...[
                          const SizedBox(height: StudioSpacing.xs),
                          Container(
                            padding: const EdgeInsets.all(StudioLayoutSpacing.inlineGap),
                            decoration: BoxDecoration(
                              color: latestExportCardTextColor.withValues(
                                alpha: 0.08,
                              ),
                              borderRadius: BorderRadius.circular(
                                StudioSpacing.radiusDense,
                              ),
                              border: Border.all(
                                color: latestExportCardTextColor.withValues(
                                  alpha: 0.14,
                                ),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    SizedBox(
                                      width: 14,
                                      height: 14,
                                      child: latestExportUi.activeTaskRunning
                                          ? CircularProgressIndicator(
                                              strokeWidth: StudioControlSize.progressStroke,
                                              color: latestExportCardTextColor,
                                            )
                                          : Icon(
                                              latestExportUi.activeTaskFailed
                                                  ? Icons.error_outline
                                                  : Icons.schedule,
                                              size: 14,
                                              color: latestExportCardTextColor,
                                            ),
                                    ),
                                    const SizedBox(width: StudioSpacing.xs),
                                    Expanded(
                                      child: Text(
                                        latestExportUi.activeTaskTitle!,
                                        style: theme.textTheme.bodySmall
                                            ?.copyWith(
                                              color: latestExportCardTextColor,
                                              fontWeight: FontWeight.w600,
                                            ),
                                      ),
                                    ),
                                  ],
                                ),
                                if ((latestExportUi.activeTaskDetail ?? '')
                                    .trim()
                                    .isNotEmpty) ...[
                                  const SizedBox(height: StudioSpacing.xs),
                                  Text(
                                    latestExportUi.activeTaskDetail!,
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: latestExportCardTextColor
                                          .withValues(alpha: 0.9),
                                    ),
                                  ),
                                ],
                                if ((latestExportUi.activeTaskError ?? '')
                                    .trim()
                                    .isNotEmpty) ...[
                                  const SizedBox(height: StudioSpacing.chromeActionGap),
                                  Text(
                                    latestExportUi.activeTaskError!,
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: latestExportCardTextColor,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                        if (latestExportUi.detail.isNotEmpty) ...[
                          const SizedBox(height: StudioSpacing.chromeActionGap),
                          Text(
                            latestExportUi.detail,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: latestExportCardTextColor,
                            ),
                          ),
                        ],
                        if (latestExportUi.meta.isNotEmpty) ...[
                          const SizedBox(height: StudioSpacing.xs),
                          for (final line in latestExportUi.meta)
                            Padding(
                              padding: const EdgeInsets.only(
                          bottom: StudioSpacing.chromeActionGap,
                        ),
                              child: Text(
                                line,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: latestExportCardTextColor.withValues(
                                    alpha: 0.88,
                                  ),
                                ),
                              ),
                            ),
                        ],
                        const SizedBox(height: StudioSpacing.radiusComfort),
                        StudioDenseActionRow(
                          children: [
                            if (latestExportUi.isWarning &&
                                onStartExport != null)
                              FilledButton.icon(
                                style: studioFormIconLabeledButtonStyle(context),
                                onPressed: exportActionBusy
                                    ? null
                                    : onStartExport,
                                icon: exportActionBusy
                                    ? const SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                          strokeWidth: StudioControlSize.progressStroke,
                                        ),
                                      )
                                    : const Icon(Icons.refresh),
                                label: Text(
                                  exportActionBusy
                                      ? l10n.shortVideoSpaceExporting
                                      : l10n.shortVideoSpaceProductionLatestExportRerun,
                                ),
                              ),
                            FilledButton.tonalIcon(
                              style: studioFormIconLabeledButtonStyle(context),
                              onPressed: onDownloadLatestExport,
                              icon: const Icon(Icons.download_outlined),
                              label: Text(
                                l10n.shortVideoSpaceDialogExportHistoryDownload,
                              ),
                            ),
                            if (onCancelLatestExportTask != null)
                              OutlinedButton.icon(
                                style: studioFormOutlinedIconLabeledButtonStyle(context),
                                onPressed: onCancelLatestExportTask,
                                icon: const Icon(Icons.stop_circle_outlined),
                                label: Text(
                                  l10n.shortVideoSpaceProductionAssemblyCancel,
                                ),
                              ),
                            if (onRetryLatestExportTask != null)
                              (latestExportUi.recommendedAction ==
                                      ShortVideoLatestExportAction.retry)
                                  ? FilledButton.icon(
                                      style: studioFormIconLabeledButtonStyle(context),
                                      onPressed: onRetryLatestExportTask,
                                      icon: const Icon(Icons.refresh),
                                      label: Text(
                                        l10n.shortVideoSpaceProductionAssemblyRetryTask,
                                      ),
                                    )
                                  : FilledButton.tonalIcon(
                                      style: studioFormIconLabeledButtonStyle(context),
                                      onPressed: onRetryLatestExportTask,
                                      icon: const Icon(Icons.refresh),
                                      label: Text(
                                        l10n.shortVideoSpaceProductionAssemblyRetryTask,
                                      ),
                                    ),
                            if (latestExportUi.activeTaskFailed &&
                                onOpenProductionForAssemblyExport != null)
                              (latestExportUi.recommendedAction ==
                                      ShortVideoLatestExportAction
                                          .openProductionWorkspace)
                                  ? FilledButton.icon(
                                      style: studioFormIconLabeledButtonStyle(context),
                                      onPressed:
                                          onOpenProductionForAssemblyExport,
                                      icon: const Icon(
                                        Icons.movie_creation_outlined,
                                      ),
                                      label: Text(
                                        l10n.shortVideoSpaceOpenProductionWorkspace,
                                      ),
                                    )
                                  : OutlinedButton.icon(
                                      style: studioFormOutlinedIconLabeledButtonStyle(context),
                                      onPressed:
                                          onOpenProductionForAssemblyExport,
                                      icon: const Icon(
                                        Icons.movie_creation_outlined,
                                      ),
                                      label: Text(
                                        l10n.shortVideoSpaceOpenProductionWorkspace,
                                      ),
                                    ),
                            OutlinedButton.icon(
                              style: studioFormOutlinedIconLabeledButtonStyle(context),
                              onPressed: onOpenExportHistory,
                              icon: const Icon(Icons.history),
                              label: Text(l10n.shortVideoSpaceExportHistory),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
                if (localAssemblyBlockedHint != null &&
                    localAssemblyBlockedHint!.trim().isNotEmpty) ...[
                  const SizedBox(height: StudioSpacing.radiusComfort),
                  Container(
                    padding: const EdgeInsets.all(StudioSpacing.radiusComfort),
                    decoration: BoxDecoration(
                      color: StudioTokens.of(context).accentSoft,
                      borderRadius: BorderRadius.circular(StudioSpacing.radiusDense),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          localAssemblyBlockedHint!,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSecondaryContainer,
                          ),
                        ),
                        if (onOpenDesktopDownloads != null) ...[
                          const SizedBox(height: StudioSpacing.radiusComfort),
                          FilledButton.tonalIcon(
                            onPressed: onOpenDesktopDownloads,
                            icon: const Icon(Icons.download_outlined),
                            label: Text(l10n.shortVideoDownloadDesktopApp),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: StudioSpacing.radiusComfort),
                StudioDenseActionRow(
                  children: [
                    FilledButton.icon(
                      style: studioFormIconLabeledButtonStyle(context),
                      onPressed:
                          exportActionBusy ||
                              !exportCheckPanelUi.exportReady ||
                              localAssemblyBlockedHint != null
                          ? null
                          : onStartExport,
                      icon: exportActionBusy
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: StudioControlSize.progressStroke),
                            )
                          : const Icon(Icons.file_upload_outlined),
                      label: Text(
                        exportActionBusy
                            ? l10n.shortVideoSpaceExporting
                            : l10n.shortVideoSpaceStartExport,
                      ),
                    ),
                    Tooltip(
                      message: preAssemblyBlockedTooltip ?? '',
                      child: OutlinedButton.icon(
                        style: studioFormOutlinedIconLabeledButtonStyle(context),
                        onPressed:
                            (exportActionBusy ||
                                preAssemblyActionBusy ||
                                localAssemblyBlockedHint != null ||
                                !assemblyInputPanelUi.gate.canPreAssembly)
                            ? null
                            : onStartPreAssembly,
                        icon: preAssemblyActionBusy
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                  strokeWidth: StudioControlSize.progressStroke,
                                ),
                              )
                            : const Icon(Icons.playlist_play_outlined),
                        label: Text(
                          preAssemblyActionBusy
                              ? l10n.shortVideoSpacePreAssemblyBusy
                              : l10n.shortVideoSpaceStartPreAssembly,
                        ),
                      ),
                    ),
                    OutlinedButton.icon(
                      style: studioFormOutlinedIconLabeledButtonStyle(context),
                      onPressed: exportActionBusy ? null : onOpenExportHistory,
                      icon: const Icon(Icons.history),
                      label: Text(l10n.shortVideoSpaceExportHistory),
                    ),
                  ],
                ),
              ],
            ),
          ),
    ];
  }

    return LayoutBuilder(
      builder: (context, constraints) {
        final splitWide = studioUseThreePaneLayout(constraints.maxWidth) &&
            assemblyInputPanelUi.visible &&
            exportCheckPanelUi.visible;
        final input = assemblyInputWidgets();
        final snapshot = assemblySnapshotWidgets();
        final version = assemblyVersionWidgets();
        final export = exportCheckWidgets();
        if (!splitWide) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              ...input,
              ...snapshot,
              ...version,
              ...export,
            ],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: input,
                  ),
                ),
                SizedBox(width: sectionSpacing),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: export,
                  ),
                ),
              ],
            ),
            ...snapshot,
            ...version,
          ],
        );
      },
    );
  }

}
