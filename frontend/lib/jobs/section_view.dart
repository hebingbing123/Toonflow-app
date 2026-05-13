import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../local_prefs/risky_operation_confirm_prefs.dart';
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
  });

  final JobsSectionViewModel model;
  final JobsSectionViewCallbacks callbacks;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final outline = Theme.of(context).colorScheme.outline;
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  l10n.jobsTitle,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
              RiskyOperationConfirmPrefsOverflowMenu(
                tooltip: l10n.jobsPrefsTooltip,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            l10n.jobsSubtitle,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: outline),
          ),
          const SizedBox(height: 8),
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
          const SizedBox(height: 8),
          ExpansionTile(
            tilePadding: EdgeInsets.zero,
            childrenPadding: EdgeInsets.zero,
            title: Text(l10n.jobsCompatTitle),
            subtitle: Text(
              l10n.jobsCompatSubtitle,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: outline),
            ),
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  l10n.jobsCompatHttpProbeFilters,
                  style: Theme.of(
                    context,
                  ).textTheme.labelSmall?.copyWith(color: outline),
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
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
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
          if (model.jobByIdLine != null) ...[
            const SizedBox(height: 8),
            SelectableText(
              l10n.jobsDetailLabel(model.jobByIdLine!),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
          if (model.jobKindsLine != null) ...[
            const SizedBox(height: 8),
            SelectableText(l10n.jobsKindsLabel(model.jobKindsLine!)),
          ],
          if (model.jobKindSummaryLine != null) ...[
            const SizedBox(height: 8),
            SelectableText(
              l10n.jobsKindSummaryLabel(model.jobKindSummaryLine!),
            ),
          ],
          if (model.jobStatusSummaryLine != null) ...[
            const SizedBox(height: 8),
            SelectableText(
              l10n.jobsStatusSummaryLabel(model.jobStatusSummaryLine!),
            ),
          ],
          if (model.jobs != null) ...[
            const SizedBox(height: 8),
            Text(
              l10n.jobsCountLabel(model.jobs!.length),
              style: Theme.of(context).textTheme.labelLarge,
            ),
            ...model.jobs!
                .take(8)
                .map(
                  (job) => ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: Text('${job.kind} · ${job.status}'),
                    subtitle: Text(
                      [
                        job.id,
                        if (job.errorMessage != null &&
                            job.errorMessage!.isNotEmpty)
                          l10n.jobsFailedReason(job.errorMessage!),
                        if (job.claimedBy != null && job.claimedBy!.isNotEmpty)
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
                                      : () => callbacks.onRetryFailedJob(job),
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
                                      : () => callbacks.onCancelQueuedJob(job),
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
        ],
      ),
    );
  }
}
