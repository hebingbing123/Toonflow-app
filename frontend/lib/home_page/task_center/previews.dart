import 'package:flutter/material.dart';

import '../../rust_api.dart';

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
