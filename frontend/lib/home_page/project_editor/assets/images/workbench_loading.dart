part of '../../../../home_page.dart';

void _setAssetImagesReloadFailure({
  required StateSetter setState,
  required AssetImagesWorkbenchRuntime runtime,
  required Object error,
}) {
  setState(() {
    runtime.clearSelection(
      images: null,
      selectedId: null,
      preview: null,
      statusLine: buildAssetImagesWorkbenchFailureNotice(
        actionSummary: '读取当前资产图片列表失败。',
        recommendedAction: AssetImagesWorkbenchRecommendedAction.loadImages,
        error: error,
        fallbackDetail: '建议稍后重新同步图片列表，确认资产下是否已有图片。',
      ),
    );
  });
}

Future<void> loadAssetImagePreview({
  required String token,
  required String projectId,
  required int assetNumericId,
  required AssetImagesWorkbenchRuntime runtime,
  required String? selectedImageId,
  required StateSetter setState,
}) async {
  final image = selectedAssetImageRow(
    runtime.imagesResponse(),
    selectedImageId: selectedImageId,
  );
  if (image == null) {
    applyAssetImagePreviewState(
      setState: setState,
      runtime: runtime,
      imagesResponse: runtime.imagesResponse(),
      selectedImageId: selectedImageId,
      previewBytes: null,
      actionSummary: '当前没有可预览的图片，已清空预览内容。',
    );
    return;
  }
  setState(() {
    runtime.onPreviewLoadingChanged(true);
    runtime.onPreviewBytesChanged(null);
  });
  try {
    final bytes = await fetchProjectAssetImageFileByProjectIds(
      token,
      projectId,
      assetNumericId,
      image.id,
    );
    applyAssetImagePreviewState(
      setState: setState,
      runtime: runtime,
      imagesResponse: runtime.imagesResponse(),
      selectedImageId: selectedImageId,
      previewBytes: bytes,
      actionSummary: '已读取当前图片预览。',
    );
  } on RustApiException catch (e) {
    setState(() {
      runtime.onStatusChanged(
        buildAssetImagesWorkbenchFailureNotice(
          actionSummary: '读取当前图片预览失败。',
          recommendedAction:
              AssetImagesWorkbenchRecommendedAction.previewSelectedImage,
          error: e,
          fallbackDetail: '建议先确认 file_path 或切换到其他图片后重试。',
        ),
      );
    });
  } finally {
    setState(() => runtime.onPreviewLoadingChanged(false));
  }
}

Future<void> reloadAssetImages({
  required String token,
  required String projectId,
  required int assetNumericId,
  required AssetImagesWorkbenchRuntime runtime,
  required StateSetter setState,
  required AssetImagesWorkbenchFormControllers patchControllers,
}) async {
  setState(() {
    runtime.onListLoadingChanged(true);
    runtime.onStatusChanged(null);
  });
  try {
    final response = await fetchProjectAssetImagesByProjectIds(
      token,
      projectId,
      assetNumericId,
    );
    final nextSelectedImageId = applyReloadedAssetImagesState(
      setState: setState,
      runtime: runtime,
      response: response,
      patchControllers: patchControllers,
    );
    await loadAssetImagePreview(
      token: token,
      projectId: projectId,
      assetNumericId: assetNumericId,
      runtime: runtime,
      selectedImageId: nextSelectedImageId,
      setState: setState,
    );
  } catch (e) {
    _setAssetImagesReloadFailure(
      setState: setState,
      runtime: runtime,
      error: e,
    );
  } finally {
    setState(() => runtime.onListLoadingChanged(false));
  }
}

Future<void> runAssetImagesRecommendedAction({
  required String token,
  required String projectId,
  required int assetNumericId,
  required AssetImagesWorkbenchRuntime runtime,
  required StateSetter setState,
  required AssetImagesWorkbenchFormControllers patchControllers,
  required TextEditingController createFilePathCtrl,
  required TextEditingController createStateCtrl,
  required TextEditingController createSortCtrl,
  required BuildContext ctx,
  required StateSetter setDialogState,
  required List<bool> assetsBusy,
  required ValueChanged<bool> onBusyMutationChanged,
  required Future<void> Function() reloadAssetsAndStats,
}) async {
  final diagnosis = runtime.diagnose();
  switch (diagnosis.recommendedAction) {
    case AssetImagesWorkbenchRecommendedAction.loadImages:
      await reloadAssetImages(
        token: token,
        projectId: projectId,
        assetNumericId: assetNumericId,
        runtime: runtime,
        setState: setState,
        patchControllers: patchControllers,
      );
      break;
    case AssetImagesWorkbenchRecommendedAction.createImage:
      await createAssetImage(
        token: token,
        projectId: projectId,
        assetNumericId: assetNumericId,
        createFilePathCtrl: createFilePathCtrl,
        createStateCtrl: createStateCtrl,
        createSortCtrl: createSortCtrl,
        setState: setState,
        ctx: ctx,
        setDialogState: setDialogState,
        assetsBusy: assetsBusy,
        onBusyMutationChanged: onBusyMutationChanged,
        reloadAssetsAndStats: reloadAssetsAndStats,
        runtime: runtime,
        patchControllers: patchControllers,
      );
      break;
    case AssetImagesWorkbenchRecommendedAction.previewSelectedImage:
      await loadAssetImagePreview(
        token: token,
        projectId: projectId,
        assetNumericId: assetNumericId,
        runtime: runtime,
        selectedImageId: runtime.currentSelectedImageId,
        setState: setState,
      );
      break;
    case AssetImagesWorkbenchRecommendedAction.updateSelectedImage:
      await patchAssetImage(
        token: token,
        projectId: projectId,
        assetNumericId: assetNumericId,
        imagesResponse: runtime.imagesResponse(),
        selectedImageId: runtime.currentSelectedImageId,
        patchControllers: patchControllers,
        setState: setState,
        ctx: ctx,
        setDialogState: setDialogState,
        assetsBusy: assetsBusy,
        onBusyMutationChanged: onBusyMutationChanged,
        reloadAssetsAndStats: reloadAssetsAndStats,
        runtime: runtime,
      );
      break;
  }
}
