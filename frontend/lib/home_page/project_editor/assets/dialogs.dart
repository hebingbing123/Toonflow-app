part of '../../../home_page.dart';

extension _HomePageProjectEditorAssetsDialogs on _HomePageState {
  /// Handles asset create and edit dialogs so the main assets section stays thin.
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

  /// Handles asset create and edit dialogs so the main assets section stays thin.
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
    var selectedAssetNumericId = list.first.numericId;
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
                          final selected = list.firstWhere(
                            (asset) => asset.numericId == v,
                          );
                          setState(() {
                            selectedAssetNumericId = v;
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
        selectedAssetNumericId,
        body,
      );
      if (!ctx.mounted) return;
      await reloadAssetsAndStats();
      if (!ctx.mounted) return;
      setDialogState(() => assetsBusy[0] = false);
      ScaffoldMessenger.of(
        ctx,
      ).showSnackBar(SnackBar(content: Text('已更新资产 #$selectedAssetNumericId')));
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

  /// Handles delete and relation dialogs so assets.dart can stay focused on section composition.
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

  /// Handles delete and relation dialogs so assets.dart can stay focused on section composition.
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

  Future<void> _openAssetFilterDialog({
    required BuildContext ctx,
    required StateSetter setDialogState,
    required String token,
    required ProjectRow p,
    required List<ScriptBrief> scriptList,
    required List<ListAssetsResponse?> assetsRef,
    required List<ListAssetsResponse?> assetsForScriptRef,
    required List<int?> assetsFilterScriptNumericId,
    required List<bool> assetsBusy,
  }) async {
    final typeCtrl = TextEditingController();
    final nameCtrl = TextEditingController();
    final pageCtrl = TextEditingController(text: '1');
    final limitCtrl = TextEditingController(text: '20');
    int? selectedScriptNumericId = assetsFilterScriptNumericId[0];
    try {
      final confirmed = await showDialog<bool>(
        context: ctx,
        builder: (dialogCtx) {
          return StatefulBuilder(
            builder: (dialogCtx, setState) {
              return AlertDialog(
                title: const Text('高级筛选资产'),
                content: SizedBox(
                  width: 520,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      DropdownButtonFormField<int?>(
                        initialValue: selectedScriptNumericId,
                        decoration: const InputDecoration(labelText: '按剧本筛选'),
                        items: [
                          const DropdownMenuItem<int?>(
                            value: null,
                            child: Text('（全部剧本）'),
                          ),
                          ...scriptList.map(
                            (script) => DropdownMenuItem<int?>(
                              value: script.numericId,
                              child: Text(
                                '#${script.numericId} ${script.name ?? ""}',
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                        ],
                        onChanged: (v) => setState(() {
                          selectedScriptNumericId = v;
                        }),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: typeCtrl,
                        decoration: const InputDecoration(
                          labelText: '资产类型（可选）',
                          hintText: 'role / clip / props',
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: nameCtrl,
                        decoration: const InputDecoration(
                          labelText: '资产名称关键字（可选）',
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: pageCtrl,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'page',
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: limitCtrl,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'limit',
                              ),
                            ),
                          ),
                        ],
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
                    child: const Text('应用筛选'),
                  ),
                ],
              );
            },
          );
        },
      );
      if (confirmed != true || !ctx.mounted) return;

      final page = int.tryParse(pageCtrl.text.trim());
      final limit = int.tryParse(limitCtrl.text.trim());
      if ((page != null && page <= 0) || (limit != null && limit <= 0)) {
        ScaffoldMessenger.of(
          ctx,
        ).showSnackBar(const SnackBar(content: Text('page/limit 必须是正整数')));
        return;
      }

      setDialogState(() => assetsBusy[0] = true);
      final filtered = await fetchProjectAssetsByProjectId(
        token,
        p.id,
        scriptNumericId: selectedScriptNumericId,
        assetType: typeCtrl.text.trim().isEmpty ? null : typeCtrl.text.trim(),
        name: nameCtrl.text.trim().isEmpty ? null : nameCtrl.text.trim(),
        page: page,
        limit: limit,
      );
      if (!ctx.mounted) return;
      setDialogState(() {
        assetsRef[0] = filtered;
        assetsFilterScriptNumericId[0] = selectedScriptNumericId;
        if (selectedScriptNumericId != null) {
          assetsForScriptRef[0] = filtered;
        } else {
          assetsForScriptRef[0] = null;
        }
        assetsBusy[0] = false;
      });
      ScaffoldMessenger.of(ctx).showSnackBar(
        SnackBar(
          content: Text('筛选完成：返回 ${filtered.items.length}/${filtered.total} 条'),
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
    } finally {
      typeCtrl.dispose();
      nameCtrl.dispose();
      pageCtrl.dispose();
      limitCtrl.dispose();
    }
  }

  Future<void> _openEditImageUploadDialog({
    required BuildContext ctx,
    required StateSetter setDialogState,
    required String token,
    required ProjectRow p,
    required List<ScriptBrief> scriptList,
    required List<bool> assetsBusy,
  }) async {
    if (scriptList.isEmpty) {
      ScaffoldMessenger.of(
        ctx,
      ).showSnackBar(const SnackBar(content: Text('请先创建剧本再上传编辑图片')));
      return;
    }
    final base64Ctrl = TextEditingController(
      text: 'data:image/png;base64,AA==',
    );
    var selectedScriptNumericId = scriptList.first.numericId;
    try {
      final confirmed = await showDialog<bool>(
        context: ctx,
        builder: (dialogCtx) {
          return StatefulBuilder(
            builder: (dialogCtx, setState) {
              return AlertDialog(
                title: const Text('上传编辑图片'),
                content: SizedBox(
                  width: 520,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      DropdownButtonFormField<int>(
                        initialValue: selectedScriptNumericId,
                        decoration: const InputDecoration(labelText: '目标剧本'),
                        items: scriptList
                            .map(
                              (s) => DropdownMenuItem<int>(
                                value: s.numericId,
                                child: Text(
                                  '#${s.numericId} ${s.name ?? ""}',
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
                      TextField(
                        controller: base64Ctrl,
                        minLines: 4,
                        maxLines: 7,
                        decoration: const InputDecoration(
                          labelText: '图片 data URI',
                          helperText: '支持 jpeg/jpg/png 的 base64 data URI',
                        ),
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
                    child: const Text('上传'),
                  ),
                ],
              );
            },
          );
        },
      );
      if (confirmed != true || !ctx.mounted) return;
      final payload = base64Ctrl.text.trim();
      if (payload.isEmpty) {
        ScaffoldMessenger.of(
          ctx,
        ).showSnackBar(const SnackBar(content: Text('base64 data URI 不能为空')));
        return;
      }

      setDialogState(() => assetsBusy[0] = true);
      final uploaded = await postProductionEditImageUploadImageV1(
        token,
        projectId: p.numericId,
        scriptId: selectedScriptNumericId,
        base64Data: payload,
      );
      if (!ctx.mounted) return;
      setDialogState(() => assetsBusy[0] = false);
      ScaffoldMessenger.of(
        ctx,
      ).showSnackBar(SnackBar(content: Text('上传成功：${uploaded.url}')));
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
      base64Ctrl.dispose();
    }
  }
}
