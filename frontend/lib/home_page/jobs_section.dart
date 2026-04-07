import 'package:flutter/material.dart';
import '../rust_api.dart';

class JobsSection extends StatelessWidget {
  const JobsSection({
    super.key,
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
  final ValueChanged<String> onJobIdChanged;
  final VoidCallback onLoadJobs;
  final VoidCallback onLoadJobsKindFlutterProbe;
  final VoidCallback onLoadJobsStatusFailed;
  final VoidCallback onLoadJobsKindProbeStatusQueued;
  final VoidCallback onLoadJobKinds;
  final VoidCallback onLoadJobKindSummary;
  final VoidCallback onLoadJobStatusSummary;
  final VoidCallback onCreateProbeJob;
  final VoidCallback onFetchJobById;
  final ValueChanged<JobRow> onSelectJob;
  final ValueChanged<JobRow> onRetryFailedJob;
  final ValueChanged<JobRow> onCancelQueuedJob;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        Text('Generation jobs', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FilledButton.tonal(
              onPressed: loadingJobs ? null : onLoadJobs,
              child: Text(loadingJobs ? '…' : 'GET /api/v1/jobs'),
            ),
            FilledButton.tonal(
              onPressed: loadingJobs ? null : onLoadJobsKindFlutterProbe,
              child: const Text('GET jobs?kind=flutter.probe'),
            ),
            FilledButton.tonal(
              onPressed: loadingJobs ? null : onLoadJobsStatusFailed,
              child: const Text('GET jobs?status=failed'),
            ),
            FilledButton.tonal(
              onPressed: loadingJobs ? null : onLoadJobsKindProbeStatusQueued,
              child: const Text('GET jobs?kind=flutter.probe&status=queued'),
            ),
            FilledButton.tonal(
              onPressed: loadingJobKinds ? null : onLoadJobKinds,
              child: Text(loadingJobKinds ? '…' : 'GET /api/v1/jobs/kinds'),
            ),
            FilledButton.tonal(
              onPressed: loadingJobKindSummary ? null : onLoadJobKindSummary,
              child: Text(
                loadingJobKindSummary ? '…' : 'GET …/jobs/kinds/summary',
              ),
            ),
            FilledButton.tonal(
              onPressed: loadingJobStatusSummary
                  ? null
                  : onLoadJobStatusSummary,
              child: Text(
                loadingJobStatusSummary ? '…' : 'GET …/jobs/status/summary',
              ),
            ),
            FilledButton.tonal(
              onPressed: creatingJob ? null : onCreateProbeJob,
              child: Text(creatingJob ? '…' : 'POST job (flutter.probe)'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        TextField(
          controller: jobIdController,
          onChanged: onJobIdChanged,
          decoration: const InputDecoration(
            labelText: 'Job id (tap a row below to paste)',
          ),
        ),
        const SizedBox(height: 8),
        FilledButton.tonal(
          onPressed: (loadingJobById || jobIdController.text.trim().isEmpty)
              ? null
              : onFetchJobById,
          child: Text(loadingJobById ? '…' : 'GET /api/v1/jobs/{id}'),
        ),
        if (jobByIdLine != null) ...[
          const SizedBox(height: 8),
          SelectableText(
            'job by id: $jobByIdLine',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
        if (jobKindsLine != null) ...[
          const SizedBox(height: 8),
          SelectableText('job kinds: $jobKindsLine'),
        ],
        if (jobKindSummaryLine != null) ...[
          const SizedBox(height: 8),
          SelectableText('job kinds/summary: $jobKindSummaryLine'),
        ],
        if (jobStatusSummaryLine != null) ...[
          const SizedBox(height: 8),
          SelectableText('job status/summary: $jobStatusSummaryLine'),
        ],
        if (jobs != null) ...[
          const SizedBox(height: 8),
          Text(
            '${jobs!.length} job(s)',
            style: Theme.of(context).textTheme.labelLarge,
          ),
          ...jobs!
              .take(8)
              .map(
                (job) => ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: Text('${job.kind} · ${job.status}'),
                  subtitle: Text(
                    [
                      job.id,
                      if (job.claimedBy != null && job.claimedBy!.isNotEmpty)
                        'claimed_by=${job.claimedBy}',
                    ].join(' · '),
                  ),
                  onTap: () => onSelectJob(job),
                  trailing:
                      (job.status == 'failed' ||
                          job.status == 'queued' ||
                          job.status == 'running')
                      ? Wrap(
                          spacing: 4,
                          children: [
                            if (job.status == 'failed')
                              TextButton(
                                onPressed: retryingJobId == job.id
                                    ? null
                                    : () => onRetryFailedJob(job),
                                child: Text(
                                  retryingJobId == job.id ? '…' : '重试',
                                ),
                              ),
                            if (job.status == 'queued' ||
                                job.status == 'running')
                              TextButton(
                                onPressed: cancellingJobId == job.id
                                    ? null
                                    : () => onCancelQueuedJob(job),
                                child: Text(
                                  cancellingJobId == job.id ? '…' : '取消',
                                ),
                              ),
                          ],
                        )
                      : null,
                ),
              ),
        ],
      ],
    );
  }
}
