import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../config.dart';
import '../design_system/components/studio_empty_state.dart';
import '../design_system/components/studio_pane_header.dart';
import '../design_system/components/studio_pane_scaffold.dart';
import '../design_system/components/studio_async_data_view.dart';
import '../design_system/components/studio_surfaces.dart';
import '../design_system/components/studio_text_styles.dart';
import '../design_system/tokens.dart';
import '../platform/studio_load_state.dart';
import '../platform/studio_optimistic_job.dart';
import '../platform/studio_optimistic_mutation.dart';
import '../local_prefs/risky_operation_confirm_prefs.dart';
import 'workbench_view.dart';
import 'previews.dart';
import '../rust_api.dart';
import 'support.dart';
import 'package:openflow_app/design_system/components/studio_dialog_shell.dart';

part 'section_workbench.dart';
part 'section_workbench_controllers.dart';

class TaskCenterSection extends StatefulWidget {
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
    this.taskApiLoadState = StudioLoadState.initial,
    this.taskApiLastError,
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
  final StudioLoadState taskApiLoadState;
  final Object? taskApiLastError;
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

  @override
  State<TaskCenterSection> createState() => _TaskCenterSectionState();
}

class _TaskCenterSectionState extends State<TaskCenterSection> {
  @override
  void initState() {
    super.initState();
    if (widget.studioPresentation &&
        widget.taskApiLoadState == StudioLoadState.initial) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        widget.onLoadTaskApi();
      });
    }
  }

  Future<void> _openTaskWorkbench(BuildContext context) async {
    final l10n = resolveAppLocalizationsForErrors(context);
    final token = widget.accessToken;
    if (token == null || token.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.taskCenterErrNotLoggedIn)));
      return;
    }
    await showStudioDialog<void>(
      context: context,
      builder: (dialogCtx) => _TaskCenterWorkbenchDialog(
        accessToken: token,
        initialProjectNumericId: widget.initialProjectNumericId,
        initialProjectUuid: widget.initialProjectUuid,
        initialProjects: widget.taskProjects ?? const <TaskCenterProjectItem>[],
        initialTaskSummary: widget.taskApiSummaryLine,
        initialCategoriesSummary: widget.taskCategoriesLine,
        initialNumericIdTaskDetail: widget.taskDetailNumericIdLine,
        initialUuidDetails: widget.taskDetailUuidLine,
        initialJobs: widget.taskApiJobs ?? const <JobRow>[],
        onNavigateExportJobDeepLink: widget.onNavigateExportJobDeepLink,
        onNavigateDomainDeepLink: widget.onNavigateDomainDeepLink,
      ),
    );
  }

  Widget _buildStudioMainBody(BuildContext context) {
    final l10n = resolveAppLocalizationsForErrors(context);
    final jobs = widget.taskApiJobs ?? const <JobRow>[];
    return StudioAsyncDataView(
      loadState: resolveStudioPaneLoadState(
        reported: widget.taskApiLoadState,
        busy: widget.loadingTaskApi,
        hasData: jobs.isNotEmpty,
      ),
      error: widget.taskApiLastError,
      onRetry: widget.onLoadTaskApi,
      scrollableLoading: true,
      empty: Center(
        child: SingleChildScrollView(
          child: StudioEmptyState.emptyData(
            title: l10n.taskCenterJobsEmpty,
            subtitle: l10n.taskCenterSectionIntro,
            icon: Icons.cloud_download_outlined,
            actionLabel: l10n.taskCenterRefreshSummary,
            onAction: widget.onLoadTaskApi,
          ),
        ),
      ),
      child: SingleChildScrollView(
        child: DecoratedBox(
          decoration: studioInsetPanelDecoration(context),
          child: Padding(
            padding: const EdgeInsets.all(StudioLayoutSpacing.cardInner),
            child: TaskCenterJobsPreview(
              jobs: jobs,
              showCountHeader: false,
              onSelectTaskJob: widget.onSelectTaskJob,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStudioHeader(BuildContext context) {
    final l10n = resolveAppLocalizationsForErrors(context);
    final tokens = StudioTokens.of(context);
    return DecoratedBox(
      decoration:
          studioInsetPanelDecoration(
            context,
            backgroundColor: tokens.bgSurface.withValues(alpha: 0.96),
          ).copyWith(
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: studioShadowColor(context, alpha: 0.12),
                blurRadius: 10,
                spreadRadius: -8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
      child: Padding(
        padding: const EdgeInsets.all(StudioLayoutSpacing.insetComfortable),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            StudioPaneToolbar(
              title: l10n.productNavTasks,
              subtitle: l10n.taskCenterSectionIntro,
              showBack: false,
              menu: RiskyOperationConfirmPrefsOverflowMenu(
                tooltip: l10n.taskCenterLocalClientPrefs,
              ),
              actions: TaskCenterActionsBar(
                loadingTaskApi: widget.loadingTaskApi,
                onOpenWorkbench: () => _openTaskWorkbench(context),
                onLoadTaskApi: widget.onLoadTaskApi,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget? _buildStudioFooter(BuildContext context) {
    final l10n = resolveAppLocalizationsForErrors(context);
    if (widget.taskApiLoadState == StudioLoadState.initial ||
        widget.taskApiLoadState == StudioLoadState.loading ||
        widget.taskApiLoadState == StudioLoadState.error) {
      return null;
    }
    final count = widget.taskApiJobs?.length ?? 0;
    return Padding(
      padding: const EdgeInsets.only(
        top: StudioLayoutSpacing.titleSubtitle,
        bottom: StudioSpacing.sm,
      ),
      child: Center(
        child: Text(
          l10n.taskCenterJobsCount(count),
          style: studioHintStyle(context)?.copyWith(
            color: StudioTokens.of(context).textSecondary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = resolveAppLocalizationsForErrors(context);
    final muted = studioMutedTextColor(context);
    final projectSummary = widget.taskProjects == null
        ? l10n.taskCenterProjectsNotLoaded
        : summarizeTaskProjects(l10n, widget.taskProjects!);
    final taskSummary = widget.taskApiLoadState == StudioLoadState.error
        ? null
        : widget.taskApiJobs == null
        ? (widget.taskApiSummaryLine ?? l10n.taskCenterTaskListNotLoaded)
        : summarizeTaskJobs(l10n, widget.taskApiJobs!);
    final Widget summaryBody = widget.taskApiLoadState == StudioLoadState.error
        ? const SizedBox.shrink()
        : TaskCenterSummaryPreview(
            mutedColor: muted,
            projectSummary: projectSummary,
            taskSummary: taskSummary ?? l10n.taskCenterTaskListNotLoaded,
            taskCategoriesLine: widget.taskCategoriesLine,
          );

    if (widget.studioPresentation) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          _buildStudioHeader(context),
          const SizedBox(height: StudioLayoutSpacing.stackMedium),
          StudioPaneScaffold(
            body: _buildStudioMainBody(context),
            footer: _buildStudioFooter(context),
          ),
        ],
      );
    }

    final header = <Widget>[
      const SizedBox(height: StudioSpacing.sm),
      StudioPaneToolbar(
        title: l10n.productNavTasks,
        subtitle: l10n.taskCenterSectionIntro,
        showBack: widget.studioPresentation,
        menu: RiskyOperationConfirmPrefsOverflowMenu(
          tooltip: l10n.taskCenterLocalClientPrefs,
        ),
        actions: TaskCenterActionsBar(
          loadingTaskApi: widget.loadingTaskApi,
          onOpenWorkbench: () => _openTaskWorkbench(context),
          onLoadTaskApi: widget.onLoadTaskApi,
        ),
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        ...header,
        const SizedBox(height: StudioSpacing.xs),
        if (widget.taskApiLoadState == StudioLoadState.initial &&
            widget.taskApiJobs == null)
          StudioEmptyState(
            title: l10n.taskCenterTaskListNotLoaded,
            icon: Icons.cloud_download_outlined,
            actionLabel: l10n.taskCenterRefreshSummary,
            onAction: widget.onLoadTaskApi,
          )
        else
          summaryBody,
        TaskCenterDetailsPreview(
          taskDetailNumericIdLine: widget.taskDetailNumericIdLine,
          taskDetailUuidLine: widget.taskDetailUuidLine,
        ),
        if (widget.taskApiJobs != null) ...<Widget>[
          const SizedBox(height: StudioSpacing.sm),
          TaskCenterJobsPreview(
            jobs: widget.taskApiJobs!,
            onSelectTaskJob: widget.onSelectTaskJob,
          ),
        ],
      ],
    );
  }
}
