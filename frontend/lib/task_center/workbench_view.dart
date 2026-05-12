import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../../rust_api.dart';

import 'support.dart';

class _PhaseFilterItem {
  const _PhaseFilterItem({required this.key, required this.label});
  final String key;
  final String label;
}

List<_PhaseFilterItem> _shortVideoProductionPhaseFilterItems(
  AppLocalizations l10n,
) => <_PhaseFilterItem>[
  _PhaseFilterItem(key: 'prep', label: l10n.taskCenterPhasePrep),
  _PhaseFilterItem(key: 'image', label: l10n.taskCenterPhaseImage),
  _PhaseFilterItem(key: 'video', label: l10n.taskCenterPhaseVideo),
  _PhaseFilterItem(key: 'export', label: l10n.taskCenterPhaseExport),
  _PhaseFilterItem(key: 'quality', label: l10n.taskCenterPhaseQuality),
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
    required this.projectUuidCtrl,
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
  final TextEditingController projectUuidCtrl;
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
    final l10n = AppLocalizations.of(context)!;
    final outline = Theme.of(context).colorScheme.outline;
    final viewportWidth = MediaQuery.sizeOf(context).width;
    final dialogWidth = viewportWidth.isFinite
        ? viewportWidth.clamp(320.0, 760.0)
        : 760.0;
    return AlertDialog(
      title: Text(l10n.taskCenterWorkbenchTitle),
      content: SizedBox(
        width: dialogWidth,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.taskCenterWorkbenchIntro(
                  model.liveUpdatesConnected
                      ? l10n.taskCenterWorkbenchRealtimeConnected
                      : '',
                ),
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: outline),
              ),
              const SizedBox(height: 12),
              Text(
                l10n.taskCenterWorkbenchFilterAndList,
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton.tonal(
                    onPressed: model.loadingProjects
                        ? null
                        : callbacks.onLoadProjects,
                    child: Text(
                      model.loadingProjects
                          ? l10n.projectsBusyProcessing
                          : l10n.taskCenterReloadTaskProjects,
                    ),
                  ),
                  FilledButton.tonal(
                    onPressed: model.loadingCategories
                        ? null
                        : callbacks.onLoadCategories,
                    child: Text(
                      model.loadingCategories
                          ? l10n.projectsBusyProcessing
                          : l10n.taskCenterReloadTaskCategories,
                    ),
                  ),
                  FilledButton.tonal(
                    onPressed: model.loadingTasks
                        ? null
                        : callbacks.onLoadTasks,
                    child: Text(
                      model.loadingTasks
                          ? l10n.projectsBusyProcessing
                          : l10n.taskCenterLoadTasksByFilters,
                    ),
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
                      decoration: InputDecoration(
                        labelText: l10n.taskCenterFieldPage,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: model.limitCtrl,
                      decoration: InputDecoration(
                        labelText: l10n.taskCenterFieldPageSize,
                      ),
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
                      decoration: InputDecoration(
                        labelText: l10n.taskCenterFieldProjectNumericIdOptional,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: model.projectUuidCtrl,
                      decoration: InputDecoration(
                        labelText: l10n.taskCenterFieldProjectUuidOptional,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: model.taskClassCtrl,
                      decoration: InputDecoration(
                        labelText: l10n.taskCenterFieldTaskClassOptional,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              TextField(
                controller: model.stateCtrl,
                decoration: InputDecoration(
                  labelText: l10n.taskCenterFieldTaskStatusOptional,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: model.productionPhaseCtrl,
                decoration: InputDecoration(
                  labelText: l10n.taskCenterFieldProductionPhaseOptional,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final item in _shortVideoProductionPhaseFilterItems(l10n))
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
                  l10n.taskCenterJobsCount(model.jobs.length),
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
                          '${taskCenterShortVideoStageLabel(l10n, job).isEmpty ? '' : ' · ${taskCenterShortVideoStageLabel(l10n, job)}'}',
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              [
                                '#${job.numericTaskId} · ${job.id}',
                                if (job.errorMessage != null &&
                                    job.errorMessage!.isNotEmpty)
                                  l10n.taskCenterFailureReason(job.errorMessage!),
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
                                            ? l10n.projectsBusyProcessing
                                            : l10n.taskCenterRetry,
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
                                            ? l10n.projectsBusyProcessing
                                            : l10n.taskCenterCancel,
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
              Text(
                l10n.taskCenterTaskDetailsSection,
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: model.numericTaskIdCtrl,
                      decoration: InputDecoration(
                        labelText: l10n.taskCenterFieldNumericTaskId,
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
                          ? l10n.projectsBusyProcessing
                          : l10n.taskCenterLoadNumericIdDetails,
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
                      decoration: InputDecoration(
                        labelText: l10n.taskCenterFieldTaskUuid,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.tonal(
                    onPressed: model.loadingUuidDetails
                        ? null
                        : callbacks.onLoadUuidDetails,
                    child: Text(
                      model.loadingUuidDetails
                          ? l10n.projectsBusyProcessing
                          : l10n.taskCenterLoadUuidDetails,
                    ),
                  ),
                ],
              ),
              if (model.numericIdTaskDetailText != null) ...[
                const SizedBox(height: 8),
                SelectableText(
                  l10n.taskCenterNumericIdDetailsLine(
                    model.numericIdTaskDetailText!,
                  ),
                ),
              ],
              if (model.uuidDetails != null) ...[
                const SizedBox(height: 8),
                SelectableText(
                  l10n.taskCenterUuidDetailsLine(model.uuidDetails!),
                ),
              ],
              if (model.statusLine != null) ...[
                const SizedBox(height: 8),
                SelectableText(l10n.taskCenterStatusLine(model.statusLine!)),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: callbacks.onClose,
          child: Text(l10n.helpHubDialogClose),
        ),
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
    final l10n = AppLocalizations.of(context)!;
    final outline = Theme.of(context).colorScheme.outline;
    final small = Theme.of(context).textTheme.bodySmall;
    final code = job.errorDetails == null
        ? null
        : job.errorDetails!['code'] as String?;
    final label = videoExportFailureCodeLabel(l10n, code ?? '');
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
            l10n.taskCenterStructuredFailure(label),
            style: small?.copyWith(color: outline),
          ),
          if (domainLink != null && domainLinkHandler != null) ...[
            const SizedBox(height: 2),
            TextButton(
              onPressed: () => domainLinkHandler(domainLink),
              child: Text(_domainDeepLinkLabel(l10n, domainLink)),
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
                  child: Text(l10n.taskCenterOpenProductionWorkspace),
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
                  child: Text(l10n.taskCenterOpenScriptWorkspace),
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
    final l10n = AppLocalizations.of(context)!;
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
            child: Text(l10n.taskCenterRegenerate),
          ),
          if (canPartial)
            TextButton(
              onPressed: () => onNavigateDomainDeepLink!(domainLink),
              child: Text(l10n.taskCenterPartialRework),
            ),
          if (canCompensate)
            TextButton(
              onPressed: () => onCompensateWritebackJob!(job),
              child: Text(l10n.taskCenterWritebackCompensation),
            ),
        ],
      ),
    );
  }
}

String _domainDeepLinkLabel(
  AppLocalizations l10n,
  TaskCenterDomainDeepLink link,
) {
  switch (link.target) {
    case TaskCenterDomainDeepLinkTarget.publish:
      return l10n.taskCenterOpenSpacePublish;
    case TaskCenterDomainDeepLinkTarget.storyboard:
      return l10n.taskCenterOpenProductionStoryboard;
    case TaskCenterDomainDeepLinkTarget.script:
      return l10n.taskCenterOpenScriptScript;
    case TaskCenterDomainDeepLinkTarget.project:
      return l10n.taskCenterOpenSpaceProject;
  }
}
