import 'package:flutter/material.dart';

import '../../rust_api.dart';

import 'support.dart';

class _PhaseFilterItem {
  const _PhaseFilterItem({required this.key, required this.label});
  final String key;
  final String label;
}

const List<_PhaseFilterItem> _shortVideoProductionPhaseFilterItems = [
  _PhaseFilterItem(key: 'prep', label: '素材准备'),
  _PhaseFilterItem(key: 'image', label: '出图'),
  _PhaseFilterItem(key: 'video', label: '出视频'),
  _PhaseFilterItem(key: 'export', label: '导出成片'),
  _PhaseFilterItem(key: 'quality', label: '质检'),
];

class TaskCenterWorkbenchDialogViewModel {
  const TaskCenterWorkbenchDialogViewModel({
    required this.projectSummary,
    required this.jobSummary,
    required this.pageCtrl,
    required this.limitCtrl,
    required this.stateCtrl,
    required this.taskClassCtrl,
    required this.projectIdCtrl,
    required this.numericTaskIdCtrl,
    required this.uuidCtrl,
    required this.productionPhaseCtrl,
    required this.categories,
    required this.jobs,
    required this.categoriesSummary,
    required this.numericIdTaskDetailText,
    required this.uuidDetails,
    required this.statusLine,
    required this.loadingProjects,
    required this.loadingCategories,
    required this.loadingTasks,
    required this.loadingNumericIdTaskDetail,
    required this.loadingUuidDetails,
    required this.retryingJobId,
    required this.cancellingJobId,
    required this.liveUpdatesConnected,
  });

  final String projectSummary;
  final String jobSummary;
  final TextEditingController pageCtrl;
  final TextEditingController limitCtrl;
  final TextEditingController stateCtrl;
  final TextEditingController taskClassCtrl;
  final TextEditingController projectIdCtrl;
  final TextEditingController numericTaskIdCtrl;
  final TextEditingController uuidCtrl;
  final TextEditingController productionPhaseCtrl;
  final List<TaskCenterTaskClassRow> categories;
  final List<JobRow> jobs;
  final String? categoriesSummary;
  final String? numericIdTaskDetailText;
  final String? uuidDetails;
  final String? statusLine;
  final bool loadingProjects;
  final bool loadingCategories;
  final bool loadingTasks;
  final bool loadingNumericIdTaskDetail;
  final bool loadingUuidDetails;
  final String? retryingJobId;
  final String? cancellingJobId;
  final bool liveUpdatesConnected;
}

class TaskCenterWorkbenchDialogViewCallbacks {
  const TaskCenterWorkbenchDialogViewCallbacks({
    required this.onLoadProjects,
    required this.onLoadCategories,
    required this.onLoadTasks,
    required this.onLoadNumericIdTaskDetail,
    required this.onLoadUuidDetails,
    required this.onPickCategory,
    required this.onPickJob,
    required this.onRetryFailedJob,
    required this.onCancelQueuedJob,
    this.onCompensateWritebackJob,
    required this.onClose,
    this.onNavigateExportJobDeepLink,
    this.onNavigateDomainDeepLink,
    required this.onPickProductionPhase,
  });

  final VoidCallback onLoadProjects;
  final VoidCallback onLoadCategories;
  final VoidCallback onLoadTasks;
  final VoidCallback onLoadNumericIdTaskDetail;
  final VoidCallback onLoadUuidDetails;
  final ValueChanged<String> onPickCategory;
  final ValueChanged<JobRow> onPickJob;
  final ValueChanged<JobRow> onRetryFailedJob;
  final ValueChanged<JobRow> onCancelQueuedJob;
  final ValueChanged<JobRow>? onCompensateWritebackJob;
  final ValueChanged<String> onPickProductionPhase;
  final VoidCallback onClose;
  final void Function(TaskCenterExportJobDeepLink link)? onNavigateExportJobDeepLink;
  final void Function(TaskCenterDomainDeepLink link)? onNavigateDomainDeepLink;
}

class TaskCenterWorkbenchDialogView extends StatelessWidget {
  const TaskCenterWorkbenchDialogView({
    super.key,
    required this.model,
    required this.callbacks,
  });

  final TaskCenterWorkbenchDialogViewModel model;
  final TaskCenterWorkbenchDialogViewCallbacks callbacks;

  @override
  Widget build(BuildContext context) {
    final outline = Theme.of(context).colorScheme.outline;
    final viewportWidth = MediaQuery.sizeOf(context).width;
    final dialogWidth = viewportWidth.isFinite
        ? viewportWidth.clamp(320.0, 760.0)
        : 760.0;
    return AlertDialog(
      title: const Text('任务工作台'),
      content: SizedBox(
        width: dialogWidth,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '在一个对话框内完成任务项目/分类读取、按项目或分类筛选列表，以及按 numeric task id 或 UUID 查看详情。'
                '${model.liveUpdatesConnected ? ' 当前已接入实时任务更新。' : ''}',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: outline),
              ),
              const SizedBox(height: 12),
              Text('筛选与列表', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton.tonal(
                    onPressed: model.loadingProjects
                        ? null
                        : callbacks.onLoadProjects,
                    child: Text(model.loadingProjects ? '…' : '刷新任务项目'),
                  ),
                  FilledButton.tonal(
                    onPressed: model.loadingCategories
                        ? null
                        : callbacks.onLoadCategories,
                    child: Text(model.loadingCategories ? '…' : '刷新任务分类'),
                  ),
                  FilledButton.tonal(
                    onPressed: model.loadingTasks
                        ? null
                        : callbacks.onLoadTasks,
                    child: Text(model.loadingTasks ? '…' : '按筛选加载任务'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                model.projectSummary,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: outline),
              ),
              if (model.categoriesSummary != null) ...[
                const SizedBox(height: 4),
                Text(
                  model.categoriesSummary!,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: outline),
                ),
              ],
              const SizedBox(height: 4),
              Text(
                model.jobSummary,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: outline),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: model.pageCtrl,
                      decoration: const InputDecoration(labelText: '页码'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: model.limitCtrl,
                      decoration: const InputDecoration(labelText: '每页数量'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: model.projectIdCtrl,
                      decoration: const InputDecoration(
                        labelText: '项目 numeric ID（可空）',
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: model.taskClassCtrl,
                      decoration: const InputDecoration(labelText: '任务分类（可空）'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              TextField(
                controller: model.stateCtrl,
                decoration: const InputDecoration(labelText: '任务状态（可空）'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: model.productionPhaseCtrl,
                decoration: const InputDecoration(
                  labelText: '短视频阶段（可空：prep/image/video/export/quality）',
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final item in _shortVideoProductionPhaseFilterItems)
                    FilterChip(
                      label: Text(item.label),
                      selected:
                          model.productionPhaseCtrl.text.trim() == item.key,
                      onSelected: (_) => callbacks.onPickProductionPhase(
                        model.productionPhaseCtrl.text.trim() == item.key
                            ? ''
                            : item.key,
                      ),
                    ),
                ],
              ),
              if (model.categories.isNotEmpty) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: model.categories
                      .take(6)
                      .map(
                        (row) => ActionChip(
                          label: Text(row.taskClass),
                          onPressed: () =>
                              callbacks.onPickCategory(row.taskClass),
                        ),
                      )
                      .toList(growable: false),
                ),
              ],
              if (model.jobs.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  '${model.jobs.length} 条任务',
                  style: Theme.of(context).textTheme.labelLarge,
                ),
                ...model.jobs
                    .take(8)
                    .map(
                      (job) => ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          '${job.kind} · ${job.status}'
                          '${taskCenterShortVideoStageLabel(job).isEmpty ? '' : ' · ${taskCenterShortVideoStageLabel(job)}'}',
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              [
                                '#${job.numericTaskId} · ${job.id}',
                                if (job.errorMessage != null &&
                                    job.errorMessage!.isNotEmpty)
                                  '失败原因=${job.errorMessage}',
                              ].join('\n'),
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                            if (job.kind == 'video.export' &&
                                job.status == 'failed')
                              _VideoExportFailedSubtitle(
                                job: job,
                                onNavigateExportJobDeepLink:
                                    callbacks.onNavigateExportJobDeepLink,
                                onNavigateDomainDeepLink:
                                    callbacks.onNavigateDomainDeepLink,
                              ),
                            if (job.status == 'failed')
                              _TaskFailedReworkActions(
                                job: job,
                                onRetry: callbacks.onRetryFailedJob,
                                onNavigateDomainDeepLink:
                                    callbacks.onNavigateDomainDeepLink,
                                onCompensateWritebackJob:
                                    callbacks.onCompensateWritebackJob,
                              ),
                          ],
                        ),
                        trailing:
                            (job.status == 'failed' ||
                                job.status == 'queued' ||
                                job.status == 'running')
                            ? Wrap(
                                spacing: 4,
                                children: [
                                  if (job.status == 'failed')
                                    TextButton(
                                      onPressed: model.retryingJobId == job.id
                                          ? null
                                          : () =>
                                                callbacks.onRetryFailedJob(job),
                                      child: Text(
                                        model.retryingJobId == job.id
                                            ? '…'
                                            : '重试',
                                      ),
                                    ),
                                  if (job.status == 'queued' ||
                                      job.status == 'running')
                                    TextButton(
                                      onPressed: model.cancellingJobId == job.id
                                          ? null
                                          : () => callbacks.onCancelQueuedJob(
                                              job,
                                            ),
                                      child: Text(
                                        model.cancellingJobId == job.id
                                            ? '…'
                                            : '取消',
                                      ),
                                    ),
                                ],
                              )
                            : const Icon(Icons.chevron_right),
                        onTap: () => callbacks.onPickJob(job),
                      ),
                    ),
              ],
              const SizedBox(height: 12),
              Text('任务详情', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: model.numericTaskIdCtrl,
                      decoration: const InputDecoration(
                        labelText: 'numeric task id',
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.tonal(
                    onPressed: model.loadingNumericIdTaskDetail
                        ? null
                        : callbacks.onLoadNumericIdTaskDetail,
                    child: Text(
                      model.loadingNumericIdTaskDetail
                          ? '…'
                          : '读取任务详情（numeric ID）',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: model.uuidCtrl,
                      decoration: const InputDecoration(labelText: '任务 UUID'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.tonal(
                    onPressed: model.loadingUuidDetails
                        ? null
                        : callbacks.onLoadUuidDetails,
                    child: Text(model.loadingUuidDetails ? '…' : '读取 UUID 详情'),
                  ),
                ],
              ),
              if (model.numericIdTaskDetailText != null) ...[
                const SizedBox(height: 8),
                SelectableText(
                  '任务详情（numeric ID）：${model.numericIdTaskDetailText}',
                ),
              ],
              if (model.uuidDetails != null) ...[
                const SizedBox(height: 8),
                SelectableText('UUID 详情：${model.uuidDetails}'),
              ],
              if (model.statusLine != null) ...[
                const SizedBox(height: 8),
                SelectableText('状态：${model.statusLine}'),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: callbacks.onClose, child: const Text('关闭')),
      ],
    );
  }
}

class _VideoExportFailedSubtitle extends StatelessWidget {
  const _VideoExportFailedSubtitle({
    required this.job,
    required this.onNavigateExportJobDeepLink,
    required this.onNavigateDomainDeepLink,
  });

  final JobRow job;
  final void Function(TaskCenterExportJobDeepLink link)?
      onNavigateExportJobDeepLink;
  final void Function(TaskCenterDomainDeepLink link)?
      onNavigateDomainDeepLink;

  @override
  Widget build(BuildContext context) {
    final outline = Theme.of(context).colorScheme.outline;
    final small = Theme.of(context).textTheme.bodySmall;
    final code = job.errorDetails == null
        ? null
        : job.errorDetails!['code'] as String?;
    final label = videoExportFailureCodeLabelZh(code ?? '');
    final link = tryParseVideoExportJobDeepLink(job);
    final deepLinkHandler = onNavigateExportJobDeepLink;
    final domainLink = tryParseTaskCenterDomainDeepLink(job);
    final domainLinkHandler = onNavigateDomainDeepLink;
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '结构化失败 · $label',
            style: small?.copyWith(color: outline),
          ),
          if (domainLink != null && domainLinkHandler != null) ...[
            const SizedBox(height: 2),
            TextButton(
              onPressed: () => domainLinkHandler(domainLink),
              child: Text(_domainDeepLinkLabel(domainLink)),
            ),
          ],
          if (link != null && deepLinkHandler != null) ...[
            const SizedBox(height: 2),
            Wrap(
              spacing: 4,
              runSpacing: 0,
              children: [
                TextButton(
                  onPressed: () => deepLinkHandler(
                    TaskCenterExportJobDeepLink(
                      projectNumericId: link.projectNumericId,
                      projectUuid: link.projectUuid,
                      scriptNumericId: link.scriptNumericId,
                      storyboardNumericId: link.storyboardNumericId,
                      workspaceId: link.workspaceId,
                      openProductionWorkspace: true,
                    ),
                  ),
                  child: const Text('打开制作工作区'),
                ),
                TextButton(
                  onPressed: () => deepLinkHandler(
                    TaskCenterExportJobDeepLink(
                      projectNumericId: link.projectNumericId,
                      projectUuid: link.projectUuid,
                      scriptNumericId: link.scriptNumericId,
                      storyboardNumericId: link.storyboardNumericId,
                      workspaceId: link.workspaceId,
                      openProductionWorkspace: false,
                    ),
                  ),
                  child: const Text('打开剧本工作区'),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _TaskFailedReworkActions extends StatelessWidget {
  const _TaskFailedReworkActions({
    required this.job,
    required this.onRetry,
    required this.onNavigateDomainDeepLink,
    required this.onCompensateWritebackJob,
  });

  final JobRow job;
  final ValueChanged<JobRow> onRetry;
  final void Function(TaskCenterDomainDeepLink link)? onNavigateDomainDeepLink;
  final ValueChanged<JobRow>? onCompensateWritebackJob;

  @override
  Widget build(BuildContext context) {
    final domainLink = tryParseTaskCenterDomainDeepLink(job);
    final canPartial = domainLink != null &&
        onNavigateDomainDeepLink != null &&
        taskCenterSupportsPartialRework(job);
    final canCompensate = onCompensateWritebackJob != null &&
        taskCenterSupportsWritebackCompensation(job);
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Wrap(
        spacing: 6,
        runSpacing: 2,
        children: [
          TextButton(
            onPressed: () => onRetry(job),
            child: const Text('重新生成'),
          ),
          if (canPartial)
            TextButton(
              onPressed: () => onNavigateDomainDeepLink!(domainLink),
              child: const Text('局部返工'),
            ),
          if (canCompensate)
            TextButton(
              onPressed: () => onCompensateWritebackJob!(job),
              child: const Text('回写补偿'),
            ),
        ],
      ),
    );
  }
}

String _domainDeepLinkLabel(TaskCenterDomainDeepLink link) {
  switch (link.target) {
    case TaskCenterDomainDeepLinkTarget.publish:
      return '打开短视频 Space（发布）';
    case TaskCenterDomainDeepLinkTarget.storyboard:
      return '打开制作工作区（分镜）';
    case TaskCenterDomainDeepLinkTarget.script:
      return '打开剧本工作区（脚本）';
    case TaskCenterDomainDeepLinkTarget.project:
      return '打开短视频 Space（项目）';
  }
}
