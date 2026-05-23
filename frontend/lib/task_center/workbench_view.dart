import 'package:flutter/material.dart';
import '../design_system/components/studio_chip.dart';

import '../design_system/components/studio_decorative_icon.dart';
import '../design_system/components/studio_card.dart';
import '../design_system/components/studio_dialog_shell.dart';
import '../design_system/components/studio_filter_row.dart';
import '../design_system/components/studio_workbench_section.dart';
import '../design_system/components/studio_text_styles.dart';
import '../design_system/tokens.dart';
import '../l10n/app_localizations.dart';
import '../rust_api.dart';

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
    final l10n = resolveAppLocalizationsForErrors(context);
    final statusLines = <String>[
      model.projectSummary,
      if (model.categoriesSummary != null) model.categoriesSummary!,
      model.jobSummary,
    ];
    final detailLines = <String>[
      if (model.numericIdTaskDetailText != null)
        l10n.taskCenterNumericIdDetailsLine(model.numericIdTaskDetailText!),
      if (model.uuidDetails != null)
        l10n.taskCenterUuidDetailsLine(model.uuidDetails!),
      if (model.statusLine != null)
        l10n.taskCenterStatusLine(model.statusLine!),
    ];

    return StudioDialogShell(
      title: l10n.taskCenterWorkbenchTitle,
      subtitle: l10n.taskCenterWorkbenchIntro(
        model.liveUpdatesConnected
            ? l10n.taskCenterWorkbenchRealtimeConnected
            : '',
      ),
      leading: studioDecorativeIcon(
        Icons.hub_outlined,
        color: StudioTokens.of(context).accent,
      ),
      onClose: callbacks.onClose,
      actions: <Widget>[
        TextButton(
          onPressed: callbacks.onClose,
          child: Text(l10n.helpHubDialogClose),
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          StudioWorkbenchSection(
            title: l10n.taskCenterWorkbenchFilterAndList,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                StudioFilterRow(
                  wideLayout: StudioFilterWideLayout.toolbarRow,
                  wideBreakpoint: 520,
                  children: <Widget>[
                    _WorkbenchToolbarButton(
                      icon: Icons.folder_open_outlined,
                      label: model.loadingProjects
                          ? l10n.projectsBusyProcessing
                          : l10n.taskCenterReloadTaskProjects,
                      onPressed: model.loadingProjects
                          ? null
                          : callbacks.onLoadProjects,
                    ),
                    _WorkbenchToolbarButton(
                      icon: Icons.category_outlined,
                      label: model.loadingCategories
                          ? l10n.projectsBusyProcessing
                          : l10n.taskCenterReloadTaskCategories,
                      onPressed: model.loadingCategories
                          ? null
                          : callbacks.onLoadCategories,
                    ),
                    _WorkbenchToolbarButton(
                      icon: Icons.playlist_play_outlined,
                      label: model.loadingTasks
                          ? l10n.projectsBusyProcessing
                          : l10n.taskCenterLoadTasksByFilters,
                      onPressed: model.loadingTasks
                          ? null
                          : callbacks.onLoadTasks,
                      emphasized: true,
                    ),
                  ],
                ),
                const SizedBox(height: StudioLayoutSpacing.inlineGap),
                StudioDialogInsetPanel(lines: statusLines),
                const SizedBox(height: StudioSpacing.sm),
                StudioFilterRow(
                  wideLayout: StudioFilterWideLayout.toolbarRow,
                  wideBreakpoint: 480,
                  children: <Widget>[
                    Expanded(
                      child: TextField(
                        controller: model.pageCtrl,
                        decoration: InputDecoration(
                          labelText: l10n.taskCenterFieldPage,
                          isDense: true,
                        ),
                      ),
                    ),
                    Expanded(
                      child: TextField(
                        controller: model.limitCtrl,
                        decoration: InputDecoration(
                          labelText: l10n.taskCenterFieldPageSize,
                          isDense: true,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                StudioFilterRow(
                  wideLayout: StudioFilterWideLayout.toolbarRow,
                  wideBreakpoint: 560,
                  children: <Widget>[
                    Expanded(
                      child: TextField(
                        controller: model.projectIdCtrl,
                        decoration: InputDecoration(
                          labelText:
                              l10n.taskCenterFieldProjectNumericIdOptional,
                          isDense: true,
                        ),
                      ),
                    ),
                    Expanded(
                      child: TextField(
                        controller: model.projectUuidCtrl,
                        decoration: InputDecoration(
                          labelText: l10n.taskCenterFieldProjectUuidOptional,
                          isDense: true,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: model.taskClassCtrl,
                  decoration: InputDecoration(
                    labelText: l10n.taskCenterFieldTaskClassOptional,
                  ),
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
                  children: <Widget>[
                    for (final item in _shortVideoProductionPhaseFilterItems(
                      l10n,
                    ))
                      StudioFilterChip(
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
                if (model.categories.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: model.categories
                        .take(6)
                        .map(
                          (row) => StudioActionChip(
                            label: Text(row.taskClass),
                            onPressed: () =>
                                callbacks.onPickCategory(row.taskClass),
                          ),
                        )
                        .toList(growable: false),
                  ),
                ],
                if (model.jobs.isNotEmpty) ...<Widget>[
                  const SizedBox(height: StudioSpacing.sm),
                  Text(
                    l10n.taskCenterJobsCount(model.jobs.length),
                    style: studioControlLabelStyle(context),
                  ),
                  const SizedBox(height: 8),
                  ...model.jobs.take(8).map(
                    (job) => _WorkbenchJobRow(
                      job: job,
                      l10n: l10n,
                      retryingJobId: model.retryingJobId,
                      cancellingJobId: model.cancellingJobId,
                      callbacks: callbacks,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: StudioSpacing.sm),
          _WorkbenchDialogSection(
            title: l10n.taskCenterTaskDetailsSection,
            icon: Icons.data_object_outlined,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                LayoutBuilder(
                  builder: (context, constraints) {
                    final stacked = constraints.maxWidth < 520;
                    final field = TextField(
                      controller: model.numericTaskIdCtrl,
                      decoration: InputDecoration(
                        labelText: l10n.taskCenterFieldNumericTaskId,
                      ),
                    );
                    final button = _WorkbenchToolbarButton(
                      icon: Icons.manage_search_outlined,
                      label: model.loadingNumericIdTaskDetail
                          ? l10n.projectsBusyProcessing
                          : l10n.taskCenterLoadNumericIdDetails,
                      onPressed: model.loadingNumericIdTaskDetail
                          ? null
                          : callbacks.onLoadNumericIdTaskDetail,
                      emphasized: true,
                    );
                    if (stacked) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: <Widget>[field, const SizedBox(height: 8), button],
                      );
                    }
                    return Row(
                      children: <Widget>[
                        Expanded(child: field),
                        const SizedBox(width: 8),
                        button,
                      ],
                    );
                  },
                ),
                const SizedBox(height: 8),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final stacked = constraints.maxWidth < 520;
                    final field = TextField(
                      controller: model.uuidCtrl,
                      decoration: InputDecoration(
                        labelText: l10n.taskCenterFieldTaskUuid,
                      ),
                    );
                    final button = _WorkbenchToolbarButton(
                      icon: Icons.fingerprint_outlined,
                      label: model.loadingUuidDetails
                          ? l10n.projectsBusyProcessing
                          : l10n.taskCenterLoadUuidDetails,
                      onPressed: model.loadingUuidDetails
                          ? null
                          : callbacks.onLoadUuidDetails,
                      emphasized: true,
                    );
                    if (stacked) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: <Widget>[field, const SizedBox(height: 8), button],
                      );
                    }
                    return Row(
                      children: <Widget>[
                        Expanded(child: field),
                        const SizedBox(width: 8),
                        button,
                      ],
                    );
                  },
                ),
                if (detailLines.isNotEmpty) ...<Widget>[
                  const SizedBox(height: StudioLayoutSpacing.inlineGap),
                  StudioDialogInsetPanel(lines: detailLines),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _WorkbenchDialogSection extends StatelessWidget {
  const _WorkbenchDialogSection({
    required this.title,
    required this.icon,
    required this.child,
  });

  final String title;
  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final tokens = StudioTokens.of(context);
    return StudioCard(
      padding: const EdgeInsets.all(StudioSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(icon, size: 18, color: tokens.signal),
              const SizedBox(width: 8),
              Expanded(
                child: Text(title, style: studioPaneTitleStyle(context)),
              ),
            ],
          ),
          const SizedBox(height: StudioSpacing.sm),
          child,
        ],
      ),
    );
  }
}

class _WorkbenchToolbarButton extends StatelessWidget {
  const _WorkbenchToolbarButton({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.emphasized = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    if (emphasized) {
      return FilledButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 16),
        label: Text(label),
      );
    }
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 16),
      label: Text(label),
    );
  }
}

class _WorkbenchJobRow extends StatelessWidget {
  const _WorkbenchJobRow({
    required this.job,
    required this.l10n,
    required this.retryingJobId,
    required this.cancellingJobId,
    required this.callbacks,
  });

  final JobRow job;
  final AppLocalizations l10n;
  final String? retryingJobId;
  final String? cancellingJobId;
  final TaskCenterWorkbenchDialogViewCallbacks callbacks;

  @override
  Widget build(BuildContext context) {
    final tokens = StudioTokens.of(context);
    final stage = taskCenterShortVideoStageLabel(l10n, job);
    final title =
        '${job.kind} · ${job.status}${stage.isEmpty ? '' : ' · $stage'}';
    final subtitleLines = <String>[
      '#${job.numericTaskId} · ${job.id}',
      if (job.errorMessage != null && job.errorMessage!.isNotEmpty)
        l10n.taskCenterFailureReason(job.errorMessage!),
    ];

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => callbacks.onPickJob(job),
          borderRadius: BorderRadius.circular(StudioSpacing.radiusButton),
          child: Ink(
            decoration: BoxDecoration(
              color: tokens.bgInset.withValues(alpha: 0.88),
              borderRadius: BorderRadius.circular(StudioSpacing.radiusButton),
              border: Border.all(color: tokens.borderSubtle),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(title, style: studioControlLabelStyle(context)),
                        const SizedBox(height: StudioLayoutSpacing.titleTight),
                        SelectableText(
                          subtitleLines.join('\n'),
                          style: studioHintStyle(context)?.copyWith(
                            fontFamily: 'monospace',
                            fontFamilyFallback: const <String>[
                              'Menlo',
                              'Consolas',
                              'monospace',
                            ],
                          ),
                        ),
                        if (job.kind == 'video.export' && job.status == 'failed')
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
                  ),
                  if (job.status == 'failed' ||
                      job.status == 'queued' ||
                      job.status == 'running')
                    Wrap(
                      spacing: 4,
                      children: <Widget>[
                        if (job.status == 'failed')
                          TextButton(
                            onPressed: retryingJobId == job.id
                                ? null
                                : () => callbacks.onRetryFailedJob(job),
                            child: Text(
                              retryingJobId == job.id
                                  ? l10n.projectsBusyProcessing
                                  : taskCenterFailedJobRetryLabel(l10n, job),
                            ),
                          ),
                        if (job.status == 'queued' || job.status == 'running')
                          TextButton(
                            onPressed: cancellingJobId == job.id
                                ? null
                                : () => callbacks.onCancelQueuedJob(job),
                            child: Text(
                              cancellingJobId == job.id
                                  ? l10n.projectsBusyProcessing
                                  : l10n.taskCenterCancel,
                            ),
                          ),
                      ],
                    )
                  else
                    Icon(
                      Icons.chevron_right,
                      color: tokens.textMuted,
                      size: 20,
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
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
    final l10n = resolveAppLocalizationsForErrors(context);
    final muted = StudioTokens.of(context).textSecondary;
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
            style: small?.copyWith(color: muted),
          ),
          if (domainLink != null && domainLinkHandler != null) ...[
            const SizedBox(height: StudioLayoutSpacing.titleTight),
            TextButton(
              onPressed: () => domainLinkHandler(domainLink),
              child: Text(_domainDeepLinkLabel(l10n, domainLink)),
            ),
          ],
          if (link != null && deepLinkHandler != null) ...[
            const SizedBox(height: StudioLayoutSpacing.titleTight),
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
    final l10n = resolveAppLocalizationsForErrors(context);
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
            child: Text(taskCenterFailedJobRegenerateLabel(l10n, job)),
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
