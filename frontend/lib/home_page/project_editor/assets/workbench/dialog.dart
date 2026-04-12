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

    Future<void> refreshWorkbench(StateSetter setLocalState) async {
      await reloadAssetsAndStats();
      final refreshed = assetsRef[0]?.items ?? const <AssetRow>[];
      setLocalState(() {
        selectedAssetNumericId = chooseInitialAssetNumericId(
          refreshed,
          preferredNumericId: selectedAssetNumericId,
        );
        statusLine = refreshed.isEmpty
            ? '当前项目还没有资产，可直接在这里创建。'
            : summarizeProjectAssetRows(refreshed);
      });
    }

    Future<void> runAction(
      StateSetter setLocalState,
      Future<void> Function() action,
    ) async {
      setLocalState(() => localBusy = true);
      try {
        await action();
        if (ctx.mounted) {
          await refreshWorkbench(setLocalState);
        }
      } finally {
        if (ctx.mounted) {
          setLocalState(() => localBusy = false);
        }
      }
    }

    Future<void> openChildWorkbench(
      BuildContext dialogCtx,
      StateSetter setLocalState,
      Future<void> Function() action,
    ) async {
      await action();
      if (!dialogCtx.mounted || !ctx.mounted) {
        return;
      }
      await refreshWorkbench(setLocalState);
    }

    await showDialog<void>(
      context: ctx,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (dialogCtx, setLocalState) {
            final assets = assetsRef[0]?.items ?? const <AssetRow>[];
            AssetRow? selectedAsset;
            if (selectedAssetNumericId != null) {
              for (final row in assets) {
                if (row.numericId == selectedAssetNumericId) {
                  selectedAsset = row;
                  break;
                }
              }
            }
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
                setLocalState,
                () => _openCreateAssetDialog(
                  ctx: dialogCtx,
                  setDialogState: setDialogState,
                  token: token,
                  p: p,
                  assetsBusy: assetsBusy,
                  reloadAssetsAndStats: reloadAssetsAndStats,
                ),
              ),
              onEdit: () => runAction(
                setLocalState,
                () => _openEditAssetDialog(
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
                setLocalState,
                () => _openDeleteAssetDialog(
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
                setLocalState,
                () => _openAssetFilterDialog(
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
                setLocalState,
                () => _openScriptAssetLinkDialog(
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
                setLocalState,
                () => _openScriptAssetLinkDialog(
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
                setLocalState,
                () => _openEditImageUploadDialog(
                  ctx: dialogCtx,
                  setDialogState: setDialogState,
                  token: token,
                  p: p,
                  scriptList: scriptList,
                  assetsBusy: assetsBusy,
                ),
              ),
              onUploadClip: () => runAction(
                setLocalState,
                () => _openClipUploadDialog(
                  ctx: dialogCtx,
                  setDialogState: setDialogState,
                  token: token,
                  p: p,
                  assetsBusy: assetsBusy,
                  reloadAssetsAndStats: reloadAssetsAndStats,
                ),
              ),
              onOpenImagesWorkbench: () => openChildWorkbench(
                dialogCtx,
                setLocalState,
                () => _openAssetImagesWorkbenchDialog(
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
                dialogCtx,
                setLocalState,
                () => _openAssetGenerationWorkbenchDialog(
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
                dialogCtx,
                setLocalState,
                () => _openCornerScapeWorkbenchDialog(
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
