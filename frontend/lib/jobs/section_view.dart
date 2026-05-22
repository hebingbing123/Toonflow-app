import 'package:flutter/material.dart';

import '../../design_system/components/studio_empty_state.dart';
import '../../design_system/components/studio_collapsible_filter_panel.dart';
import '../../design_system/components/studio_filter_row.dart';
import '../../design_system/components/studio_pane_header.dart';
import '../../design_system/components/studio_pane_scaffold.dart';
import '../../design_system/components/studio_text_styles.dart';
import '../../design_system/tokens.dart';
import '../../design_system/ix/studio_api_error_callout.dart';
import '../../local_prefs/risky_operation_confirm_prefs.dart';
import '../../platform/studio_load_state.dart';
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

  Widget _buildJobList(
    BuildContext context, {
    required List<JobRow> visibleJobs,
    required bool showCountHeader,
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
                    if (i > 0) const SizedBox(height: 4),
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

  Widget _buildStudioMainBody(BuildContext context) {
    final l10n = resolveAppLocalizationsForErrors(context);
    if (model.jobsLoadState == StudioLoadState.error) {
      return const SizedBox.shrink();
    }
    if (model.jobsLoadState == StudioLoadState.initial ||
        model.jobsLoadState == StudioLoadState.loading ||
        model.loadingJobs) {
      return const Center(child: CircularProgressIndicator());
    }
    final visibleJobs = _visibleJobs();
    if (visibleJobs.isEmpty) {
      return Center(
        child: StudioEmptyState(
          title: l10n.jobsEmptyValue,
          subtitle: l10n.jobsSubtitle,
          icon: Icons.work_outline,
        ),
      );
    }
    return SingleChildScrollView(
      child: _buildJobList(
        context,
        visibleJobs: visibleJobs,
        showCountHeader: false,
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
          style: Theme.of(context).textTheme.labelLarge,
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
      StudioPaneHeader(
        title: l10n.jobsTitle,
        subtitle: l10n.jobsSubtitle,
        showBack: false,
        trailing: RiskyOperationConfirmPrefsOverflowMenu(
          tooltip: l10n.jobsPrefsTooltip,
        ),
      ),
      const SizedBox(height: 12),
      if (studioPresentation)
        StudioCollapsibleFilterPanel(
          child: StudioFilterRow(
            wideLayout: StudioFilterWideLayout.toolbarRow,
            wideBreakpoint: 480,
            children: <Widget>[
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
            ],
          ),
        )
      else
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
          ...header,
          const SizedBox(height: 12),
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
          const SizedBox(height: 12),
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
            const SizedBox(height: 12),
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
