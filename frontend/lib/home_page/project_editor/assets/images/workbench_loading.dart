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
  required AssetImagesWorkbenchScope scope,
  required int assetNumericId,
  required String? selectedImageId,
  required StateSetter setState,
}) async {
  final image = selectedAssetImageRow(
    scope.runtime.imagesResponse(),
    selectedImageId: selectedImageId,
  );
  if (image == null) {
    applyAssetImagePreviewState(
      setState: setState,
      runtime: scope.runtime,
      imagesResponse: scope.runtime.imagesResponse(),
      selectedImageId: selectedImageId,
      previewBytes: null,
      actionSummary: '当前没有可预览的图片，已清空预览内容。',
    );
    return;
  }
  setState(() {
    scope.runtime.onPreviewLoadingChanged(true);
    scope.runtime.onPreviewBytesChanged(null);
  });
  try {
    final bytes = await fetchProjectAssetImageFileByProjectIds(
      scope.token,
      scope.projectId,
      assetNumericId,
      image.id,
    );
    applyAssetImagePreviewState(
      setState: setState,
      runtime: scope.runtime,
      imagesResponse: scope.runtime.imagesResponse(),
      selectedImageId: selectedImageId,
      previewBytes: bytes,
      actionSummary: '已读取当前图片预览。',
    );
  } on RustApiException catch (e) {
    setState(() {
      scope.runtime.onStatusChanged(
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
    setState(() => scope.runtime.onPreviewLoadingChanged(false));
  }
}

Future<void> reloadAssetImages({
  required AssetImagesWorkbenchScope scope,
  required int assetNumericId,
  required StateSetter setState,
}) async {
  setState(() {
    scope.runtime.onListLoadingChanged(true);
    scope.runtime.onStatusChanged(null);
  });
  try {
    final response = await fetchProjectAssetImagesByProjectIds(
      scope.token,
      scope.projectId,
      assetNumericId,
    );
    final nextSelectedImageId = applyReloadedAssetImagesState(
      setState: setState,
      runtime: scope.runtime,
      response: response,
      patchControllers: scope.patchControllers,
    );
    await loadAssetImagePreview(
      scope: scope,
      assetNumericId: assetNumericId,
      selectedImageId: nextSelectedImageId,
      setState: setState,
    );
  } catch (e) {
    _setAssetImagesReloadFailure(
      setState: setState,
      runtime: scope.runtime,
      error: e,
    );
  } finally {
    setState(() => scope.runtime.onListLoadingChanged(false));
  }
}

Future<void> runAssetImagesRecommendedAction({
  required AssetImagesWorkbenchScope scope,
  required int assetNumericId,
  required StateSetter setState,
}) async {
  final diagnosis = scope.runtime.diagnose();
  switch (diagnosis.recommendedAction) {
    case AssetImagesWorkbenchRecommendedAction.loadImages:
      await reloadAssetImages(
        scope: scope,
        assetNumericId: assetNumericId,
        setState: setState,
      );
      break;
    case AssetImagesWorkbenchRecommendedAction.createImage:
      await createAssetImage(
        scope: scope,
        assetNumericId: assetNumericId,
        setState: setState,
      );
      break;
    case AssetImagesWorkbenchRecommendedAction.previewSelectedImage:
      await loadAssetImagePreview(
        scope: scope,
        assetNumericId: assetNumericId,
        selectedImageId: scope.runtime.currentSelectedImageId,
        setState: setState,
      );
      break;
    case AssetImagesWorkbenchRecommendedAction.updateSelectedImage:
      await patchAssetImage(
        scope: scope,
        assetNumericId: assetNumericId,
        imagesResponse: scope.runtime.imagesResponse(),
        selectedImageId: scope.runtime.currentSelectedImageId,
        setState: setState,
      );
      break;
  }
}
