part of 'dialog.dart';

List<AssetRow> _filterAssetsByType(List<AssetRow> assets, String selectedType) {
  final normalized = selectedType.trim();
  if (normalized.isEmpty) return assets;
  return assets
      .where((a) => a.assetType.trim() == normalized)
      .toList(growable: false);
}

Map<String, List<int>> _resolvePollingSelections(
  AssetsPollingImageResponseV1? pollingData,
) {
  if (pollingData == null) return const <String, List<int>>{};
  return collectAssetIdsByImageState(pollingData.statuses);
}

Map<String, List<int>> _resolvePromptSelections(
  List<WorkbenchAssetPollingPromptItem>? promptPollingData,
) {
  if (promptPollingData == null) return const <String, List<int>>{};
  return collectAssetIdsByPromptState(promptPollingData);
}

int? _resolveSingleSelectedAssetId(List<int> selectedIds) =>
    selectedIds.length == 1 ? selectedIds.first : null;

AssetGenerationWorkbenchDialogViewModel _buildAssetGenerationWorkbenchViewModel({
  required List<ScriptBrief> scriptList,
  required List<AssetRow> visibleAssets,
  required List<AssetRow> scopedAssets,
  required Map<String, List<int>> typeSelections,
  required Map<String, List<int>> pollingSelections,
  required Map<String, List<int>> promptSelections,
  required List<int> selectedIds,
  required int? selectedSingleAssetId,
  required int? filterScriptNumericId,
  required int selectedScriptNumericId,
  required String selectedType,
  required bool loadingSummary,
  required bool busyMutation,
  required AssetsDataResponseV1? productionData,
  required AssetsPollingImageResponseV1? pollingData,
  required WorkbenchAssetMaterialDataResponse? materialData,
  required WorkbenchAssetBatchGenerationResponse? batchData,
  required List<WorkbenchAssetPollingPromptItem>? promptPollingData,
  required String? statusLine,
  required TextEditingController modelCtrl,
  required TextEditingController resolutionCtrl,
  required TextEditingController imageUrlCtrl,
  required TextEditingController batchNameCtrl,
  required TextEditingController batchLimitCtrl,
  required String accessToken,
  required String projectUuid,
  required int batchAssetCount,
  required ValueChanged<BillingEstimateResponse?> onBatchEstimateChanged,
}) {
  return AssetGenerationWorkbenchDialogViewModel(
    scriptList: scriptList,
    visibleAssets: visibleAssets,
    scopedAssets: scopedAssets,
    typeSelections: typeSelections,
    pollingSelections: pollingSelections,
    promptSelections: promptSelections,
    selectedIds: selectedIds,
    selectedSingleAssetId: selectedSingleAssetId,
    filterScriptNumericId: filterScriptNumericId,
    selectedScriptNumericId: selectedScriptNumericId,
    selectedType: selectedType,
    loadingSummary: loadingSummary,
    busyMutation: busyMutation,
    productionData: productionData,
    pollingData: pollingData,
    materialData: materialData,
    batchData: batchData,
    promptPollingData: promptPollingData,
    statusLine: statusLine,
    modelCtrl: modelCtrl,
    resolutionCtrl: resolutionCtrl,
    imageUrlCtrl: imageUrlCtrl,
    batchNameCtrl: batchNameCtrl,
    batchLimitCtrl: batchLimitCtrl,
    accessToken: accessToken,
    projectUuid: projectUuid,
    batchAssetCount: batchAssetCount,
    onBatchEstimateChanged: onBatchEstimateChanged,
  );
}

