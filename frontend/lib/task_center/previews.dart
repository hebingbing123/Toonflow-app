import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
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
    final l10n = AppLocalizations.of(context)!;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        FilledButton.tonal(
          onPressed: onOpenWorkbench,
          child: Text(l10n.taskCenterOpenWorkbench),
        ),
        FilledButton.tonal(
          onPressed: loadingTaskApi ? null : onLoadTaskApi,
          child: Text(
            loadingTaskApi
                ? l10n.projectsBusyProcessing
                : l10n.taskCenterRefreshSummary,
          ),
        ),
      ],
    );
  }
}

/// Encapsulates numeric-id task probes so the main task center keeps only domain flow.
class TaskCenterCompatibilityPanel extends StatelessWidget {
  const TaskCenterCompatibilityPanel({
    super.key,
    required this.outlineColor,
    required this.loadingTaskProjects,
    required this.loadingTaskCategories,
    required this.loadingTaskApi,
    required this.loadingTaskDetailsByNumericId,
    required this.loadingTaskDetailsUuid,
    required this.taskDetailJobIdController,
    required this.onTaskDetailJobIdChanged,
    required this.onLoadTaskProjects,
    required this.onLoadTaskCategories,
    required this.onLoadTaskApi,
    required this.onProbeTaskDetailByNumericId,
    required this.onProbeTaskDetailUuid,
  });

  final Color outlineColor;
  final bool loadingTaskProjects;
  final bool loadingTaskCategories;
  final bool loadingTaskApi;
  final bool loadingTaskDetailsByNumericId;
  final bool loadingTaskDetailsUuid;
  final TextEditingController taskDetailJobIdController;
  final ValueChanged<String> onTaskDetailJobIdChanged;
  final VoidCallback onLoadTaskProjects;
  final VoidCallback onLoadTaskCategories;
  final VoidCallback onLoadTaskApi;
  final VoidCallback onProbeTaskDetailByNumericId;
  final VoidCallback onProbeTaskDetailUuid;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return ExpansionTile(
      tilePadding: EdgeInsets.zero,
      childrenPadding: EdgeInsets.zero,
      title: Text(l10n.taskCenterCompatibilityCheck),
      subtitle: Text(
        l10n.taskCenterCompatibilityHint,
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
              child: Text(
                loadingTaskProjects
                    ? l10n.projectsBusyProcessing
                    : l10n.taskCenterLoadTaskProjects,
              ),
            ),
            FilledButton.tonal(
              onPressed: loadingTaskCategories ? null : onLoadTaskCategories,
              child: Text(
                loadingTaskCategories
                    ? l10n.projectsBusyProcessing
                    : l10n.taskCenterLoadTaskCategories,
              ),
            ),
            FilledButton.tonal(
              onPressed: loadingTaskApi ? null : onLoadTaskApi,
              child: Text(
                loadingTaskApi
                    ? l10n.projectsBusyProcessing
                    : l10n.taskCenterLoadTaskList,
              ),
            ),
            FilledButton.tonal(
              onPressed: loadingTaskDetailsByNumericId ? null : onProbeTaskDetailByNumericId,
              child: Text(
                loadingTaskDetailsByNumericId
                    ? l10n.projectsBusyProcessing
                    : l10n.taskCenterViewFirstTaskDetails,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        TextField(
          controller: taskDetailJobIdController,
          onChanged: onTaskDetailJobIdChanged,
          decoration: InputDecoration(
            labelText: l10n.taskCenterFieldTaskUuidTapToFill,
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
            loadingTaskDetailsUuid
                ? l10n.projectsBusyProcessing
                : l10n.taskCenterViewByUuid,
          ),
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
    final l10n = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        Text(
          l10n.taskCenterJobsCount(jobs.length),
          style: Theme.of(context).textTheme.labelLarge,
        ),
        ...jobs.take(8).map(
          (job) => ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            title: Text(l10n.l10nBatch_c084376ea9(job.kind, job.status)),
            subtitle: Text(l10n.l10nBatch_978d9d9f6f(job.numericTaskId, job.id)),
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
    final l10n = AppLocalizations.of(context)!;
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
          Text(l10n.taskCenterCategoriesLine(taskCategoriesLine!), style: bodySmall),
        ],
      ],
    );
  }
}

/// Displays the latest numeric-id and UUID detail snapshots returned by task probes.
class TaskCenterDetailsPreview extends StatelessWidget {
  const TaskCenterDetailsPreview({
    super.key,
    this.taskDetailNumericIdLine,
    this.taskDetailUuidLine,
  });

  final String? taskDetailNumericIdLine;
  final String? taskDetailUuidLine;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (taskDetailNumericIdLine != null) ...[
          const SizedBox(height: 8),
          SelectableText(
            l10n.taskCenterNumericIdDetailsLine(taskDetailNumericIdLine!),
          ),
        ],
        if (taskDetailUuidLine != null) ...[
          const SizedBox(height: 8),
          SelectableText(l10n.taskCenterUuidDetailsLine(taskDetailUuidLine!)),
        ],
      ],
    );
  }
}
