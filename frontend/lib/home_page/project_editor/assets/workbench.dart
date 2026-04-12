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
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            FilledButton.tonal(
                              onPressed: localBusy || assetsBusy[0]
                                  ? null
                                  : () => runAction(
                                      setLocalState,
                                      () => _openCreateAssetDialog(
                                        ctx: dialogCtx,
                                        setDialogState: setDialogState,
                                        token: token,
                                        p: p,
                                        assetsBusy: assetsBusy,
                                        reloadAssetsAndStats:
                                            reloadAssetsAndStats,
                                      ),
                                    ),
                              child: const Text('新建资产'),
                            ),
                            OutlinedButton(
                              onPressed:
                                  localBusy || assetsBusy[0] || assets.isEmpty
                                  ? null
                                  : () => runAction(
                                      setLocalState,
                                      () => _openEditAssetDialog(
                                        ctx: dialogCtx,
                                        setDialogState: setDialogState,
                                        token: token,
                                        p: p,
                                        assetsRef: assetsRef,
                                        assetsBusy: assetsBusy,
                                        reloadAssetsAndStats:
                                            reloadAssetsAndStats,
                                      ),
                                    ),
                              child: const Text('编辑资产'),
                            ),
                            OutlinedButton(
                              onPressed:
                                  localBusy || assetsBusy[0] || assets.isEmpty
                                  ? null
                                  : () => runAction(
                                      setLocalState,
                                      () => _openDeleteAssetDialog(
                                        ctx: dialogCtx,
                                        setDialogState: setDialogState,
                                        token: token,
                                        p: p,
                                        assetsRef: assetsRef,
                                        assetsBusy: assetsBusy,
                                        reloadAssetsAndStats:
                                            reloadAssetsAndStats,
                                      ),
                                    ),
                              child: const Text('删除资产'),
                            ),
                            OutlinedButton(
                              onPressed:
                                  localBusy || assetsBusy[0] || assets.isEmpty
                                  ? null
                                  : () => runAction(
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
                              child: const Text('筛选资产'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            OutlinedButton(
                              onPressed:
                                  localBusy ||
                                      assetsBusy[0] ||
                                      assets.isEmpty ||
                                      scriptList.isEmpty ||
                                      selectedScriptNumericId == null
                                  ? null
                                  : () => runAction(
                                      setLocalState,
                                      () => _openScriptAssetLinkDialog(
                                        ctx: dialogCtx,
                                        setDialogState: setDialogState,
                                        token: token,
                                        p: p,
                                        scriptList: scriptList,
                                        assetsRef: assetsRef,
                                        assetsBusy: assetsBusy,
                                        reloadAssetsAndStats:
                                            reloadAssetsAndStats,
                                        unlink: false,
                                      ),
                                    ),
                              child: const Text('关联剧本与资产'),
                            ),
                            OutlinedButton(
                              onPressed:
                                  localBusy ||
                                      assetsBusy[0] ||
                                      assets.isEmpty ||
                                      scriptList.isEmpty ||
                                      selectedScriptNumericId == null
                                  ? null
                                  : () => runAction(
                                      setLocalState,
                                      () => _openScriptAssetLinkDialog(
                                        ctx: dialogCtx,
                                        setDialogState: setDialogState,
                                        token: token,
                                        p: p,
                                        scriptList: scriptList,
                                        assetsRef: assetsRef,
                                        assetsBusy: assetsBusy,
                                        reloadAssetsAndStats:
                                            reloadAssetsAndStats,
                                        unlink: true,
                                      ),
                                    ),
                              child: const Text('取消关联'),
                            ),
                            OutlinedButton(
                              onPressed:
                                  localBusy ||
                                      assetsBusy[0] ||
                                      scriptList.isEmpty
                                  ? null
                                  : () => runAction(
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
                              child: const Text('上传编辑图片'),
                            ),
                            OutlinedButton(
                              onPressed: localBusy || assetsBusy[0]
                                  ? null
                                  : () => runAction(
                                      setLocalState,
                                      () => _openClipUploadDialog(
                                        ctx: dialogCtx,
                                        setDialogState: setDialogState,
                                        token: token,
                                        p: p,
                                        assetsBusy: assetsBusy,
                                        reloadAssetsAndStats:
                                            reloadAssetsAndStats,
                                      ),
                                    ),
                              child: const Text('上传 Clip 资产'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          '专项工作台',
                          style: Theme.of(dialogCtx).textTheme.titleSmall,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '把图片管理、出图链路和历史图查询也统一挂到这里，资产主区只保留一个正式入口。',
                          style: Theme.of(dialogCtx).textTheme.bodySmall,
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            OutlinedButton(
                              onPressed: localBusy || assetsBusy[0]
                                  ? null
                                  : () => openChildWorkbench(
                                      dialogCtx,
                                      setLocalState,
                                      () => _openAssetImagesWorkbenchDialog(
                                        ctx: dialogCtx,
                                        setDialogState: setDialogState,
                                        token: token,
                                        p: p,
                                        assetsRef: assetsRef,
                                        assetsBusy: assetsBusy,
                                        reloadAssetsAndStats:
                                            reloadAssetsAndStats,
                                        preferredAssetNumericId:
                                            selectedAssetNumericId,
                                      ),
                                    ),
                              child: const Text('资产图片工作台'),
                            ),
                            OutlinedButton(
                              onPressed: localBusy || assetsBusy[0]
                                  ? null
                                  : () => openChildWorkbench(
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
                                        reloadAssetsAndStats:
                                            reloadAssetsAndStats,
                                        preferredAssetNumericId:
                                            selectedAssetNumericId,
                                      ),
                                    ),
                              child: const Text('资产出图工作台'),
                            ),
                            OutlinedButton(
                              onPressed: localBusy || assetsBusy[0]
                                  ? null
                                  : () => openChildWorkbench(
                                      dialogCtx,
                                      setLocalState,
                                      () => _openCornerScapeWorkbenchDialog(
                                        ctx: dialogCtx,
                                        setDialogState: setDialogState,
                                        token: token,
                                        p: p,
                                        assetsBusy: assetsBusy,
                                        preferredAssetNumericId:
                                            selectedAssetNumericId,
                                      ),
                                    ),
                              child: const Text('资产历史图工作台'),
                            ),
                          ],
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
