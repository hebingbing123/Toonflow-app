import 'package:flutter/material.dart';

import '../design_system/components/studio_filter_row.dart';
import '../design_system/tokens.dart';
import '../rust_api.dart';
import 'support.dart';

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
    final l10n = resolveAppLocalizationsForErrors(context);
    return StudioFilterRow(
      wideBreakpoint: 560,
      children: [
        FilledButton.icon(
          onPressed: onOpenWorkbench,
          icon: const Icon(Icons.open_in_new, size: 16),
          label: Text(l10n.taskCenterOpenWorkbench),
        ),
        OutlinedButton.icon(
          onPressed: loadingTaskApi ? null : onLoadTaskApi,
          icon: const Icon(Icons.refresh, size: 16),
          label: Text(
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
    required this.mutedColor,
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

  final Color mutedColor;
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
    final l10n = resolveAppLocalizationsForErrors(context);
    return ExpansionTile(
      tilePadding: EdgeInsets.zero,
      childrenPadding: EdgeInsets.zero,
      title: Text(l10n.taskCenterCompatibilityCheck),
      subtitle: Text(
        l10n.taskCenterCompatibilityHint,
        style: Theme.of(
          context,
        ).textTheme.bodySmall?.copyWith(color: mutedColor),
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
              onPressed: loadingTaskDetailsByNumericId
                  ? null
                  : onProbeTaskDetailByNumericId,
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
    this.showCountHeader = true,
  });

  final List<JobRow> jobs;
  final ValueChanged<JobRow> onSelectTaskJob;
  final bool showCountHeader;

  @override
  Widget build(BuildContext context) {
    final l10n = resolveAppLocalizationsForErrors(context);
    final compact = MediaQuery.sizeOf(context).width < 520;
    final detailStyle = Theme.of(context).textTheme.bodySmall?.copyWith(
      color: StudioTokens.of(context).textSecondary,
      height: 1.35,
    );
    final grouped = groupJobsByPhase(jobs);
    final tiles = <Widget>[];
    var shown = 0;
    for (final phase in taskCenterPhaseDisplayOrder) {
      final phaseJobs = grouped[phase];
      if (phaseJobs == null || phaseJobs.isEmpty) {
        continue;
      }
      final phaseLabel = taskCenterShortVideoStageLabel(l10n, phaseJobs.first);
      tiles.add(
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(
            '$phaseLabel (${phaseJobs.length})',
            style: Theme.of(context).textTheme.labelLarge,
          ),
        ),
      );
      for (final job in phaseJobs) {
        if (shown >= 8) {
          break;
        }
        shown++;
        final title = phaseLabel.isEmpty
            ? l10n.l10nBatch_c084376ea9(job.kind, job.status)
            : '${job.kind} · ${job.status}';
        final detailLines = <String>[
          l10n.l10nBatch_978d9d9f6f(job.numericTaskId, job.id),
          if (job.claimedBy != null && job.claimedBy!.isNotEmpty)
            l10n.jobsClaimedBy(job.claimedBy!),
          if (job.errorMessage != null && job.errorMessage!.isNotEmpty)
            l10n.taskCenterFailureReason(job.errorMessage!),
        ];
        tiles.add(
          ListTile(
            dense: !compact,
            contentPadding: EdgeInsets.zero,
            minVerticalPadding: compact ? 10 : 6,
            title: Text(
              title,
              maxLines: compact ? 2 : 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (var i = 0; i < detailLines.length; i++) ...<Widget>[
                    if (i > 0) const SizedBox(height: 4),
                    Text(
                      detailLines[i],
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: detailStyle,
                    ),
                  ],
                ],
              ),
            ),
            trailing: compact ? null : const Icon(Icons.chevron_right),
            onTap: () => onSelectTaskJob(job),
          ),
        );
      }
      if (shown >= 8) {
        break;
      }
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showCountHeader) ...<Widget>[
          const SizedBox(height: 8),
          Text(
            l10n.taskCenterJobsCount(jobs.length),
            style: Theme.of(context).textTheme.labelLarge,
          ),
        ],
        ...tiles,
      ],
    );
  }
}

/// Shows the compact project/category/task summaries above the workbench entry.
class TaskCenterSummaryPreview extends StatelessWidget {
  const TaskCenterSummaryPreview({
    super.key,
    required this.mutedColor,
    required this.projectSummary,
    required this.taskSummary,
    this.taskCategoriesLine,
  });

  final Color mutedColor;
  final String projectSummary;
  final String taskSummary;
  final String? taskCategoriesLine;

  @override
  Widget build(BuildContext context) {
    final l10n = resolveAppLocalizationsForErrors(context);
    final bodySmall = Theme.of(
      context,
    ).textTheme.bodySmall?.copyWith(color: mutedColor);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(projectSummary, style: bodySmall),
        const SizedBox(height: 4),
        Text(taskSummary, style: bodySmall),
        if (taskCategoriesLine != null) ...[
          const SizedBox(height: 4),
          Text(
            l10n.taskCenterCategoriesLine(taskCategoriesLine!),
            style: bodySmall,
          ),
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
    final l10n = resolveAppLocalizationsForErrors(context);
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
