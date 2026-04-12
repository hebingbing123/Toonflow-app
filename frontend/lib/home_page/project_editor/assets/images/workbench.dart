part of '../../../../home_page.dart';

extension _HomePageProjectEditorAssetsImagesWorkbench on _HomePageState {
  Future<void> _openAssetImagesWorkbenchDialog({
    required BuildContext ctx,
    required StateSetter setDialogState,
    required String token,
    required ProjectRow p,
    required List<ListAssetsResponse?> assetsRef,
    required List<bool> assetsBusy,
    required Future<void> Function() reloadAssetsAndStats,
    int? preferredAssetNumericId,
  }) async {
    final assets = assetsRef[0]?.items ?? const <AssetRow>[];
    if (assets.isEmpty) {
      ScaffoldMessenger.of(
        ctx,
      ).showSnackBar(const SnackBar(content: Text('请先创建资产再管理图片')));
      return;
    }
    var selectedAssetNumericId = chooseInitialAssetNumericId(
      assets,
      preferredNumericId: preferredAssetNumericId,
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
        final bytes = await fetchProjectAssetImageFileByProjectIds(
          token,
          p.id,
          selectedAssetNumericId,
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
        final response = await fetchProjectAssetImagesByProjectIds(
          token,
          p.id,
          selectedAssetNumericId,
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
        await createProjectAssetImageForProject(
          token,
          p.id,
          selectedAssetNumericId,
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
        await patchProjectAssetImageByProjectIds(
          token,
          p.id,
          selectedAssetNumericId,
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
        await deleteProjectAssetImageByProjectIds(
          token,
          p.id,
          selectedAssetNumericId,
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
              return _buildAssetImagesWorkbenchDialog(
                ctx: ctx,
                dialogCtx: dialogCtx,
                assets: assets,
                imageItems: imageItems,
                selectedAssetNumericId: selectedAssetNumericId,
                selectedImageId: selectedImageId,
                diagnosis: diagnosis,
                loadingList: loadingList,
                loadingPreview: loadingPreview,
                busyMutation: busyMutation,
                statusLine: statusLine,
                previewBytes: previewBytes,
                createFilePathCtrl: createFilePathCtrl,
                createStateCtrl: createStateCtrl,
                createSortCtrl: createSortCtrl,
                patchFilePathCtrl: patchFilePathCtrl,
                patchStateCtrl: patchStateCtrl,
                patchSortCtrl: patchSortCtrl,
                onAssetChanged: (value) async {
                  if (value == null) return;
                  setState(() {
                    selectedAssetNumericId = value;
                    imagesResponse = null;
                    selectedImageId = null;
                    previewBytes = null;
                    statusLine = '正在切换到资产 #$value 并加载图片列表…';
                  });
                  await reloadImages(setState);
                },
                onRecommendedAction: () => runRecommendedAction(setState),
                onReloadImages: () => reloadImages(setState),
                onLoadPreview: () => loadPreview(setState),
                onImageChanged: imageItems.isEmpty
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
                onCreateImage: () => createImage(setState),
                onPatchImage: () => patchImage(setState),
                onDeleteImage: () => deleteImage(setState),
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
