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
  AppLocalizations l10n,
  AssetImagesWorkbenchRuntime runtime,
  Object error,
) {
  runtime.onStatusChanged(
    buildAssetImagesWorkbenchFailureNotice(
      l10n: l10n,
      actionSummary: l10n.projectEditorAssetImagesPreviewLoadFailed,
      recommendedAction:
          AssetImagesWorkbenchRecommendedAction.previewSelectedImage,
      error: error,
      fallbackDetail: l10n.projectEditorAssetImagesPreviewLoadFailedFallback,
    ),
  );
}

void _setAssetImagesReloadFailure(
  AppLocalizations l10n,
  AssetImagesWorkbenchRuntime runtime,
  Object error,
) {
  runtime.clearSelection(
    images: null,
    selectedId: null,
    preview: null,
    statusLine: buildAssetImagesWorkbenchFailureNotice(
      l10n: l10n,
      actionSummary: l10n.projectEditorAssetImagesListLoadFailed,
      recommendedAction: AssetImagesWorkbenchRecommendedAction.loadImages,
      error: error,
      fallbackDetail: l10n.projectEditorAssetImagesListLoadFailedFallback,
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
      l10n: scope.mutation.l10n,
      setState: setState,
      runtime: scope.runtime,
      imagesResponse: scope.runtime.imagesResponse(),
      selectedImageId: selectedImageId,
      previewBytes: null,
      actionSummary: scope.mutation.l10n.projectEditorAssetImagesNoPreviewCleared,
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
        l10n: scope.mutation.l10n,
        setState: setState,
        runtime: scope.runtime,
        imagesResponse: scope.runtime.imagesResponse(),
        selectedImageId: selectedImageId,
        previewBytes: bytes,
        actionSummary: scope.mutation.l10n.projectEditorAssetImagesPreviewLoaded,
      );
    },
    onErrorStateUpdate: (error) =>
        _setAssetImagesPreviewFailure(scope.mutation.l10n, scope.runtime, error),
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
        l10n: scope.mutation.l10n,
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
        _setAssetImagesReloadFailure(scope.mutation.l10n, scope.runtime, error),
    endStateUpdate: () => scope.runtime.onListLoadingChanged(false),
  );
}

Future<void> runAssetImagesRecommendedAction({
  required AssetImagesWorkbenchScope scope,
  required int assetNumericId,
  required StateSetter setState,
}) async {
  final diagnosis = scope.runtime.diagnose(scope.mutation.l10n);
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
