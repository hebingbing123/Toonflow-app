part of '../../../../home_page.dart';

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
