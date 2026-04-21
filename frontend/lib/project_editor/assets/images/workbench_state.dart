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

  AssetImagesWorkbenchRuntime buildRuntime() {
    return AssetImagesWorkbenchRuntime(
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
  }

  AssetImagesWorkbenchDialogState captureDialogState({
    required List<AssetRow> assets,
    required AssetImagesWorkbenchFormControllers createControllers,
    required AssetImagesWorkbenchFormControllers patchControllers,
  }) {
    return AssetImagesWorkbenchDialogState.capture(
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
  final AssetImagesWorkbenchFormControllers createControllers;
  final AssetImagesWorkbenchFormControllers patchControllers;

  factory AssetImagesWorkbenchDialogState.capture({
    required List<AssetRow> assets,
    required ListAssetImagesResponse? imagesResponse,
    required int selectedAssetNumericId,
    required String? selectedImageId,
    required bool loadingList,
    required bool loadingPreview,
    required bool busyMutation,
    required String? statusLine,
    required Uint8List? previewBytes,
    required AssetImagesWorkbenchFormControllers createControllers,
    required AssetImagesWorkbenchFormControllers patchControllers,
  }) {
    final imageItems = imagesResponse?.items ?? const <AssetImageRow>[];
    final diagnosis = diagnoseAssetImagesWorkbench(
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
  });

  final Future<void> Function(int? value) onAssetChanged;
  final Future<void> Function() onRecommendedAction;
  final Future<void> Function() onReloadImages;
  final Future<void> Function() onLoadPreview;
  final Future<void> Function(String? value)? onImageChanged;
  final Future<void> Function() onCreateImage;
  final Future<void> Function() onPatchImage;
  final Future<void> Function() onDeleteImage;
}
