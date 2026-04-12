part of '../../../home_page.dart';

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

    try {
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
              return AlertDialog(
                title: const Text('资产主工作台'),
                content: SizedBox(
                  width: 780,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '把资产 CRUD、剧本关联、筛选和上传入口收口到一个正式工作台，主区不再堆一排控制台式按钮。',
                          style: Theme.of(dialogCtx).textTheme.bodySmall,
                        ),
                        const SizedBox(height: 12),
                        _ProjectAssetsWorkbenchOverview(
                          statusLine: statusLine,
                          scriptScopedLine: summarizeScriptScopedAssets(
                            assetsFilterScriptNumericId[0],
                            scopedAssets,
                          ),
                          selectedAsset: selectedAsset,
                          assets: assets,
                          scriptList: scriptList,
                          selectedAssetNumericId: selectedAssetNumericId,
                          selectedScriptNumericId: selectedScriptNumericId,
                          onAssetChanged: assets.isEmpty
                              ? null
                              : (value) {
                                  setLocalState(
                                    () => selectedAssetNumericId = value,
                                  );
                                },
                          onScriptChanged: scriptList.isEmpty
                              ? null
                              : (value) {
                                  setLocalState(
                                    () => selectedScriptNumericId = value,
                                  );
                                },
                        ),
                        const SizedBox(height: 12),
                        _ProjectAssetsWorkbenchActions(
                          localBusy: localBusy,
                          assetsBusy: assetsBusy[0],
                          assets: assets,
                          scriptList: scriptList,
                          selectedScriptNumericId: selectedScriptNumericId,
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
                              assetsFilterScriptNumericId:
                                  assetsFilterScriptNumericId,
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
                        ),
                        const SizedBox(height: 12),
                        _ProjectAssetsWorkbenchLaunchers(
                          localBusy: localBusy,
                          assetsBusy: assetsBusy[0],
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
                              assetsFilterScriptNumericId:
                                  assetsFilterScriptNumericId,
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
                        ),
                      ],
                    ),
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: localBusy
                        ? null
                        : () => refreshWorkbench(setLocalState),
                    child: Text(localBusy ? '处理中…' : '刷新工作台'),
                  ),
                  TextButton(
                    onPressed: localBusy
                        ? null
                        : () => Navigator.of(dialogCtx).pop(),
                    child: const Text('关闭'),
                  ),
                ],
              );
            },
          );
        },
      );
    } catch (_) {
      rethrow;
    }
  }
}
