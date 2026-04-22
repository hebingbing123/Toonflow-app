part of 'dialog.dart';

typedef _SnapshotApplyResult = ({
  List<AssetRow> currentVisibleAssets,
  List<int> selectedIds,
  int? focusedAssetNumericId,
  String statusLine,
});

String? _buildSnapshotLoadingStatusLine(String? lead) {
  return lead == null ? null : '$lead，正在同步工作台摘要…';
}

_SnapshotApplyResult _buildSnapshotApplyResult({
  required String? lead,
  required List<AssetRow> visibleAssets,
  required String selectedType,
  required Set<int> preferredIds,
  required int? preferredNumericId,
  required AssetsDataResponseV1? productionData,
  required AssetsPollingImageResponseV1? pollingData,
  required List<WorkbenchAssetPollingPromptItem>? promptPollingData,
}) {
  final currentVisibleAssets = _filterAssetsByType(visibleAssets, selectedType);
  final selectedIds = chooseVisibleAssetSelection(
    currentVisibleAssets,
    preferredIds: preferredIds,
    preferredNumericId: preferredNumericId,
  );
  final focusedAssetNumericId = selectedIds.isEmpty ? null : selectedIds.first;
  final statusLine = summarizeAssetWorkbenchSnapshot(
    lead: lead,
    visibleAssets: currentVisibleAssets,
    selectedIds: selectedIds,
    productionData: productionData,
    pollingData: pollingData,
    promptPollingData: promptPollingData,
  );
  return (
    currentVisibleAssets: currentVisibleAssets,
    selectedIds: selectedIds,
    focusedAssetNumericId: focusedAssetNumericId,
    statusLine: statusLine,
  );
}

