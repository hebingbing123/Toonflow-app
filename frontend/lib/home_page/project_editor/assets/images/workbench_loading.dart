part of '../../../../home_page.dart';

Future<void> loadAssetImagePreview({
  required String token,
  required String projectId,
  required int assetNumericId,
  required ListAssetImagesResponse? imagesResponse,
  required String? selectedImageId,
  required Uint8List? previewBytes,
  required StateSetter setState,
  required ValueChanged<Uint8List?> onPreviewBytesChanged,
  required ValueChanged<bool> onLoadingChanged,
  required ValueChanged<String?> onStatusChanged,
}) async {
  final image = selectedAssetImageRow(
    imagesResponse,
    selectedImageId: selectedImageId,
  );
  if (image == null) {
    setState(() => onPreviewBytesChanged(null));
    syncAssetImagesStatusLine(
      setState: setState,
      imagesResponse: imagesResponse,
      selectedImageId: selectedImageId,
      previewBytes: null,
      onStatusChanged: onStatusChanged,
    );
    return;
  }
  setState(() {
    onLoadingChanged(true);
    onPreviewBytesChanged(null);
  });
  try {
    final bytes = await fetchProjectAssetImageFileByProjectIds(
      token,
      projectId,
      assetNumericId,
      image.id,
    );
    setState(() => onPreviewBytesChanged(bytes));
    final diagnosis = diagnoseAssetImagesWorkbench(
      imagesResponse: imagesResponse,
      selectedImageId: selectedImageId,
      hasPreviewBytes: true,
    );
    setState(() {
      onStatusChanged(
        buildAssetImagesWorkbenchFollowUp(
          actionSummary: '已读取当前图片预览。',
          diagnosis: diagnosis,
        ),
      );
    });
  } on RustApiException catch (e) {
    setState(() {
      onStatusChanged(
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
    setState(() => onLoadingChanged(false));
  }
}

Future<void> reloadAssetImages({
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
}) async {
  setState(() {
    onLoadingChanged(true);
    onStatusChanged(null);
  });
  try {
    final response = await fetchProjectAssetImagesByProjectIds(
      token,
      projectId,
      assetNumericId,
    );
    final nextSelectedImageId = chooseInitialAssetImageId(
      response,
      preferredImageId: currentSelectedImageId,
    );
    setState(() {
      onImagesResponseChanged(response);
      onSelectedImageIdChanged(nextSelectedImageId);
      onPreviewBytesChanged(null);
      onStatusChanged(
        buildAssetImagesWorkbenchFollowUp(
          actionSummary: '已同步当前资产的图片列表。',
          diagnosis: diagnoseAssetImagesWorkbench(
            imagesResponse: response,
            selectedImageId: nextSelectedImageId,
            hasPreviewBytes: false,
          ),
        ),
      );
    });
    syncAssetImagesPatchFieldsFromSelected(
      setState: setState,
      imagesResponse: response,
      selectedImageId: nextSelectedImageId,
      patchFilePathCtrl: patchFilePathCtrl,
      patchStateCtrl: patchStateCtrl,
      patchSortCtrl: patchSortCtrl,
    );
    await loadAssetImagePreview(
      token: token,
      projectId: projectId,
      assetNumericId: assetNumericId,
      imagesResponse: response,
      selectedImageId: nextSelectedImageId,
      previewBytes: null,
      setState: setState,
      onPreviewBytesChanged: onPreviewBytesChanged,
      onLoadingChanged: onPreviewLoadingChanged,
      onStatusChanged: onStatusChanged,
    );
  } on RustApiException catch (e) {
    setState(() {
      onImagesResponseChanged(null);
      onSelectedImageIdChanged(null);
      onPreviewBytesChanged(null);
      onStatusChanged(
        buildAssetImagesWorkbenchFailureNotice(
          actionSummary: '读取当前资产图片列表失败。',
          recommendedAction: AssetImagesWorkbenchRecommendedAction.loadImages,
          error: e,
          fallbackDetail: '建议稍后重新同步图片列表，确认资产下是否已有图片。',
        ),
      );
    });
  } catch (e) {
    setState(() {
      onImagesResponseChanged(null);
      onSelectedImageIdChanged(null);
      onPreviewBytesChanged(null);
      onStatusChanged(
        buildAssetImagesWorkbenchFailureNotice(
          actionSummary: '读取当前资产图片列表失败。',
          recommendedAction: AssetImagesWorkbenchRecommendedAction.loadImages,
          error: e,
          fallbackDetail: '建议稍后重新同步图片列表，确认资产下是否已有图片。',
        ),
      );
    });
  } finally {
    setState(() => onLoadingChanged(false));
  }
}

Future<void> runAssetImagesRecommendedAction({
  required String token,
  required String projectId,
  required int assetNumericId,
  required ListAssetImagesResponse? imagesResponse,
  required String? selectedImageId,
  required Uint8List? previewBytes,
  required StateSetter setState,
  required ValueChanged<ListAssetImagesResponse?> onImagesResponseChanged,
  required ValueChanged<String?> onSelectedImageIdChanged,
  required ValueChanged<Uint8List?> onPreviewBytesChanged,
  required ValueChanged<bool> onListLoadingChanged,
  required ValueChanged<bool> onPreviewLoadingChanged,
  required ValueChanged<String?> onStatusChanged,
  required TextEditingController patchFilePathCtrl,
  required TextEditingController patchStateCtrl,
  required TextEditingController patchSortCtrl,
  required TextEditingController createFilePathCtrl,
  required TextEditingController createStateCtrl,
  required TextEditingController createSortCtrl,
  required BuildContext ctx,
  required StateSetter setDialogState,
  required List<bool> assetsBusy,
  required ValueChanged<bool> onBusyMutationChanged,
  required Future<void> Function() reloadAssetsAndStats,
  required ListAssetImagesResponse? Function() getImagesResponse,
  required String? Function() getSelectedImageId,
  required Uint8List? Function() getPreviewBytes,
}) async {
  final diagnosis = diagnoseAssetImagesWorkbench(
    imagesResponse: imagesResponse,
    selectedImageId: selectedImageId,
    hasPreviewBytes: previewBytes != null,
  );
  switch (diagnosis.recommendedAction) {
    case AssetImagesWorkbenchRecommendedAction.loadImages:
      await reloadAssetImages(
        token: token,
        projectId: projectId,
        assetNumericId: assetNumericId,
        currentSelectedImageId: selectedImageId,
        setState: setState,
        onImagesResponseChanged: onImagesResponseChanged,
        onSelectedImageIdChanged: onSelectedImageIdChanged,
        onPreviewBytesChanged: onPreviewBytesChanged,
        onLoadingChanged: onListLoadingChanged,
        onPreviewLoadingChanged: onPreviewLoadingChanged,
        onStatusChanged: onStatusChanged,
        patchFilePathCtrl: patchFilePathCtrl,
        patchStateCtrl: patchStateCtrl,
        patchSortCtrl: patchSortCtrl,
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
        currentSelectedImageId: selectedImageId,
        getImagesResponse: getImagesResponse,
        getSelectedImageId: getSelectedImageId,
        getPreviewBytes: getPreviewBytes,
        onImagesResponseChanged: onImagesResponseChanged,
        onSelectedImageIdChanged: onSelectedImageIdChanged,
        onPreviewBytesChanged: onPreviewBytesChanged,
        onListLoadingChanged: onListLoadingChanged,
        onPreviewLoadingChanged: onPreviewLoadingChanged,
        onStatusChanged: onStatusChanged,
        patchFilePathCtrl: patchFilePathCtrl,
        patchStateCtrl: patchStateCtrl,
        patchSortCtrl: patchSortCtrl,
      );
      break;
    case AssetImagesWorkbenchRecommendedAction.previewSelectedImage:
      await loadAssetImagePreview(
        token: token,
        projectId: projectId,
        assetNumericId: assetNumericId,
        imagesResponse: imagesResponse,
        selectedImageId: selectedImageId,
        previewBytes: previewBytes,
        setState: setState,
        onPreviewBytesChanged: onPreviewBytesChanged,
        onLoadingChanged: onPreviewLoadingChanged,
        onStatusChanged: onStatusChanged,
      );
      break;
    case AssetImagesWorkbenchRecommendedAction.updateSelectedImage:
      await patchAssetImage(
        token: token,
        projectId: projectId,
        assetNumericId: assetNumericId,
        imagesResponse: imagesResponse,
        selectedImageId: selectedImageId,
        previewBytes: previewBytes,
        patchFilePathCtrl: patchFilePathCtrl,
        patchStateCtrl: patchStateCtrl,
        patchSortCtrl: patchSortCtrl,
        setState: setState,
        ctx: ctx,
        setDialogState: setDialogState,
        assetsBusy: assetsBusy,
        onBusyMutationChanged: onBusyMutationChanged,
        reloadAssetsAndStats: reloadAssetsAndStats,
        getImagesResponse: getImagesResponse,
        getSelectedImageId: getSelectedImageId,
        getPreviewBytes: getPreviewBytes,
        onImagesResponseChanged: onImagesResponseChanged,
        onSelectedImageIdChanged: onSelectedImageIdChanged,
        onPreviewBytesChanged: onPreviewBytesChanged,
        onListLoadingChanged: onListLoadingChanged,
        onPreviewLoadingChanged: onPreviewLoadingChanged,
        onStatusChanged: onStatusChanged,
      );
      break;
  }
}
