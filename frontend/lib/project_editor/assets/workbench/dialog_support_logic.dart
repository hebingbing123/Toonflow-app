part of 'dialog_support.dart';

int? chooseInitialScriptNumericId(
  Iterable<ScriptBrief> scripts, {
  int? preferredNumericId,
}) {
  final rows = scripts.toList(growable: false);
  if (rows.isEmpty) {
    return null;
  }
  if (preferredNumericId != null) {
    for (final script in rows) {
      if (script.numericId == preferredNumericId) {
        return preferredNumericId;
      }
    }
  }
  return rows.first.numericId;
}

class ProjectAssetsWorkbenchSession {
  ProjectAssetsWorkbenchSession({
    required List<AssetRow> visibleAssets,
    required List<ScriptBrief> scriptList,
    required String initialStatusLine,
    this.targetKind = ProjectStudioAssetEditorTargetKind.overview,
    this.focusNotice,
    int? preferredAssetNumericId,
    int? preferredScriptNumericId,
  }) : selectedAssetNumericId = chooseInitialAssetNumericId(
         visibleAssets,
         preferredNumericId: preferredAssetNumericId,
       ),
       selectedScriptNumericId = chooseInitialScriptNumericId(
         scriptList,
         preferredNumericId: preferredScriptNumericId,
       ),
       statusLine = initialStatusLine;

  int? selectedAssetNumericId;
  int? selectedScriptNumericId;
  String statusLine;
  final ProjectStudioAssetEditorTargetKind targetKind;
  final String? focusNotice;
  bool localBusy = false;
}

class ProjectAssetsWorkbenchController {
  const ProjectAssetsWorkbenchController({
    required this.ctx,
    required this.token,
    required this.project,
    required this.setDialogState,
    required this.scriptList,
    required this.assetsRef,
    required this.assetsForScriptRef,
    required this.assetsFilterScriptNumericId,
    required this.assetsBusy,
    required this.reloadAssetsAndStats,
    required this.session,
    required this.onCreateAsset,
    required this.onEditAsset,
    required this.onDeleteAsset,
    required this.onFilterAssets,
    required this.onLinkAsset,
    required this.onUnlinkAsset,
    required this.onReviewCandidates,
    required this.onUploadEditImage,
    required this.onUploadClip,
    required this.onOpenImagesWorkbench,
    required this.onOpenGenerationWorkbench,
    required this.onOpenHistoryWorkbench,
  });

  final BuildContext ctx;
  final String token;
  final ProjectRow project;
  final StateSetter setDialogState;
  final List<ScriptBrief> scriptList;
  final List<ListAssetsResponse?> assetsRef;
  final List<ListAssetsResponse?> assetsForScriptRef;
  final List<int?> assetsFilterScriptNumericId;
  final List<bool> assetsBusy;
  final Future<void> Function() reloadAssetsAndStats;
  final ProjectAssetsWorkbenchSession session;
  final Future<void> Function(BuildContext dialogCtx) onCreateAsset;
  final Future<void> Function(BuildContext dialogCtx) onEditAsset;
  final Future<void> Function(BuildContext dialogCtx) onDeleteAsset;
  final Future<void> Function(BuildContext dialogCtx) onFilterAssets;
  final Future<void> Function(BuildContext dialogCtx) onLinkAsset;
  final Future<void> Function(BuildContext dialogCtx) onUnlinkAsset;
  final Future<void> Function(
    BuildContext dialogCtx,
    int? preferredAssetNumericId,
  )
  onReviewCandidates;
  final Future<void> Function(BuildContext dialogCtx) onUploadEditImage;
  final Future<void> Function(BuildContext dialogCtx) onUploadClip;
  final Future<void> Function(
    BuildContext dialogCtx,
    int? preferredAssetNumericId,
  )
  onOpenImagesWorkbench;
  final Future<void> Function(
    BuildContext dialogCtx,
    int? preferredAssetNumericId,
  )
  onOpenGenerationWorkbench;
  final Future<void> Function(
    BuildContext dialogCtx,
    int? preferredAssetNumericId,
  )
  onOpenHistoryWorkbench;

  Future<void> refreshWorkbench(StateSetter setLocalState) =>
      refreshProjectAssetsWorkbench(
        l10n: resolveAppLocalizationsForErrors(ctx),
        reloadAssetsAndStats: reloadAssetsAndStats,
        assetsRef: assetsRef,
        selectedAssetNumericId: session.selectedAssetNumericId,
        onSelectedAssetNumericIdChanged: (value) =>
            session.selectedAssetNumericId = value,
        onStatusLineChanged: (line) => session.statusLine = line,
        setLocalState: setLocalState,
      );

  Future<void> runWorkbenchAction({
    required StateSetter setLocalState,
    required Future<void> Function() action,
  }) => runAction(
    ctx: ctx,
    setLocalState: setLocalState,
    onBusyChanged: (busy) => session.localBusy = busy,
    refreshWorkbench: () => refreshWorkbench(setLocalState),
    action: action,
  );

  Future<void> openWorkbenchChildDialog({
    required BuildContext dialogCtx,
    required StateSetter setLocalState,
    required Future<void> Function() action,
  }) => openChildWorkbench(
    parentCtx: ctx,
    dialogCtx: dialogCtx,
    refreshWorkbench: () => refreshWorkbench(setLocalState),
    action: action,
  );
}

AssetRow? findAssetByNumericId(List<AssetRow> assets, int? numericId) {
  if (numericId == null) {
    return null;
  }
  for (final row in assets) {
    if (row.numericId == numericId) {
      return row;
    }
  }
  return null;
}

Future<void> refreshProjectAssetsWorkbench({
  required AppLocalizations l10n,
  required Future<void> Function() reloadAssetsAndStats,
  required List<ListAssetsResponse?> assetsRef,
  required int? selectedAssetNumericId,
  required ValueChanged<int?> onSelectedAssetNumericIdChanged,
  required ValueChanged<String> onStatusLineChanged,
  required StateSetter setLocalState,
}) async {
  await reloadAssetsAndStats();
  final refreshed = assetsRef[0]?.items ?? const <AssetRow>[];
  setLocalState(() {
    onSelectedAssetNumericIdChanged(
      chooseInitialAssetNumericId(
        refreshed,
        preferredNumericId: selectedAssetNumericId,
      ),
    );
    onStatusLineChanged(
      refreshed.isEmpty
          ? l10n.projectEditorAssetsWorkbenchNoAssetsYet
          : summarizeProjectAssetRows(refreshed),
    );
  });
}

Future<void> runAction({
  required BuildContext ctx,
  required StateSetter setLocalState,
  required ValueChanged<bool> onBusyChanged,
  required Future<void> Function() refreshWorkbench,
  required Future<void> Function() action,
}) async {
  setLocalState(() => onBusyChanged(true));
  try {
    await action();
    if (ctx.mounted) {
      await refreshWorkbench();
    }
  } finally {
    if (ctx.mounted) {
      setLocalState(() => onBusyChanged(false));
    }
  }
}

Future<void> openChildWorkbench({
  required BuildContext parentCtx,
  required BuildContext dialogCtx,
  required Future<void> Function() refreshWorkbench,
  required Future<void> Function() action,
}) async {
  await action();
  if (!dialogCtx.mounted || !parentCtx.mounted) {
    return;
  }
  await refreshWorkbench();
}
