part of 'dialog.dart';

typedef _BatchCandidatesRequest = ({String assetType, String name, int limit});

_BatchCandidatesRequest _buildBatchCandidatesRequest({
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
    throw const FormatException('批量候选读取需要有效资产类型');
  }
  if (limit <= 0) {
    throw const FormatException('候选 limit 需要大于 0');
  }
  return (assetType: effectiveType, name: batchNameText.trim(), limit: limit);
}

String _buildBatchCandidatesStatusLine({
  required WorkbenchAssetBatchGenerationResponse response,
  required String assetType,
}) {
  return '${summarizeWorkbenchBatchGenerationData(response)} · type=$assetType';
}

String _buildBatchGenerateLead({
  required int total,
  required int enqueuedCount,
}) {
  return '已为 $total 条资产创建出图任务，队列 $enqueuedCount 条';
}

String _buildDeleteDerivativesLead({
  required int deleted,
  required List<int> assetIds,
}) {
  return '已删除 $deleted 个衍生图记录，资产 ${assetIds.join(", ")}';
}

String _buildUpdateImageUrlLead({
  required int assetId,
  required String message,
}) {
  return '已更新资产 #$assetId 封面 URL：$message';
}

String _buildWorkbenchPollingStatusLine({
  required List<AssetRow> scopedAssets,
  required Set<int> selectedIds,
  required AssetsDataResponseV1? productionData,
  required AssetsPollingImageResponseV1? pollingData,
  required List<WorkbenchAssetPollingPromptItem>? promptPollingData,
}) {
  return summarizeAssetWorkbenchSnapshot(
    visibleAssets: scopedAssets,
    selectedIds: selectedIds,
    productionData: productionData,
    pollingData: pollingData,
    promptPollingData: promptPollingData,
  );
}

