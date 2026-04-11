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
    int? preferredAssetLegacyId,
  }) async {
    final assets = assetsRef[0]?.items ?? const <AssetRow>[];
    if (assets.isEmpty) {
      ScaffoldMessenger.of(
        ctx,
      ).showSnackBar(const SnackBar(content: Text('请先创建资产再管理图片')));
      return;
    }
    var selectedAssetLegacyId = chooseInitialAssetLegacyId(
      assets,
      preferredLegacyId: preferredAssetLegacyId,
    )!;
    String? selectedImageId;
    ListAssetImagesResponse? imagesResponse;
    Uint8List? previewBytes;
    bool loadingList = false;
    bool loadingPreview = false;
    bool busyMutation = false;
    bool initialLoadTriggered = false;
    String? statusLine;

    final createFilePathCtrl = TextEditingController();
    final createStateCtrl = TextEditingController();
    final createSortCtrl = TextEditingController();
    final patchFilePathCtrl = TextEditingController();
    final patchStateCtrl = TextEditingController();
    final patchSortCtrl = TextEditingController();

    void syncStatusLine(StateSetter setState) {
      final response = imagesResponse;
      final diagnosis = diagnoseAssetImagesWorkbench(
        imagesResponse: response,
        selectedImageId: selectedImageId,
        hasPreviewBytes: previewBytes != null,
      );
      setState(() {
        final selectionLine = response == null
            ? ''
            : summarizeAssetImageSelection(
                response,
                selectedImageId: selectedImageId,
              );
        statusLine = selectionLine.isEmpty
            ? '${diagnosis.summary} ${diagnosis.detail}'
            : '$selectionLine ${diagnosis.detail}';
      });
    }

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

    Future<void> loadPreview(StateSetter setState) async {
      final image = selectedImage();
      if (image == null) {
        setState(() => previewBytes = null);
        syncStatusLine(setState);
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
        final diagnosis = diagnoseAssetImagesWorkbench(
          imagesResponse: imagesResponse,
          selectedImageId: selectedImageId,
          hasPreviewBytes: true,
        );
        setState(() {
          statusLine = buildAssetImagesWorkbenchFollowUp(
            actionSummary: '已读取当前图片预览。',
            diagnosis: diagnosis,
          );
        });
      } on RustApiException catch (e) {
        setState(() {
          statusLine = buildAssetImagesWorkbenchFailureNotice(
            actionSummary: '读取当前图片预览失败。',
            recommendedAction:
                AssetImagesWorkbenchRecommendedAction.previewSelectedImage,
            error: e,
            fallbackDetail: '建议先确认 file_path 或切换到其他图片后重试。',
          );
        });
      } finally {
        setState(() => loadingPreview = false);
      }
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
        final nextSelectedImageId = chooseInitialAssetImageId(
          response,
          preferredImageId: selectedImageId,
        );
        setState(() {
          imagesResponse = response;
          selectedImageId = nextSelectedImageId;
          previewBytes = null;
          statusLine = buildAssetImagesWorkbenchFollowUp(
            actionSummary: '已同步当前资产的图片列表。',
            diagnosis: diagnoseAssetImagesWorkbench(
              imagesResponse: response,
              selectedImageId: nextSelectedImageId,
              hasPreviewBytes: false,
            ),
          );
        });
        syncPatchFieldsFromSelected(setState);
        await loadPreview(setState);
      } on RustApiException catch (e) {
        setState(() {
          imagesResponse = null;
          selectedImageId = null;
          previewBytes = null;
          statusLine = buildAssetImagesWorkbenchFailureNotice(
            actionSummary: '读取当前资产图片列表失败。',
            recommendedAction: AssetImagesWorkbenchRecommendedAction.loadImages,
            error: e,
            fallbackDetail: '建议稍后重新同步图片列表，确认资产下是否已有图片。',
          );
        });
      } catch (e) {
        setState(() {
          imagesResponse = null;
          selectedImageId = null;
          previewBytes = null;
          statusLine = buildAssetImagesWorkbenchFailureNotice(
            actionSummary: '读取当前资产图片列表失败。',
            recommendedAction: AssetImagesWorkbenchRecommendedAction.loadImages,
            error: e,
            fallbackDetail: '建议稍后重新同步图片列表，确认资产下是否已有图片。',
          );
        });
      } finally {
        setState(() => loadingList = false);
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
        setState(() {
          statusLine = buildAssetImagesWorkbenchFollowUp(
            actionSummary: '已新增资产图片。',
            diagnosis: diagnoseAssetImagesWorkbench(
              imagesResponse: imagesResponse,
              selectedImageId: selectedImageId,
              hasPreviewBytes: previewBytes != null,
            ),
          );
        });
      } on RustApiException catch (e) {
        setState(() {
          statusLine = buildAssetImagesWorkbenchFailureNotice(
            actionSummary: '新增资产图片失败。',
            recommendedAction:
                AssetImagesWorkbenchRecommendedAction.createImage,
            error: e,
            fallbackDetail: '建议检查 file_path、state 或 sort_index 后重试。',
          );
        });
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
        await reloadAssetsAndStats();
        setState(() {
          statusLine = buildAssetImagesWorkbenchFollowUp(
            actionSummary: '已更新当前图片。',
            diagnosis: diagnoseAssetImagesWorkbench(
              imagesResponse: imagesResponse,
              selectedImageId: selectedImageId,
              hasPreviewBytes: previewBytes != null,
            ),
          );
        });
      } on RustApiException catch (e) {
        setState(() {
          statusLine = buildAssetImagesWorkbenchFailureNotice(
            actionSummary: '更新当前图片失败。',
            recommendedAction:
                AssetImagesWorkbenchRecommendedAction.updateSelectedImage,
            error: e,
            fallbackDetail: '建议先重新读取预览，确认当前图片后再修改。',
          );
        });
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
        await reloadAssetsAndStats();
        setState(() {
          statusLine = buildAssetImagesWorkbenchFollowUp(
            actionSummary: '已删除当前图片。',
            diagnosis: diagnoseAssetImagesWorkbench(
              imagesResponse: imagesResponse,
              selectedImageId: selectedImageId,
              hasPreviewBytes: previewBytes != null,
            ),
          );
        });
      } on RustApiException catch (e) {
        setState(() {
          statusLine = buildAssetImagesWorkbenchFailureNotice(
            actionSummary: '删除当前图片失败。',
            recommendedAction:
                AssetImagesWorkbenchRecommendedAction.updateSelectedImage,
            error: e,
            fallbackDetail: '建议先刷新图片列表，确认当前选择后再删除。',
          );
        });
      } finally {
        setState(() => busyMutation = false);
        if (ctx.mounted) {
          setDialogState(() => assetsBusy[0] = false);
        }
      }
    }

    Future<void> runRecommendedAction(StateSetter setState) async {
      final diagnosis = diagnoseAssetImagesWorkbench(
        imagesResponse: imagesResponse,
        selectedImageId: selectedImageId,
        hasPreviewBytes: previewBytes != null,
      );
      switch (diagnosis.recommendedAction) {
        case AssetImagesWorkbenchRecommendedAction.loadImages:
          await reloadImages(setState);
          break;
        case AssetImagesWorkbenchRecommendedAction.createImage:
          await createImage(setState);
          break;
        case AssetImagesWorkbenchRecommendedAction.previewSelectedImage:
          await loadPreview(setState);
          break;
        case AssetImagesWorkbenchRecommendedAction.updateSelectedImage:
          await patchImage(setState);
          break;
      }
    }

    try {
      await showDialog<void>(
        context: ctx,
        builder: (dialogCtx) {
          return StatefulBuilder(
            builder: (dialogCtx, setState) {
              if (!initialLoadTriggered) {
                initialLoadTriggered = true;
                WidgetsBinding.instance.addPostFrameCallback((_) async {
                  if (!dialogCtx.mounted) return;
                  await reloadImages(setState);
                });
              }
              final imageItems =
                  imagesResponse?.items ?? const <AssetImageRow>[];
              final diagnosis = diagnoseAssetImagesWorkbench(
                imagesResponse: imagesResponse,
                selectedImageId: selectedImageId,
                hasPreviewBytes: previewBytes != null,
              );
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
                        onChanged: (value) async {
                          if (value == null) return;
                          setState(() {
                            selectedAssetLegacyId = value;
                            imagesResponse = null;
                            selectedImageId = null;
                            previewBytes = null;
                            statusLine = '正在切换到资产 #$value 并加载图片列表…';
                          });
                          await reloadImages(setState);
                        },
                      ),
                      const SizedBox(height: 8),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: Theme.of(
                              dialogCtx,
                            ).colorScheme.outlineVariant,
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              diagnosis.summary,
                              style: Theme.of(dialogCtx).textTheme.titleSmall,
                            ),
                            const SizedBox(height: 6),
                            Text(
                              diagnosis.detail,
                              style: Theme.of(dialogCtx).textTheme.bodySmall,
                            ),
                            const SizedBox(height: 8),
                            FilledButton.tonal(
                              onPressed:
                                  loadingList || loadingPreview || busyMutation
                                  ? null
                                  : () => runRecommendedAction(setState),
                              child: Text(
                                describeAssetImagesWorkbenchRecommendedAction(
                                  diagnosis.recommendedAction,
                                ),
                              ),
                            ),
                          ],
                        ),
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
                            : (value) async {
                                if (value == null) return;
                                setState(() {
                                  selectedImageId = value;
                                  previewBytes = null;
                                  statusLine = '正在切换图片并刷新预览…';
                                });
                                syncStatusLine(setState);
                                syncPatchFieldsFromSelected(setState);
                                await loadPreview(setState);
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
