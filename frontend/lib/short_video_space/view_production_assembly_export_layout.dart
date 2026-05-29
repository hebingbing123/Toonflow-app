part of 'view.dart';

class _ProductionAssemblyExportLayout extends StatelessWidget {
  const _ProductionAssemblyExportLayout({
    this.dense = false,
    required this.videoRatio,
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
  final String videoRatio;
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
                _ShortVideoPanelFetchBody(
                  loading: assemblyPanelUi.loading,
                  unavailable: assemblyPanelUi.unavailable,
                  statusLine: assemblyPanelUi.headline,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
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
                  ),
                ),
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
    return LayoutBuilder(
      builder: (context, constraints) {
        final splitWide = studioUseThreePaneLayout(constraints.maxWidth) &&
            assemblyInputPanelUi.visible &&
            exportCheckPanelUi.visible;
        final input = assemblyInputWidgets();
        final snapshot = assemblySnapshotWidgets();
        final version = assemblyVersionWidgets();
        final export = buildExportCheckWidgets(context);
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
