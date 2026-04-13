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

    final createControllers = AssetImagesWorkbenchFormControllers();
    final patchControllers = AssetImagesWorkbenchFormControllers();
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
      createControllers: createControllers,
      patchControllers: patchControllers,
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
              final dialogState = AssetImagesWorkbenchDialogState.capture(
                assets: assets,
                imagesResponse: imagesResponse,
                selectedAssetNumericId: selectedAssetNumericId,
                selectedImageId: selectedImageId,
                loadingList: loadingList,
                loadingPreview: loadingPreview,
                busyMutation: busyMutation,
                statusLine: statusLine,
                previewBytes: previewBytes,
                createControllers: createControllers,
                patchControllers: patchControllers,
              );
              return _buildAssetImagesWorkbenchDialog(
                ctx: ctx,
                dialogCtx: dialogCtx,
                state: dialogState,
                callbacks: controller.buildDialogCallbacks(setState: setState),
              );
            },
          );
        },
      );
    } finally {
      createControllers.dispose();
      patchControllers.dispose();
    }
  }
}
