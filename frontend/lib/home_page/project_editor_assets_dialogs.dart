part of '../home_page.dart';

extension _HomePageProjectEditorAssetsDialogs on _HomePageState {
  Future<void> _openAssetFilterDialog({
    required BuildContext ctx,
    required StateSetter setDialogState,
    required String token,
    required ProjectRow p,
    required List<ScriptBrief> scriptList,
    required List<ListAssetsResponse?> assetsRef,
    required List<ListAssetsResponse?> assetsForScriptRef,
    required List<int?> assetsFilterScriptLegacyId,
    required List<bool> assetsBusy,
  }) async {
    final typeCtrl = TextEditingController();
    final nameCtrl = TextEditingController();
    final pageCtrl = TextEditingController(text: '1');
    final limitCtrl = TextEditingController(text: '20');
    int? selectedScriptLegacyId = assetsFilterScriptLegacyId[0];
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
                        initialValue: selectedScriptLegacyId,
                        decoration: const InputDecoration(labelText: '按剧本筛选'),
                        items: [
                          const DropdownMenuItem<int?>(
                            value: null,
                            child: Text('（全部剧本）'),
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
                        onChanged: (v) => setState(() {
                          selectedScriptLegacyId = v;
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
                              decoration: const InputDecoration(labelText: 'page'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: limitCtrl,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(labelText: 'limit'),
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
        ScaffoldMessenger.of(ctx).showSnackBar(
          const SnackBar(content: Text('page/limit 必须是正整数')),
        );
        return;
      }

      setDialogState(() => assetsBusy[0] = true);
      final filtered = await fetchProjectAssetsByLegacyId(
        token,
        p.legacyId,
        scriptLegacyId: selectedScriptLegacyId,
        assetType: typeCtrl.text.trim().isEmpty ? null : typeCtrl.text.trim(),
        name: nameCtrl.text.trim().isEmpty ? null : nameCtrl.text.trim(),
        page: page,
        limit: limit,
      );
      if (!ctx.mounted) return;
      setDialogState(() {
        assetsRef[0] = filtered;
        assetsFilterScriptLegacyId[0] = selectedScriptLegacyId;
        if (selectedScriptLegacyId != null) {
          assetsForScriptRef[0] = filtered;
        } else {
          assetsForScriptRef[0] = null;
        }
        assetsBusy[0] = false;
      });
      ScaffoldMessenger.of(ctx).showSnackBar(
        SnackBar(
          content: Text(
            '筛选完成：返回 ${filtered.items.length}/${filtered.total} 条',
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
      ScaffoldMessenger.of(ctx).showSnackBar(
        const SnackBar(content: Text('请先创建剧本再上传编辑图片')),
      );
      return;
    }
    final base64Ctrl = TextEditingController(
      text: 'data:image/png;base64,AA==',
    );
    var selectedScriptLegacyId = scriptList.first.legacyId;
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
                        initialValue: selectedScriptLegacyId,
                        decoration: const InputDecoration(labelText: '目标剧本'),
                        items: scriptList
                            .map(
                              (s) => DropdownMenuItem<int>(
                                value: s.legacyId,
                                child: Text(
                                  '#${s.legacyId} ${s.name ?? ""}',
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
        ScaffoldMessenger.of(ctx).showSnackBar(
          const SnackBar(content: Text('base64 data URI 不能为空')),
        );
        return;
      }

      setDialogState(() => assetsBusy[0] = true);
      final uploaded = await postProductionEditImageUploadImageV1(
        token,
        projectId: p.legacyId,
        scriptId: selectedScriptLegacyId,
        base64Data: payload,
      );
      if (!ctx.mounted) return;
      setDialogState(() => assetsBusy[0] = false);
      ScaffoldMessenger.of(ctx).showSnackBar(
        SnackBar(content: Text('上传成功：${uploaded.url}')),
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
      base64Ctrl.dispose();
    }
  }
}
