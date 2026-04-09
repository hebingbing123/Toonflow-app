part of '../home_page.dart';

extension _HomePageProjectEditorAssetsImagesWorkbench on _HomePageState {
  Future<void> _openAssetImagesWorkbenchDialog({
    required BuildContext ctx,
    required StateSetter setDialogState,
    required String token,
    required ProjectRow p,
    required List<ListAssetsResponse?> assetsRef,
    required List<bool> assetsBusy,
    required Future<void> Function() reloadAssetsAndStats,
  }) async {
    final assets = assetsRef[0]?.items ?? const <AssetRow>[];
    if (assets.isEmpty) {
      ScaffoldMessenger.of(
        ctx,
      ).showSnackBar(const SnackBar(content: Text('请先创建资产再管理图片')));
      return;
    }
    var selectedAssetLegacyId = assets.first.legacyId;
    String? selectedImageId;
    ListAssetImagesResponse? imagesResponse;
    Uint8List? previewBytes;
    bool loadingList = false;
    bool loadingPreview = false;
    bool busyMutation = false;
    String? statusLine;

    final createFilePathCtrl = TextEditingController();
    final createStateCtrl = TextEditingController();
    final createSortCtrl = TextEditingController();
    final patchFilePathCtrl = TextEditingController();
    final patchStateCtrl = TextEditingController();
    final patchSortCtrl = TextEditingController();

    AssetImageRow? selectedImage() {
      final items = imagesResponse?.items ?? const <AssetImageRow>[];
      if (selectedImageId == null) return null;
      for (final row in items) {
        if (row.id == selectedImageId) {
          return row;
        }
      }
      return null;
    }

    void syncPatchFieldsFromSelected(StateSetter setState) {
      final image = selectedImage();
      setState(() {
        if (image == null) {
          patchFilePathCtrl.text = '';
          patchStateCtrl.text = '';
          patchSortCtrl.text = '';
          return;
        }
        patchFilePathCtrl.text = image.filePath ?? '';
        patchStateCtrl.text = image.state ?? '';
        patchSortCtrl.text = image.sortIndex.toString();
      });
    }

    Future<void> reloadImages(StateSetter setState) async {
      setState(() {
        loadingList = true;
        statusLine = null;
      });
      try {
        final response = await fetchProjectAssetImagesByLegacyIds(
          token,
          p.legacyId,
          selectedAssetLegacyId,
        );
        setState(() {
          imagesResponse = response;
          selectedImageId = response.items.isEmpty
              ? null
              : response.items.first.id;
          previewBytes = null;
          statusLine = '已加载 ${response.items.length} 张图片';
        });
        syncPatchFieldsFromSelected(setState);
      } on RustApiException catch (e) {
        setState(() {
          imagesResponse = null;
          selectedImageId = null;
          previewBytes = null;
          statusLine = '加载失败：$e';
        });
      } catch (e) {
        setState(() {
          imagesResponse = null;
          selectedImageId = null;
          previewBytes = null;
          statusLine = '加载失败：$e';
        });
      } finally {
        setState(() => loadingList = false);
      }
    }

    Future<void> loadPreview(StateSetter setState) async {
      final image = selectedImage();
      if (image == null) {
        setState(() => previewBytes = null);
        return;
      }
      setState(() {
        loadingPreview = true;
        previewBytes = null;
      });
      try {
        final bytes = await fetchProjectAssetImageFileByLegacyIds(
          token,
          p.legacyId,
          selectedAssetLegacyId,
          image.id,
        );
        setState(() => previewBytes = bytes);
      } on RustApiException catch (e) {
        setState(() => statusLine = '预览失败：$e');
      } finally {
        setState(() => loadingPreview = false);
      }
    }

    int? parsePositiveInt(String raw) {
      if (raw.trim().isEmpty) return null;
      final parsed = int.tryParse(raw.trim());
      if (parsed == null || parsed <= 0) return null;
      return parsed;
    }

    Future<void> createImage(StateSetter setState) async {
      final filePath = createFilePathCtrl.text.trim();
      final state = createStateCtrl.text.trim();
      final sort = parsePositiveInt(createSortCtrl.text);
      if (createSortCtrl.text.trim().isNotEmpty && sort == null) {
        setState(() => statusLine = '新增 sort_index 需为正整数');
        return;
      }
      setDialogState(() => assetsBusy[0] = true);
      setState(() => busyMutation = true);
      try {
        await createProjectAssetImage(
          token,
          p.legacyId,
          selectedAssetLegacyId,
          filePath: filePath.isEmpty ? null : filePath,
          state: state.isEmpty ? null : state,
          sortIndex: sort,
        );
        await reloadImages(setState);
        await reloadAssetsAndStats();
        setState(() => statusLine = '已新增资产图片');
      } on RustApiException catch (e) {
        setState(() => statusLine = '新增失败：$e');
      } finally {
        setState(() => busyMutation = false);
        if (ctx.mounted) {
          setDialogState(() => assetsBusy[0] = false);
        }
      }
    }

    Future<void> patchImage(StateSetter setState) async {
      final image = selectedImage();
      if (image == null) {
        setState(() => statusLine = '请先选择要编辑的图片');
        return;
      }
      final body = <String, dynamic>{};
      final filePath = patchFilePathCtrl.text.trim();
      final state = patchStateCtrl.text.trim();
      final sortRaw = patchSortCtrl.text.trim();
      if (filePath.isNotEmpty) {
        body['file_path'] = filePath;
      } else {
        body['file_path'] = null;
      }
      if (state.isNotEmpty) {
        body['state'] = state;
      } else {
        body['state'] = null;
      }
      if (sortRaw.isNotEmpty) {
        final sort = parsePositiveInt(sortRaw);
        if (sort == null) {
          setState(() => statusLine = '编辑 sort_index 需为正整数');
          return;
        }
        body['sort_index'] = sort;
      }
      setDialogState(() => assetsBusy[0] = true);
      setState(() => busyMutation = true);
      try {
        await patchProjectAssetImageByLegacyIds(
          token,
          p.legacyId,
          selectedAssetLegacyId,
          image.id,
          body,
        );
        await reloadImages(setState);
        setState(() => statusLine = '已更新图片');
      } on RustApiException catch (e) {
        setState(() => statusLine = '更新失败：$e');
      } finally {
        setState(() => busyMutation = false);
        if (ctx.mounted) {
          setDialogState(() => assetsBusy[0] = false);
        }
      }
    }

    Future<void> deleteImage(StateSetter setState) async {
      final image = selectedImage();
      if (image == null) {
        setState(() => statusLine = '请先选择要删除的图片');
        return;
      }
      setDialogState(() => assetsBusy[0] = true);
      setState(() => busyMutation = true);
      try {
        await deleteProjectAssetImageByLegacyIds(
          token,
          p.legacyId,
          selectedAssetLegacyId,
          image.id,
        );
        await reloadImages(setState);
        setState(() => statusLine = '已删除图片');
      } on RustApiException catch (e) {
        setState(() => statusLine = '删除失败：$e');
      } finally {
        setState(() => busyMutation = false);
        if (ctx.mounted) {
          setDialogState(() => assetsBusy[0] = false);
        }
      }
    }

    try {
      await showDialog<void>(
        context: ctx,
        builder: (dialogCtx) {
          return StatefulBuilder(
            builder: (dialogCtx, setState) {
              final imageItems =
                  imagesResponse?.items ?? const <AssetImageRow>[];
              return AlertDialog(
                title: const Text('资产图片工作台'),
                content: SizedBox(
                  width: 760,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      DropdownButtonFormField<int>(
                        initialValue: selectedAssetLegacyId,
                        decoration: const InputDecoration(labelText: '目标资产'),
                        items: assets
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
                        onChanged: (value) {
                          if (value == null) return;
                          setState(() {
                            selectedAssetLegacyId = value;
                            imagesResponse = null;
                            selectedImageId = null;
                            previewBytes = null;
                            statusLine = null;
                          });
                        },
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          FilledButton(
                            onPressed: loadingList || busyMutation
                                ? null
                                : () => reloadImages(setState),
                            child: Text(loadingList ? '加载中…' : '加载图片列表'),
                          ),
                          TextButton(
                            onPressed: loadingPreview || busyMutation
                                ? null
                                : () => loadPreview(setState),
                            child: Text(loadingPreview ? '预览中…' : '预览当前图片'),
                          ),
                        ],
                      ),
                      if (statusLine != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          statusLine!,
                          style: Theme.of(ctx).textTheme.bodySmall,
                        ),
                      ],
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        initialValue: selectedImageId,
                        decoration: const InputDecoration(labelText: '图片列表'),
                        items: imageItems
                            .map(
                              (img) => DropdownMenuItem<String>(
                                value: img.id,
                                child: Text(
                                  '#${img.sortIndex} · ${img.state ?? "-"} · ${img.id.substring(0, img.id.length >= 8 ? 8 : img.id.length)}',
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: imageItems.isEmpty
                            ? null
                            : (value) {
                                if (value == null) return;
                                setState(() {
                                  selectedImageId = value;
                                  previewBytes = null;
                                });
                                syncPatchFieldsFromSelected(setState);
                              },
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: createFilePathCtrl,
                        decoration: const InputDecoration(
                          labelText: '新增 file_path（可选）',
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: createStateCtrl,
                              decoration: const InputDecoration(
                                labelText: '新增 state（可选）',
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: createSortCtrl,
                              decoration: const InputDecoration(
                                labelText: '新增 sort_index（可选）',
                              ),
                              keyboardType: TextInputType.number,
                            ),
                          ),
                        ],
                      ),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton(
                          onPressed: busyMutation
                              ? null
                              : () => createImage(setState),
                          child: const Text('新增图片'),
                        ),
                      ),
                      TextField(
                        controller: patchFilePathCtrl,
                        decoration: const InputDecoration(
                          labelText: '编辑 file_path（可置空）',
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: patchStateCtrl,
                              decoration: const InputDecoration(
                                labelText: '编辑 state（可置空）',
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: patchSortCtrl,
                              decoration: const InputDecoration(
                                labelText: '编辑 sort_index（可选）',
                              ),
                              keyboardType: TextInputType.number,
                            ),
                          ),
                        ],
                      ),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          TextButton(
                            onPressed: busyMutation
                                ? null
                                : () => patchImage(setState),
                            child: const Text('保存当前图片'),
                          ),
                          TextButton(
                            onPressed: busyMutation
                                ? null
                                : () => deleteImage(setState),
                            child: const Text('删除当前图片'),
                          ),
                        ],
                      ),
                      if (previewBytes != null)
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.memory(
                            previewBytes!,
                            height: 160,
                            width: double.infinity,
                            fit: BoxFit.cover,
                            gaplessPlayback: true,
                          ),
                        ),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(dialogCtx).pop(),
                    child: const Text('关闭'),
                  ),
                ],
              );
            },
          );
        },
      );
    } finally {
      createFilePathCtrl.dispose();
      createStateCtrl.dispose();
      createSortCtrl.dispose();
      patchFilePathCtrl.dispose();
      patchStateCtrl.dispose();
      patchSortCtrl.dispose();
    }
  }
}
