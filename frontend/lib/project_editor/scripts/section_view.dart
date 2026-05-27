import 'package:flutter/material.dart';

import '../../design_system/components/studio_empty_state.dart';
import '../../design_system/components/studio_surfaces.dart';
import '../../design_system/components/studio_filter_row.dart';
import '../../design_system/components/studio_workbench_section.dart';
import '../../design_system/components/studio_text_styles.dart';
import '../../design_system/tokens.dart';
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
  });

  final bool saving;
  final bool scriptTaskBusy;
  final String? scriptTaskLine;
  final List<ScriptBrief> scriptList;
  final ScriptBatchWorkbenchDiagnosis overviewDiagnosis;
  final String overviewActionLabel;
  final VoidCallback? overviewAction;
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
    this.onOpenStoryboardStep,
    this.onOpenScriptEditor,
  });

  final VoidCallback? onOpenWorkbench;
  final VoidCallback? onOpenPlanWorkbench;
  final VoidCallback? onOpenBatchAddDialog;
  final VoidCallback? onExportAll;
  final VoidCallback? onPollAll;
  final VoidCallback? onExtractAll;
  final VoidCallback? onCreateEmptyScript;
  final void Function(ScriptBrief script)? onOpenStoryboardStep;
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          l10n.projectEditorScriptsSectionCountLine(model.scriptList.length),
          style: theme.textTheme.labelLarge,
        ),
        const SizedBox(height: StudioSpacing.xs),
        Text(
          l10n.projectEditorScriptsSectionIntroBody,
          style: studioHintStyle(context),
        ),
        const SizedBox(height: StudioSpacing.xs),
        StudioWorkbenchSection(
          title: l10n.projectEditorScriptsSectionBatchWorkbenchTitle,
          subtitle: l10n.projectEditorScriptsSectionBatchWorkbenchDescription,
          child: StudioFilterRow(
            wideLayout: StudioFilterWideLayout.toolbarRow,
            wideBreakpoint: 480,
            children: <Widget>[
              FilledButton.tonal(
                style: studioFormTonalButtonStyle(context),
                onPressed: model.saving || model.scriptTaskBusy
                    ? null
                    : callbacks.onOpenWorkbench,
                child: Text(l10n.projectEditorScriptsSectionOpenBatchWorkbench),
              ),
              OutlinedButton(
                style: studioFormSecondaryButtonStyle(context),
                onPressed: model.saving || model.scriptTaskBusy
                    ? null
                    : callbacks.onOpenPlanWorkbench,
                child: Text(l10n.projectEditorScriptsSectionOpenPlanWorkbench),
              ),
            ],
          ),
        ),
        const SizedBox(height: StudioSpacing.xs),
        StudioWorkbenchSection(
          title: l10n.projectEditorScriptsSectionSuggestionsTitle,
          subtitle: model.overviewDiagnosis.summary,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                model.overviewDiagnosis.detail,
                style: studioHintStyle(context),
              ),
              const SizedBox(height: StudioSpacing.xs),
              FilledButton.tonal(
                style: studioFormTonalButtonStyle(context),
                onPressed: model.overviewAction,
                child: Text(model.overviewActionLabel),
              ),
            ],
          ),
        ),
        const SizedBox(height: StudioSpacing.xs),
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
          const SizedBox(height: StudioSpacing.xs),
          Text(
            model.scriptTaskLine!,
            style: studioHintStyle(context),
          ),
        ],
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton(
            onPressed: model.saving ? null : callbacks.onCreateEmptyScript,
            child: Text(l10n.projectEditorScriptsSectionCreateEmpty),
          ),
        ),
        if (model.scriptList.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: StudioSpacing.sm),
            child: StudioEmptyState.emptyData(
              title: l10n.projectEditorScriptsSectionCountLine(0),
              subtitle: l10n.projectEditorScriptsSectionIntroBody,
              icon: Icons.description_outlined,
              actionLabel: l10n.projectEditorScriptsSectionCreateEmpty,
              onAction: model.saving ? null : callbacks.onCreateEmptyScript,
            ),
          )
        else
          ...model.scriptList.map(
            (script) {
              final openStoryboard = callbacks.onOpenStoryboardStep;
              final openEditor = callbacks.onOpenScriptEditor;
              final onTap = model.saving
                  ? null
                  : openStoryboard != null
                  ? () => openStoryboard(script)
                  : openEditor != null
                  ? () => openEditor(script)
                  : null;
              return ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text(
                  '#${script.numericId} ${script.name ?? ""}',
                  style: theme.textTheme.bodySmall,
                ),
                trailing: openStoryboard != null && openEditor != null
                    ? IconButton(
                        tooltip: l10n.projectEditorScriptsSectionEditScript,
                        icon: const Icon(Icons.edit_outlined, size: 18),
                        onPressed: model.saving
                            ? null
                            : () => openEditor(script),
                      )
                    : const Icon(Icons.chevron_right, size: 18),
                onTap: onTap,
              );
            },
          ),
      ],
    );
  }
}
