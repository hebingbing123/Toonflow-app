import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../config.dart';
import '../design_system/components/studio_pane_header.dart';
import '../design_system/components/studio_text_styles.dart';
import '../local_prefs/risky_operation_confirm_prefs.dart';
import 'workbench_view.dart';
import 'previews.dart';
import '../rust_api.dart';
import 'support.dart';

part 'section_workbench.dart';
part 'section_workbench_controllers.dart';

class TaskCenterSection extends StatelessWidget {
  const TaskCenterSection({
    super.key,
    required this.accessToken,
    required this.initialProjectNumericId,
    required this.initialProjectUuid,
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
    this.studioPresentation = false,
  });

  final String? accessToken;
  final int? initialProjectNumericId;
  final String? initialProjectUuid;
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
  final bool studioPresentation;

  Future<void> _openTaskWorkbench(BuildContext context) async {
    final l10n = resolveAppLocalizationsForErrors(context);
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
        initialProjectUuid: initialProjectUuid,
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
    final l10n = resolveAppLocalizationsForErrors(context);
    final muted = studioMutedTextColor(context);
    final width = MediaQuery.sizeOf(context).width;
    final useWideSplitLayout = studioPresentation && width >= 1500;
    final projectSummary = taskProjects == null
        ? l10n.taskCenterProjectsNotLoaded
        : summarizeTaskProjects(l10n, taskProjects!);
    final taskSummary = taskApiJobs == null
        ? (taskApiSummaryLine ?? l10n.taskCenterTaskListNotLoaded)
        : summarizeTaskJobs(l10n, taskApiJobs!);
    final summaryPreview = TaskCenterSummaryPreview(
      mutedColor: muted,
      projectSummary: projectSummary,
      taskSummary: taskSummary,
      taskCategoriesLine: taskCategoriesLine,
    );
    final compatibilityPanel = TaskCenterCompatibilityPanel(
      mutedColor: muted,
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
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        StudioPaneHeader(
          title: l10n.productNavTasks,
          subtitle: l10n.taskCenterSectionIntro,
          showBack: studioPresentation,
          trailing: RiskyOperationConfirmPrefsOverflowMenu(
            tooltip: l10n.taskCenterLocalClientPrefs,
          ),
        ),
        const SizedBox(height: 12),
        if (useWideSplitLayout)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                flex: 7,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    TaskCenterActionsBar(
                      loadingTaskApi: loadingTaskApi,
                      onOpenWorkbench: () => _openTaskWorkbench(context),
                      onLoadTaskApi: onLoadTaskApi,
                    ),
                    const SizedBox(height: 14),
                    summaryPreview,
                    if (!studioPresentation) ...<Widget>[
                      const SizedBox(height: 12),
                      TaskCenterDetailsPreview(
                        taskDetailNumericIdLine: taskDetailNumericIdLine,
                        taskDetailUuidLine: taskDetailUuidLine,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 28),
              Expanded(flex: 5, child: compatibilityPanel),
            ],
          )
        else ...<Widget>[
          TaskCenterActionsBar(
            loadingTaskApi: loadingTaskApi,
            onOpenWorkbench: () => _openTaskWorkbench(context),
            onLoadTaskApi: onLoadTaskApi,
          ),
          const SizedBox(height: 8),
          summaryPreview,
          const SizedBox(height: 8),
          compatibilityPanel,
        ],
        if (!studioPresentation)
          TaskCenterDetailsPreview(
            taskDetailNumericIdLine: taskDetailNumericIdLine,
            taskDetailUuidLine: taskDetailUuidLine,
          ),
        if (taskApiJobs != null) ...[
          const SizedBox(height: 12),
          TaskCenterJobsPreview(
            jobs: taskApiJobs!,
            onSelectTaskJob: onSelectTaskJob,
          ),
        ],
      ],
    );
  }
}
