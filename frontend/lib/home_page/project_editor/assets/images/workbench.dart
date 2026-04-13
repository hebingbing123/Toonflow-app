part of '../../../../home_page.dart';

extension _HomePageProjectEditorAssetsImagesWorkbench on _HomePageState {
  /// Keep the dialog entry focused on orchestration while helpers own the
  /// image-list state sync, loading, and mutation branches.
  Future<void> _openAssetImagesWorkbenchDialog({
    required BuildContext ctx,
    required StateSetter setDialogState,
    required String token,
    required ProjectRow p,
    required List<ListAssetsResponse?> assetsRef,
    required List<bool> assetsBusy,
    required Future<void> Function() reloadAssetsAndStats,
    int? preferredAssetNumericId,
  }) async {
    final assets = assetsRef[0]?.items ?? const <AssetRow>[];
    if (assets.isEmpty) {
      ScaffoldMessenger.of(
        ctx,
      ).showSnackBar(const SnackBar(content: Text('请先创建资产再管理图片')));
      return;
    }
    var selectedAssetNumericId = chooseInitialAssetNumericId(
      assets,
      preferredNumericId: preferredAssetNumericId,
    )!;
    String? selectedImageId;
    ListAssetImagesResponse? imagesResponse;
    Uint8List? previewBytes;
    bool loadingList = false;
    bool loadingPreview = false;
    bool busyMutation = false;
    bool initialLoadTriggered = false;
    String? statusLine;

    final createFilePathCtrl = TextEditingController();
    final createStateCtrl = TextEditingController();
    final createSortCtrl = TextEditingController();
    final patchFilePathCtrl = TextEditingController();
    final patchStateCtrl = TextEditingController();
    final patchSortCtrl = TextEditingController();
    final runtime = AssetImagesWorkbenchRuntime(
      imagesResponse: () => imagesResponse,
      selectedImageId: () => selectedImageId,
      previewBytes: () => previewBytes,
      onImagesResponseChanged: (response) => imagesResponse = response,
      onSelectedImageIdChanged: (value) => selectedImageId = value,
      onPreviewBytesChanged: (bytes) => previewBytes = bytes,
      onListLoadingChanged: (loading) => loadingList = loading,
      onPreviewLoadingChanged: (loading) => loadingPreview = loading,
      onStatusChanged: (line) => statusLine = line,
    );
    final controller = AssetImagesWorkbenchController(
      token: token,
      projectId: p.id,
      runtime: runtime,
      currentAssetNumericId: () => selectedAssetNumericId,
      onAssetNumericIdChanged: (value) => selectedAssetNumericId = value,
      createFilePathCtrl: createFilePathCtrl,
      createStateCtrl: createStateCtrl,
      createSortCtrl: createSortCtrl,
      patchFilePathCtrl: patchFilePathCtrl,
      patchStateCtrl: patchStateCtrl,
      patchSortCtrl: patchSortCtrl,
      ctx: ctx,
      setDialogState: setDialogState,
      assetsBusy: assetsBusy,
      onBusyMutationChanged: (busy) => busyMutation = busy,
      reloadAssetsAndStats: reloadAssetsAndStats,
    );

    try {
      await showDialog<void>(
        context: ctx,
        builder: (dialogCtx) {
          return StatefulBuilder(
            builder: (dialogCtx, setState) {
              if (!initialLoadTriggered) {
                initialLoadTriggered = true;
                controller.scheduleInitialLoad(
                  dialogCtx: dialogCtx,
                  setState: setState,
                );
              }
              final imageItems =
                  imagesResponse?.items ?? const <AssetImageRow>[];
              final diagnosis = diagnoseAssetImagesWorkbench(
                imagesResponse: imagesResponse,
                selectedImageId: selectedImageId,
                hasPreviewBytes: previewBytes != null,
              );
              return _buildAssetImagesWorkbenchDialog(
                ctx: ctx,
                dialogCtx: dialogCtx,
                assets: assets,
                imageItems: imageItems,
                selectedAssetNumericId: selectedAssetNumericId,
                selectedImageId: selectedImageId,
                diagnosis: diagnosis,
                loadingList: loadingList,
                loadingPreview: loadingPreview,
                busyMutation: busyMutation,
                statusLine: statusLine,
                previewBytes: previewBytes,
                createFilePathCtrl: createFilePathCtrl,
                createStateCtrl: createStateCtrl,
                createSortCtrl: createSortCtrl,
                patchFilePathCtrl: patchFilePathCtrl,
                patchStateCtrl: patchStateCtrl,
                patchSortCtrl: patchSortCtrl,
                onAssetChanged: (value) =>
                    controller.changeAsset(value: value, setState: setState),
                onRecommendedAction: () =>
                    controller.runRecommendedAction(setState),
                onReloadImages: () => controller.reloadImages(setState),
                onLoadPreview: () => controller.loadPreview(setState),
                onImageChanged: imageItems.isEmpty
                    ? null
                    : (value) => controller.selectImage(
                        value: value,
                        setState: setState,
                      ),
                onCreateImage: () => controller.createImage(setState),
                onPatchImage: () => controller.patchImage(setState),
                onDeleteImage: () => controller.deleteImage(setState),
              );
            },
          );
        },
      );
    } finally {
      createFilePathCtrl.dispose();
      createStateCtrl.dispose();
      createSortCtrl.dispose();
      patchFilePathCtrl.dispose();
      patchStateCtrl.dispose();
      patchSortCtrl.dispose();
    }
  }
}
