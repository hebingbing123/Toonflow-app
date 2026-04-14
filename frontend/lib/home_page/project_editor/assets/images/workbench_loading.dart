part of 'workbench_support.dart';

Future<void> _runAssetImagesLoadFlow({
  required StateSetter setState,
  required VoidCallback beginStateUpdate,
  required Future<void> Function() action,
  required void Function(Object error) onErrorStateUpdate,
  required VoidCallback endStateUpdate,
}) async {
  setState(beginStateUpdate);
  try {
    await action();
  } catch (error) {
    setState(() => onErrorStateUpdate(error));
  } finally {
    setState(endStateUpdate);
  }
}

void _setAssetImagesPreviewLoading(AssetImagesWorkbenchRuntime runtime) {
  runtime.onPreviewLoadingChanged(true);
  runtime.onPreviewBytesChanged(null);
}

void _setAssetImagesPreviewFailure(
  AssetImagesWorkbenchRuntime runtime,
  Object error,
) {
  runtime.onStatusChanged(
    buildAssetImagesWorkbenchFailureNotice(
      actionSummary: '读取当前图片预览失败。',
      recommendedAction:
          AssetImagesWorkbenchRecommendedAction.previewSelectedImage,
      error: error,
      fallbackDetail: '建议先确认 file_path 或切换到其他图片后重试。',
    ),
  );
}

void _setAssetImagesReloadFailure(
  AssetImagesWorkbenchRuntime runtime,
  Object error,
) {
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
  await _runAssetImagesLoadFlow(
    setState: setState,
    beginStateUpdate: () => _setAssetImagesPreviewLoading(scope.runtime),
    action: () async {
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
    },
    onErrorStateUpdate: (error) =>
        _setAssetImagesPreviewFailure(scope.runtime, error),
    endStateUpdate: () => scope.runtime.onPreviewLoadingChanged(false),
  );
}

Future<void> reloadAssetImages({
  required AssetImagesWorkbenchScope scope,
  required int assetNumericId,
  required StateSetter setState,
}) async {
  await _runAssetImagesLoadFlow(
    setState: setState,
    beginStateUpdate: () {
      scope.runtime.onListLoadingChanged(true);
      scope.runtime.onStatusChanged(null);
    },
    action: () async {
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
    },
    onErrorStateUpdate: (error) =>
        _setAssetImagesReloadFailure(scope.runtime, error),
    endStateUpdate: () => scope.runtime.onListLoadingChanged(false),
  );
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
