import 'package:flutter/material.dart';

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
    final theme = Theme.of(context);
    final planData = model.planData;
    return AlertDialog(
      title: const Text('Story skeleton & adaptation strategy'),
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
                  'planId ${planData.planId ?? 'new'} · ${planData.scriptRows.length} script row(s) mounted'
                  '${planData.scriptRows.isEmpty ? '' : ' · ${planData.scriptRows.take(3).map((row) => row.name ?? '#${row.id ?? 0}').join(' / ')}'}',
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
                    child: const Text('Fill skeleton draft from events'),
                  ),
                  OutlinedButton(
                    onPressed: model.localBusy
                        ? null
                        : callbacks.onFillAdaptationStrategySeed,
                    child: const Text('Fill strategy draft from events'),
                  ),
                  FilledButton.tonal(
                    onPressed: model.localBusy
                        ? null
                        : callbacks.onGenerateDraftPackets,
                    child: const Text('Generate script draft packets'),
                  ),
                  FilledButton.tonal(
                    onPressed: model.localBusy
                        ? null
                        : callbacks.onGenerateGuidance,
                    child: const Text('Generate structured rewrite guidance'),
                  ),
                  OutlinedButton(
                    onPressed: model.localBusy || model.draftPackets.isEmpty
                        ? null
                        : callbacks.onWriteDraftPackets,
                    child: const Text('Write script drafts'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: model.storySkeletonCtrl,
                minLines: 6,
                maxLines: 10,
                decoration: const InputDecoration(
                  labelText: 'Story Skeleton',
                  helperText:
                      'Focus on story spine, main conflict, turning points, and resolution path',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: model.adaptationStrategyCtrl,
                minLines: 6,
                maxLines: 10,
                decoration: const InputDecoration(
                  labelText: 'Adaptation Strategy',
                  helperText:
                      'Capture adaptation trade-offs, character arcs, pacing, and style constraints',
                ),
              ),
              const SizedBox(height: 16),
              Text('Script draft preview', style: theme.textTheme.titleSmall),
              const SizedBox(height: 8),
              if (model.draftPackets.isEmpty)
                Text(
                  'No draft packets yet. Refine skeleton/strategy first, then generate.',
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
                                'Chapters ${draft.chapterIndexes.isEmpty ? 'TBD' : draft.chapterIndexes.join(', ')}'
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
                'Structured rewrite guidance',
                style: theme.textTheme.titleSmall,
              ),
              const SizedBox(height: 8),
              if (model.guidanceRows.isEmpty)
                Text(
                  'No structured guidance yet. Run before and after drafts to constrain revisions.',
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
                                'Chapters ${guidance.chapterIndexes.isEmpty ? 'TBD' : guidance.chapterIndexes.join(', ')}'
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
          child: Text(model.localBusy ? 'Refreshing…' : 'Reload plan'),
        ),
        FilledButton(
          onPressed: model.localBusy ? null : callbacks.onSave,
          child: Text(model.localBusy ? 'Saving…' : 'Save plan'),
        ),
        TextButton(onPressed: callbacks.onClose, child: const Text('Close')),
      ],
    );
  }
}
