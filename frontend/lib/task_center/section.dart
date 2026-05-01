import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../config.dart';
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
  });

  final String? accessToken;
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

  Future<void> _openTaskWorkbench(BuildContext context) async {
    final token = accessToken;
    if (token == null || token.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('当前未登录，无法读取任务中心')));
      return;
    }
    await showDialog<void>(
      context: context,
      builder: (dialogCtx) => _TaskCenterWorkbenchDialog(
        accessToken: token,
        initialProjects: taskProjects ?? const <TaskCenterProjectItem>[],
        initialTaskSummary: taskApiSummaryLine,
        initialCategoriesSummary: taskCategoriesLine,
        initialNumericIdTaskDetail: taskDetailNumericIdLine,
        initialUuidDetails: taskDetailUuidLine,
        initialJobs: taskApiJobs ?? const <JobRow>[],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final outline = Theme.of(context).colorScheme.outline;
    final projectSummary = taskProjects == null
        ? '尚未加载任务项目'
        : summarizeTaskProjects(taskProjects!);
    final taskSummary = taskApiJobs == null
        ? (taskApiSummaryLine ?? '尚未加载任务列表')
        : summarizeTaskJobs(taskApiJobs!);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        Text('任务中心', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        Text(
          '用正式工作台完成任务项目、分类、筛选列表和详情查看，主区不再依赖首条/UUID probe 按钮。',
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
