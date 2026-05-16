part of 'workbench_support.dart';

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

String _buildAssetImagesStatusLine({
  required AppLocalizations l10n,
  required ListAssetImagesResponse? imagesResponse,
  required String? selectedImageId,
  required Uint8List? previewBytes,
}) {
  final diagnosis = diagnoseAssetImagesWorkbench(
    l10n,
    imagesResponse: imagesResponse,
    selectedImageId: selectedImageId,
    hasPreviewBytes: previewBytes != null,
  );
  final selectionLine = imagesResponse == null
      ? ''
      : summarizeAssetImageSelection(
          l10n,
          imagesResponse,
          selectedImageId: selectedImageId,
        );
  return selectionLine.isEmpty
      ? '${diagnosis.summary} ${diagnosis.detail}'
      : '$selectionLine ${diagnosis.detail}';
}

class _AssetImagesPatchFieldValues {
  const _AssetImagesPatchFieldValues({
    required this.filePath,
    required this.state,
    required this.sortIndex,
  });

  final String filePath;
  final String state;
  final String sortIndex;
}

class _AssetImagesSelectionSyncState {
  const _AssetImagesSelectionSyncState({
    required this.selectedImageId,
    required this.previewBytes,
    required this.statusLine,
    required this.patchFields,
  });

  final String? selectedImageId;
  final Uint8List? previewBytes;
  final String statusLine;
  final _AssetImagesPatchFieldValues patchFields;
}

_AssetImagesPatchFieldValues _buildAssetImagesPatchFieldValues({
  required ListAssetImagesResponse? imagesResponse,
  required String? selectedImageId,
}) {
  final image = selectedAssetImageRow(
    imagesResponse,
    selectedImageId: selectedImageId,
  );
  if (image == null) {
    return const _AssetImagesPatchFieldValues(
      filePath: '',
      state: '',
      sortIndex: '',
    );
  }
  return _AssetImagesPatchFieldValues(
    filePath: image.filePath ?? '',
    state: image.state ?? '',
    sortIndex: image.sortIndex.toString(),
  );
}

_AssetImagesSelectionSyncState _prepareAssetImagesSelectionSyncState({
  required AppLocalizations l10n,
  required ListAssetImagesResponse? imagesResponse,
  required String? selectedImageId,
  required Uint8List? previewBytes,
}) {
  return _AssetImagesSelectionSyncState(
    selectedImageId: selectedImageId,
    previewBytes: previewBytes,
    statusLine: _buildAssetImagesStatusLine(
      l10n: l10n,
      imagesResponse: imagesResponse,
      selectedImageId: selectedImageId,
      previewBytes: previewBytes,
    ),
    patchFields: _buildAssetImagesPatchFieldValues(
      imagesResponse: imagesResponse,
      selectedImageId: selectedImageId,
    ),
  );
}

void _applyAssetImagesSelectionSyncState({
  required AssetImagesWorkbenchRuntime runtime,
  required AssetImagesWorkbenchFormControllers patchControllers,
  required _AssetImagesSelectionSyncState state,
}) {
  runtime.onSelectedImageIdChanged(state.selectedImageId);
  runtime.onPreviewBytesChanged(state.previewBytes);
  runtime.onStatusChanged(state.statusLine);
  patchControllers.filePathCtrl.text = state.patchFields.filePath;
  patchControllers.stateCtrl.text = state.patchFields.state;
  patchControllers.sortCtrl.text = state.patchFields.sortIndex;
}

void syncAssetImagesSelectionState({
  required AppLocalizations l10n,
  required StateSetter setState,
  required AssetImagesWorkbenchRuntime runtime,
  required ListAssetImagesResponse? imagesResponse,
  required String? selectedImageId,
  required Uint8List? previewBytes,
  required AssetImagesWorkbenchFormControllers patchControllers,
}) {
  final nextState = _prepareAssetImagesSelectionSyncState(
    l10n: l10n,
    imagesResponse: imagesResponse,
    selectedImageId: selectedImageId,
    previewBytes: previewBytes,
  );
  setState(() {
    _applyAssetImagesSelectionSyncState(
      runtime: runtime,
      patchControllers: patchControllers,
      state: nextState,
    );
  });
}

void setAssetImagesFollowUpStatus({
  required AppLocalizations l10n,
  required StateSetter setState,
  required AssetImagesWorkbenchRuntime runtime,
  required ListAssetImagesResponse? imagesResponse,
  required String? selectedImageId,
  required bool hasPreviewBytes,
  required String actionSummary,
}) {
  final diagnosis = diagnoseAssetImagesWorkbench(
    l10n,
    imagesResponse: imagesResponse,
    selectedImageId: selectedImageId,
    hasPreviewBytes: hasPreviewBytes,
  );
  setState(() {
    runtime.onStatusChanged(
      buildAssetImagesWorkbenchFollowUp(
        l10n: l10n,
        actionSummary: actionSummary,
        diagnosis: diagnosis,
      ),
    );
  });
}

String? applyReloadedAssetImagesState({
  required AppLocalizations l10n,
  required StateSetter setState,
  required AssetImagesWorkbenchRuntime runtime,
  required ListAssetImagesResponse response,
  required AssetImagesWorkbenchFormControllers patchControllers,
}) {
  final nextSelectedImageId = chooseInitialAssetImageId(
    response,
    preferredImageId: runtime.currentSelectedImageId,
  );
  final nextState = _prepareAssetImagesSelectionSyncState(
    l10n: l10n,
    imagesResponse: response,
    selectedImageId: nextSelectedImageId,
    previewBytes: null,
  );
  final followUpStatus = buildAssetImagesWorkbenchFollowUp(
    l10n: l10n,
    actionSummary: l10n.projectEditorAssetImagesListSynced,
    diagnosis: diagnoseAssetImagesWorkbench(
      l10n,
      imagesResponse: response,
      selectedImageId: nextSelectedImageId,
      hasPreviewBytes: false,
    ),
  );
  setState(() {
    runtime.onImagesResponseChanged(response);
    _applyAssetImagesSelectionSyncState(
      runtime: runtime,
      patchControllers: patchControllers,
      state: nextState,
    );
    runtime.onStatusChanged(followUpStatus);
  });
  return nextSelectedImageId;
}

void applyAssetImagePreviewState({
  required AppLocalizations l10n,
  required StateSetter setState,
  required AssetImagesWorkbenchRuntime runtime,
  required ListAssetImagesResponse? imagesResponse,
  required String? selectedImageId,
  required Uint8List? previewBytes,
  required String actionSummary,
}) {
  final followUpStatus = buildAssetImagesWorkbenchFollowUp(
    l10n: l10n,
    actionSummary: actionSummary,
    diagnosis: diagnoseAssetImagesWorkbench(
      l10n,
      imagesResponse: imagesResponse,
      selectedImageId: selectedImageId,
      hasPreviewBytes: previewBytes != null,
    ),
  );
  setState(() {
    runtime.onPreviewBytesChanged(previewBytes);
    runtime.onStatusChanged(followUpStatus);
  });
}

