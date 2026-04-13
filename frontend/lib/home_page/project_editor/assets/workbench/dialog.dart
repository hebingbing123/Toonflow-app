part of '../../../../home_page.dart';

extension _HomePageProjectEditorAssetsWorkbench on _HomePageState {
  Future<void> _openAssetWorkbenchDialog({
    required BuildContext ctx,
    required StateSetter setDialogState,
    required String token,
    required ProjectRow p,
    required List<ScriptBrief> scriptList,
    required List<ListAssetsResponse?> assetsRef,
    required List<ListAssetsResponse?> assetsForScriptRef,
    required List<int?> assetsFilterScriptNumericId,
    required List<bool> assetsBusy,
    required Future<void> Function() reloadAssetsAndStats,
  }) async {
    final visibleAssets = assetsRef[0]?.items ?? const <AssetRow>[];
    var selectedAssetNumericId = chooseInitialAssetNumericId(visibleAssets);
    var selectedScriptNumericId = scriptList.isEmpty
        ? null
        : scriptList.first.numericId;
    String statusLine = visibleAssets.isEmpty
        ? '当前项目还没有资产，可直接在这里创建。'
        : summarizeProjectAssetRows(visibleAssets);
    bool localBusy = false;

    await showDialog<void>(
      context: ctx,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (dialogCtx, setLocalState) {
            final assets = assetsRef[0]?.items ?? const <AssetRow>[];
            final selectedAsset = findAssetByNumericId(
              assets,
              selectedAssetNumericId,
            );
            final scopedAssets = assetsFilterScriptNumericId[0] == null
                ? assets
                : (assetsForScriptRef[0]?.items ?? const <AssetRow>[]);
            return buildProjectAssetsWorkbenchDialog(
              dialogCtx: dialogCtx,
              localBusy: localBusy,
              assetsBusy: assetsBusy[0],
              statusLine: statusLine,
              scopedAssets: scopedAssets,
              assetsFilterScriptNumericId: assetsFilterScriptNumericId[0],
              selectedAsset: selectedAsset,
              assets: assets,
              scriptList: scriptList,
              selectedAssetNumericId: selectedAssetNumericId,
              selectedScriptNumericId: selectedScriptNumericId,
              onAssetChanged: assets.isEmpty
                  ? null
                  : (value) {
                      setLocalState(() => selectedAssetNumericId = value);
                    },
              onScriptChanged: scriptList.isEmpty
                  ? null
                  : (value) {
                      setLocalState(() => selectedScriptNumericId = value);
                    },
              onCreate: () => runAction(
                ctx: ctx,
                setLocalState: setLocalState,
                onBusyChanged: (busy) => localBusy = busy,
                refreshWorkbench: () => refreshProjectAssetsWorkbench(
                  reloadAssetsAndStats: reloadAssetsAndStats,
                  assetsRef: assetsRef,
                  selectedAssetNumericId: selectedAssetNumericId,
                  onSelectedAssetNumericIdChanged: (value) =>
                      selectedAssetNumericId = value,
                  onStatusLineChanged: (line) => statusLine = line,
                  setLocalState: setLocalState,
                ),
                action: () => _openCreateAssetDialog(
                  ctx: dialogCtx,
                  setDialogState: setDialogState,
                  token: token,
                  p: p,
                  assetsBusy: assetsBusy,
                  reloadAssetsAndStats: reloadAssetsAndStats,
                ),
              ),
              onEdit: () => runAction(
                ctx: ctx,
                setLocalState: setLocalState,
                onBusyChanged: (busy) => localBusy = busy,
                refreshWorkbench: () => refreshProjectAssetsWorkbench(
                  reloadAssetsAndStats: reloadAssetsAndStats,
                  assetsRef: assetsRef,
                  selectedAssetNumericId: selectedAssetNumericId,
                  onSelectedAssetNumericIdChanged: (value) =>
                      selectedAssetNumericId = value,
                  onStatusLineChanged: (line) => statusLine = line,
                  setLocalState: setLocalState,
                ),
                action: () => _openEditAssetDialog(
                  ctx: dialogCtx,
                  setDialogState: setDialogState,
                  token: token,
                  p: p,
                  assetsRef: assetsRef,
                  assetsBusy: assetsBusy,
                  reloadAssetsAndStats: reloadAssetsAndStats,
                ),
              ),
              onDelete: () => runAction(
                ctx: ctx,
                setLocalState: setLocalState,
                onBusyChanged: (busy) => localBusy = busy,
                refreshWorkbench: () => refreshProjectAssetsWorkbench(
                  reloadAssetsAndStats: reloadAssetsAndStats,
                  assetsRef: assetsRef,
                  selectedAssetNumericId: selectedAssetNumericId,
                  onSelectedAssetNumericIdChanged: (value) =>
                      selectedAssetNumericId = value,
                  onStatusLineChanged: (line) => statusLine = line,
                  setLocalState: setLocalState,
                ),
                action: () => _openDeleteAssetDialog(
                  ctx: dialogCtx,
                  setDialogState: setDialogState,
                  token: token,
                  p: p,
                  assetsRef: assetsRef,
                  assetsBusy: assetsBusy,
                  reloadAssetsAndStats: reloadAssetsAndStats,
                ),
              ),
              onFilter: () => runAction(
                ctx: ctx,
                setLocalState: setLocalState,
                onBusyChanged: (busy) => localBusy = busy,
                refreshWorkbench: () => refreshProjectAssetsWorkbench(
                  reloadAssetsAndStats: reloadAssetsAndStats,
                  assetsRef: assetsRef,
                  selectedAssetNumericId: selectedAssetNumericId,
                  onSelectedAssetNumericIdChanged: (value) =>
                      selectedAssetNumericId = value,
                  onStatusLineChanged: (line) => statusLine = line,
                  setLocalState: setLocalState,
                ),
                action: () => _openAssetFilterDialog(
                  ctx: dialogCtx,
                  setDialogState: setDialogState,
                  token: token,
                  p: p,
                  scriptList: scriptList,
                  assetsRef: assetsRef,
                  assetsForScriptRef: assetsForScriptRef,
                  assetsFilterScriptNumericId: assetsFilterScriptNumericId,
                  assetsBusy: assetsBusy,
                ),
              ),
              onLink: () => runAction(
                ctx: ctx,
                setLocalState: setLocalState,
                onBusyChanged: (busy) => localBusy = busy,
                refreshWorkbench: () => refreshProjectAssetsWorkbench(
                  reloadAssetsAndStats: reloadAssetsAndStats,
                  assetsRef: assetsRef,
                  selectedAssetNumericId: selectedAssetNumericId,
                  onSelectedAssetNumericIdChanged: (value) =>
                      selectedAssetNumericId = value,
                  onStatusLineChanged: (line) => statusLine = line,
                  setLocalState: setLocalState,
                ),
                action: () => _openScriptAssetLinkDialog(
                  ctx: dialogCtx,
                  setDialogState: setDialogState,
                  token: token,
                  p: p,
                  scriptList: scriptList,
                  assetsRef: assetsRef,
                  assetsBusy: assetsBusy,
                  reloadAssetsAndStats: reloadAssetsAndStats,
                  unlink: false,
                ),
              ),
              onUnlink: () => runAction(
                ctx: ctx,
                setLocalState: setLocalState,
                onBusyChanged: (busy) => localBusy = busy,
                refreshWorkbench: () => refreshProjectAssetsWorkbench(
                  reloadAssetsAndStats: reloadAssetsAndStats,
                  assetsRef: assetsRef,
                  selectedAssetNumericId: selectedAssetNumericId,
                  onSelectedAssetNumericIdChanged: (value) =>
                      selectedAssetNumericId = value,
                  onStatusLineChanged: (line) => statusLine = line,
                  setLocalState: setLocalState,
                ),
                action: () => _openScriptAssetLinkDialog(
                  ctx: dialogCtx,
                  setDialogState: setDialogState,
                  token: token,
                  p: p,
                  scriptList: scriptList,
                  assetsRef: assetsRef,
                  assetsBusy: assetsBusy,
                  reloadAssetsAndStats: reloadAssetsAndStats,
                  unlink: true,
                ),
              ),
              onUploadEditImage: () => runAction(
                ctx: ctx,
                setLocalState: setLocalState,
                onBusyChanged: (busy) => localBusy = busy,
                refreshWorkbench: () => refreshProjectAssetsWorkbench(
                  reloadAssetsAndStats: reloadAssetsAndStats,
                  assetsRef: assetsRef,
                  selectedAssetNumericId: selectedAssetNumericId,
                  onSelectedAssetNumericIdChanged: (value) =>
                      selectedAssetNumericId = value,
                  onStatusLineChanged: (line) => statusLine = line,
                  setLocalState: setLocalState,
                ),
                action: () => _openEditImageUploadDialog(
                  ctx: dialogCtx,
                  setDialogState: setDialogState,
                  token: token,
                  p: p,
                  scriptList: scriptList,
                  assetsBusy: assetsBusy,
                ),
              ),
              onUploadClip: () => runAction(
                ctx: ctx,
                setLocalState: setLocalState,
                onBusyChanged: (busy) => localBusy = busy,
                refreshWorkbench: () => refreshProjectAssetsWorkbench(
                  reloadAssetsAndStats: reloadAssetsAndStats,
                  assetsRef: assetsRef,
                  selectedAssetNumericId: selectedAssetNumericId,
                  onSelectedAssetNumericIdChanged: (value) =>
                      selectedAssetNumericId = value,
                  onStatusLineChanged: (line) => statusLine = line,
                  setLocalState: setLocalState,
                ),
                action: () => _openClipUploadDialog(
                  ctx: dialogCtx,
                  setDialogState: setDialogState,
                  token: token,
                  p: p,
                  assetsBusy: assetsBusy,
                  reloadAssetsAndStats: reloadAssetsAndStats,
                ),
              ),
              onOpenImagesWorkbench: () => openChildWorkbench(
                parentCtx: ctx,
                dialogCtx: dialogCtx,
                refreshWorkbench: () => refreshProjectAssetsWorkbench(
                  reloadAssetsAndStats: reloadAssetsAndStats,
                  assetsRef: assetsRef,
                  selectedAssetNumericId: selectedAssetNumericId,
                  onSelectedAssetNumericIdChanged: (value) =>
                      selectedAssetNumericId = value,
                  onStatusLineChanged: (line) => statusLine = line,
                  setLocalState: setLocalState,
                ),
                action: () => _openAssetImagesWorkbenchDialog(
                  ctx: dialogCtx,
                  setDialogState: setDialogState,
                  token: token,
                  p: p,
                  assetsRef: assetsRef,
                  assetsBusy: assetsBusy,
                  reloadAssetsAndStats: reloadAssetsAndStats,
                  preferredAssetNumericId: selectedAssetNumericId,
                ),
              ),
              onOpenGenerationWorkbench: () => openChildWorkbench(
                parentCtx: ctx,
                dialogCtx: dialogCtx,
                refreshWorkbench: () => refreshProjectAssetsWorkbench(
                  reloadAssetsAndStats: reloadAssetsAndStats,
                  assetsRef: assetsRef,
                  selectedAssetNumericId: selectedAssetNumericId,
                  onSelectedAssetNumericIdChanged: (value) =>
                      selectedAssetNumericId = value,
                  onStatusLineChanged: (line) => statusLine = line,
                  setLocalState: setLocalState,
                ),
                action: () => _openAssetGenerationWorkbenchDialog(
                  ctx: dialogCtx,
                  setDialogState: setDialogState,
                  token: token,
                  p: p,
                  scriptList: scriptList,
                  assetsRef: assetsRef,
                  assetsForScriptRef: assetsForScriptRef,
                  assetsFilterScriptNumericId: assetsFilterScriptNumericId,
                  assetsBusy: assetsBusy,
                  reloadAssetsAndStats: reloadAssetsAndStats,
                  preferredAssetNumericId: selectedAssetNumericId,
                ),
              ),
              onOpenHistoryWorkbench: () => openChildWorkbench(
                parentCtx: ctx,
                dialogCtx: dialogCtx,
                refreshWorkbench: () => refreshProjectAssetsWorkbench(
                  reloadAssetsAndStats: reloadAssetsAndStats,
                  assetsRef: assetsRef,
                  selectedAssetNumericId: selectedAssetNumericId,
                  onSelectedAssetNumericIdChanged: (value) =>
                      selectedAssetNumericId = value,
                  onStatusLineChanged: (line) => statusLine = line,
                  setLocalState: setLocalState,
                ),
                action: () => _openCornerScapeWorkbenchDialog(
                  ctx: dialogCtx,
                  setDialogState: setDialogState,
                  token: token,
                  p: p,
                  assetsBusy: assetsBusy,
                  preferredAssetNumericId: selectedAssetNumericId,
                ),
              ),
              onRefresh: localBusy
                  ? null
                  : () => refreshProjectAssetsWorkbench(
                      reloadAssetsAndStats: reloadAssetsAndStats,
                      assetsRef: assetsRef,
                      selectedAssetNumericId: selectedAssetNumericId,
                      onSelectedAssetNumericIdChanged: (value) =>
                          selectedAssetNumericId = value,
                      onStatusLineChanged: (line) => statusLine = line,
                      setLocalState: setLocalState,
                    ),
              onClose: localBusy ? null : () => Navigator.of(dialogCtx).pop(),
            );
          },
        );
      },
    );
  }
}
