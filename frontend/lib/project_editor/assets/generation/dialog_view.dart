import 'package:flutter/material.dart';

import '../../../../rust_api.dart';
import 'support.dart';

part 'dialog_view_controls_panel.dart';
part 'dialog_view_actions_panel.dart';
part 'dialog_view_status_panel.dart';
part 'dialog_view_selection_panel.dart';

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

class AssetGenerationWorkbenchDialogView extends StatelessWidget {
  const AssetGenerationWorkbenchDialogView({
    super.key,
    required this.model,
    required this.callbacks,
  });

  final AssetGenerationWorkbenchDialogViewModel model;
  final AssetGenerationWorkbenchDialogViewCallbacks callbacks;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('资产出图工作台'),
      content: SizedBox(
        width: 860,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '把 production 资产摘要、批量出图、状态轮询、衍生图清理和封面 URL 更新收口到项目资产主流程，不再只依赖 system probe。',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.outline,
                ),
              ),
              const SizedBox(height: 12),
              _AssetGenerationControlsPanel(
                busy: model.busyMutation,
                scriptList: model.scriptList,
                typeSelections: model.typeSelections,
                selectedScriptNumericId: model.selectedScriptNumericId,
                selectedType: model.selectedType,
                modelCtrl: model.modelCtrl,
                resolutionCtrl: model.resolutionCtrl,
                imageUrlCtrl: model.imageUrlCtrl,
                batchNameCtrl: model.batchNameCtrl,
                batchLimitCtrl: model.batchLimitCtrl,
                onScriptChanged: callbacks.onScriptChanged,
                onImageUrlChanged: callbacks.onImageUrlChanged,
                onTypeChanged: callbacks.onTypeChanged,
              ),
              const SizedBox(height: 12),
              _AssetGenerationActionsPanel(
                loadingSummary: model.loadingSummary,
                busyMutation: model.busyMutation,
                visibleAssets: model.visibleAssets,
                scopedAssets: model.scopedAssets,
                selectedIds: model.selectedIds,
                selectedSingleAssetId: model.selectedSingleAssetId,
                imageUrlCtrl: model.imageUrlCtrl,
                onSyncWorkbenchSnapshot: callbacks.onSyncWorkbenchSnapshot,
                onLoadMaterialContext: callbacks.onLoadMaterialContext,
                onLoadBatchCandidates: callbacks.onLoadBatchCandidates,
                onSelectAllVisible: callbacks.onSelectAllVisible,
                onRebuildSelectionByType: callbacks.onRebuildSelectionByType,
                onClearSelection: callbacks.onClearSelection,
                onBatchGenerateImages: callbacks.onBatchGenerateImages,
                onPollImageStatuses: callbacks.onPollImageStatuses,
                onPollPromptStatuses: callbacks.onPollPromptStatuses,
                onDeleteDerivatives: callbacks.onDeleteDerivatives,
                onUpdateImageUrl: callbacks.onUpdateImageUrl,
              ),
              const SizedBox(height: 8),
              _AssetGenerationStatusPanel(
                busy: model.busyMutation,
                statusLine: model.statusLine,
                productionData: model.productionData,
                pollingData: model.pollingData,
                materialData: model.materialData,
                batchData: model.batchData,
                promptPollingData: model.promptPollingData,
                pollingSelections: model.pollingSelections,
                promptSelections: model.promptSelections,
                onApplyPollingSelection: callbacks.onApplyPollingSelection,
                onApplyMaterialSelection: callbacks.onApplyMaterialSelection,
                onApplyBatchSelection: callbacks.onApplyBatchSelection,
                onApplyPromptSelection: callbacks.onApplyPromptSelection,
              ),
              _AssetGenerationSelectionPanel(
                busy: model.busyMutation,
                filterScriptNumericId: model.filterScriptNumericId,
                scopedAssets: model.scopedAssets,
                selectedIds: model.selectedIds.toSet(),
                onToggleAsset: callbacks.onToggleAsset,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: model.busyMutation ? null : callbacks.onClose,
          child: const Text('关闭'),
        ),
      ],
    );
  }
}

