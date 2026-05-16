import 'package:flutter/material.dart';

import '../../../rust_api.dart';
import '../../../script_editor/support.dart';

class ProjectScriptsWorkbenchDialogViewModel {
  const ProjectScriptsWorkbenchDialogViewModel({
    required this.localBusy,
    required this.infoLine,
    required this.filterCtrl,
    required this.previewRows,
    required this.selectedIdsCtrl,
    required this.diagnosis,
    required this.recommendedActionLabel,
    required this.groupSizeCtrl,
    required this.addCountCtrl,
    required this.addPrefixCtrl,
    required this.addBodyCtrl,
    required this.scriptList,
    required this.scriptTaskLine,
  });

  final bool localBusy;
  final String infoLine;
  final TextEditingController filterCtrl;
  final List<ScriptWorkbenchDetailRow> previewRows;
  final TextEditingController selectedIdsCtrl;
  final ScriptBatchWorkbenchDiagnosis diagnosis;
  final String recommendedActionLabel;
  final TextEditingController groupSizeCtrl;
  final TextEditingController addCountCtrl;
  final TextEditingController addPrefixCtrl;
  final TextEditingController addBodyCtrl;
  final List<ScriptBrief> scriptList;
  final String? scriptTaskLine;
}

class ProjectScriptsWorkbenchDialogViewCallbacks {
  const ProjectScriptsWorkbenchDialogViewCallbacks({
    required this.onReadContext,
    required this.onUsePreviewOrAll,
    required this.onReloadScripts,
    required this.onRunRecommendedAction,
    required this.onExportSelected,
    required this.onPollSelected,
    required this.onExtractSelected,
    required this.onBatchCreate,
    required this.onClose,
  });

  final VoidCallback? onReadContext;
  final VoidCallback? onUsePreviewOrAll;
  final VoidCallback? onReloadScripts;
  final VoidCallback? onRunRecommendedAction;
  final VoidCallback? onExportSelected;
  final VoidCallback? onPollSelected;
  final VoidCallback? onExtractSelected;
  final VoidCallback? onBatchCreate;
  final VoidCallback? onClose;
}

class ProjectScriptsWorkbenchDialogView extends StatelessWidget {
  const ProjectScriptsWorkbenchDialogView({
    super.key,
    required this.model,
    required this.callbacks,
  });

  final ProjectScriptsWorkbenchDialogViewModel model;
  final ProjectScriptsWorkbenchDialogViewCallbacks callbacks;

  @override
  Widget build(BuildContext context) {
    final l10n = resolveAppLocalizationsForErrors(context);
    return AlertDialog(
      title: Text(l10n.projectEditorScriptsWorkbenchDialogTitle),
      content: SizedBox(
        width: 820,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                model.infoLine,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: model.filterCtrl,
                decoration: InputDecoration(
                  labelText: l10n.projectEditorScriptsWorkbenchDialogNameFilterLabel,
                  helperText:
                      l10n.projectEditorScriptsWorkbenchDialogNameFilterHelper,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton.tonal(
                    onPressed: model.localBusy ? null : callbacks.onReadContext,
                    child: Text(
                      l10n.projectEditorScriptsWorkbenchDialogReadScriptContext,
                    ),
                  ),
                  OutlinedButton(
                    onPressed: model.localBusy
                        ? null
                        : callbacks.onUsePreviewOrAll,
                    child: Text(
                      model.previewRows.isNotEmpty
                          ? l10n.projectEditorScriptsWorkbenchDialogUseCurrentPreview
                          : l10n.projectEditorScriptsWorkbenchDialogUseAllScripts,
                    ),
                  ),
                  OutlinedButton(
                    onPressed: model.localBusy
                        ? null
                        : callbacks.onReloadScripts,
                    child: Text(
                      l10n.projectEditorScriptsWorkbenchDialogReloadProjectScripts,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextField(
                controller: model.selectedIdsCtrl,
                minLines: 2,
                maxLines: 4,
                decoration: InputDecoration(
                  labelText: l10n.projectEditorScriptsWorkbenchDialogTargetScriptIdsLabel,
                  helperText:
                      l10n.projectEditorScriptsWorkbenchDialogTargetScriptIdsHelper,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(
                    context,
                  ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.45),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      model.diagnosis.summary,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      model.diagnosis.detail,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.outline,
                      ),
                    ),
                    const SizedBox(height: 8),
                    FilledButton.tonal(
                      key: const Key(
                        'project-scripts-workbench-recommended-action',
                      ),
                      onPressed: model.localBusy
                          ? null
                          : callbacks.onRunRecommendedAction,
                      child: Text(model.recommendedActionLabel),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: model.groupSizeCtrl,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText:
                      l10n.projectEditorScriptsWorkbenchDialogExtractGroupSizeLabel,
                  helperText:
                      l10n.projectEditorScriptsWorkbenchDialogExtractGroupSizeHelper,
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton(
                    onPressed: model.localBusy
                        ? null
                        : callbacks.onExportSelected,
                    child: Text(l10n.projectEditorScriptsWorkbenchRecommendExportSelected),
                  ),
                  OutlinedButton(
                    onPressed: model.localBusy
                        ? null
                        : callbacks.onPollSelected,
                    child: Text(l10n.projectEditorScriptsWorkbenchRecommendPollSelected),
                  ),
                  OutlinedButton(
                    onPressed: model.localBusy
                        ? null
                        : callbacks.onExtractSelected,
                    child: Text(l10n.projectEditorScriptsWorkbenchRecommendExtractSelected),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                l10n.projectEditorScriptsBatchAddTitle,
                style: Theme.of(context).textTheme.labelLarge,
              ),
              const SizedBox(height: 8),
              TextField(
                controller: model.addCountCtrl,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: l10n.projectEditorScriptsBatchAddCountLabel,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: model.addPrefixCtrl,
                decoration: InputDecoration(
                  labelText: l10n.projectEditorScriptsBatchAddNamePrefixLabel,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: model.addBodyCtrl,
                minLines: 3,
                maxLines: 5,
                decoration: InputDecoration(
                  labelText: l10n.projectEditorScriptsBatchAddContentLabel,
                ),
              ),
              const SizedBox(height: 8),
              FilledButton.tonal(
                onPressed: model.localBusy ? null : callbacks.onBatchCreate,
                child: Text(l10n.projectEditorScriptsWorkbenchDialogBatchCreate),
              ),
              const SizedBox(height: 16),
              Text(
                l10n.projectEditorScriptsWorkbenchDialogContextPreviewHeading,
                style: Theme.of(context).textTheme.labelLarge,
              ),
              const SizedBox(height: 8),
              if (model.previewRows.isEmpty)
                Text(
                  model.scriptList.isEmpty
                      ? l10n.projectEditorScriptsWorkbenchDialogContextPreviewEmpty
                      : model.scriptList
                            .take(6)
                            .map(
                              (script) =>
                                  l10n.projectEditorScriptsWorkbenchDialogPreviewRowBrief(
                                    script.numericId,
                                    script.name ?? '',
                                    script.extractState ?? 0,
                                  ),
                            )
                            .join('\n'),
                  style: Theme.of(context).textTheme.bodySmall,
                )
              else
                ...model.previewRows
                    .take(6)
                    .map(
                      (row) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text(
                          l10n.projectEditorScriptsWorkbenchDialogPreviewRowWithAssets(
                            row.numericId,
                            row.name ?? '',
                            row.extractState ?? 0,
                            summarizeRelatedScriptAssets(l10n, row.relatedAssets),
                          ),
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                    ),
              if ((model.scriptTaskLine ?? '').trim().isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  model.scriptTaskLine!,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: model.localBusy ? null : callbacks.onClose,
          child: Text(l10n.projectEditorScriptsWorkbenchDialogClose),
        ),
      ],
    );
  }
}
