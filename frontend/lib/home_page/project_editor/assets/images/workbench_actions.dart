part of '../../../../home_page.dart';

Future<void> changeAssetImagesWorkbenchAsset({
  required int? value,
  required String token,
  required String projectId,
  required int currentAssetNumericId,
  required AssetImagesWorkbenchRuntime runtime,
  required StateSetter setState,
  required ValueChanged<int> onAssetNumericIdChanged,
  required TextEditingController patchFilePathCtrl,
  required TextEditingController patchStateCtrl,
  required TextEditingController patchSortCtrl,
}) async {
  if (value == null || value == currentAssetNumericId) {
    return;
  }
  setState(() {
    onAssetNumericIdChanged(value);
    runtime.clearSelection(
      images: null,
      selectedId: null,
      preview: null,
      statusLine: '正在切换到资产 #$value 并加载图片列表…',
    );
  });
  await reloadAssetImages(
    token: token,
    projectId: projectId,
    assetNumericId: value,
    runtime: runtime,
    setState: setState,
    patchFilePathCtrl: patchFilePathCtrl,
    patchStateCtrl: patchStateCtrl,
    patchSortCtrl: patchSortCtrl,
  );
}

Future<void> selectAssetImagesWorkbenchImage({
  required String? value,
  required String token,
  required String projectId,
  required int assetNumericId,
  required AssetImagesWorkbenchRuntime runtime,
  required StateSetter setState,
  required TextEditingController patchFilePathCtrl,
  required TextEditingController patchStateCtrl,
  required TextEditingController patchSortCtrl,
}) async {
  if (value == null) {
    return;
  }
  setState(() {
    runtime.onStatusChanged('正在切换图片并刷新预览…');
  });
  syncAssetImagesSelectionState(
    setState: setState,
    runtime: runtime,
    imagesResponse: runtime.imagesResponse(),
    selectedImageId: value,
    previewBytes: null,
    patchFilePathCtrl: patchFilePathCtrl,
    patchStateCtrl: patchStateCtrl,
    patchSortCtrl: patchSortCtrl,
  );
  await loadAssetImagePreview(
    token: token,
    projectId: projectId,
    assetNumericId: assetNumericId,
    runtime: runtime,
    selectedImageId: value,
    setState: setState,
  );
}
