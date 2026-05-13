import 'package:flutter/material.dart';
import '../../../l10n/app_localizations.dart';

import '../../../../rust_api.dart';
import 'support.dart';
import 'dialog_view_contract.dart';

export 'dialog_view_contract.dart';

part 'dialog_view_controls_panel.dart';
part 'dialog_view_actions_panel.dart';
part 'dialog_view_status_panel.dart';
part 'dialog_view_selection_panel.dart';

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
    final l10n = AppLocalizations.of(context)!;
    return AlertDialog(
      title: Text(l10n.projectEditorAssetGenerationTitle),
      content: SizedBox(
        width: 860,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.projectEditorAssetGenerationDescription,
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
          child: Text(l10n.projectEditorAssetGenerationClose),
        ),
      ],
    );
  }
}

