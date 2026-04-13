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

    try {
      await showDialog<void>(
        context: ctx,
        builder: (dialogCtx) {
          return StatefulBuilder(
            builder: (dialogCtx, setState) {
              if (!initialLoadTriggered) {
                initialLoadTriggered = true;
                scheduleInitialAssetImagesLoad(
                  dialogCtx: dialogCtx,
                  token: token,
                  projectId: p.id,
                  assetNumericId: selectedAssetNumericId,
                  currentSelectedImageId: selectedImageId,
                  setState: setState,
                  onImagesResponseChanged: (response) =>
                      imagesResponse = response,
                  onSelectedImageIdChanged: (value) => selectedImageId = value,
                  onPreviewBytesChanged: (bytes) => previewBytes = bytes,
                  onLoadingChanged: (loading) => loadingList = loading,
                  onPreviewLoadingChanged: (loading) => loadingPreview = loading,
                  onStatusChanged: (line) => statusLine = line,
                  patchFilePathCtrl: patchFilePathCtrl,
                  patchStateCtrl: patchStateCtrl,
                  patchSortCtrl: patchSortCtrl,
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
                onAssetChanged: (value) => changeAssetImagesWorkbenchAsset(
                  value: value,
                  token: token,
                  projectId: p.id,
                  currentAssetNumericId: selectedAssetNumericId,
                  currentSelectedImageId: selectedImageId,
                  setState: setState,
                  onAssetNumericIdChanged: (nextValue) =>
                      selectedAssetNumericId = nextValue,
                  onImagesResponseChanged: (response) =>
                      imagesResponse = response,
                  onSelectedImageIdChanged: (nextValue) =>
                      selectedImageId = nextValue,
                  onPreviewBytesChanged: (bytes) => previewBytes = bytes,
                  onLoadingChanged: (loading) => loadingList = loading,
                  onPreviewLoadingChanged: (loading) => loadingPreview = loading,
                  onStatusChanged: (line) => statusLine = line,
                  patchFilePathCtrl: patchFilePathCtrl,
                  patchStateCtrl: patchStateCtrl,
                  patchSortCtrl: patchSortCtrl,
                ),
                onRecommendedAction: () => runAssetImagesRecommendedAction(
                  token: token,
                  projectId: p.id,
                  assetNumericId: selectedAssetNumericId,
                  imagesResponse: imagesResponse,
                  selectedImageId: selectedImageId,
                  previewBytes: previewBytes,
                  setState: setState,
                  onImagesResponseChanged: (response) =>
                      imagesResponse = response,
                  onSelectedImageIdChanged: (value) => selectedImageId = value,
                  onPreviewBytesChanged: (bytes) => previewBytes = bytes,
                  onListLoadingChanged: (loading) => loadingList = loading,
                  onPreviewLoadingChanged: (loading) =>
                      loadingPreview = loading,
                  onStatusChanged: (line) => statusLine = line,
                  patchFilePathCtrl: patchFilePathCtrl,
                  patchStateCtrl: patchStateCtrl,
                  patchSortCtrl: patchSortCtrl,
                  createFilePathCtrl: createFilePathCtrl,
                  createStateCtrl: createStateCtrl,
                  createSortCtrl: createSortCtrl,
                  ctx: ctx,
                  setDialogState: setDialogState,
                  assetsBusy: assetsBusy,
                  onBusyMutationChanged: (busy) => busyMutation = busy,
                  reloadAssetsAndStats: reloadAssetsAndStats,
                  getImagesResponse: () => imagesResponse,
                  getSelectedImageId: () => selectedImageId,
                  getPreviewBytes: () => previewBytes,
                ),
                onReloadImages: () => reloadAssetImages(
                  token: token,
                  projectId: p.id,
                  assetNumericId: selectedAssetNumericId,
                  currentSelectedImageId: selectedImageId,
                  setState: setState,
                  onImagesResponseChanged: (response) =>
                      imagesResponse = response,
                  onSelectedImageIdChanged: (value) => selectedImageId = value,
                  onPreviewBytesChanged: (bytes) => previewBytes = bytes,
                  onLoadingChanged: (loading) => loadingList = loading,
                  onPreviewLoadingChanged: (loading) =>
                      loadingPreview = loading,
                  onStatusChanged: (line) => statusLine = line,
                  patchFilePathCtrl: patchFilePathCtrl,
                  patchStateCtrl: patchStateCtrl,
                  patchSortCtrl: patchSortCtrl,
                ),
                onLoadPreview: () => loadAssetImagePreview(
                  token: token,
                  projectId: p.id,
                  assetNumericId: selectedAssetNumericId,
                  imagesResponse: imagesResponse,
                  selectedImageId: selectedImageId,
                  previewBytes: previewBytes,
                  setState: setState,
                  onPreviewBytesChanged: (bytes) => previewBytes = bytes,
                  onLoadingChanged: (loading) => loadingPreview = loading,
                  onStatusChanged: (line) => statusLine = line,
                ),
                onImageChanged: imageItems.isEmpty
                    ? null
                    : (value) => selectAssetImagesWorkbenchImage(
                      value: value,
                      token: token,
                      projectId: p.id,
                      assetNumericId: selectedAssetNumericId,
                      imagesResponse: imagesResponse,
                      previewBytes: previewBytes,
                      setState: setState,
                      onSelectedImageIdChanged: (nextValue) =>
                          selectedImageId = nextValue,
                      onPreviewBytesChanged: (bytes) => previewBytes = bytes,
                      onLoadingChanged: (loading) => loadingPreview = loading,
                      onStatusChanged: (line) => statusLine = line,
                      patchFilePathCtrl: patchFilePathCtrl,
                      patchStateCtrl: patchStateCtrl,
                      patchSortCtrl: patchSortCtrl,
                    ),
                onCreateImage: () => createAssetImage(
                  token: token,
                  projectId: p.id,
                  assetNumericId: selectedAssetNumericId,
                  createFilePathCtrl: createFilePathCtrl,
                  createStateCtrl: createStateCtrl,
                  createSortCtrl: createSortCtrl,
                  setState: setState,
                  ctx: ctx,
                  setDialogState: setDialogState,
                  assetsBusy: assetsBusy,
                  onBusyMutationChanged: (busy) => busyMutation = busy,
                  reloadAssetsAndStats: reloadAssetsAndStats,
                  currentSelectedImageId: selectedImageId,
                  getImagesResponse: () => imagesResponse,
                  getSelectedImageId: () => selectedImageId,
                  getPreviewBytes: () => previewBytes,
                  onImagesResponseChanged: (response) =>
                      imagesResponse = response,
                  onSelectedImageIdChanged: (value) => selectedImageId = value,
                  onPreviewBytesChanged: (bytes) => previewBytes = bytes,
                  onListLoadingChanged: (loading) => loadingList = loading,
                  onPreviewLoadingChanged: (loading) =>
                      loadingPreview = loading,
                  onStatusChanged: (line) => statusLine = line,
                  patchFilePathCtrl: patchFilePathCtrl,
                  patchStateCtrl: patchStateCtrl,
                  patchSortCtrl: patchSortCtrl,
                ),
                onPatchImage: () => patchAssetImage(
                  token: token,
                  projectId: p.id,
                  assetNumericId: selectedAssetNumericId,
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
                  onBusyMutationChanged: (busy) => busyMutation = busy,
                  reloadAssetsAndStats: reloadAssetsAndStats,
                  getImagesResponse: () => imagesResponse,
                  getSelectedImageId: () => selectedImageId,
                  getPreviewBytes: () => previewBytes,
                  onImagesResponseChanged: (response) =>
                      imagesResponse = response,
                  onSelectedImageIdChanged: (value) => selectedImageId = value,
                  onPreviewBytesChanged: (bytes) => previewBytes = bytes,
                  onListLoadingChanged: (loading) => loadingList = loading,
                  onPreviewLoadingChanged: (loading) =>
                      loadingPreview = loading,
                  onStatusChanged: (line) => statusLine = line,
                ),
                onDeleteImage: () => deleteAssetImage(
                  token: token,
                  projectId: p.id,
                  assetNumericId: selectedAssetNumericId,
                  imagesResponse: imagesResponse,
                  selectedImageId: selectedImageId,
                  previewBytes: previewBytes,
                  setState: setState,
                  ctx: ctx,
                  setDialogState: setDialogState,
                  assetsBusy: assetsBusy,
                  onBusyMutationChanged: (busy) => busyMutation = busy,
                  reloadAssetsAndStats: reloadAssetsAndStats,
                  getImagesResponse: () => imagesResponse,
                  getSelectedImageId: () => selectedImageId,
                  getPreviewBytes: () => previewBytes,
                  onImagesResponseChanged: (response) =>
                      imagesResponse = response,
                  onSelectedImageIdChanged: (value) => selectedImageId = value,
                  onPreviewBytesChanged: (bytes) => previewBytes = bytes,
                  onListLoadingChanged: (loading) => loadingList = loading,
                  onPreviewLoadingChanged: (loading) =>
                      loadingPreview = loading,
                  onStatusChanged: (line) => statusLine = line,
                  patchFilePathCtrl: patchFilePathCtrl,
                  patchStateCtrl: patchStateCtrl,
                  patchSortCtrl: patchSortCtrl,
                ),
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
