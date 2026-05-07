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
      title: const Text('骨架与改编策略'),
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
                  'planId ${planData.planId ?? 'new'} · 已挂载 ${planData.scriptRows.length} 条剧本'
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
                    child: const Text('用事件填充骨架草稿'),
                  ),
                  OutlinedButton(
                    onPressed: model.localBusy
                        ? null
                        : callbacks.onFillAdaptationStrategySeed,
                    child: const Text('用事件填充策略草稿'),
                  ),
                  FilledButton.tonal(
                    onPressed: model.localBusy
                        ? null
                        : callbacks.onGenerateDraftPackets,
                    child: const Text('生成剧本初稿包'),
                  ),
                  FilledButton.tonal(
                    onPressed: model.localBusy
                        ? null
                        : callbacks.onGenerateGuidance,
                    child: const Text('生成结构化改写 guidance'),
                  ),
                  OutlinedButton(
                    onPressed: model.localBusy || model.draftPackets.isEmpty
                        ? null
                        : callbacks.onWriteDraftPackets,
                    child: const Text('写入剧本初稿'),
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
                  helperText: '聚焦故事骨架、主冲突、关键转折和收束路径',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: model.adaptationStrategyCtrl,
                minLines: 6,
                maxLines: 10,
                decoration: const InputDecoration(
                  labelText: 'Adaptation Strategy',
                  helperText: '记录改编取舍、人物弧光、节奏策略和风格约束',
                ),
              ),
              const SizedBox(height: 16),
              Text('剧本初稿预览', style: theme.textTheme.titleSmall),
              const SizedBox(height: 8),
              if (model.draftPackets.isEmpty)
                Text(
                  '还没有生成初稿包，建议先整理骨架/策略后再生成。',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                )
              else
                ...model.draftPackets.take(4).map(
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
                          Text(draft.name, style: theme.textTheme.titleSmall),
                          const SizedBox(height: 4),
                          Text(
                            '章节 ${draft.chapterIndexes.isEmpty ? '待补' : draft.chapterIndexes.join(', ')}'
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
              Text('结构化改写 Guidance', style: theme.textTheme.titleSmall),
              const SizedBox(height: 8),
              if (model.guidanceRows.isEmpty)
                Text(
                  '还没有生成结构化改写 guidance，建议在剧本初稿前后都跑一次，用来约束后续改稿。',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                )
              else
                ...model.guidanceRows.take(4).map(
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
                            '章节 ${guidance.chapterIndexes.isEmpty ? '待补' : guidance.chapterIndexes.join(', ')}'
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
          child: Text(model.localBusy ? '刷新中…' : '刷新计划'),
        ),
        FilledButton(
          onPressed: model.localBusy ? null : callbacks.onSave,
          child: Text(model.localBusy ? '保存中…' : '保存计划'),
        ),
        TextButton(onPressed: callbacks.onClose, child: const Text('关闭')),
      ],
    );
  }
}
