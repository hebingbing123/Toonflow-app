part of 'dialog.dart';

typedef _SnapshotApplyResult = ({
  List<AssetRow> currentVisibleAssets,
  List<int> selectedIds,
  int? focusedAssetNumericId,
  String statusLine,
});

String? _buildSnapshotLoadingStatusLine(AppLocalizations l10n, String? lead) {
  return lead == null ? null : l10n.projectEditorAssetGenSnapshotLoadingWithLead(lead);
}

_SnapshotApplyResult _buildSnapshotApplyResult({
  required AppLocalizations l10n,
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
    visibleAssets: currentVisibleAssets,
    selectedIds: selectedIds,
    l10n: l10n,
    productionData: productionData,
    pollingData: pollingData,
    promptPollingData: promptPollingData,
    lead: lead,
  );
  return (
    currentVisibleAssets: currentVisibleAssets,
    selectedIds: selectedIds,
    focusedAssetNumericId: focusedAssetNumericId,
    statusLine: statusLine,
  );
}

