import 'package:flutter/material.dart';
import '../../design_system/components/studio_entrance_motion.dart';
import '../../design_system/studio_responsive_layout.dart';
import '../../design_system/tokens.dart';

import '../../../design_system/components/studio_empty_state.dart';
import '../../../design_system/components/studio_model_cost_controls.dart';
import '../../../design_system/components/studio_text_styles.dart';
import '../../../rust_api.dart';
import 'package:openflow_app/design_system/components/studio_dense_action_row.dart';
import 'package:openflow_app/design_system/components/studio_dialog_shell.dart';
import 'package:openflow_app/design_system/components/studio_surfaces.dart';
import 'package:openflow_app/design_system/ix/studio_context_menu.dart';

class ScriptEditImageWorkbenchDialogViewModel {
  const ScriptEditImageWorkbenchDialogViewModel({
    required this.loading,
    required this.busy,
    required this.steps,
    required this.defaultModel,
    required this.uploadedImageUrl,
    required this.statusLine,
    required this.uploadCtrl,
    required this.flowIdCtrl,
    required this.promptCtrl,
    required this.modelCtrl,
    required this.accessToken,
    required this.projectId,
    required this.onEstimateChanged,
    required this.stepIdCtrl,
    required this.stepStatusCtrl,
  });

  final bool loading;
  final bool busy;
  final List<ImageFlowStepV1> steps;
  final ImageDefaultModelResponseV1? defaultModel;
  final String? uploadedImageUrl;
  final String? statusLine;
  final TextEditingController uploadCtrl;
  final TextEditingController flowIdCtrl;
  final TextEditingController promptCtrl;
  final TextEditingController modelCtrl;
  final String accessToken;
  final String projectId;
  final ValueChanged<BillingEstimateResponse?> onEstimateChanged;
  final TextEditingController stepIdCtrl;
  final TextEditingController stepStatusCtrl;
}

class ScriptEditImageWorkbenchDialogViewCallbacks {
  const ScriptEditImageWorkbenchDialogViewCallbacks({
    required this.onRefresh,
    required this.onUploadSourceImage,
    required this.onGenerateFlowImage,
    required this.onSaveFlow,
    required this.onSelectStep,
    required this.onUpdateStepStatus,
    required this.onClose,
  });

  final Future<void> Function() onRefresh;
  final Future<void> Function() onUploadSourceImage;
  final Future<void> Function() onGenerateFlowImage;
  final Future<void> Function() onSaveFlow;
  final ValueChanged<ImageFlowStepV1> onSelectStep;
  final Future<void> Function() onUpdateStepStatus;
  final VoidCallback onClose;
}

/// Script edit-image workbench dialog: flow sync, source upload, generate, step edits.
class ScriptEditImageWorkbenchDialogView extends StatelessWidget {
  const ScriptEditImageWorkbenchDialogView({
    super.key,
    required this.model,
    required this.callbacks,
  });

  final ScriptEditImageWorkbenchDialogViewModel model;
  final ScriptEditImageWorkbenchDialogViewCallbacks callbacks;

  @override
  Widget build(BuildContext context) {
    final l10n = resolveAppLocalizationsForErrors(context);
    final theme = Theme.of(context);
    final viewportWidth = MediaQuery.sizeOf(context).width;
    final dialogWidth = viewportWidth.isFinite
        ? viewportWidth.clamp(320.0, 780.0)
        : 780.0;
    return StudioAlertDialog(
      title: Text(l10n.scriptEditorEditImageWorkbenchTitle),
      content: SizedBox(
        width: dialogWidth,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.scriptEditorEditImageWorkbenchIntro,
                style: studioHintStyle(context),
              ),
              const SizedBox(height: StudioSpacing.sm),
              StudioDenseActionRow(
                spacing: StudioSpacing.xs,
                children: [
                  FilledButton.tonal(
                    style: studioFormTonalButtonStyle(context),
                    onPressed: model.loading || model.busy
                        ? null
                        : callbacks.onRefresh,
                    child: Text(
                      model.loading
                          ? l10n.scriptEditorEditImageWorkbenchSyncing
                          : l10n.scriptEditorEditImageWorkbenchResyncFlow,
                    ),
                  ),
                  if (model.defaultModel != null)
                    Text(
                      l10n.scriptEditorEditImageWorkbenchDefaultModelLine(
                        model.defaultModel!.model,
                        model.defaultModel!.resolution,
                      ),
                      style: theme.textTheme.bodySmall,
                    ),
                ],
              ),
              const SizedBox(height: StudioSpacing.sm),
              TextField(
                controller: model.uploadCtrl,
                minLines: 4,
                maxLines: 8,
                decoration: InputDecoration(
                  labelText: l10n.scriptEditorEditImageWorkbenchUploadLabel,
                  helperText: l10n.scriptEditorEditImageWorkbenchUploadHelper,
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: StudioSpacing.xs),
              StudioDenseActionRow(
                spacing: StudioSpacing.xs,
                children: [
                  FilledButton(
                    style: studioFormPrimaryButtonStyle(context),
                    onPressed: model.busy
                        ? null
                        : callbacks.onUploadSourceImage,
                    child: Text(
                      model.busy
                          ? l10n.scriptEditorEditImageWorkbenchBusy
                          : l10n.scriptEditorEditImageWorkbenchUploadSource,
                    ),
                  ),
                ],
              ),
              if (model.uploadedImageUrl != null) ...[
                const SizedBox(height: StudioSpacing.xs),
                SelectableText(
                  model.uploadedImageUrl!,
                  style: theme.textTheme.bodySmall,
                ),
              ],
              const SizedBox(height: StudioSpacing.sm),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: model.flowIdCtrl,
                      decoration: InputDecoration(
                        labelText:
                            l10n.scriptEditorEditImageWorkbenchFlowIdLabel,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: StudioSpacing.xs),
              StudioModelCostControls(
                accessToken: model.accessToken,
                projectUuid: model.projectId,
                studioStepSlug: 'script',
                modelSlot: 'image',
                taskKind: 'script_edit_image',
                typeFilter: 'image',
                modelValueController: model.modelCtrl,
                enabled: !model.busy,
                onEstimateChanged: model.onEstimateChanged,
              ),
              const SizedBox(height: StudioSpacing.xs),
              TextField(
                controller: model.promptCtrl,
                minLines: 3,
                maxLines: 6,
                decoration: InputDecoration(
                  labelText: l10n.scriptEditorEditImageWorkbenchPromptLabel,
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: StudioSpacing.xs),
              StudioDenseActionRow(
                spacing: StudioSpacing.xs,
                children: [
                  FilledButton(
                    style: studioFormPrimaryButtonStyle(context),
                    onPressed: model.busy
                        ? null
                        : callbacks.onGenerateFlowImage,
                    child: Text(l10n.scriptEditorEditImageWorkbenchGenerate),
                  ),
                  TextButton(
                    onPressed: model.busy ? null : callbacks.onSaveFlow,
                    child: Text(l10n.scriptEditorEditImageWorkbenchSaveFlow),
                  ),
                ],
              ),
              const SizedBox(height: StudioSpacing.sm),
              Text(
                l10n.scriptEditorEditImageWorkbenchStepsHeading,
                style: theme.textTheme.titleSmall,
              ),
              const SizedBox(height: StudioSpacing.xs),
              if (model.steps.isEmpty)
                StudioEmptyState.emptyData(
                  title: l10n.scriptEditorEditImageWorkbenchStepsEmpty,
                )
              else
                SizedBox(
                  height: studioAdaptiveDialogHeight(
                    context,
                    fraction: 0.22,
                    min: 140,
                    max: StudioLayoutSize.fieldStandard,
                  ),
                  child: ListView.builder(
                    itemCount: model.steps.length,
                    itemBuilder: (context, index) {
                      final step = model.steps[index];
                      final selected =
                          step.stepId == model.stepIdCtrl.text.trim();
                      return studioStaggeredItem(
                        index,
                        entranceKey: model.steps.length,
                        child: StudioListRow(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          selected: selected,
                          title: Text(step.stepName),
                          subtitle: Text(
                            l10n.scriptEditorEditImageWorkbenchStepLine(
                              step.stepId,
                              step.status,
                            ),
                          ),
                          onTap: model.busy
                              ? null
                              : () => callbacks.onSelectStep(step),
                        ),
                      );
                    },
                  ),
                ),
              const SizedBox(height: StudioSpacing.xs),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: model.stepIdCtrl,
                      decoration: InputDecoration(
                        labelText:
                            l10n.scriptEditorEditImageWorkbenchStepIdLabel,
                      ),
                    ),
                  ),
                  const SizedBox(width: StudioSpacing.sm),
                  Expanded(
                    child: TextField(
                      controller: model.stepStatusCtrl,
                      decoration: InputDecoration(
                        labelText:
                            l10n.scriptEditorEditImageWorkbenchNewStatusLabel,
                        helperText:
                            l10n.scriptEditorEditImageWorkbenchNewStatusHelper,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: StudioSpacing.xs),
              TextButton(
                onPressed: model.busy ? null : callbacks.onUpdateStepStatus,
                child: Text(l10n.scriptEditorEditImageWorkbenchUpdateStep),
              ),
              if (model.statusLine != null) ...[
                const SizedBox(height: StudioSpacing.xs),
                Text(model.statusLine!, style: theme.textTheme.bodySmall),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: model.busy ? null : callbacks.onClose,
          child: Text(l10n.projectEditorScriptsWorkbenchDialogClose),
        ),
      ],
    );
  }
}
