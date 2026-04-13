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

    Future<void> refreshWorkbench(StateSetter setLocalState) =>
        refreshProjectAssetsWorkbench(
          reloadAssetsAndStats: reloadAssetsAndStats,
          assetsRef: assetsRef,
          selectedAssetNumericId: selectedAssetNumericId,
          onSelectedAssetNumericIdChanged: (value) =>
              selectedAssetNumericId = value,
          onStatusLineChanged: (line) => statusLine = line,
          setLocalState: setLocalState,
        );

    Future<void> runWorkbenchAction({
      required StateSetter setLocalState,
      required Future<void> Function() action,
    }) => runAction(
      ctx: ctx,
      setLocalState: setLocalState,
      onBusyChanged: (busy) => localBusy = busy,
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
              onCreate: () => runWorkbenchAction(
                setLocalState: setLocalState,
                action: () => _openCreateAssetDialog(
                  ctx: dialogCtx,
                  setDialogState: setDialogState,
                  token: token,
                  p: p,
                  assetsBusy: assetsBusy,
                  reloadAssetsAndStats: reloadAssetsAndStats,
                ),
              ),
              onEdit: () => runWorkbenchAction(
                setLocalState: setLocalState,
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
              onDelete: () => runWorkbenchAction(
                setLocalState: setLocalState,
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
              onFilter: () => runWorkbenchAction(
                setLocalState: setLocalState,
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
              onLink: () => runWorkbenchAction(
                setLocalState: setLocalState,
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
              onUnlink: () => runWorkbenchAction(
                setLocalState: setLocalState,
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
              onUploadEditImage: () => runWorkbenchAction(
                setLocalState: setLocalState,
                action: () => _openEditImageUploadDialog(
                  ctx: dialogCtx,
                  setDialogState: setDialogState,
                  token: token,
                  p: p,
                  scriptList: scriptList,
                  assetsBusy: assetsBusy,
                ),
              ),
              onUploadClip: () => runWorkbenchAction(
                setLocalState: setLocalState,
                action: () => _openClipUploadDialog(
                  ctx: dialogCtx,
                  setDialogState: setDialogState,
                  token: token,
                  p: p,
                  assetsBusy: assetsBusy,
                  reloadAssetsAndStats: reloadAssetsAndStats,
                ),
              ),
              onOpenImagesWorkbench: () => openWorkbenchChildDialog(
                dialogCtx: dialogCtx,
                setLocalState: setLocalState,
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
              onOpenGenerationWorkbench: () => openWorkbenchChildDialog(
                dialogCtx: dialogCtx,
                setLocalState: setLocalState,
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
              onOpenHistoryWorkbench: () => openWorkbenchChildDialog(
                dialogCtx: dialogCtx,
                setLocalState: setLocalState,
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
                  : () => refreshWorkbench(setLocalState),
              onClose: localBusy ? null : () => Navigator.of(dialogCtx).pop(),
            );
          },
        );
      },
    );
  }
}
