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
        Text(
          'Task Center (legacy parity)',
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FilledButton.tonal(
              onPressed: loadingTaskProjects ? null : onLoadTaskProjects,
              child: Text(
                loadingTaskProjects ? '…' : 'POST …/tasks/get-project',
              ),
            ),
            FilledButton.tonal(
              onPressed: loadingTaskCategories ? null : onLoadTaskCategories,
              child: Text(
                loadingTaskCategories
                    ? '…'
                    : 'POST …/tasks/get-task-categories',
              ),
            ),
            FilledButton.tonal(
              onPressed: loadingTaskApi ? null : onLoadTaskApi,
              child: Text(loadingTaskApi ? '…' : 'POST …/tasks/get-task-api'),
            ),
            FilledButton.tonal(
              onPressed: loadingTaskDetailsLegacy
                  ? null
                  : onProbeTaskDetailLegacy,
              child: Text(
                loadingTaskDetailsLegacy
                    ? '…'
                    : 'POST …/tasks/task-details (501)',
              ),
            ),
          ],
        ),
        if (taskProjects != null) ...[
          const SizedBox(height: 8),
          SelectableText(
            taskProjects!.isEmpty
                ? 'task projects: (empty)'
                : 'task projects: ${taskProjects!.map((p) => '#${p.id} ${p.name}').join('; ')}',
          ),
        ],
        if (taskCategoriesLine != null) ...[
          const SizedBox(height: 8),
          SelectableText('task categories: $taskCategoriesLine'),
        ],
        if (taskApiSummaryLine != null) ...[
          const SizedBox(height: 8),
          SelectableText('task api: $taskApiSummaryLine'),
        ],
        if (taskDetailLegacyLine != null) ...[
          const SizedBox(height: 8),
          SelectableText('task-details/int: $taskDetailLegacyLine'),
        ],
        const SizedBox(height: 8),
        TextField(
          controller: taskDetailJobIdController,
          onChanged: onTaskDetailJobIdChanged,
          decoration: const InputDecoration(
            labelText: 'Task/job UUID (tap a row below to paste)',
          ),
        ),
        const SizedBox(height: 8),
        FilledButton.tonal(
          onPressed:
              loadingTaskDetailsUuid ||
                  taskDetailJobIdController.text.trim().isEmpty
              ? null
              : onProbeTaskDetailUuid,
          child: Text(
            loadingTaskDetailsUuid ? '…' : 'POST …/tasks/task-details (UUID)',
          ),
        ),
        if (taskDetailUuidLine != null) ...[
          const SizedBox(height: 8),
          SelectableText('task-details/uuid: $taskDetailUuidLine'),
        ],
        if (taskApiJobs != null) ...[
          const SizedBox(height: 8),
          Text(
            '${taskApiJobs!.length} task row(s)',
            style: Theme.of(context).textTheme.labelLarge,
          ),
          ...taskApiJobs!
              .take(8)
              .map(
                (job) => ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: Text('${job.kind} · ${job.status}'),
                  subtitle: Text(job.id),
                  onTap: () => onSelectTaskJob(job),
                ),
              ),
        ],
      ],
    );
  }
}
