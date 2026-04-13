part of '../../../../home_page.dart';

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
  required AssetImagesWorkbenchFormControllers patchControllers,
}) {
  final image = selectedAssetImageRow(
    imagesResponse,
    selectedImageId: selectedImageId,
  );
  setState(() {
    if (image == null) {
      patchControllers.filePathCtrl.text = '';
      patchControllers.stateCtrl.text = '';
      patchControllers.sortCtrl.text = '';
      return;
    }
    patchControllers.filePathCtrl.text = image.filePath ?? '';
    patchControllers.stateCtrl.text = image.state ?? '';
    patchControllers.sortCtrl.text = image.sortIndex.toString();
  });
}

void syncAssetImagesSelectionState({
  required StateSetter setState,
  required AssetImagesWorkbenchRuntime runtime,
  required ListAssetImagesResponse? imagesResponse,
  required String? selectedImageId,
  required Uint8List? previewBytes,
  required AssetImagesWorkbenchFormControllers patchControllers,
}) {
  setState(() {
    runtime.onSelectedImageIdChanged(selectedImageId);
    runtime.onPreviewBytesChanged(previewBytes);
  });
  syncAssetImagesStatusLine(
    setState: setState,
    imagesResponse: imagesResponse,
    selectedImageId: selectedImageId,
    previewBytes: previewBytes,
    onStatusChanged: runtime.onStatusChanged,
  );
  syncAssetImagesPatchFieldsFromSelected(
    setState: setState,
    imagesResponse: imagesResponse,
    selectedImageId: selectedImageId,
    patchControllers: patchControllers,
  );
}

void setAssetImagesFollowUpStatus({
  required StateSetter setState,
  required AssetImagesWorkbenchRuntime runtime,
  required ListAssetImagesResponse? imagesResponse,
  required String? selectedImageId,
  required bool hasPreviewBytes,
  required String actionSummary,
}) {
  final diagnosis = diagnoseAssetImagesWorkbench(
    imagesResponse: imagesResponse,
    selectedImageId: selectedImageId,
    hasPreviewBytes: hasPreviewBytes,
  );
  setState(() {
    runtime.onStatusChanged(
      buildAssetImagesWorkbenchFollowUp(
        actionSummary: actionSummary,
        diagnosis: diagnosis,
      ),
    );
  });
}

String? applyReloadedAssetImagesState({
  required StateSetter setState,
  required AssetImagesWorkbenchRuntime runtime,
  required ListAssetImagesResponse response,
  required AssetImagesWorkbenchFormControllers patchControllers,
}) {
  final nextSelectedImageId = chooseInitialAssetImageId(
    response,
    preferredImageId: runtime.currentSelectedImageId,
  );
  setState(() => runtime.onImagesResponseChanged(response));
  syncAssetImagesSelectionState(
    setState: setState,
    runtime: runtime,
    imagesResponse: runtime.imagesResponse(),
    selectedImageId: nextSelectedImageId,
    previewBytes: null,
    patchControllers: patchControllers,
  );
  setAssetImagesFollowUpStatus(
    setState: setState,
    runtime: runtime,
    imagesResponse: runtime.imagesResponse(),
    selectedImageId: nextSelectedImageId,
    hasPreviewBytes: false,
    actionSummary: '已同步当前资产的图片列表。',
  );
  return nextSelectedImageId;
}

void applyAssetImagePreviewState({
  required StateSetter setState,
  required AssetImagesWorkbenchRuntime runtime,
  required ListAssetImagesResponse? imagesResponse,
  required String? selectedImageId,
  required Uint8List? previewBytes,
  required String actionSummary,
}) {
  setState(() => runtime.onPreviewBytesChanged(previewBytes));
  setAssetImagesFollowUpStatus(
    setState: setState,
    runtime: runtime,
    imagesResponse: imagesResponse,
    selectedImageId: selectedImageId,
    hasPreviewBytes: previewBytes != null,
    actionSummary: actionSummary,
  );
}

int? parsePositiveWorkbenchInt(String raw) {
  if (raw.trim().isEmpty) return null;
  final parsed = int.tryParse(raw.trim());
  if (parsed == null || parsed <= 0) return null;
  return parsed;
}
