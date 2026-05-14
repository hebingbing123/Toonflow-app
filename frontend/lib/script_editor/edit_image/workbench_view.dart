import 'package:flutter/material.dart';

import '../../../rust_api.dart';

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
    final outline = theme.colorScheme.outline;
    final viewportWidth = MediaQuery.sizeOf(context).width;
    final dialogWidth = viewportWidth.isFinite
        ? viewportWidth.clamp(320.0, 780.0)
        : 780.0;
    return AlertDialog(
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
                style: theme.textTheme.bodySmall?.copyWith(color: outline),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  FilledButton.tonal(
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
              const SizedBox(height: 12),
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
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  FilledButton(
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
                const SizedBox(height: 8),
                SelectableText(
                  model.uploadedImageUrl!,
                  style: theme.textTheme.bodySmall,
                ),
              ],
              const SizedBox(height: 16),
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
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: model.modelCtrl,
                      decoration: InputDecoration(
                        labelText: l10n
                            .scriptEditorEditImageWorkbenchModelOptionalLabel,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              TextField(
                controller: model.promptCtrl,
                minLines: 3,
                maxLines: 6,
                decoration: InputDecoration(
                  labelText: l10n.scriptEditorEditImageWorkbenchPromptLabel,
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton(
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
              const SizedBox(height: 16),
              Text(
                l10n.scriptEditorEditImageWorkbenchStepsHeading,
                style: theme.textTheme.titleSmall,
              ),
              const SizedBox(height: 8),
              if (model.steps.isEmpty)
                Text(
                  l10n.scriptEditorEditImageWorkbenchStepsEmpty,
                  style: theme.textTheme.bodySmall,
                )
              else
                SizedBox(
                  height: 160,
                  child: ListView.builder(
                    itemCount: model.steps.length,
                    itemBuilder: (context, index) {
                      final step = model.steps[index];
                      final selected =
                          step.stepId == model.stepIdCtrl.text.trim();
                      return ListTile(
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
                      );
                    },
                  ),
                ),
              const SizedBox(height: 8),
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
                  const SizedBox(width: 12),
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
              const SizedBox(height: 8),
              TextButton(
                onPressed: model.busy ? null : callbacks.onUpdateStepStatus,
                child: Text(l10n.scriptEditorEditImageWorkbenchUpdateStep),
              ),
              if (model.statusLine != null) ...[
                const SizedBox(height: 8),
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
