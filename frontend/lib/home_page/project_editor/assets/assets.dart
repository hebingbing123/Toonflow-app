part of '../../../home_page.dart';

extension _HomePageProjectEditorAssets on _HomePageState {
  Future<void> _openCreateAssetDialog({
    required BuildContext ctx,
    required StateSetter setDialogState,
    required String token,
    required ProjectRow p,
    required List<bool> assetsBusy,
    required Future<void> Function() reloadAssetsAndStats,
  }) async {
    final nameCtrl = TextEditingController();
    final typeCtrl = TextEditingController(text: 'role');
    final descriptionCtrl = TextEditingController();
    try {
      final confirmed = await showDialog<bool>(
        context: ctx,
        builder: (dialogCtx) {
          return AlertDialog(
            title: const Text('新建资产'),
            content: SizedBox(
              width: 520,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(labelText: '资产名称'),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: typeCtrl,
                    decoration: const InputDecoration(
                      labelText: '资产类型',
                      helperText: '示例：role / clip / props',
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: descriptionCtrl,
                    minLines: 2,
                    maxLines: 4,
                    decoration: const InputDecoration(labelText: '描述（可选）'),
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
                child: const Text('创建'),
              ),
            ],
          );
        },
      );
      if (confirmed != true || !ctx.mounted) return;
      final name = nameCtrl.text.trim();
      final type = typeCtrl.text.trim();
      if (name.isEmpty || type.isEmpty) {
        ScaffoldMessenger.of(
          ctx,
        ).showSnackBar(const SnackBar(content: Text('资产名称和类型不能为空')));
        return;
      }

      setDialogState(() => assetsBusy[0] = true);
      await createProjectAssetUnderProject(
        token,
        p.id,
        name: name,
        type: type,
        description: descriptionCtrl.text.trim().isEmpty
            ? null
            : descriptionCtrl.text.trim(),
      );
      if (!ctx.mounted) return;
      await reloadAssetsAndStats();
      if (!ctx.mounted) return;
      setDialogState(() => assetsBusy[0] = false);
      ScaffoldMessenger.of(
        ctx,
      ).showSnackBar(const SnackBar(content: Text('已创建资产')));
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
    } finally {
      nameCtrl.dispose();
      typeCtrl.dispose();
      descriptionCtrl.dispose();
    }
  }

  Future<void> _openEditAssetDialog({
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
      ).showSnackBar(const SnackBar(content: Text('当前没有可编辑资产')));
      return;
    }
    var selectedAssetLegacyId = list.first.legacyId;
    final nameCtrl = TextEditingController(text: list.first.name);
    final typeCtrl = TextEditingController(text: list.first.assetType);
    final descriptionCtrl = TextEditingController(
      text: list.first.description ?? '',
    );
    try {
      final confirmed = await showDialog<bool>(
        context: ctx,
        builder: (dialogCtx) {
          return StatefulBuilder(
            builder: (dialogCtx, setState) {
              return AlertDialog(
                title: const Text('编辑资产'),
                content: SizedBox(
                  width: 520,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      DropdownButtonFormField<int>(
                        initialValue: selectedAssetLegacyId,
                        decoration: const InputDecoration(labelText: '目标资产'),
                        items: list
                            .map(
                              (asset) => DropdownMenuItem<int>(
                                value: asset.legacyId,
                                child: Text(
                                  '#${asset.legacyId} ${asset.name}',
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: (v) {
                          if (v == null) return;
                          final selected = list.firstWhere(
                            (asset) => asset.legacyId == v,
                          );
                          setState(() {
                            selectedAssetLegacyId = v;
                            nameCtrl.text = selected.name;
                            typeCtrl.text = selected.assetType;
                            descriptionCtrl.text = selected.description ?? '';
                          });
                        },
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: nameCtrl,
                        decoration: const InputDecoration(labelText: '资产名称'),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: typeCtrl,
                        decoration: const InputDecoration(labelText: '资产类型'),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: descriptionCtrl,
                        minLines: 2,
                        maxLines: 4,
                        decoration: const InputDecoration(labelText: '描述（可选）'),
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
                    child: const Text('保存'),
                  ),
                ],
              );
            },
          );
        },
      );
      if (confirmed != true || !ctx.mounted) return;
      final body = <String, dynamic>{};
      final name = nameCtrl.text.trim();
      final type = typeCtrl.text.trim();
      if (name.isNotEmpty) {
        body['name'] = name;
      }
      if (type.isNotEmpty) {
        body['asset_type'] = type;
      }
      body['description'] = descriptionCtrl.text.trim().isEmpty
          ? null
          : descriptionCtrl.text.trim();
      if (body.isEmpty) {
        ScaffoldMessenger.of(
          ctx,
        ).showSnackBar(const SnackBar(content: Text('请至少填写一项修改内容')));
        return;
      }

      setDialogState(() => assetsBusy[0] = true);
      await patchProjectAssetByProjectIds(
        token,
        p.id,
        selectedAssetLegacyId,
        body,
      );
      if (!ctx.mounted) return;
      await reloadAssetsAndStats();
      if (!ctx.mounted) return;
      setDialogState(() => assetsBusy[0] = false);
      ScaffoldMessenger.of(
        ctx,
      ).showSnackBar(SnackBar(content: Text('已更新资产 #$selectedAssetLegacyId')));
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
    } finally {
      nameCtrl.dispose();
      typeCtrl.dispose();
      descriptionCtrl.dispose();
    }
  }

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
    var selectedAssetLegacyId = list.first.legacyId;
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
                  initialValue: selectedAssetLegacyId,
                  decoration: const InputDecoration(labelText: '目标资产'),
                  items: list
                      .map(
                        (asset) => DropdownMenuItem<int>(
                          value: asset.legacyId,
                          child: Text(
                            '#${asset.legacyId} ${asset.name}',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (v) {
                    if (v == null) return;
                    setState(() => selectedAssetLegacyId = v);
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
        selectedAssetLegacyId,
      );
      if (!ctx.mounted) return;
      await reloadAssetsAndStats();
      if (!ctx.mounted) return;
      setDialogState(() => assetsBusy[0] = false);
      ScaffoldMessenger.of(
        ctx,
      ).showSnackBar(SnackBar(content: Text('已删除资产 #$selectedAssetLegacyId')));
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
    var selectedScriptLegacyId = scriptList.first.legacyId;
    var selectedAssetLegacyId = list.first.legacyId;
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
                      initialValue: selectedScriptLegacyId,
                      decoration: const InputDecoration(labelText: '剧本'),
                      items: scriptList
                          .map(
                            (script) => DropdownMenuItem<int>(
                              value: script.legacyId,
                              child: Text(
                                '#${script.legacyId} ${script.name ?? ""}',
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (v) {
                        if (v == null) return;
                        setState(() => selectedScriptLegacyId = v);
                      },
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<int>(
                      initialValue: selectedAssetLegacyId,
                      decoration: const InputDecoration(labelText: '资产'),
                      items: list
                          .map(
                            (asset) => DropdownMenuItem<int>(
                              value: asset.legacyId,
                              child: Text(
                                '#${asset.legacyId} ${asset.name}',
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (v) {
                        if (v == null) return;
                        setState(() => selectedAssetLegacyId = v);
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
          selectedScriptLegacyId,
          selectedAssetLegacyId,
        );
      } else {
        await linkScriptToAssetByProjectIds(
          token,
          p.id,
          selectedScriptLegacyId,
          selectedAssetLegacyId,
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
                ? '已取消关联 script#$selectedScriptLegacyId · asset#$selectedAssetLegacyId'
                : '已关联 script#$selectedScriptLegacyId · asset#$selectedAssetLegacyId',
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
    required List<int?> assetsFilterScriptLegacyId,
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
            filterScriptLegacyId: assetsFilterScriptLegacyId[0],
            assetsLoading: assetsLoading[0],
            assetsScriptFilterLoading: assetsScriptFilterLoading[0],
            assetsBusy: assetsBusy[0],
            onFilterChanged: (value) async {
              setDialogState(() => assetsScriptFilterLoading[0] = true);
              assetsFilterScriptLegacyId[0] = value;
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
              assetsFilterScriptLegacyId: assetsFilterScriptLegacyId,
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
            '保留旧资产轮询、历史图片和 legacy 形检查入口，默认折叠',
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
                  assetsFilterScriptLegacyId: assetsFilterScriptLegacyId,
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
                  assetsFilterScriptLegacyId: assetsFilterScriptLegacyId,
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
