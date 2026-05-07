import 'package:flutter/material.dart';

import '../../rust_api.dart';

class ProjectScriptPlanWorkbenchViewModel {
  const ProjectScriptPlanWorkbenchViewModel({
    required this.localBusy,
    required this.infoLine,
    required this.storySkeletonCtrl,
    required this.adaptationStrategyCtrl,
    required this.planData,
    required this.eventSummaryLine,
  });

  final bool localBusy;
  final String infoLine;
  final TextEditingController storySkeletonCtrl;
  final TextEditingController adaptationStrategyCtrl;
  final ScriptAgentPlanData? planData;
  final String eventSummaryLine;
}

class ProjectScriptPlanWorkbenchViewCallbacks {
  const ProjectScriptPlanWorkbenchViewCallbacks({
    required this.onReload,
    required this.onSave,
    required this.onFillStorySkeletonSeed,
    required this.onFillAdaptationStrategySeed,
    required this.onClose,
  });

  final VoidCallback? onReload;
  final VoidCallback? onSave;
  final VoidCallback? onFillStorySkeletonSeed;
  final VoidCallback? onFillAdaptationStrategySeed;
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
