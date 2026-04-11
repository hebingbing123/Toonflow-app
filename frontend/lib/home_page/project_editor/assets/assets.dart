part of '../../../home_page.dart';

extension _HomePageProjectEditorAssets on _HomePageState {
  Future<void> _openDeleteAssetDialog({
    required BuildContext ctx,
    required StateSetter setDialogState,
    required String token,
    required ProjectRow p,
    required List<ListAssetsResponse?> assetsRef,
    required List<bool> assetsBusy,
    required Future<void> Function() reloadAssetsAndStats,
  }) async {
    final list = assetsRef[0]?.items ?? const <AssetRow>[];
    if (list.isEmpty) {
      ScaffoldMessenger.of(
        ctx,
      ).showSnackBar(const SnackBar(content: Text('当前没有可删除资产')));
      return;
    }
    var selectedAssetNumericId = list.first.numericId;
    final confirmed = await showDialog<bool>(
      context: ctx,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (dialogCtx, setState) {
            return AlertDialog(
              title: const Text('删除资产'),
              content: SizedBox(
                width: 420,
                child: DropdownButtonFormField<int>(
                  initialValue: selectedAssetNumericId,
                  decoration: const InputDecoration(labelText: '目标资产'),
                  items: list
                      .map(
                        (asset) => DropdownMenuItem<int>(
                          value: asset.numericId,
                          child: Text(
                            '#${asset.numericId} ${asset.name}',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (v) {
                    if (v == null) return;
                    setState(() => selectedAssetNumericId = v);
                  },
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogCtx).pop(false),
                  child: const Text('取消'),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(dialogCtx).pop(true),
                  child: const Text('删除'),
                ),
              ],
            );
          },
        );
      },
    );
    if (confirmed != true || !ctx.mounted) return;
    try {
      setDialogState(() => assetsBusy[0] = true);
      await deleteProjectAssetByProjectIds(
        token,
        p.id,
        selectedAssetNumericId,
      );
      if (!ctx.mounted) return;
      await reloadAssetsAndStats();
      if (!ctx.mounted) return;
      setDialogState(() => assetsBusy[0] = false);
      ScaffoldMessenger.of(
        ctx,
      ).showSnackBar(SnackBar(content: Text('已删除资产 #$selectedAssetNumericId')));
    } on RustApiException catch (e) {
      if (ctx.mounted) {
        setDialogState(() => assetsBusy[0] = false);
        ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text('$e')));
      }
    } catch (e) {
      if (ctx.mounted) {
        setDialogState(() => assetsBusy[0] = false);
        ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  Future<void> _openScriptAssetLinkDialog({
    required BuildContext ctx,
    required StateSetter setDialogState,
    required String token,
    required ProjectRow p,
    required List<ScriptBrief> scriptList,
    required List<ListAssetsResponse?> assetsRef,
    required List<bool> assetsBusy,
    required Future<void> Function() reloadAssetsAndStats,
    required bool unlink,
  }) async {
    final list = assetsRef[0]?.items ?? const <AssetRow>[];
    if (scriptList.isEmpty || list.isEmpty) {
      ScaffoldMessenger.of(
        ctx,
      ).showSnackBar(const SnackBar(content: Text('请先准备至少一个剧本和一个资产')));
      return;
    }
    var selectedScriptNumericId = scriptList.first.numericId;
    var selectedAssetNumericId = list.first.numericId;
    final confirmed = await showDialog<bool>(
      context: ctx,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (dialogCtx, setState) {
            return AlertDialog(
              title: Text(unlink ? '取消剧本-资产关联' : '关联剧本与资产'),
              content: SizedBox(
                width: 520,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<int>(
                      initialValue: selectedScriptNumericId,
                      decoration: const InputDecoration(labelText: '剧本'),
                      items: scriptList
                          .map(
                            (script) => DropdownMenuItem<int>(
                              value: script.numericId,
                              child: Text(
                                '#${script.numericId} ${script.name ?? ""}',
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (v) {
                        if (v == null) return;
                        setState(() => selectedScriptNumericId = v);
                      },
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<int>(
                      initialValue: selectedAssetNumericId,
                      decoration: const InputDecoration(labelText: '资产'),
                      items: list
                          .map(
                            (asset) => DropdownMenuItem<int>(
                              value: asset.numericId,
                              child: Text(
                                '#${asset.numericId} ${asset.name}',
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (v) {
                        if (v == null) return;
                        setState(() => selectedAssetNumericId = v);
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogCtx).pop(false),
                  child: const Text('取消'),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(dialogCtx).pop(true),
                  child: Text(unlink ? '取消关联' : '确认关联'),
                ),
              ],
            );
          },
        );
      },
    );
    if (confirmed != true || !ctx.mounted) return;
    try {
      setDialogState(() => assetsBusy[0] = true);
      if (unlink) {
        await unlinkScriptFromAssetByProjectIds(
          token,
          p.id,
          selectedScriptNumericId,
          selectedAssetNumericId,
        );
      } else {
        await linkScriptToAssetByProjectIds(
          token,
          p.id,
          selectedScriptNumericId,
          selectedAssetNumericId,
        );
      }
      if (!ctx.mounted) return;
      await reloadAssetsAndStats();
      if (!ctx.mounted) return;
      setDialogState(() => assetsBusy[0] = false);
      ScaffoldMessenger.of(ctx).showSnackBar(
        SnackBar(
          content: Text(
            unlink
                ? '已取消关联 script#$selectedScriptNumericId · asset#$selectedAssetNumericId'
                : '已关联 script#$selectedScriptNumericId · asset#$selectedAssetNumericId',
          ),
        ),
      );
    } on RustApiException catch (e) {
      if (ctx.mounted) {
        setDialogState(() => assetsBusy[0] = false);
        ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text('$e')));
      }
    } catch (e) {
      if (ctx.mounted) {
        setDialogState(() => assetsBusy[0] = false);
        ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  Widget _buildProjectAssetsSection({
    required BuildContext ctx,
    required StateSetter setDialogState,
    required String token,
    required ProjectRow p,
    required List<ScriptBrief> scriptList,
    required List<ListAssetsResponse?> assetsRef,
    required List<ListAssetsResponse?> assetsForScriptRef,
    required List<int?> assetsFilterScriptNumericId,
    required List<bool> assetsLoading,
    required List<bool> assetsScriptFilterLoading,
    required List<bool> assetsBusy,
    required Future<void> Function() reloadAssetsAndStats,
  }) {
    final visibleAssets = assetsRef[0]?.items ?? const <AssetRow>[];
    final assetsForScript = assetsForScriptRef[0]?.items;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (assetsRef[0] != null)
          _ProjectAssetsOverviewPanel(
            scriptList: scriptList,
            visibleAssets: visibleAssets,
            assetsForScript: assetsForScript,
            filterScriptNumericId: assetsFilterScriptNumericId[0],
            assetsLoading: assetsLoading[0],
            assetsScriptFilterLoading: assetsScriptFilterLoading[0],
            assetsBusy: assetsBusy[0],
            onFilterChanged: (value) async {
              setDialogState(() => assetsScriptFilterLoading[0] = true);
              assetsFilterScriptNumericId[0] = value;
              if (value == null) {
                assetsForScriptRef[0] = null;
              }
              try {
                await reloadAssetsAndStats();
              } finally {
                if (ctx.mounted) {
                  setDialogState(() => assetsScriptFilterLoading[0] = false);
                }
              }
            },
            onRefresh: () async {
              setDialogState(() => assetsLoading[0] = true);
              try {
                await reloadAssetsAndStats();
              } finally {
                if (ctx.mounted) {
                  setDialogState(() => assetsLoading[0] = false);
                }
              }
            },
            onOpenWorkbench: () => _openAssetWorkbenchDialog(
              ctx: ctx,
              setDialogState: setDialogState,
              token: token,
              p: p,
              scriptList: scriptList,
              assetsRef: assetsRef,
              assetsForScriptRef: assetsForScriptRef,
              assetsFilterScriptNumericId: assetsFilterScriptNumericId,
              assetsBusy: assetsBusy,
              reloadAssetsAndStats: reloadAssetsAndStats,
            ),
          )
        else
          Text(
            '资产列表尚未加载',
            style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
              color: Theme.of(ctx).colorScheme.outline,
            ),
          ),
        const SizedBox(height: 8),
        ExpansionTile(
          tilePadding: EdgeInsets.zero,
          childrenPadding: EdgeInsets.zero,
          title: const Text('兼容性检查'),
          subtitle: Text(
            '保留旧资产轮询、历史图片和 workbench 形检查入口，默认折叠',
            style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
              color: Theme.of(ctx).colorScheme.outline,
            ),
          ),
          children: [
            _buildProjectAssetsImagesCompatibilitySection(
              ctx: ctx,
              setDialogState: setDialogState,
              token: token,
              p: p,
              assetsRef: assetsRef,
              assetsLoading: assetsLoading,
              assetsScriptFilterLoading: assetsScriptFilterLoading,
              assetsBusy: assetsBusy,
              reloadAssetsAndStats: reloadAssetsAndStats,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 4,
              runSpacing: 0,
              children: [
                ..._buildProjectAssetsPrimaryActions(
                  ctx: ctx,
                  setDialogState: setDialogState,
                  token: token,
                  p: p,
                  assetsRef: assetsRef,
                  assetsFilterScriptNumericId: assetsFilterScriptNumericId,
                  assetsLoading: assetsLoading,
                  assetsScriptFilterLoading: assetsScriptFilterLoading,
                  assetsBusy: assetsBusy,
                  reloadAssetsAndStats: reloadAssetsAndStats,
                ),
                ..._buildProjectAssetsRelationActions(
                  ctx: ctx,
                  setDialogState: setDialogState,
                  token: token,
                  p: p,
                  scriptList: scriptList,
                  assetsRef: assetsRef,
                  assetsLoading: assetsLoading,
                  assetsScriptFilterLoading: assetsScriptFilterLoading,
                  assetsBusy: assetsBusy,
                  reloadAssetsAndStats: reloadAssetsAndStats,
                ),
                ..._buildProjectAssetsQueryCompatibilityActions(
                  ctx: ctx,
                  setDialogState: setDialogState,
                  token: token,
                  p: p,
                  assetsRef: assetsRef,
                  assetsFilterScriptNumericId: assetsFilterScriptNumericId,
                  assetsLoading: assetsLoading,
                  assetsScriptFilterLoading: assetsScriptFilterLoading,
                  assetsBusy: assetsBusy,
                  reloadAssetsAndStats: reloadAssetsAndStats,
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }
}
