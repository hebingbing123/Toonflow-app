import 'package:flutter/material.dart';

import '../../design_system/components/studio_empty_state.dart';
import '../../design_system/components/studio_filter_row.dart';
import '../../design_system/components/studio_toolbar_button.dart';
import '../../design_system/components/studio_pane_header.dart';
import '../../design_system/components/studio_pane_scaffold.dart';
import '../../design_system/components/studio_skeleton.dart';
import '../../design_system/components/studio_surfaces.dart';
import '../../design_system/components/studio_text_styles.dart';
import '../../design_system/tokens.dart';
import '../../design_system/ix/studio_api_error_callout.dart';
import '../../local_prefs/risky_operation_confirm_prefs.dart';
import '../../platform/studio_load_state.dart';
import '../../l10n/app_localizations.dart';
import '../../l10n/studio_code_labels.dart';
import '../../rust_api.dart';

class JobsSectionViewModel {
  const JobsSectionViewModel({
    required this.loadingJobs,
    required this.loadingJobKinds,
    required this.loadingJobKindSummary,
    required this.loadingJobStatusSummary,
    required this.creatingJob,
    required this.loadingJobById,
    required this.jobIdController,
    required this.jobs,
    this.jobsLoadState = StudioLoadState.initial,
    this.jobsLastError,
    required this.jobByIdLine,
    required this.jobKindsLine,
    required this.jobKindSummaryLine,
    required this.jobStatusSummaryLine,
    required this.cancellingJobId,
    required this.retryingJobId,
  });

  final bool loadingJobs;
  final bool loadingJobKinds;
  final bool loadingJobKindSummary;
  final bool loadingJobStatusSummary;
  final bool creatingJob;
  final bool loadingJobById;
  final TextEditingController jobIdController;
  final List<JobRow>? jobs;
  final StudioLoadState jobsLoadState;
  final Object? jobsLastError;
  final String? jobByIdLine;
  final String? jobKindsLine;
  final String? jobKindSummaryLine;
  final String? jobStatusSummaryLine;
  final String? cancellingJobId;
  final String? retryingJobId;
}

class JobsSectionViewCallbacks {
  const JobsSectionViewCallbacks({
    required this.onJobIdChanged,
    required this.onLoadJobs,
    required this.onLoadJobsKindFlutterProbe,
    required this.onLoadJobsStatusFailed,
    required this.onLoadJobsKindProbeStatusQueued,
    required this.onLoadJobKinds,
    required this.onLoadJobKindSummary,
    required this.onLoadJobStatusSummary,
    required this.onCreateProbeJob,
    required this.onFetchJobById,
    required this.onSelectJob,
    required this.onRetryFailedJob,
    required this.onCancelQueuedJob,
  });

  final ValueChanged<String> onJobIdChanged;
  final VoidCallback? onLoadJobs;
  final VoidCallback? onLoadJobsKindFlutterProbe;
  final VoidCallback? onLoadJobsStatusFailed;
  final VoidCallback? onLoadJobsKindProbeStatusQueued;
  final VoidCallback? onLoadJobKinds;
  final VoidCallback? onLoadJobKindSummary;
  final VoidCallback? onLoadJobStatusSummary;
  final VoidCallback? onCreateProbeJob;
  final VoidCallback? onFetchJobById;
  final ValueChanged<JobRow> onSelectJob;
  final ValueChanged<JobRow> onRetryFailedJob;
  final ValueChanged<JobRow> onCancelQueuedJob;
}

class JobsSectionView extends StatelessWidget {
  const JobsSectionView({
    super.key,
    required this.model,
    required this.callbacks,
    this.studioPresentation = false,
  });

  final JobsSectionViewModel model;
  final JobsSectionViewCallbacks callbacks;
  final bool studioPresentation;

  List<JobRow> _visibleJobs() {
    final jobs = model.jobs;
    if (jobs == null) {
      return const <JobRow>[];
    }
    if (!studioPresentation) {
      return jobs;
    }
    return jobs
        .where((job) => job.kind != 'flutter.probe')
        .toList(growable: false);
  }

  Widget _buildStudioLoadingBody(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: DecoratedBox(
          decoration: studioInsetPanelDecoration(context),
          child: const Padding(
            padding: EdgeInsets.all(StudioLayoutSpacing.insetComfortable),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                StudioSkeleton(height: 18),
                SizedBox(height: StudioSpacing.sm),
                StudioSkeleton(height: 56),
                SizedBox(height: StudioSpacing.sm),
                StudioSkeleton(height: 56),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStudioJobTile(
    BuildContext context, {
    required JobRow job,
    required AppLocalizations l10n,
    required bool compact,
    required TextStyle? detailStyle,
  }) {
    final tokens = StudioTokens.of(context);
    final detailLines = <String>[
      job.id,
      if (job.errorMessage != null && job.errorMessage!.isNotEmpty)
        l10n.jobsFailedReason(job.errorMessage!),
      if (job.claimedBy != null && job.claimedBy!.isNotEmpty)
        l10n.jobsClaimedBy(job.claimedBy!),
    ];
    final actionButtons = <Widget>[
      if (job.status == 'failed')
        TextButton(
          onPressed: model.retryingJobId == job.id
              ? null
              : () => callbacks.onRetryFailedJob(job),
          child: Text(
            model.retryingJobId == job.id ? '…' : l10n.jobsRetry,
          ),
        ),
      if (job.status == 'queued' || job.status == 'running')
        TextButton(
          onPressed: model.cancellingJobId == job.id
              ? null
              : () => callbacks.onCancelQueuedJob(job),
          child: Text(
            model.cancellingJobId == job.id ? '…' : l10n.jobsCancel,
          ),
        ),
    ];
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => callbacks.onSelectJob(job),
        borderRadius: BorderRadius.circular(StudioSpacing.radiusButton),
        child: Container(
          margin: const EdgeInsets.only(top: StudioSpacing.xs),
          padding: const EdgeInsets.symmetric(
            horizontal: StudioLayoutSpacing.cardInner - 4,
            vertical: StudioSpacing.sm,
          ),
          decoration: BoxDecoration(
            color: tokens.bgSurface.withValues(alpha: 0.92),
            borderRadius: BorderRadius.circular(StudioSpacing.radiusButton),
            border: Border.all(color: tokens.borderSubtle),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Expanded(
                    child: Text(
                      studioJobListTitle(l10n, job.kind, job.status),
                      maxLines: compact ? 2 : 1,
                      overflow: TextOverflow.ellipsis,
                      style: studioCardTitleStyle(context),
                    ),
                  ),
                  if (!compact && actionButtons.isNotEmpty)
                    Wrap(spacing: 4, children: actionButtons),
                  if (!compact) ...<Widget>[
                    const SizedBox(width: StudioSpacing.xs),
                    Icon(Icons.chevron_right, size: 20, color: tokens.textMuted),
                  ],
                ],
              ),
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    for (var i = 0; i < detailLines.length; i++) ...<Widget>[
                      if (i > 0) const SizedBox(height: StudioLayoutSpacing.titleTight),
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
              if (compact && actionButtons.isNotEmpty) ...<Widget>[
                const SizedBox(height: 8),
                Wrap(spacing: 8, runSpacing: 4, children: actionButtons),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildJobList(
    BuildContext context, {
    required List<JobRow> visibleJobs,
    required bool showCountHeader,
    bool studioCards = false,
  }) {
    final l10n = resolveAppLocalizationsForErrors(context);
    final compact = MediaQuery.sizeOf(context).width < 520;
    final detailStyle = Theme.of(context).textTheme.bodySmall?.copyWith(
      color: StudioTokens.of(context).textSecondary,
      height: 1.35,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        if (showCountHeader) ...<Widget>[
          Text(
            l10n.jobsCountLabel(visibleJobs.length),
            style: Theme.of(context).textTheme.labelLarge,
          ),
        ],
        ...visibleJobs.take(8).map((job) {
          if (studioCards) {
            return _buildStudioJobTile(
              context,
              job: job,
              l10n: l10n,
              compact: compact,
              detailStyle: detailStyle,
            );
          }
          final detailLines = <String>[
            job.id,
            if (job.errorMessage != null && job.errorMessage!.isNotEmpty)
              l10n.jobsFailedReason(job.errorMessage!),
            if (job.claimedBy != null && job.claimedBy!.isNotEmpty)
              l10n.jobsClaimedBy(job.claimedBy!),
          ];
          final actionButtons = <Widget>[
            if (job.status == 'failed')
              TextButton(
                onPressed: model.retryingJobId == job.id
                    ? null
                    : () => callbacks.onRetryFailedJob(job),
                child: Text(
                  model.retryingJobId == job.id ? '…' : l10n.jobsRetry,
                ),
              ),
            if (job.status == 'queued' || job.status == 'running')
              TextButton(
                onPressed: model.cancellingJobId == job.id
                    ? null
                    : () => callbacks.onCancelQueuedJob(job),
                child: Text(
                  model.cancellingJobId == job.id ? '…' : l10n.jobsCancel,
                ),
              ),
          ];
          return ListTile(
            dense: !compact,
            contentPadding: EdgeInsets.zero,
            minVerticalPadding: compact ? 10 : 6,
            title: Text(
              studioJobListTitle(l10n, job.kind, job.status),
              maxLines: compact ? 2 : 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  for (var i = 0; i < detailLines.length; i++) ...<Widget>[
                    if (i > 0) const SizedBox(height: StudioLayoutSpacing.titleTight),
                    Text(
                      detailLines[i],
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: detailStyle,
                    ),
                  ],
                  if (compact && actionButtons.isNotEmpty) ...<Widget>[
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: actionButtons,
                    ),
                  ],
                ],
              ),
            ),
            onTap: () => callbacks.onSelectJob(job),
            trailing: compact || actionButtons.isEmpty
                ? null
                : Wrap(spacing: 4, children: actionButtons),
          );
        }),
      ],
    );
  }

  Widget _buildJobsToolbarActions(BuildContext context, AppLocalizations l10n) {
    return StudioFilterRow(
      wideLayout: StudioFilterWideLayout.toolbarRow,
      wideBreakpoint: 480,
      children: <Widget>[
        StudioToolbarButton(
          label: model.loadingJobs ? '…' : l10n.jobsLoadList,
          onPressed: model.loadingJobs ? null : callbacks.onLoadJobs,
          busy: model.loadingJobs,
        ),
        StudioToolbarButton(
          label: l10n.jobsLoadFailed,
          onPressed: model.loadingJobs ? null : callbacks.onLoadJobsStatusFailed,
        ),
      ],
    );
  }

  Widget _buildStudioHeader(BuildContext context, AppLocalizations l10n) {
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
              title: l10n.jobsTitle,
              subtitle: l10n.jobsSubtitle,
              showBack: false,
              menu: RiskyOperationConfirmPrefsOverflowMenu(
                tooltip: l10n.jobsPrefsTooltip,
              ),
              actions: _buildJobsToolbarActions(context, l10n),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStudioMainBody(BuildContext context) {
    final l10n = resolveAppLocalizationsForErrors(context);
    if (model.jobsLoadState == StudioLoadState.error) {
      return const SizedBox.shrink();
    }
    if (model.jobsLoadState == StudioLoadState.initial ||
        model.jobsLoadState == StudioLoadState.loading ||
        model.loadingJobs) {
      return _buildStudioLoadingBody(context);
    }
    final visibleJobs = _visibleJobs();
    if (visibleJobs.isEmpty) {
      return Center(
        child: StudioEmptyState.emptyData(
          title: l10n.jobsEmptyValue,
          subtitle: l10n.jobsSubtitle,
          icon: Icons.work_outline,
          actionLabel: l10n.jobsLoadList,
          onAction: callbacks.onLoadJobs,
        ),
      );
    }
    return SingleChildScrollView(
      child: DecoratedBox(
        decoration: studioInsetPanelDecoration(context),
        child: Padding(
          padding: const EdgeInsets.all(StudioLayoutSpacing.cardInner),
          child: _buildJobList(
            context,
            visibleJobs: visibleJobs,
            showCountHeader: false,
            studioCards: true,
          ),
        ),
      ),
    );
  }

  Widget? _buildStudioFooter(BuildContext context) {
    if (model.jobsLoadState == StudioLoadState.initial ||
        model.jobsLoadState == StudioLoadState.loading ||
        model.jobsLoadState == StudioLoadState.error) {
      return null;
    }
    final l10n = resolveAppLocalizationsForErrors(context);
    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 8),
      child: Center(
        child: Text(
          l10n.jobsCountLabel(_visibleJobs().length),
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

    final header = <Widget>[
      const SizedBox(height: 16),
      if (studioPresentation)
        StudioPaneToolbar(
          title: l10n.jobsTitle,
          subtitle: l10n.jobsSubtitle,
          showBack: false,
          menu: RiskyOperationConfirmPrefsOverflowMenu(
            tooltip: l10n.jobsPrefsTooltip,
          ),
          actions: _buildJobsToolbarActions(context, l10n),
        )
      else ...<Widget>[
        StudioPaneHeader(
          title: l10n.jobsTitle,
          subtitle: l10n.jobsSubtitle,
          showBack: false,
          trailing: RiskyOperationConfirmPrefsOverflowMenu(
            tooltip: l10n.jobsPrefsTooltip,
          ),
        ),
        const SizedBox(height: StudioSpacing.sm),
      ],
      if (!studioPresentation)
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FilledButton.tonal(
              onPressed: model.loadingJobs ? null : callbacks.onLoadJobs,
              child: Text(model.loadingJobs ? '…' : l10n.jobsLoadList),
            ),
            FilledButton.tonal(
              onPressed: model.loadingJobs
                  ? null
                  : callbacks.onLoadJobsStatusFailed,
              child: Text(l10n.jobsLoadFailed),
            ),
            FilledButton.tonal(
              onPressed: model.loadingJobKinds ? null : callbacks.onLoadJobKinds,
              child: Text(model.loadingJobKinds ? '…' : l10n.jobsLoadKinds),
            ),
            FilledButton.tonal(
              onPressed: model.loadingJobKindSummary
                  ? null
                  : callbacks.onLoadJobKindSummary,
              child: Text(
                model.loadingJobKindSummary ? '…' : l10n.jobsLoadKindSummary,
              ),
            ),
            FilledButton.tonal(
              onPressed: model.loadingJobStatusSummary
                  ? null
                  : callbacks.onLoadJobStatusSummary,
              child: Text(
                model.loadingJobStatusSummary
                    ? '…'
                    : l10n.jobsLoadStatusSummary,
              ),
            ),
          ],
        ),
    ];

    if (studioPresentation) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          const SizedBox(height: 16),
          _buildStudioHeader(context, l10n),
          const SizedBox(height: StudioSpacing.sm),
          if (model.jobsLoadState == StudioLoadState.error &&
              model.jobsLastError != null)
            StudioApiErrorCallout(
              error: model.jobsLastError!,
              onRetry: callbacks.onLoadJobs,
            )
          else
            StudioPaneScaffold(
              body: _buildStudioMainBody(context),
              footer: _buildStudioFooter(context),
            ),
        ],
      );
    }

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          ...header,
          const SizedBox(height: 8),
          ExpansionTile(
            tilePadding: EdgeInsets.zero,
            childrenPadding: EdgeInsets.zero,
            initiallyExpanded: false,
            title: Text(l10n.jobsCompatTitle),
            subtitle: Text(
              l10n.jobsCompatSubtitle,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: muted),
            ),
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  l10n.jobsCompatHttpProbeFilters,
                  style: Theme.of(
                    context,
                  ).textTheme.labelSmall?.copyWith(color: muted),
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton.tonal(
                    onPressed: model.loadingJobs
                        ? null
                        : callbacks.onLoadJobsKindFlutterProbe,
                    child: Text(l10n.jobsFilterFlutterProbe),
                  ),
                  FilledButton.tonal(
                    onPressed: model.loadingJobs
                        ? null
                        : callbacks.onLoadJobsKindProbeStatusQueued,
                    child: Text(l10n.jobsFilterFlutterProbeQueued),
                  ),
                  FilledButton.tonal(
                    onPressed: model.creatingJob
                        ? null
                        : callbacks.onCreateProbeJob,
                    child: Text(
                      model.creatingJob ? '…' : l10n.jobsCreateProbeJob,
                    ),
                  ),
                  FilledButton.tonal(
                    onPressed: model.loadingJobKinds
                        ? null
                        : callbacks.onLoadJobKinds,
                    child: Text(
                      model.loadingJobKinds ? '…' : l10n.jobsLoadKinds,
                    ),
                  ),
                  FilledButton.tonal(
                    onPressed: model.loadingJobKindSummary
                        ? null
                        : callbacks.onLoadJobKindSummary,
                    child: Text(
                      model.loadingJobKindSummary
                          ? '…'
                          : l10n.jobsLoadKindSummary,
                    ),
                  ),
                  FilledButton.tonal(
                    onPressed: model.loadingJobStatusSummary
                        ? null
                        : callbacks.onLoadJobStatusSummary,
                    child: Text(
                      model.loadingJobStatusSummary
                          ? '…'
                          : l10n.jobsLoadStatusSummary,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: StudioSpacing.sm),
          TextField(
            controller: model.jobIdController,
            onChanged: callbacks.onJobIdChanged,
            decoration: InputDecoration(labelText: l10n.jobsJobIdLabel),
          ),
          const SizedBox(height: 8),
          FilledButton.tonal(
            onPressed:
                (model.loadingJobById ||
                    model.jobIdController.text.trim().isEmpty)
                ? null
                : callbacks.onFetchJobById,
            child: Text(model.loadingJobById ? '…' : l10n.jobsFetchDetail),
          ),
          if (model.jobByIdLine != null) ...<Widget>[
            const SizedBox(height: 8),
            SelectableText(
              l10n.jobsDetailLabel(model.jobByIdLine!),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
          if (model.jobKindsLine != null) ...<Widget>[
            const SizedBox(height: 8),
            SelectableText(l10n.jobsKindsLabel(model.jobKindsLine!)),
          ],
          if (model.jobKindSummaryLine != null) ...<Widget>[
            const SizedBox(height: 8),
            SelectableText(
              l10n.jobsKindSummaryLabel(model.jobKindSummaryLine!),
            ),
          ],
          if (model.jobStatusSummaryLine != null) ...<Widget>[
            const SizedBox(height: 8),
            SelectableText(
              l10n.jobsStatusSummaryLabel(model.jobStatusSummaryLine!),
            ),
          ],
          if (model.jobs != null) ...<Widget>[
            const SizedBox(height: StudioSpacing.sm),
            _buildJobList(
              context,
              visibleJobs: _visibleJobs(),
              showCountHeader: true,
            ),
          ],
        ],
      ),
    );
  }
}
