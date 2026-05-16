import 'package:flutter/material.dart';

import '../../rust_api.dart';
import '../../script_editor/support.dart';

class ProjectScriptsSectionViewModel {
  const ProjectScriptsSectionViewModel({
    required this.saving,
    required this.scriptTaskBusy,
    required this.scriptTaskLine,
    required this.scriptList,
    required this.overviewDiagnosis,
    required this.overviewActionLabel,
    required this.overviewAction,
    required this.probeActions,
  });

  final bool saving;
  final bool scriptTaskBusy;
  final String? scriptTaskLine;
  final List<ScriptBrief> scriptList;
  final ScriptBatchWorkbenchDiagnosis overviewDiagnosis;
  final String overviewActionLabel;
  final VoidCallback? overviewAction;
  final List<Widget> probeActions;
}

class ProjectScriptsSectionViewCallbacks {
  const ProjectScriptsSectionViewCallbacks({
    required this.onOpenWorkbench,
    required this.onOpenPlanWorkbench,
    required this.onOpenBatchAddDialog,
    required this.onExportAll,
    required this.onPollAll,
    required this.onExtractAll,
    required this.onCreateEmptyScript,
    required this.onOpenScriptEditor,
  });

  final VoidCallback? onOpenWorkbench;
  final VoidCallback? onOpenPlanWorkbench;
  final VoidCallback? onOpenBatchAddDialog;
  final VoidCallback? onExportAll;
  final VoidCallback? onPollAll;
  final VoidCallback? onExtractAll;
  final VoidCallback? onCreateEmptyScript;
  final void Function(ScriptBrief script)? onOpenScriptEditor;
}

/// Project editor scripts section: batch workbench entry, suggestions card, and script list.
class ProjectScriptsSectionView extends StatelessWidget {
  const ProjectScriptsSectionView({
    super.key,
    required this.model,
    required this.callbacks,
  });

  final ProjectScriptsSectionViewModel model;
  final ProjectScriptsSectionViewCallbacks callbacks;

  @override
  Widget build(BuildContext context) {
    final l10n = resolveAppLocalizationsForErrors(context);
    final theme = Theme.of(context);
    final outline = theme.colorScheme.outline;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          l10n.projectEditorScriptsSectionCountLine(model.scriptList.length),
          style: theme.textTheme.labelLarge,
        ),
        const SizedBox(height: 4),
        Text(
          l10n.projectEditorScriptsSectionIntroBody,
          style: theme.textTheme.bodySmall?.copyWith(color: outline),
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            border: Border.all(color: theme.colorScheme.outlineVariant),
            borderRadius: BorderRadius.circular(12),
            color: theme.colorScheme.surfaceContainerHighest.withValues(
              alpha: 0.35,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.projectEditorScriptsSectionBatchWorkbenchTitle,
                style: theme.textTheme.titleSmall,
              ),
              const SizedBox(height: 4),
              Text(
                l10n.projectEditorScriptsSectionBatchWorkbenchDescription,
                style: theme.textTheme.bodySmall?.copyWith(color: outline),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton.tonal(
                    onPressed: model.saving || model.scriptTaskBusy
                        ? null
                        : callbacks.onOpenWorkbench,
                    child: Text(l10n.projectEditorScriptsSectionOpenBatchWorkbench),
                  ),
                  OutlinedButton(
                    onPressed: model.saving || model.scriptTaskBusy
                        ? null
                        : callbacks.onOpenPlanWorkbench,
                    child: Text(l10n.projectEditorScriptsSectionOpenPlanWorkbench),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            border: Border.all(color: theme.colorScheme.outlineVariant),
            borderRadius: BorderRadius.circular(12),
            color: theme.colorScheme.surfaceContainerHighest.withValues(
              alpha: 0.28,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.projectEditorScriptsSectionSuggestionsTitle,
                style: theme.textTheme.titleSmall,
              ),
              const SizedBox(height: 4),
              Text(
                model.overviewDiagnosis.summary,
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 4),
              Text(
                model.overviewDiagnosis.detail,
                style: theme.textTheme.bodySmall?.copyWith(color: outline),
              ),
              const SizedBox(height: 8),
              FilledButton.tonal(
                onPressed: model.overviewAction,
                child: Text(model.overviewActionLabel),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 4,
          runSpacing: 0,
          children: [
            TextButton(
              onPressed: model.saving ? null : callbacks.onOpenBatchAddDialog,
              child: Text(l10n.projectEditorScriptsSectionBatchAdd),
            ),
            TextButton(
              onPressed:
                  model.saving ||
                      model.scriptTaskBusy ||
                      model.scriptList.isEmpty
                  ? null
                  : callbacks.onExportAll,
              child: Text(
                model.scriptTaskBusy
                    ? l10n.projectsBusyProcessing
                    : l10n.projectEditorScriptsSectionExportAll,
              ),
            ),
            TextButton(
              onPressed:
                  model.saving ||
                      model.scriptTaskBusy ||
                      model.scriptList.isEmpty
                  ? null
                  : callbacks.onPollAll,
              child: Text(l10n.projectEditorScriptsSectionPollAllExtract),
            ),
            TextButton(
              onPressed:
                  model.saving ||
                      model.scriptTaskBusy ||
                      model.scriptList.isEmpty
                  ? null
                  : callbacks.onExtractAll,
              child: Text(l10n.projectEditorScriptsSectionExtractAllMaterials),
            ),
          ],
        ),
        if (model.scriptTaskLine != null) ...[
          const SizedBox(height: 4),
          Text(
            model.scriptTaskLine!,
            style: theme.textTheme.bodySmall?.copyWith(color: outline),
          ),
        ],
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton(
            onPressed: model.saving ? null : callbacks.onCreateEmptyScript,
            child: Text(l10n.projectEditorScriptsSectionCreateEmpty),
          ),
        ),
        ExpansionTile(
          tilePadding: EdgeInsets.zero,
          childrenPadding: EdgeInsets.zero,
          title: Text(l10n.projectEditorScriptsSectionCompatibilityTile),
          subtitle: Text(
            l10n.projectEditorScriptsSectionCompatibilitySubtitle,
            style: theme.textTheme.bodySmall?.copyWith(color: outline),
          ),
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: Wrap(
                spacing: 4,
                runSpacing: 0,
                children: model.probeActions,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ...model.scriptList.map(
          (script) => ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            title: Text(
              '#${script.numericId} ${script.name ?? ""}',
              style: theme.textTheme.bodySmall,
            ),
            trailing: const Icon(Icons.edit_outlined, size: 18),
            onTap: model.saving || callbacks.onOpenScriptEditor == null
                ? null
                : () => callbacks.onOpenScriptEditor!(script),
          ),
        ),
      ],
    );
  }
}
