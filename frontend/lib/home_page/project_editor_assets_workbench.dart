part of '../home_page.dart';

extension _HomePageProjectEditorAssetsWorkbench on _HomePageState {
  Future<void> _openAssetWorkbenchDialog({
    required BuildContext ctx,
    required StateSetter setDialogState,
    required String token,
    required ProjectRow p,
    required List<ScriptBrief> scriptList,
    required List<ListAssetsResponse?> assetsRef,
    required List<ListAssetsResponse?> assetsForScriptRef,
    required List<int?> assetsFilterScriptLegacyId,
    required List<bool> assetsBusy,
    required Future<void> Function() reloadAssetsAndStats,
  }) async {
    final visibleAssets = assetsRef[0]?.items ?? const <AssetRow>[];
    var selectedAssetLegacyId = chooseInitialAssetLegacyId(visibleAssets);
    var selectedScriptLegacyId = scriptList.isEmpty ? null : scriptList.first.legacyId;
    String statusLine = visibleAssets.isEmpty
        ? '当前项目还没有资产，可直接在这里创建。'
        : summarizeProjectAssetRows(visibleAssets);
    bool localBusy = false;

    Future<void> refreshWorkbench(StateSetter setLocalState) async {
      await reloadAssetsAndStats();
      final refreshed = assetsRef[0]?.items ?? const <AssetRow>[];
      setLocalState(() {
        selectedAssetLegacyId = chooseInitialAssetLegacyId(
          refreshed,
          preferredLegacyId: selectedAssetLegacyId,
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

    try {
      await showDialog<void>(
        context: ctx,
        builder: (dialogCtx) {
          return StatefulBuilder(
            builder: (dialogCtx, setLocalState) {
              final assets = assetsRef[0]?.items ?? const <AssetRow>[];
              AssetRow? selectedAsset;
              if (selectedAssetLegacyId != null) {
                for (final row in assets) {
                  if (row.legacyId == selectedAssetLegacyId) {
                    selectedAsset = row;
                    break;
                  }
                }
              }
              final scopedAssets = assetsFilterScriptLegacyId[0] == null
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
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: Theme.of(dialogCtx).colorScheme.outlineVariant,
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                statusLine,
                                style: Theme.of(dialogCtx).textTheme.bodySmall,
                              ),
                              const SizedBox(height: 6),
                              Text(
                                summarizeScriptScopedAssets(
                                  assetsFilterScriptLegacyId[0],
                                  scopedAssets,
                                ),
                                style: Theme.of(dialogCtx).textTheme.bodySmall,
                              ),
                              if (selectedAsset != null) ...[
                                const SizedBox(height: 6),
                                Text(
                                  '当前焦点资产：#${selectedAsset.legacyId} ${selectedAsset.name} · ${selectedAsset.assetType}',
                                  style: Theme.of(dialogCtx).textTheme.bodySmall,
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<int?>(
                          initialValue: selectedAssetLegacyId,
                          decoration: const InputDecoration(
                            labelText: '当前焦点资产',
                            helperText: '用于快速查看当前工作焦点；具体编辑在下方动作中完成。',
                          ),
                          items: [
                            const DropdownMenuItem<int?>(
                              value: null,
                              child: Text('（当前无资产）'),
                            ),
                            ...assets.map(
                              (asset) => DropdownMenuItem<int?>(
                                value: asset.legacyId,
                                child: Text(
                                  '#${asset.legacyId} ${asset.name}',
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                          ],
                          onChanged: assets.isEmpty
                              ? null
                              : (value) {
                                  setLocalState(() => selectedAssetLegacyId = value);
                                },
                        ),
                        const SizedBox(height: 8),
                        DropdownButtonFormField<int?>(
                          initialValue: selectedScriptLegacyId,
                          decoration: const InputDecoration(
                            labelText: '当前焦点剧本',
                            helperText: '用于剧本-资产关联相关动作。',
                          ),
                          items: [
                            const DropdownMenuItem<int?>(
                              value: null,
                              child: Text('（当前无剧本）'),
                            ),
                            ...scriptList.map(
                              (script) => DropdownMenuItem<int?>(
                                value: script.legacyId,
                                child: Text(
                                  '#${script.legacyId} ${script.name ?? ""}',
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                          ],
                          onChanged: scriptList.isEmpty
                              ? null
                              : (value) {
                                  setLocalState(() => selectedScriptLegacyId = value);
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
                                        reloadAssetsAndStats: reloadAssetsAndStats,
                                      ),
                                    ),
                              child: const Text('新建资产'),
                            ),
                            OutlinedButton(
                              onPressed: localBusy || assetsBusy[0] || assets.isEmpty
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
                                        reloadAssetsAndStats: reloadAssetsAndStats,
                                      ),
                                    ),
                              child: const Text('编辑资产'),
                            ),
                            OutlinedButton(
                              onPressed: localBusy || assetsBusy[0] || assets.isEmpty
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
                                        reloadAssetsAndStats: reloadAssetsAndStats,
                                      ),
                                    ),
                              child: const Text('删除资产'),
                            ),
                            OutlinedButton(
                              onPressed: localBusy || assetsBusy[0] || assets.isEmpty
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
                                        assetsFilterScriptLegacyId: assetsFilterScriptLegacyId,
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
                              onPressed: localBusy ||
                                      assetsBusy[0] ||
                                      assets.isEmpty ||
                                      scriptList.isEmpty ||
                                      selectedScriptLegacyId == null
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
                                        reloadAssetsAndStats: reloadAssetsAndStats,
                                        unlink: false,
                                      ),
                                    ),
                              child: const Text('关联剧本与资产'),
                            ),
                            OutlinedButton(
                              onPressed: localBusy ||
                                      assetsBusy[0] ||
                                      assets.isEmpty ||
                                      scriptList.isEmpty ||
                                      selectedScriptLegacyId == null
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
                                        reloadAssetsAndStats: reloadAssetsAndStats,
                                        unlink: true,
                                      ),
                                    ),
                              child: const Text('取消关联'),
                            ),
                            OutlinedButton(
                              onPressed: localBusy || assetsBusy[0] || scriptList.isEmpty
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
                                        reloadAssetsAndStats: reloadAssetsAndStats,
                                      ),
                                    ),
                              child: const Text('上传 Clip 资产'),
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
                    onPressed: localBusy ? null : () => Navigator.of(dialogCtx).pop(),
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
