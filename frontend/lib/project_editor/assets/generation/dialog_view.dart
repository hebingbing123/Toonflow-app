import 'package:flutter/material.dart';
import '../../../design_system/tokens.dart';

import 'package:openflow_app/design_system/layout_breakpoints.dart';
import '../../../design_system/components/studio_dropdown_field.dart';
import '../../../design_system/components/studio_dense_action_row.dart';
import '../../../design_system/components/studio_surfaces.dart';
import '../../../design_system/components/studio_text_styles.dart';
import '../../../design_system/components/studio_model_cost_controls.dart';
import '../../../../rust_api.dart';
import '../asset_type_labels.dart';
import 'support.dart';
import 'dialog_view_contract.dart';
import 'package:openflow_app/design_system/components/studio_dialog_shell.dart';

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
    final l10n = resolveAppLocalizationsForErrors(context);
    return StudioAlertDialog(
      title: Text(l10n.projectEditorAssetGenerationTitle),
      content: SizedBox(
        width: studioConstrainedDialogWidth(context, maxWidth: 860),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.projectEditorAssetGenerationDescription,
                style: studioHintStyle(context),
              ),
              const SizedBox(height: StudioSpacing.sm),
              _AssetGenerationControlsPanel(
                busy: model.busyMutation,
                scriptList: model.scriptList,
                typeSelections: model.typeSelections,
                selectedScriptNumericId: model.selectedScriptNumericId,
                selectedType: model.selectedType,
                accessToken: model.accessToken,
                projectUuid: model.projectUuid,
                batchAssetCount: model.batchAssetCount,
                onBatchEstimateChanged: model.onBatchEstimateChanged,
                modelCtrl: model.modelCtrl,
                resolutionCtrl: model.resolutionCtrl,
                imageUrlCtrl: model.imageUrlCtrl,
                batchNameCtrl: model.batchNameCtrl,
                batchLimitCtrl: model.batchLimitCtrl,
                onScriptChanged: callbacks.onScriptChanged,
                onImageUrlChanged: callbacks.onImageUrlChanged,
                onTypeChanged: callbacks.onTypeChanged,
              ),
              const SizedBox(height: StudioSpacing.sm),
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

