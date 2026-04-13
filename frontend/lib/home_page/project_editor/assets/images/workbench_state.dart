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
  required ListAssetImagesResponse? imagesResponse,
  required String? selectedImageId,
  required Uint8List? previewBytes,
}) {
  final diagnosis = diagnoseAssetImagesWorkbench(
    imagesResponse: imagesResponse,
    selectedImageId: selectedImageId,
    hasPreviewBytes: previewBytes != null,
  );
  final selectionLine = imagesResponse == null
      ? ''
      : summarizeAssetImageSelection(
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
  required ListAssetImagesResponse? imagesResponse,
  required String? selectedImageId,
  required Uint8List? previewBytes,
}) {
  return _AssetImagesSelectionSyncState(
    selectedImageId: selectedImageId,
    previewBytes: previewBytes,
    statusLine: _buildAssetImagesStatusLine(
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
  required StateSetter setState,
  required AssetImagesWorkbenchRuntime runtime,
  required ListAssetImagesResponse? imagesResponse,
  required String? selectedImageId,
  required Uint8List? previewBytes,
  required AssetImagesWorkbenchFormControllers patchControllers,
}) {
  final nextState = _prepareAssetImagesSelectionSyncState(
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
  final nextState = _prepareAssetImagesSelectionSyncState(
    imagesResponse: response,
    selectedImageId: nextSelectedImageId,
    previewBytes: null,
  );
  final followUpStatus = buildAssetImagesWorkbenchFollowUp(
    actionSummary: '已同步当前资产的图片列表。',
    diagnosis: diagnoseAssetImagesWorkbench(
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
  required StateSetter setState,
  required AssetImagesWorkbenchRuntime runtime,
  required ListAssetImagesResponse? imagesResponse,
  required String? selectedImageId,
  required Uint8List? previewBytes,
  required String actionSummary,
}) {
  final followUpStatus = buildAssetImagesWorkbenchFollowUp(
    actionSummary: actionSummary,
    diagnosis: diagnoseAssetImagesWorkbench(
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
