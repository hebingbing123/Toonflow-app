import 'package:flutter/material.dart';

import '../rust_api.dart';

class TaskCenterSection extends StatelessWidget {
  const TaskCenterSection({
    super.key,
    required this.loadingTaskProjects,
    required this.loadingTaskCategories,
    required this.loadingTaskApi,
    required this.loadingTaskDetailsLegacy,
    required this.loadingTaskDetailsUuid,
    required this.taskDetailJobIdController,
    required this.taskProjects,
    required this.taskCategoriesLine,
    required this.taskApiSummaryLine,
    required this.taskDetailLegacyLine,
    required this.taskDetailUuidLine,
    required this.taskApiJobs,
    required this.onTaskDetailJobIdChanged,
    required this.onLoadTaskProjects,
    required this.onLoadTaskCategories,
    required this.onLoadTaskApi,
    required this.onProbeTaskDetailLegacy,
    required this.onProbeTaskDetailUuid,
    required this.onSelectTaskJob,
  });

  final bool loadingTaskProjects;
  final bool loadingTaskCategories;
  final bool loadingTaskApi;
  final bool loadingTaskDetailsLegacy;
  final bool loadingTaskDetailsUuid;
  final TextEditingController taskDetailJobIdController;
  final List<LegacyTasksProjectItem>? taskProjects;
  final String? taskCategoriesLine;
  final String? taskApiSummaryLine;
  final String? taskDetailLegacyLine;
  final String? taskDetailUuidLine;
  final List<JobRow>? taskApiJobs;
  final ValueChanged<String> onTaskDetailJobIdChanged;
  final VoidCallback onLoadTaskProjects;
  final VoidCallback onLoadTaskCategories;
  final VoidCallback onLoadTaskApi;
  final VoidCallback onProbeTaskDetailLegacy;
  final VoidCallback onProbeTaskDetailUuid;
  final ValueChanged<JobRow> onSelectTaskJob;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        Text('任务中心', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        Text(
          '查看任务项目、分类和最近任务，并按 legacy id 或 UUID 打开单条详情。',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.outline,
          ),
        ),
        const SizedBox(height: 8),
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
              onPressed: loadingTaskDetailsLegacy
                  ? null
                  : onProbeTaskDetailLegacy,
              child: Text(loadingTaskDetailsLegacy ? '…' : '查看首条任务详情'),
            ),
          ],
        ),
        if (taskProjects != null) ...[
          const SizedBox(height: 8),
          SelectableText(
            taskProjects!.isEmpty
                ? '任务项目：空'
                : '任务项目：${taskProjects!.map((p) => '#${p.id} ${p.name}').join('; ')}',
          ),
        ],
        if (taskCategoriesLine != null) ...[
          const SizedBox(height: 8),
          SelectableText('任务分类：$taskCategoriesLine'),
        ],
        if (taskApiSummaryLine != null) ...[
          const SizedBox(height: 8),
          SelectableText('任务列表：$taskApiSummaryLine'),
        ],
        if (taskDetailLegacyLine != null) ...[
          const SizedBox(height: 8),
          SelectableText('首条任务详情：$taskDetailLegacyLine'),
        ],
        const SizedBox(height: 8),
        TextField(
          controller: taskDetailJobIdController,
          onChanged: onTaskDetailJobIdChanged,
          decoration: const InputDecoration(labelText: '任务 UUID（点下方列表可自动填入）'),
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
        if (taskDetailUuidLine != null) ...[
          const SizedBox(height: 8),
          SelectableText('UUID 详情：$taskDetailUuidLine'),
        ],
        if (taskApiJobs != null) ...[
          const SizedBox(height: 8),
          Text(
            '${taskApiJobs!.length} 条任务',
            style: Theme.of(context).textTheme.labelLarge,
          ),
          ...taskApiJobs!
              .take(8)
              .map(
                (job) => ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: Text('${job.kind} · ${job.status}'),
                  subtitle: Text('#${job.legacyTaskId} · ${job.id}'),
                  onTap: () => onSelectTaskJob(job),
                ),
              ),
        ],
      ],
    );
  }
}
