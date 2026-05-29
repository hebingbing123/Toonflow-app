part of 'workbench_support.dart';

class AssetImagesWorkbenchFormControllers {
  AssetImagesWorkbenchFormControllers()
    : filePathCtrl = TextEditingController(),
      stateCtrl = TextEditingController(),
      sortCtrl = TextEditingController();

  final TextEditingController filePathCtrl;
  final TextEditingController stateCtrl;
  final TextEditingController sortCtrl;

  void dispose() {
    filePathCtrl.dispose();
    stateCtrl.dispose();
    sortCtrl.dispose();
  }
}

class AssetImagesWorkbenchSession {
  AssetImagesWorkbenchSession._({required this.selectedAssetNumericId});

  factory AssetImagesWorkbenchSession.initialize({
    required List<AssetRow> assets,
    int? preferredAssetNumericId,
  }) {
    return AssetImagesWorkbenchSession._(
      selectedAssetNumericId: chooseInitialAssetNumericId(
        assets,
        preferredNumericId: preferredAssetNumericId,
      )!,
    );
  }

  int selectedAssetNumericId;
  String? selectedImageId;
  ListAssetImagesResponse? imagesResponse;
  Uint8List? previewBytes;
  bool loadingList = false;
  bool loadingPreview = false;
  bool busyMutation = false;
  bool initialLoadTriggered = false;
  String? statusLine;
  List<AssetBlockRow> assetBlocks = const [];
  bool loadingBlocks = false;
  final TextEditingController blockKeyController = TextEditingController();

  AssetImagesWorkbenchRuntime buildRuntime() {
    return AssetImagesWorkbenchRuntime(
      imagesResponse: () => imagesResponse,
      selectedImageId: () => selectedImageId,
      previewBytes: () => previewBytes,
      assetBlocks: () => assetBlocks,
      loadingBlocks: () => loadingBlocks,
      onImagesResponseChanged: (response) => imagesResponse = response,
      onSelectedImageIdChanged: (value) => selectedImageId = value,
      onPreviewBytesChanged: (bytes) => previewBytes = bytes,
      onAssetBlocksChanged: (rows) => assetBlocks = rows,
      onListLoadingChanged: (loading) => loadingList = loading,
      onPreviewLoadingChanged: (loading) => loadingPreview = loading,
      onLoadingBlocksChanged: (loading) => loadingBlocks = loading,
      onStatusChanged: (line) => statusLine = line,
    );
  }

  AssetImagesWorkbenchDialogState captureDialogState({
    required AppLocalizations l10n,
    required List<AssetRow> assets,
    required AssetImagesWorkbenchFormControllers createControllers,
    required AssetImagesWorkbenchFormControllers patchControllers,
  }) {
    return AssetImagesWorkbenchDialogState.capture(
      l10n: l10n,
      assets: assets,
      imagesResponse: imagesResponse,
      selectedAssetNumericId: selectedAssetNumericId,
      selectedImageId: selectedImageId,
      loadingList: loadingList,
      loadingPreview: loadingPreview,
      busyMutation: busyMutation,
      statusLine: statusLine,
      previewBytes: previewBytes,
      assetBlocks: assetBlocks,
      loadingBlocks: loadingBlocks,
      blockKeyController: blockKeyController,
      createControllers: createControllers,
      patchControllers: patchControllers,
    );
  }
}

class AssetImagesWorkbenchDialogState {
  const AssetImagesWorkbenchDialogState({
    required this.assets,
    required this.imageItems,
    required this.selectedAssetNumericId,
    required this.selectedImageId,
    required this.diagnosis,
    required this.loadingList,
    required this.loadingPreview,
    required this.busyMutation,
    required this.statusLine,
    required this.previewBytes,
    required this.assetBlocks,
    required this.loadingBlocks,
    required this.blockKeyController,
    required this.createControllers,
    required this.patchControllers,
  });

  final List<AssetRow> assets;
  final List<AssetImageRow> imageItems;
  final int selectedAssetNumericId;
  final String? selectedImageId;
  final AssetImagesWorkbenchDiagnosis diagnosis;
  final bool loadingList;
  final bool loadingPreview;
  final bool busyMutation;
  final String? statusLine;
  final Uint8List? previewBytes;
  final List<AssetBlockRow> assetBlocks;
  final bool loadingBlocks;
  final TextEditingController blockKeyController;
  final AssetImagesWorkbenchFormControllers createControllers;
  final AssetImagesWorkbenchFormControllers patchControllers;

  factory AssetImagesWorkbenchDialogState.capture({
    required AppLocalizations l10n,
    required List<AssetRow> assets,
    required ListAssetImagesResponse? imagesResponse,
    required int selectedAssetNumericId,
    required String? selectedImageId,
    required bool loadingList,
    required bool loadingPreview,
    required bool busyMutation,
    required String? statusLine,
    required Uint8List? previewBytes,
    required List<AssetBlockRow> assetBlocks,
    required bool loadingBlocks,
    required TextEditingController blockKeyController,
    required AssetImagesWorkbenchFormControllers createControllers,
    required AssetImagesWorkbenchFormControllers patchControllers,
  }) {
    final imageItems = imagesResponse?.items ?? const <AssetImageRow>[];
    final diagnosis = diagnoseAssetImagesWorkbench(
      l10n,
      imagesResponse: imagesResponse,
      selectedImageId: selectedImageId,
      hasPreviewBytes: previewBytes != null,
    );
    return AssetImagesWorkbenchDialogState(
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
      assetBlocks: assetBlocks,
      loadingBlocks: loadingBlocks,
      blockKeyController: blockKeyController,
      createControllers: createControllers,
      patchControllers: patchControllers,
    );
  }
}

class AssetImagesWorkbenchDialogCallbacks {
  const AssetImagesWorkbenchDialogCallbacks({
    required this.onAssetChanged,
    required this.onRecommendedAction,
    required this.onReloadImages,
    required this.onLoadPreview,
    required this.onImageChanged,
    required this.onCreateImage,
    required this.onPatchImage,
    required this.onDeleteImage,
    required this.onReloadBlocks,
    required this.onRegisterBlock,
  });

  final Future<void> Function(int? value) onAssetChanged;
  final Future<void> Function() onRecommendedAction;
  final Future<void> Function() onReloadImages;
  final Future<void> Function() onLoadPreview;
  final Future<void> Function(String? value)? onImageChanged;
  final Future<void> Function() onCreateImage;
  final Future<void> Function() onPatchImage;
  final Future<void> Function() onDeleteImage;
  final Future<void> Function() onReloadBlocks;
  final Future<void> Function() onRegisterBlock;
}
