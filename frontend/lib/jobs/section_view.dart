import 'package:flutter/material.dart';

import '../../design_system/components/studio_empty_state.dart';
import '../../design_system/components/studio_filter_row.dart';
import '../../design_system/components/studio_pane_header.dart';
import '../../design_system/components/studio_text_styles.dart';
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

  @override
  Widget build(BuildContext context) {
    final l10n = resolveAppLocalizationsForErrors(context);
    final muted = studioMutedTextColor(context);
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),
          StudioPaneHeader(
            title: l10n.jobsTitle,
            subtitle: l10n.jobsSubtitle,
            showBack: studioPresentation,
            trailing: RiskyOperationConfirmPrefsOverflowMenu(
              tooltip: l10n.jobsPrefsTooltip,
            ),
          ),
          const SizedBox(height: 12),
          if (studioPresentation)
            StudioFilterRow(
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
                  onPressed: model.loadingJobKinds
                      ? null
                      : callbacks.onLoadJobKinds,
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
          if (studioPresentation &&
              model.jobsLoadState == StudioLoadState.error &&
              model.jobsLastError != null) ...<Widget>[
            const SizedBox(height: 12),
            StudioApiErrorCallout(
              error: model.jobsLastError!,
              onRetry: callbacks.onLoadJobs,
            ),
          ] else if (studioPresentation &&
              model.jobsLoadState == StudioLoadState.empty) ...<Widget>[
            const SizedBox(height: 12),
            StudioEmptyState(
              title: l10n.jobsEmptyValue,
              subtitle: l10n.jobsSubtitle,
              icon: Icons.work_outline,
              actionLabel: l10n.jobsLoadList,
              onAction: callbacks.onLoadJobs,
            ),
          ],
          if (!studioPresentation) ...<Widget>[
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
          ],
          if (!studioPresentation) ...<Widget>[
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
          ],
          if (!studioPresentation && model.jobByIdLine != null) ...[
            const SizedBox(height: 8),
            SelectableText(
              l10n.jobsDetailLabel(model.jobByIdLine!),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
          if (!studioPresentation && model.jobKindsLine != null) ...[
            const SizedBox(height: 8),
            SelectableText(l10n.jobsKindsLabel(model.jobKindsLine!)),
          ],
          if (!studioPresentation && model.jobKindSummaryLine != null) ...[
            const SizedBox(height: 8),
            SelectableText(
              l10n.jobsKindSummaryLabel(model.jobKindSummaryLine!),
            ),
          ],
          if (!studioPresentation && model.jobStatusSummaryLine != null) ...[
            const SizedBox(height: 8),
            SelectableText(
              l10n.jobsStatusSummaryLabel(model.jobStatusSummaryLine!),
            ),
          ],
          if (model.jobs != null) ...[
            const SizedBox(height: 12),
            Builder(
              builder: (context) {
                final visibleJobs = studioPresentation
                    ? model.jobs!
                          .where((job) => job.kind != 'flutter.probe')
                          .toList(growable: false)
                    : model.jobs!;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      l10n.jobsCountLabel(visibleJobs.length),
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                    ...visibleJobs.take(8).map(
                      (job) => ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title: Text(studioJobListTitle(l10n, job.kind, job.status)),
                        subtitle: Text(
                          [
                            job.id,
                            if (job.errorMessage != null &&
                                job.errorMessage!.isNotEmpty)
                              l10n.jobsFailedReason(job.errorMessage!),
                            if (job.claimedBy != null &&
                                job.claimedBy!.isNotEmpty)
                              l10n.jobsClaimedBy(job.claimedBy!),
                          ].join(' · '),
                        ),
                        onTap: () => callbacks.onSelectJob(job),
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
                                            : l10n.jobsRetry,
                                      ),
                                    ),
                                  if (job.status == 'queued' ||
                                      job.status == 'running')
                                    TextButton(
                                      onPressed: model.cancellingJobId == job.id
                                          ? null
                                          : () =>
                                                callbacks.onCancelQueuedJob(job),
                                      child: Text(
                                        model.cancellingJobId == job.id
                                            ? '…'
                                            : l10n.jobsCancel,
                                      ),
                                    ),
                                ],
                              )
                            : null,
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
        ],
      ),
    );
  }
}
