part of '../../../../home_page.dart';

void scheduleInitialAssetImagesLoad({
  required BuildContext dialogCtx,
  required String token,
  required String projectId,
  required int assetNumericId,
  required AssetImagesWorkbenchRuntime runtime,
  required StateSetter setState,
  required TextEditingController patchFilePathCtrl,
  required TextEditingController patchStateCtrl,
  required TextEditingController patchSortCtrl,
}) {
  WidgetsBinding.instance.addPostFrameCallback((_) async {
    if (!dialogCtx.mounted) {
      return;
    }
    await reloadAssetImages(
      token: token,
      projectId: projectId,
      assetNumericId: assetNumericId,
      runtime: runtime,
      setState: setState,
      patchFilePathCtrl: patchFilePathCtrl,
      patchStateCtrl: patchStateCtrl,
      patchSortCtrl: patchSortCtrl,
    );
  });
}

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
    runtime.onSelectedImageIdChanged(value);
    runtime.onPreviewBytesChanged(null);
    runtime.onStatusChanged('正在切换图片并刷新预览…');
  });
  syncAssetImagesStatusLine(
    setState: setState,
    imagesResponse: runtime.imagesResponse(),
    selectedImageId: value,
    previewBytes: null,
    onStatusChanged: runtime.onStatusChanged,
  );
  syncAssetImagesPatchFieldsFromSelected(
    setState: setState,
    imagesResponse: runtime.imagesResponse(),
    selectedImageId: value,
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
