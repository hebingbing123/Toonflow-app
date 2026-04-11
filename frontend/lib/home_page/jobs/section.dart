import 'package:flutter/material.dart';
import '../../rust_api.dart';

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
    final outline = Theme.of(context).colorScheme.outline;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        Text('任务作业', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        Text(
          '查看作业列表、状态汇总，并按 ID 打开单条执行记录。',
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
              onPressed: loadingJobs ? null : onLoadJobs,
              child: Text(loadingJobs ? '…' : '加载作业列表'),
            ),
            FilledButton.tonal(
              onPressed: loadingJobs ? null : onLoadJobsStatusFailed,
              child: const Text('查看失败作业'),
            ),
            FilledButton.tonal(
              onPressed: loadingJobKinds ? null : onLoadJobKinds,
              child: Text(loadingJobKinds ? '…' : '加载作业类型'),
            ),
            FilledButton.tonal(
              onPressed: loadingJobKindSummary ? null : onLoadJobKindSummary,
              child: Text(loadingJobKindSummary ? '…' : '查看类型汇总'),
            ),
            FilledButton.tonal(
              onPressed: loadingJobStatusSummary
                  ? null
                  : onLoadJobStatusSummary,
              child: Text(loadingJobStatusSummary ? '…' : '查看状态汇总'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ExpansionTile(
          tilePadding: EdgeInsets.zero,
          childrenPadding: EdgeInsets.zero,
          title: const Text('兼容性检查'),
          subtitle: Text(
            '保留 flutter.probe 相关回归入口，默认折叠',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: outline),
          ),
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Legacy probe filters',
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
                  onPressed: loadingJobs ? null : onLoadJobsKindFlutterProbe,
                  child: const Text('按 flutter.probe 查看'),
                ),
                FilledButton.tonal(
                  onPressed: loadingJobs
                      ? null
                      : onLoadJobsKindProbeStatusQueued,
                  child: const Text('查看 flutter.probe 排队中'),
                ),
                FilledButton.tonal(
                  onPressed: creatingJob ? null : onCreateProbeJob,
                  child: Text(creatingJob ? '…' : '创建 probe 作业'),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 8),
        TextField(
          controller: jobIdController,
          onChanged: onJobIdChanged,
          decoration: const InputDecoration(labelText: '作业 ID（点下方列表可自动填入）'),
        ),
        const SizedBox(height: 8),
        FilledButton.tonal(
          onPressed: (loadingJobById || jobIdController.text.trim().isEmpty)
              ? null
              : onFetchJobById,
          child: Text(loadingJobById ? '…' : '查看作业详情'),
        ),
        if (jobByIdLine != null) ...[
          const SizedBox(height: 8),
          SelectableText(
            '作业详情：$jobByIdLine',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
        if (jobKindsLine != null) ...[
          const SizedBox(height: 8),
          SelectableText('作业类型：$jobKindsLine'),
        ],
        if (jobKindSummaryLine != null) ...[
          const SizedBox(height: 8),
          SelectableText('类型汇总：$jobKindSummaryLine'),
        ],
        if (jobStatusSummaryLine != null) ...[
          const SizedBox(height: 8),
          SelectableText('状态汇总：$jobStatusSummaryLine'),
        ],
        if (jobs != null) ...[
          const SizedBox(height: 8),
          Text(
            '${jobs!.length} 条作业',
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
