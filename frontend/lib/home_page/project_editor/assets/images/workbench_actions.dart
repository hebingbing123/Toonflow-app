part of '../../../../home_page.dart';

void scheduleInitialAssetImagesLoad({
  required BuildContext dialogCtx,
  required String token,
  required String projectId,
  required int assetNumericId,
  required String? currentSelectedImageId,
  required StateSetter setState,
  required ValueChanged<ListAssetImagesResponse?> onImagesResponseChanged,
  required ValueChanged<String?> onSelectedImageIdChanged,
  required ValueChanged<Uint8List?> onPreviewBytesChanged,
  required ValueChanged<bool> onLoadingChanged,
  required ValueChanged<bool> onPreviewLoadingChanged,
  required ValueChanged<String?> onStatusChanged,
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
      currentSelectedImageId: currentSelectedImageId,
      setState: setState,
      onImagesResponseChanged: onImagesResponseChanged,
      onSelectedImageIdChanged: onSelectedImageIdChanged,
      onPreviewBytesChanged: onPreviewBytesChanged,
      onLoadingChanged: onLoadingChanged,
      onPreviewLoadingChanged: onPreviewLoadingChanged,
      onStatusChanged: onStatusChanged,
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
  required String? currentSelectedImageId,
  required StateSetter setState,
  required ValueChanged<int> onAssetNumericIdChanged,
  required ValueChanged<ListAssetImagesResponse?> onImagesResponseChanged,
  required ValueChanged<String?> onSelectedImageIdChanged,
  required ValueChanged<Uint8List?> onPreviewBytesChanged,
  required ValueChanged<bool> onLoadingChanged,
  required ValueChanged<bool> onPreviewLoadingChanged,
  required ValueChanged<String?> onStatusChanged,
  required TextEditingController patchFilePathCtrl,
  required TextEditingController patchStateCtrl,
  required TextEditingController patchSortCtrl,
}) async {
  if (value == null || value == currentAssetNumericId) {
    return;
  }
  setState(() {
    onAssetNumericIdChanged(value);
    onImagesResponseChanged(null);
    onSelectedImageIdChanged(null);
    onPreviewBytesChanged(null);
    onStatusChanged('正在切换到资产 #$value 并加载图片列表…');
  });
  await reloadAssetImages(
    token: token,
    projectId: projectId,
    assetNumericId: value,
    currentSelectedImageId: currentSelectedImageId,
    setState: setState,
    onImagesResponseChanged: onImagesResponseChanged,
    onSelectedImageIdChanged: onSelectedImageIdChanged,
    onPreviewBytesChanged: onPreviewBytesChanged,
    onLoadingChanged: onLoadingChanged,
    onPreviewLoadingChanged: onPreviewLoadingChanged,
    onStatusChanged: onStatusChanged,
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
  required ListAssetImagesResponse? imagesResponse,
  required Uint8List? previewBytes,
  required StateSetter setState,
  required ValueChanged<String?> onSelectedImageIdChanged,
  required ValueChanged<Uint8List?> onPreviewBytesChanged,
  required ValueChanged<bool> onLoadingChanged,
  required ValueChanged<String?> onStatusChanged,
  required TextEditingController patchFilePathCtrl,
  required TextEditingController patchStateCtrl,
  required TextEditingController patchSortCtrl,
}) async {
  if (value == null) {
    return;
  }
  setState(() {
    onSelectedImageIdChanged(value);
    onPreviewBytesChanged(null);
    onStatusChanged('正在切换图片并刷新预览…');
  });
  syncAssetImagesStatusLine(
    setState: setState,
    imagesResponse: imagesResponse,
    selectedImageId: value,
    previewBytes: null,
    onStatusChanged: onStatusChanged,
  );
  syncAssetImagesPatchFieldsFromSelected(
    setState: setState,
    imagesResponse: imagesResponse,
    selectedImageId: value,
    patchFilePathCtrl: patchFilePathCtrl,
    patchStateCtrl: patchStateCtrl,
    patchSortCtrl: patchSortCtrl,
  );
  await loadAssetImagePreview(
    token: token,
    projectId: projectId,
    assetNumericId: assetNumericId,
    imagesResponse: imagesResponse,
    selectedImageId: value,
    previewBytes: previewBytes,
    setState: setState,
    onPreviewBytesChanged: onPreviewBytesChanged,
    onLoadingChanged: onLoadingChanged,
    onStatusChanged: onStatusChanged,
  );
}
