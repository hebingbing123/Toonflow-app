import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../config.dart';
import '../l10n/app_localizations.dart';
import '../local_prefs/risky_operation_confirm_prefs.dart';
import 'workbench_view.dart';
import 'previews.dart';
import '../../rust_api.dart';
import 'support.dart';

part 'section_workbench.dart';
part 'section_workbench_controllers.dart';

class TaskCenterSection extends StatelessWidget {
  const TaskCenterSection({
    super.key,
    required this.accessToken,
    required this.initialProjectNumericId,
    required this.loadingTaskProjects,
    required this.loadingTaskCategories,
    required this.loadingTaskApi,
    required this.loadingTaskDetailsByNumericId,
    required this.loadingTaskDetailsUuid,
    required this.taskDetailJobIdController,
    required this.taskProjects,
    required this.taskCategoriesLine,
    required this.taskApiSummaryLine,
    required this.taskDetailNumericIdLine,
    required this.taskDetailUuidLine,
    required this.taskApiJobs,
    required this.onTaskDetailJobIdChanged,
    required this.onLoadTaskProjects,
    required this.onLoadTaskCategories,
    required this.onLoadTaskApi,
    required this.onProbeTaskDetailByNumericId,
    required this.onProbeTaskDetailUuid,
    required this.onSelectTaskJob,
    this.onNavigateExportJobDeepLink,
    this.onNavigateDomainDeepLink,
  });

  final String? accessToken;
  final int? initialProjectNumericId;
  final bool loadingTaskProjects;
  final bool loadingTaskCategories;
  final bool loadingTaskApi;
  final bool loadingTaskDetailsByNumericId;
  final bool loadingTaskDetailsUuid;
  final TextEditingController taskDetailJobIdController;
  final List<TaskCenterProjectItem>? taskProjects;
  final String? taskCategoriesLine;
  final String? taskApiSummaryLine;
  final String? taskDetailNumericIdLine;
  final String? taskDetailUuidLine;
  final List<JobRow>? taskApiJobs;
  final ValueChanged<String> onTaskDetailJobIdChanged;
  final VoidCallback onLoadTaskProjects;
  final VoidCallback onLoadTaskCategories;
  final VoidCallback onLoadTaskApi;
  final VoidCallback onProbeTaskDetailByNumericId;
  final VoidCallback onProbeTaskDetailUuid;
  final ValueChanged<JobRow> onSelectTaskJob;
  final void Function(TaskCenterExportJobDeepLink link)?
      onNavigateExportJobDeepLink;
  final void Function(TaskCenterDomainDeepLink link)? onNavigateDomainDeepLink;

  Future<void> _openTaskWorkbench(BuildContext context) async {
    final l10n = AppLocalizations.of(context)!;
    final token = accessToken;
    if (token == null || token.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.taskCenterErrNotLoggedIn)));
      return;
    }
    await showDialog<void>(
      context: context,
      builder: (dialogCtx) => _TaskCenterWorkbenchDialog(
        accessToken: token,
        initialProjectNumericId: initialProjectNumericId,
        initialProjects: taskProjects ?? const <TaskCenterProjectItem>[],
        initialTaskSummary: taskApiSummaryLine,
        initialCategoriesSummary: taskCategoriesLine,
        initialNumericIdTaskDetail: taskDetailNumericIdLine,
        initialUuidDetails: taskDetailUuidLine,
        initialJobs: taskApiJobs ?? const <JobRow>[],
        onNavigateExportJobDeepLink: onNavigateExportJobDeepLink,
        onNavigateDomainDeepLink: onNavigateDomainDeepLink,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final outline = Theme.of(context).colorScheme.outline;
    final projectSummary = taskProjects == null
        ? l10n.taskCenterProjectsNotLoaded
        : summarizeTaskProjects(l10n, taskProjects!);
    final taskSummary = taskApiJobs == null
        ? (taskApiSummaryLine ?? l10n.taskCenterTaskListNotLoaded)
        : summarizeTaskJobs(l10n, taskApiJobs!);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                l10n.productNavTasks,
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ),
            RiskyOperationConfirmPrefsOverflowMenu(
              tooltip: l10n.taskCenterLocalClientPrefs,
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          l10n.taskCenterSectionIntro,
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: outline),
        ),
        const SizedBox(height: 8),
        TaskCenterActionsBar(
          loadingTaskApi: loadingTaskApi,
          onOpenWorkbench: () => _openTaskWorkbench(context),
          onLoadTaskApi: onLoadTaskApi,
        ),
        const SizedBox(height: 8),
        TaskCenterSummaryPreview(
          outlineColor: outline,
          projectSummary: projectSummary,
          taskSummary: taskSummary,
          taskCategoriesLine: taskCategoriesLine,
        ),
        const SizedBox(height: 8),
        TaskCenterCompatibilityPanel(
          outlineColor: outline,
          loadingTaskProjects: loadingTaskProjects,
          loadingTaskCategories: loadingTaskCategories,
          loadingTaskApi: loadingTaskApi,
          loadingTaskDetailsByNumericId: loadingTaskDetailsByNumericId,
          loadingTaskDetailsUuid: loadingTaskDetailsUuid,
          taskDetailJobIdController: taskDetailJobIdController,
          onTaskDetailJobIdChanged: onTaskDetailJobIdChanged,
          onLoadTaskProjects: onLoadTaskProjects,
          onLoadTaskCategories: onLoadTaskCategories,
          onLoadTaskApi: onLoadTaskApi,
          onProbeTaskDetailByNumericId: onProbeTaskDetailByNumericId,
          onProbeTaskDetailUuid: onProbeTaskDetailUuid,
        ),
        TaskCenterDetailsPreview(
          taskDetailNumericIdLine: taskDetailNumericIdLine,
          taskDetailUuidLine: taskDetailUuidLine,
        ),
        if (taskApiJobs != null) ...[
          TaskCenterJobsPreview(
            jobs: taskApiJobs!,
            onSelectTaskJob: onSelectTaskJob,
          ),
        ],
      ],
    );
  }
}
