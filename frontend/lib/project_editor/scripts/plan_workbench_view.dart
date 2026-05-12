import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../rust_api.dart';
import 'plan_workbench_support.dart';

class ProjectScriptPlanWorkbenchViewModel {
  const ProjectScriptPlanWorkbenchViewModel({
    required this.localBusy,
    required this.infoLine,
    required this.storySkeletonCtrl,
    required this.adaptationStrategyCtrl,
    required this.planData,
    required this.eventSummaryLine,
    required this.draftSummaryLine,
    required this.draftPackets,
    required this.guidanceSummaryLine,
    required this.guidanceRows,
  });

  final bool localBusy;
  final String infoLine;
  final TextEditingController storySkeletonCtrl;
  final TextEditingController adaptationStrategyCtrl;
  final ScriptAgentPlanData? planData;
  final String eventSummaryLine;
  final String draftSummaryLine;
  final List<ScriptDraftPacket> draftPackets;
  final String guidanceSummaryLine;
  final List<StructuredRewriteGuidance> guidanceRows;
}

class ProjectScriptPlanWorkbenchViewCallbacks {
  const ProjectScriptPlanWorkbenchViewCallbacks({
    required this.onReload,
    required this.onSave,
    required this.onFillStorySkeletonSeed,
    required this.onFillAdaptationStrategySeed,
    required this.onGenerateDraftPackets,
    required this.onWriteDraftPackets,
    required this.onGenerateGuidance,
    required this.onClose,
  });

  final VoidCallback? onReload;
  final VoidCallback? onSave;
  final VoidCallback? onFillStorySkeletonSeed;
  final VoidCallback? onFillAdaptationStrategySeed;
  final VoidCallback? onGenerateDraftPackets;
  final VoidCallback? onWriteDraftPackets;
  final VoidCallback? onGenerateGuidance;
  final VoidCallback? onClose;
}

class ProjectScriptPlanWorkbenchView extends StatelessWidget {
  const ProjectScriptPlanWorkbenchView({
    super.key,
    required this.model,
    required this.callbacks,
  });

  final ProjectScriptPlanWorkbenchViewModel model;
  final ProjectScriptPlanWorkbenchViewCallbacks callbacks;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final planData = model.planData;
    return AlertDialog(
      title: Text(l10n.projectScriptPlanWorkbenchTitle),
      content: SizedBox(
        width: 720,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(model.infoLine, style: theme.textTheme.bodySmall),
              const SizedBox(height: 8),
              if (planData != null)
                Text(
                  l10n.projectScriptPlanWorkbenchPlanMountedLine(
                    planData.planId?.toString() ?? 'new',
                    planData.scriptRows.length,
                    planData.scriptRows.isEmpty
                        ? ''
                        : ' · ${planData.scriptRows.take(3).map((row) => row.name ?? '#${row.id ?? 0}').join(' / ')}',
                  ),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              const SizedBox(height: 8),
              Text(
                model.eventSummaryLine,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                model.draftSummaryLine,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                model.guidanceSummaryLine,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton(
                    onPressed: model.localBusy
                        ? null
                        : callbacks.onFillStorySkeletonSeed,
                    child: Text(l10n.projectScriptPlanWorkbenchFillSkeletonFromEvents),
                  ),
                  OutlinedButton(
                    onPressed: model.localBusy
                        ? null
                        : callbacks.onFillAdaptationStrategySeed,
                    child: Text(l10n.projectScriptPlanWorkbenchFillStrategyFromEvents),
                  ),
                  FilledButton.tonal(
                    onPressed: model.localBusy
                        ? null
                        : callbacks.onGenerateDraftPackets,
                    child: Text(l10n.projectScriptPlanWorkbenchGenerateDraftPackets),
                  ),
                  FilledButton.tonal(
                    onPressed: model.localBusy
                        ? null
                        : callbacks.onGenerateGuidance,
                    child: Text(l10n.projectScriptPlanWorkbenchGenerateStructuredGuidance),
                  ),
                  OutlinedButton(
                    onPressed: model.localBusy || model.draftPackets.isEmpty
                        ? null
                        : callbacks.onWriteDraftPackets,
                    child: Text(l10n.projectScriptPlanWorkbenchWriteScriptDrafts),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: model.storySkeletonCtrl,
                minLines: 6,
                maxLines: 10,
                decoration: InputDecoration(
                  labelText: l10n.projectScriptPlanWorkbenchStorySkeletonLabel,
                  helperText: l10n.projectScriptPlanWorkbenchStorySkeletonHelper,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: model.adaptationStrategyCtrl,
                minLines: 6,
                maxLines: 10,
                decoration: InputDecoration(
                  labelText: l10n.projectScriptPlanWorkbenchAdaptationStrategyLabel,
                  helperText:
                      l10n.projectScriptPlanWorkbenchAdaptationStrategyHelper,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                l10n.projectScriptPlanWorkbenchScriptDraftPreviewTitle,
                style: theme.textTheme.titleSmall,
              ),
              const SizedBox(height: 8),
              if (model.draftPackets.isEmpty)
                Text(
                  l10n.projectScriptPlanWorkbenchNoDraftPacketsHint,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                )
              else
                ...model.draftPackets
                    .take(4)
                    .map(
                      (draft) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: theme.colorScheme.outlineVariant,
                            ),
                            borderRadius: BorderRadius.circular(12),
                            color: theme.colorScheme.surfaceContainerHighest
                                .withValues(alpha: 0.25),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                draft.name,
                                style: theme.textTheme.titleSmall,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${l10n.projectScriptPlanWorkbenchChaptersPrefix} ${draft.chapterIndexes.isEmpty ? l10n.projectScriptPlanWorkbenchTbd : draft.chapterIndexes.join(', ')}'
                                '${draft.eventNames.isEmpty ? '' : ' · ${draft.eventNames.take(3).join(' / ')}'}',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                              const SizedBox(height: 6),
                              SelectableText(
                                draft.content,
                                maxLines: 10,
                                style: theme.textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
              const SizedBox(height: 8),
              Text(
                l10n.projectScriptPlanWorkbenchStructuredGuidanceTitle,
                style: theme.textTheme.titleSmall,
              ),
              const SizedBox(height: 8),
              if (model.guidanceRows.isEmpty)
                Text(
                  l10n.projectScriptPlanWorkbenchNoGuidanceHint,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                )
              else
                ...model.guidanceRows
                    .take(4)
                    .map(
                      (guidance) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: theme.colorScheme.outlineVariant,
                            ),
                            borderRadius: BorderRadius.circular(12),
                            color: theme.colorScheme.surfaceContainerHighest
                                .withValues(alpha: 0.2),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                guidance.name,
                                style: theme.textTheme.titleSmall,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${l10n.projectScriptPlanWorkbenchChaptersPrefix} ${guidance.chapterIndexes.isEmpty ? l10n.projectScriptPlanWorkbenchTbd : guidance.chapterIndexes.join(', ')}'
                                '${guidance.eventNames.isEmpty ? '' : ' · ${guidance.eventNames.take(3).join(' / ')}'}',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                              const SizedBox(height: 6),
                              SelectableText(
                                guidance.content,
                                maxLines: 10,
                                style: theme.textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: model.localBusy ? null : callbacks.onReload,
          child: Text(
            model.localBusy
                ? l10n.projectScriptPlanWorkbenchRefreshing
                : l10n.projectScriptPlanWorkbenchReloadPlan,
          ),
        ),
        FilledButton(
          onPressed: model.localBusy ? null : callbacks.onSave,
          child: Text(
            model.localBusy
                ? l10n.projectScriptPlanWorkbenchSaving
                : l10n.projectScriptPlanWorkbenchSavePlan,
          ),
        ),
        TextButton(
          onPressed: callbacks.onClose,
          child: Text(l10n.projectEditorScriptsWorkbenchDialogClose),
        ),
      ],
    );
  }
}
