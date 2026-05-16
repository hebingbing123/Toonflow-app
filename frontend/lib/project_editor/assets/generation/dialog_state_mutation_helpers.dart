part of 'dialog.dart';

typedef _BatchCandidatesRequest = ({String assetType, String name, int limit});

_BatchCandidatesRequest _buildBatchCandidatesRequest({
  required AppLocalizations l10n,
  required String selectedType,
  required List<AssetRow> visibleAssets,
  required String batchNameText,
  required String batchLimitText,
}) {
  final effectiveType = selectedType.isEmpty
      ? visibleAssets.first.assetType.trim()
      : selectedType;
  final limit = int.tryParse(batchLimitText.trim()) ?? 10;
  if (effectiveType.isEmpty) {
    throw FormatException(l10n.projectEditorAssetGenBatchCandidatesNeedAssetType);
  }
  if (limit <= 0) {
    throw FormatException(l10n.projectEditorAssetGenBatchCandidatesLimitPositive);
  }
  return (assetType: effectiveType, name: batchNameText.trim(), limit: limit);
}

String _buildBatchCandidatesStatusLine({
  required AppLocalizations l10n,
  required WorkbenchAssetBatchGenerationResponse response,
  required String assetType,
}) {
  return l10n.projectEditorAssetGenBatchCandidatesStatusWithType(
    summarizeWorkbenchBatchGenerationData(response, l10n),
    assetType,
  );
}

String _buildBatchGenerateLead({
  required AppLocalizations l10n,
  required int total,
  required int enqueuedCount,
}) {
  return l10n.projectEditorAssetGenLeadBatchGenerate(total, enqueuedCount);
}

String _buildDeleteDerivativesLead({
  required AppLocalizations l10n,
  required int deleted,
  required List<int> assetIds,
}) {
  return l10n.projectEditorAssetGenLeadDeleteDerivatives(
    deleted,
    assetIds.join(', '),
  );
}

String _buildUpdateImageUrlLead({
  required AppLocalizations l10n,
  required int assetId,
  required String message,
}) {
  return l10n.projectEditorAssetGenLeadUpdateImageUrl(assetId, message);
}

String _buildWorkbenchPollingStatusLine({
  required AppLocalizations l10n,
  required List<AssetRow> scopedAssets,
  required Set<int> selectedIds,
  required AssetsDataResponseV1? productionData,
  required AssetsPollingImageResponseV1? pollingData,
  required List<WorkbenchAssetPollingPromptItem>? promptPollingData,
}) {
  return summarizeAssetWorkbenchSnapshot(
    visibleAssets: scopedAssets,
    selectedIds: selectedIds,
    l10n: l10n,
    productionData: productionData,
    pollingData: pollingData,
    promptPollingData: promptPollingData,
  );
}

