import 'package:flutter/material.dart';

import '../../../../rust_api.dart';

class AssetGenerationWorkbenchDialogViewModel {
  const AssetGenerationWorkbenchDialogViewModel({
    required this.scriptList,
    required this.visibleAssets,
    required this.scopedAssets,
    required this.typeSelections,
    required this.pollingSelections,
    required this.promptSelections,
    required this.selectedIds,
    required this.selectedSingleAssetId,
    required this.filterScriptNumericId,
    required this.selectedScriptNumericId,
    required this.selectedType,
    required this.loadingSummary,
    required this.busyMutation,
    required this.productionData,
    required this.pollingData,
    required this.materialData,
    required this.batchData,
    required this.promptPollingData,
    required this.statusLine,
    required this.modelCtrl,
    required this.resolutionCtrl,
    required this.imageUrlCtrl,
    required this.batchNameCtrl,
    required this.batchLimitCtrl,
    required this.accessToken,
    required this.projectUuid,
    required this.batchAssetCount,
    required this.onBatchEstimateChanged,
  });

  final List<ScriptBrief> scriptList;
  final List<AssetRow> visibleAssets;
  final List<AssetRow> scopedAssets;
  final Map<String, List<int>> typeSelections;
  final Map<String, List<int>> pollingSelections;
  final Map<String, List<int>> promptSelections;
  final List<int> selectedIds;
  final int? selectedSingleAssetId;
  final int? filterScriptNumericId;
  final int selectedScriptNumericId;
  final String selectedType;
  final bool loadingSummary;
  final bool busyMutation;
  final AssetsDataResponseV1? productionData;
  final AssetsPollingImageResponseV1? pollingData;
  final WorkbenchAssetMaterialDataResponse? materialData;
  final WorkbenchAssetBatchGenerationResponse? batchData;
  final List<WorkbenchAssetPollingPromptItem>? promptPollingData;
  final String? statusLine;
  final TextEditingController modelCtrl;
  final TextEditingController resolutionCtrl;
  final TextEditingController imageUrlCtrl;
  final TextEditingController batchNameCtrl;
  final TextEditingController batchLimitCtrl;
  final String accessToken;
  final String projectUuid;
  final int batchAssetCount;
  final ValueChanged<BillingEstimateResponse?> onBatchEstimateChanged;
}

class AssetGenerationWorkbenchDialogViewCallbacks {
  const AssetGenerationWorkbenchDialogViewCallbacks({
    required this.onScriptChanged,
    required this.onImageUrlChanged,
    required this.onTypeChanged,
    required this.onSyncWorkbenchSnapshot,
    required this.onLoadMaterialContext,
    required this.onLoadBatchCandidates,
    required this.onSelectAllVisible,
    required this.onRebuildSelectionByType,
    required this.onClearSelection,
    required this.onBatchGenerateImages,
    required this.onPollImageStatuses,
    required this.onPollPromptStatuses,
    required this.onDeleteDerivatives,
    required this.onUpdateImageUrl,
    required this.onApplyPollingSelection,
    required this.onApplyMaterialSelection,
    required this.onApplyBatchSelection,
    required this.onApplyPromptSelection,
    required this.onToggleAsset,
    required this.onClose,
  });

  final ValueChanged<int> onScriptChanged;
  final ValueChanged<String> onImageUrlChanged;
  final ValueChanged<String> onTypeChanged;
  final VoidCallback onSyncWorkbenchSnapshot;
  final VoidCallback onLoadMaterialContext;
  final VoidCallback onLoadBatchCandidates;
  final VoidCallback onSelectAllVisible;
  final VoidCallback onRebuildSelectionByType;
  final VoidCallback onClearSelection;
  final VoidCallback onBatchGenerateImages;
  final VoidCallback onPollImageStatuses;
  final VoidCallback onPollPromptStatuses;
  final VoidCallback onDeleteDerivatives;
  final VoidCallback onUpdateImageUrl;
  final void Function(String label, List<int> ids) onApplyPollingSelection;
  final VoidCallback onApplyMaterialSelection;
  final VoidCallback onApplyBatchSelection;
  final void Function(String label, List<int> ids) onApplyPromptSelection;
  final void Function(AssetRow asset, bool checked) onToggleAsset;
  final VoidCallback onClose;
}

