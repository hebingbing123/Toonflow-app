import 'package:flutter/material.dart';

import '../../rust_api.dart';

/// Keeps the top-level task center actions together before drill-down content.
class TaskCenterActionsBar extends StatelessWidget {
  const TaskCenterActionsBar({
    super.key,
    required this.loadingTaskApi,
    required this.onOpenWorkbench,
    required this.onLoadTaskApi,
  });

  final bool loadingTaskApi;
  final VoidCallback onOpenWorkbench;
  final VoidCallback onLoadTaskApi;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        FilledButton.tonal(
          onPressed: onOpenWorkbench,
          child: const Text('打开任务工作台'),
        ),
        FilledButton.tonal(
          onPressed: loadingTaskApi ? null : onLoadTaskApi,
          child: Text(loadingTaskApi ? '…' : '刷新任务摘要'),
        ),
      ],
    );
  }
}

/// Encapsulates legacy task probes so the main task center keeps only domain flow.
class TaskCenterCompatibilityPanel extends StatelessWidget {
  const TaskCenterCompatibilityPanel({
    super.key,
    required this.outlineColor,
    required this.loadingTaskProjects,
    required this.loadingTaskCategories,
    required this.loadingTaskApi,
    required this.loadingTaskDetailsLegacy,
    required this.loadingTaskDetailsUuid,
    required this.taskDetailJobIdController,
    required this.onTaskDetailJobIdChanged,
    required this.onLoadTaskProjects,
    required this.onLoadTaskCategories,
    required this.onLoadTaskApi,
    required this.onProbeTaskDetailLegacy,
    required this.onProbeTaskDetailUuid,
  });

  final Color outlineColor;
  final bool loadingTaskProjects;
  final bool loadingTaskCategories;
  final bool loadingTaskApi;
  final bool loadingTaskDetailsLegacy;
  final bool loadingTaskDetailsUuid;
  final TextEditingController taskDetailJobIdController;
  final ValueChanged<String> onTaskDetailJobIdChanged;
  final VoidCallback onLoadTaskProjects;
  final VoidCallback onLoadTaskCategories;
  final VoidCallback onLoadTaskApi;
  final VoidCallback onProbeTaskDetailLegacy;
  final VoidCallback onProbeTaskDetailUuid;

  @override
  Widget build(BuildContext context) {
    return ExpansionTile(
      tilePadding: EdgeInsets.zero,
      childrenPadding: EdgeInsets.zero,
      title: const Text('兼容性检查'),
      subtitle: Text(
        '保留旧式加载/详情 probe 作为回归入口，默认折叠',
        style: Theme.of(
          context,
        ).textTheme.bodySmall?.copyWith(color: outlineColor),
      ),
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FilledButton.tonal(
              onPressed: loadingTaskProjects ? null : onLoadTaskProjects,
              child: Text(loadingTaskProjects ? '…' : '加载任务项目'),
            ),
            FilledButton.tonal(
              onPressed: loadingTaskCategories ? null : onLoadTaskCategories,
              child: Text(loadingTaskCategories ? '…' : '加载任务分类'),
            ),
            FilledButton.tonal(
              onPressed: loadingTaskApi ? null : onLoadTaskApi,
              child: Text(loadingTaskApi ? '…' : '加载任务列表'),
            ),
            FilledButton.tonal(
              onPressed: loadingTaskDetailsLegacy ? null : onProbeTaskDetailLegacy,
              child: Text(loadingTaskDetailsLegacy ? '…' : '查看首条任务详情'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        TextField(
          controller: taskDetailJobIdController,
          onChanged: onTaskDetailJobIdChanged,
          decoration: const InputDecoration(
            labelText: '任务 UUID（点下方列表可自动填入）',
          ),
        ),
        const SizedBox(height: 8),
        FilledButton.tonal(
          onPressed:
              loadingTaskDetailsUuid ||
                  taskDetailJobIdController.text.trim().isEmpty
              ? null
              : onProbeTaskDetailUuid,
          child: Text(loadingTaskDetailsUuid ? '…' : '按 UUID 查看详情'),
        ),
      ],
    );
  }
}

/// Renders the current task list snapshot without owning any fetch state.
class TaskCenterJobsPreview extends StatelessWidget {
  const TaskCenterJobsPreview({
    super.key,
    required this.jobs,
    required this.onSelectTaskJob,
  });

  final List<JobRow> jobs;
  final ValueChanged<JobRow> onSelectTaskJob;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        Text('${jobs.length} 条任务', style: Theme.of(context).textTheme.labelLarge),
        ...jobs.take(8).map(
          (job) => ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            title: Text('${job.kind} · ${job.status}'),
            subtitle: Text('#${job.legacyTaskId} · ${job.id}'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => onSelectTaskJob(job),
          ),
        ),
      ],
    );
  }
}

/// Shows the compact project/category/task summaries above the workbench entry.
class TaskCenterSummaryPreview extends StatelessWidget {
  const TaskCenterSummaryPreview({
    super.key,
    required this.outlineColor,
    required this.projectSummary,
    required this.taskSummary,
    this.taskCategoriesLine,
  });

  final Color outlineColor;
  final String projectSummary;
  final String taskSummary;
  final String? taskCategoriesLine;

  @override
  Widget build(BuildContext context) {
    final bodySmall = Theme.of(
      context,
    ).textTheme.bodySmall?.copyWith(color: outlineColor);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(projectSummary, style: bodySmall),
        const SizedBox(height: 4),
        Text(taskSummary, style: bodySmall),
        if (taskCategoriesLine != null) ...[
          const SizedBox(height: 4),
          Text('分类摘要：$taskCategoriesLine', style: bodySmall),
        ],
      ],
    );
  }
}
