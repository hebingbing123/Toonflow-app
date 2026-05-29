part of 'view.dart';

/// Production overview and stats panel widget
class _ProductionPanel extends StatelessWidget {
  const _ProductionPanel({
    this.dense = false,
    required this.videoRatio,
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
  final String videoRatio;
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _ProductionAssetsOverviewSection(
          dense: dense,
          ui: assetsOverviewPanelUi,
        ),
        _ProductionAssemblyExportLayout(
          dense: dense,
          videoRatio: videoRatio,
          assemblyPanelUi: assemblyPanelUi,
          assemblyInputPanelUi: assemblyInputPanelUi,
          exportCheckPanelUi: exportCheckPanelUi,
          latestExportUi: latestExportUi,
          onStartExport: onStartExport,
          onStartPreAssembly: onStartPreAssembly,
          onFixAssemblyStoryboard: onFixAssemblyStoryboard,
          onFixAssemblyProduction: onFixAssemblyProduction,
          onFixAssemblyClipDesk: onFixAssemblyClipDesk,
          onOpenAssemblyTaskCenter: onOpenAssemblyTaskCenter,
          onCancelAssemblyJob: onCancelAssemblyJob,
          onRetryAssemblyJob: onRetryAssemblyJob,
          onCreateDraftFromAssemblyJob: onCreateDraftFromAssemblyJob,
          preAssemblyBlockedTooltip: preAssemblyBlockedTooltip,
          onOpenExportHistory: onOpenExportHistory,
          onDownloadLatestExport: onDownloadLatestExport,
          onCancelLatestExportTask: onCancelLatestExportTask,
          onRetryLatestExportTask: onRetryLatestExportTask,
          exportActionBusy: exportActionBusy,
          preAssemblyActionBusy: preAssemblyActionBusy,
          localAssemblyBlockedHint: localAssemblyBlockedHint,
          onOpenProductionForAssemblyExport: onOpenProductionForAssemblyExport,
          onOpenDesktopDownloads: onOpenDesktopDownloads,
          onOpenAssemblyClipDeskOps: onOpenAssemblyClipDeskOps,
          onOpenAssemblyDefaultsEditor: onOpenAssemblyDefaultsEditor,
          assemblyVersionManagerPanel: assemblyVersionManagerPanel,
          assemblyInputPanelKey: assemblyInputPanelKey,
          onRefreshExportCheck: onRefreshExportCheck,
        ),
      ],
    );
  }
}
