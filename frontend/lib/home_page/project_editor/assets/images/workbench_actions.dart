part of '../../../../home_page.dart';

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
      statusLine: '正在切换到资产 #$value 并加载图片列表…',
    );
  });
  await reloadAssetImages(
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
    scope.runtime.onStatusChanged('正在切换图片并刷新预览…');
  });
  await loadAssetImagePreview(
    scope: scope,
    assetNumericId: assetNumericId,
    selectedImageId: value,
    setState: setState,
  );
}
