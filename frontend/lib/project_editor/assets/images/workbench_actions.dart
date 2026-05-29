part of 'workbench_support.dart';

Future<void> changeAssetImagesWorkbenchAsset({
  required int? value,
  required AssetImagesWorkbenchScope scope,
  required int currentAssetNumericId,
  required StateSetter setState,
  required ValueChanged<int> onAssetNumericIdChanged,
}) async {
  if (value == null || value == currentAssetNumericId) {
    return;
  }
  setState(() {
    onAssetNumericIdChanged(value);
    scope.runtime.clearSelection(
      images: null,
      selectedId: null,
      preview: null,
      statusLine: scope.mutation.l10n.projectEditorAssetImagesSwitchingAsset(value),
    );
  });
  await reloadAssetImages(
    scope: scope,
    assetNumericId: value,
    setState: setState,
  );
  await reloadAssetBlocks(
    scope: scope,
    assetNumericId: value,
    setState: setState,
  );
}

Future<void> selectAssetImagesWorkbenchImage({
  required String? value,
  required AssetImagesWorkbenchScope scope,
  required int assetNumericId,
  required StateSetter setState,
}) async {
  if (value == null) {
    return;
  }
  final nextState = _prepareAssetImagesSelectionSyncState(
    l10n: scope.mutation.l10n,
    imagesResponse: scope.runtime.imagesResponse(),
    selectedImageId: value,
    previewBytes: null,
  );
  setState(() {
    _applyAssetImagesSelectionSyncState(
      runtime: scope.runtime,
      patchControllers: scope.patchControllers,
      state: nextState,
    );
    scope.runtime.onStatusChanged(
      scope.mutation.l10n.projectEditorAssetImagesSwitchingImagePreview,
    );
  });
  await loadAssetImagePreview(
    scope: scope,
    assetNumericId: assetNumericId,
    selectedImageId: value,
    setState: setState,
  );
}
