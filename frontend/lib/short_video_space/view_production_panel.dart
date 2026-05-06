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
    required this.onOpenProductionForAssemblyExport,
    required this.onOpenAssemblyClipDeskOps,
    required this.onOpenAssemblyDefaultsEditor,
  });

  final String spaceOverviewSummary;
  final List<ShortVideoMetricData> overviewMetrics;
  final String qualitySummaryLine;
  final List<ShortVideoMetricData> badCaseMetrics;
  final List<String> recentTaskLines;
  final ShortVideoAssetsOverviewPanelUi assetsOverviewPanelUi;
  final ShortVideoAssemblyPanelUi assemblyPanelUi;
  final ShortVideoExportCheckPanelUi exportCheckPanelUi;
  final VoidCallback? onOpenProductionForAssemblyExport;
  final VoidCallback? onOpenAssemblyClipDeskOps;
  final VoidCallback? onOpenAssemblyDefaultsEditor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final outline = theme.colorScheme.outline;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('当前项目概览', style: theme.textTheme.titleSmall),
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
                Text('最近坏例倾向', style: theme.textTheme.labelLarge),
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
                Text('最近任务流', style: theme.textTheme.labelLarge),
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
                Text('资产总览', style: theme.textTheme.titleSmall),
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
                Text('成片装配快照', style: theme.textTheme.titleSmall),
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
                      '成片候选验收（质量评审）',
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
                    Text('受限多轨导出决策（K5）', style: theme.textTheme.labelMedium),
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
                        label: const Text('打开制作工作区'),
                      ),
                      if (onOpenAssemblyClipDeskOps != null)
                        OutlinedButton.icon(
                          onPressed: onOpenAssemblyClipDeskOps,
                          icon: const Icon(Icons.tune_outlined),
                          label: const Text('镜头基础操作'),
                        ),
                      if (onOpenAssemblyDefaultsEditor != null)
                        OutlinedButton.icon(
                          onPressed: onOpenAssemblyDefaultsEditor,
                          icon: const Icon(Icons.subtitles_outlined),
                          label: const Text('成片样式调整'),
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
        if (exportCheckPanelUi.visible) ...[
          const SizedBox(height: 16),
          _Panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('导出前检查', style: theme.textTheme.titleSmall),
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
                  if (exportCheckPanelUi.blockingLines.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      '阻塞项（按接口顺序节选）',
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
                          style: theme.textTheme.bodySmall,
                        ),
                      ),
                  ],
                ],
                const SizedBox(height: 8),
                Text(
                  exportCheckPanelUi.detail,
                  style: theme.textTheme.bodySmall?.copyWith(color: outline),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
