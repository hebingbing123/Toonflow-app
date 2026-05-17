part of 'view.dart';

/// Production overview and stats panel widget
class _ProductionPanel extends StatelessWidget {
  const _ProductionPanel({
    required this.spaceOverviewSummary,
    required this.overviewMetrics,
    required this.qualitySummaryLine,
    required this.badCaseMetrics,
    required this.recentTaskLines,
    required this.assetsOverviewPanelUi,
    required this.assemblyPanelUi,
    required this.exportCheckPanelUi,
    required this.onStartExport,
    required this.onStartPreAssembly,
    required this.onOpenExportHistory,
    required this.exportActionBusy,
    required this.preAssemblyActionBusy,
    required this.onOpenProductionForAssemblyExport,
    required this.onOpenAssemblyClipDeskOps,
    required this.onOpenAssemblyDefaultsEditor,
    this.assemblyVersionManagerPanel,
  });

  final String spaceOverviewSummary;
  final List<ShortVideoMetricData> overviewMetrics;
  final String qualitySummaryLine;
  final List<ShortVideoMetricData> badCaseMetrics;
  final List<String> recentTaskLines;
  final ShortVideoAssetsOverviewPanelUi assetsOverviewPanelUi;
  final ShortVideoAssemblyPanelUi assemblyPanelUi;
  final ShortVideoExportCheckPanelUi exportCheckPanelUi;
  final VoidCallback? onStartExport;
  final VoidCallback? onStartPreAssembly;
  final VoidCallback? onOpenExportHistory;
  final bool exportActionBusy;
  final bool preAssemblyActionBusy;
  final VoidCallback? onOpenProductionForAssemblyExport;
  final VoidCallback? onOpenAssemblyClipDeskOps;
  final VoidCallback? onOpenAssemblyDefaultsEditor;
  final Widget? assemblyVersionManagerPanel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final outline = theme.colorScheme.outline;
    final l10n = resolveAppLocalizationsForErrors(context);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l10n.shortVideoSpaceCurrentProjectOverview, style: theme.textTheme.titleSmall),
              const SizedBox(height: 8),
              Text(
                spaceOverviewSummary,
                style: theme.textTheme.bodyMedium?.copyWith(color: outline),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: overviewMetrics
                    .map(
                      (item) =>
                          _MetricChip(label: item.label, value: item.value),
                    )
                    .toList(growable: false),
              ),
              const SizedBox(height: 12),
              Text(qualitySummaryLine, style: theme.textTheme.bodySmall),
              if (badCaseMetrics.isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(l10n.shortVideoSpaceRecentBadCaseTrends, style: theme.textTheme.labelLarge),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: badCaseMetrics
                      .map(
                        (item) =>
                            _MetricChip(label: item.label, value: item.value),
                      )
                      .toList(growable: false),
                ),
              ],
              if (recentTaskLines.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(l10n.shortVideoSpaceRecentTaskFlow, style: theme.textTheme.labelLarge),
                const SizedBox(height: 8),
                for (final line in recentTaskLines)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.fiber_manual_record,
                          size: 10,
                          color: theme.colorScheme.primary,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(line, style: theme.textTheme.bodySmall),
                        ),
                      ],
                    ),
                  ),
              ],
            ],
          ),
        ),
        if (assetsOverviewPanelUi.visible) ...[
          const SizedBox(height: 16),
          _Panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l10n.shortVideoSpaceAssetsOverview, style: theme.textTheme.titleSmall),
                const SizedBox(height: 8),
                if (assetsOverviewPanelUi.loading)
                  Text(
                    assetsOverviewPanelUi.headline,
                    style: theme.textTheme.bodyMedium?.copyWith(color: outline),
                  )
                else if (assetsOverviewPanelUi.unavailable)
                  Text(
                    assetsOverviewPanelUi.headline,
                    style: theme.textTheme.bodyMedium?.copyWith(color: outline),
                  )
                else ...[
                  Text(
                    assetsOverviewPanelUi.headline,
                    style: theme.textTheme.bodyMedium?.copyWith(color: outline),
                  ),
                  if (assetsOverviewPanelUi.typeLines.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    for (final line in assetsOverviewPanelUi.typeLines)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.category_outlined,
                              size: 16,
                              color: theme.colorScheme.primary,
                            ),
                            const SizedBox(width: 8),
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
                const SizedBox(height: 8),
                Text(
                  assetsOverviewPanelUi.detail,
                  style: theme.textTheme.bodySmall?.copyWith(color: outline),
                ),
              ],
            ),
          ),
        ],
        if (assemblyPanelUi.visible) ...[
          const SizedBox(height: 16),
          _Panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l10n.shortVideoSpaceAssemblySnapshot, style: theme.textTheme.titleSmall),
                const SizedBox(height: 8),
                if (assemblyPanelUi.loading)
                  Text(
                    assemblyPanelUi.headline,
                    style: theme.textTheme.bodyMedium?.copyWith(color: outline),
                  )
                else if (assemblyPanelUi.unavailable)
                  Text(
                    assemblyPanelUi.headline,
                    style: theme.textTheme.bodyMedium?.copyWith(color: outline),
                  )
                else ...[
                  Text(
                    assemblyPanelUi.headline,
                    style: theme.textTheme.bodyMedium?.copyWith(color: outline),
                  ),
                  if (assemblyPanelUi.defaultsLine.trim().isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      assemblyPanelUi.defaultsLine,
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                  if (assemblyPanelUi.qualityLines.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Text(
                      l10n.shortVideoSpaceQualityReview,
                      style: theme.textTheme.labelMedium,
                    ),
                    const SizedBox(height: 6),
                    for (final line in assemblyPanelUi.qualityLines)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.fact_check_outlined,
                              size: 16,
                              color: theme.colorScheme.tertiary,
                            ),
                            const SizedBox(width: 8),
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
                    const SizedBox(height: 10),
                    for (final line in assemblyPanelUi.scriptLines)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.movie_filter_outlined,
                              size: 16,
                              color: theme.colorScheme.primary,
                            ),
                            const SizedBox(width: 8),
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
                    const SizedBox(height: 10),
                    Text(l10n.shortVideoSpaceMultiTrackExportDecision, style: theme.textTheme.labelMedium),
                    const SizedBox(height: 6),
                    for (final line in assemblyPanelUi.multiTrackDecisionLines)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.alt_route_outlined,
                              size: 16,
                              color: theme.colorScheme.secondary,
                            ),
                            const SizedBox(width: 8),
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
                const SizedBox(height: 8),
                Text(
                  assemblyPanelUi.detail,
                  style: theme.textTheme.bodySmall?.copyWith(color: outline),
                ),
                if (onOpenProductionForAssemblyExport != null &&
                    assemblyPanelUi.visible &&
                    !assemblyPanelUi.loading &&
                    !assemblyPanelUi.unavailable) ...[
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      OutlinedButton.icon(
                        onPressed: onOpenProductionForAssemblyExport,
                        icon: const Icon(Icons.movie_creation_outlined),
                        label: Text(l10n.shortVideoSpaceOpenProductionWorkspace),
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
                          label: Text(l10n.shortVideoSpaceAssemblyStyleAdjustment),
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
        if (assemblyVersionManagerPanel != null) ...[
          const SizedBox(height: 16),
          assemblyVersionManagerPanel!,
        ],
        if (exportCheckPanelUi.visible) ...[
          const SizedBox(height: 16),
          _Panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l10n.shortVideoSpaceExportPreCheck, style: theme.textTheme.titleSmall),
                const SizedBox(height: 8),
                if (exportCheckPanelUi.loading)
                  Text(
                    exportCheckPanelUi.headline,
                    style: theme.textTheme.bodyMedium?.copyWith(color: outline),
                  )
                else if (exportCheckPanelUi.unavailable)
                  Text(
                    exportCheckPanelUi.headline,
                    style: theme.textTheme.bodyMedium?.copyWith(color: outline),
                  )
                else ...[
                  Text(
                    exportCheckPanelUi.headline,
                    style: theme.textTheme.bodyMedium?.copyWith(color: outline),
                  ),
                  if (exportCheckPanelUi.metrics.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: exportCheckPanelUi.metrics
                          .map(
                            (m) =>
                                _MetricChip(label: m.label, value: m.value),
                          )
                          .toList(growable: false),
                    ),
                  ],
                  if (exportCheckPanelUi.qualityGateLine.trim().isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Text(
                      exportCheckPanelUi.qualityGateLine,
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                  if (exportCheckPanelUi.qualityGateBlockingLines.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      l10n.shortVideoSpaceQualityGateBlockingReasons,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: outline,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    for (final line in exportCheckPanelUi.qualityGateBlockingLines)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text(
                          line,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.error,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                  ],
                  if (exportCheckPanelUi.storyboardGapEntries.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      l10n.shortVideoSpacePublishExportCheckStoryboardGapsTitle,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: outline,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    for (final gap in exportCheckPanelUi.storyboardGapEntries)
                      Theme(
                        data: theme.copyWith(dividerColor: Colors.transparent),
                        child: ExpansionTile(
                          tilePadding: EdgeInsets.zero,
                          childrenPadding: const EdgeInsets.only(
                            left: 8,
                            bottom: 6,
                          ),
                          title: Text(
                            gap.title,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: gap.hasBlocking
                                  ? theme.colorScheme.error
                                  : Colors.orange,
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
                                    color: outline,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                  ] else if (exportCheckPanelUi.blockingLines.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      l10n.shortVideoSpaceBlockingItems,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: outline,
                      ),
                    ),
                    const SizedBox(height: 6),
                    for (final line in exportCheckPanelUi.blockingLines)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text(
                          line,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.error,
                          ),
                        ),
                      ),
                  ],
                  if (exportCheckPanelUi.warningLines.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      l10n.shortVideoSpaceWarningItems,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: outline,
                      ),
                    ),
                    const SizedBox(height: 6),
                    for (final line in exportCheckPanelUi.warningLines)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text(
                          line,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: Colors.orange,
                          ),
                        ),
                      ),
                  ],
                ],
                const SizedBox(height: 8),
                Text(
                  exportCheckPanelUi.detail,
                  style: theme.textTheme.bodySmall?.copyWith(color: outline),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    FilledButton.icon(
                      onPressed: exportActionBusy || !exportCheckPanelUi.exportReady
                          ? null
                          : onStartExport,
                      icon: exportActionBusy
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.file_upload_outlined),
                      label: Text(exportActionBusy ? l10n.shortVideoSpaceExporting : l10n.shortVideoSpaceStartExport),
                    ),
                    OutlinedButton.icon(
                      onPressed: (exportActionBusy || preAssemblyActionBusy)
                          ? null
                          : onStartPreAssembly,
                      icon: preAssemblyActionBusy
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.playlist_play_outlined),
                      label: Text(
                        preAssemblyActionBusy
                            ? l10n.shortVideoSpacePreAssemblyBusy
                            : l10n.shortVideoSpaceStartPreAssembly,
                      ),
                    ),
                    OutlinedButton.icon(
                      onPressed: exportActionBusy ? null : onOpenExportHistory,
                      icon: const Icon(Icons.history),
                      label: Text(l10n.shortVideoSpaceExportHistory),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
