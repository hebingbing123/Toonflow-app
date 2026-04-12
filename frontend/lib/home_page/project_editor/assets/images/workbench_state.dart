part of '../../../../home_page.dart';

AssetImageRow? selectedAssetImageRow(
  ListAssetImagesResponse? imagesResponse, {
  required String? selectedImageId,
}) {
  final items = imagesResponse?.items ?? const <AssetImageRow>[];
  if (selectedImageId == null) return null;
  for (final row in items) {
    if (row.id == selectedImageId) {
      return row;
    }
  }
  return null;
}

void syncAssetImagesStatusLine({
  required StateSetter setState,
  required ListAssetImagesResponse? imagesResponse,
  required String? selectedImageId,
  required Uint8List? previewBytes,
  required ValueChanged<String?> onStatusChanged,
}) {
  final diagnosis = diagnoseAssetImagesWorkbench(
    imagesResponse: imagesResponse,
    selectedImageId: selectedImageId,
    hasPreviewBytes: previewBytes != null,
  );
  setState(() {
    final selectionLine = imagesResponse == null
        ? ''
        : summarizeAssetImageSelection(
            imagesResponse,
            selectedImageId: selectedImageId,
          );
    onStatusChanged(
      selectionLine.isEmpty
          ? '${diagnosis.summary} ${diagnosis.detail}'
          : '$selectionLine ${diagnosis.detail}',
    );
  });
}

void syncAssetImagesPatchFieldsFromSelected({
  required StateSetter setState,
  required ListAssetImagesResponse? imagesResponse,
  required String? selectedImageId,
  required TextEditingController patchFilePathCtrl,
  required TextEditingController patchStateCtrl,
  required TextEditingController patchSortCtrl,
}) {
  final image = selectedAssetImageRow(
    imagesResponse,
    selectedImageId: selectedImageId,
  );
  setState(() {
    if (image == null) {
      patchFilePathCtrl.text = '';
      patchStateCtrl.text = '';
      patchSortCtrl.text = '';
      return;
    }
    patchFilePathCtrl.text = image.filePath ?? '';
    patchStateCtrl.text = image.state ?? '';
    patchSortCtrl.text = image.sortIndex.toString();
  });
}

int? parsePositiveWorkbenchInt(String raw) {
  if (raw.trim().isEmpty) return null;
  final parsed = int.tryParse(raw.trim());
  if (parsed == null || parsed <= 0) return null;
  return parsed;
}
