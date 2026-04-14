part of 'workbench_support.dart';

class AssetImagesWorkbenchRuntime {
  const AssetImagesWorkbenchRuntime({
    required this.imagesResponse,
    required this.selectedImageId,
    required this.previewBytes,
    required this.onImagesResponseChanged,
    required this.onSelectedImageIdChanged,
    required this.onPreviewBytesChanged,
    required this.onListLoadingChanged,
    required this.onPreviewLoadingChanged,
    required this.onStatusChanged,
  });

  final ListAssetImagesResponse? Function() imagesResponse;
  final String? Function() selectedImageId;
  final Uint8List? Function() previewBytes;
  final ValueChanged<ListAssetImagesResponse?> onImagesResponseChanged;
  final ValueChanged<String?> onSelectedImageIdChanged;
  final ValueChanged<Uint8List?> onPreviewBytesChanged;
  final ValueChanged<bool> onListLoadingChanged;
  final ValueChanged<bool> onPreviewLoadingChanged;
  final ValueChanged<String?> onStatusChanged;

  String? get currentSelectedImageId => selectedImageId();

  AssetImagesWorkbenchDiagnosis diagnose() {
    return diagnoseAssetImagesWorkbench(
      imagesResponse: imagesResponse(),
      selectedImageId: selectedImageId(),
      hasPreviewBytes: previewBytes() != null,
    );
  }

  void clearSelection({
    ListAssetImagesResponse? images,
    String? selectedId,
    Uint8List? preview,
    String? statusLine,
  }) {
    onImagesResponseChanged(images);
    onSelectedImageIdChanged(selectedId);
    onPreviewBytesChanged(preview);
    onStatusChanged(statusLine);
  }
}

class AssetImagesWorkbenchMutationContext {
  const AssetImagesWorkbenchMutationContext({
    required this.ctx,
    required this.setDialogState,
    required this.assetsBusy,
    required this.onBusyMutationChanged,
    required this.reloadAssetsAndStats,
  });

  final BuildContext ctx;
  final StateSetter setDialogState;
  final List<bool> assetsBusy;
  final ValueChanged<bool> onBusyMutationChanged;
  final Future<void> Function() reloadAssetsAndStats;
}

class AssetImagesWorkbenchScope {
  const AssetImagesWorkbenchScope({
    required this.token,
    required this.projectId,
    required this.runtime,
    required this.createControllers,
    required this.patchControllers,
    required this.mutation,
  });

  final String token;
  final String projectId;
  final AssetImagesWorkbenchRuntime runtime;
  final AssetImagesWorkbenchFormControllers createControllers;
  final AssetImagesWorkbenchFormControllers patchControllers;
  final AssetImagesWorkbenchMutationContext mutation;
}
