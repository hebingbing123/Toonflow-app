import 'package:flutter/material.dart';

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
              onPressed: model.loadingJobs ? null : callbacks.onLoadJobs,
              child: Text(model.loadingJobs ? '…' : '加载作业列表'),
            ),
            FilledButton.tonal(
              onPressed: model.loadingJobs
                  ? null
                  : callbacks.onLoadJobsStatusFailed,
              child: const Text('查看失败作业'),
            ),
            FilledButton.tonal(
              onPressed: model.loadingJobKinds
                  ? null
                  : callbacks.onLoadJobKinds,
              child: Text(model.loadingJobKinds ? '…' : '加载作业类型'),
            ),
            FilledButton.tonal(
              onPressed: model.loadingJobKindSummary
                  ? null
                  : callbacks.onLoadJobKindSummary,
              child: Text(model.loadingJobKindSummary ? '…' : '查看类型汇总'),
            ),
            FilledButton.tonal(
              onPressed: model.loadingJobStatusSummary
                  ? null
                  : callbacks.onLoadJobStatusSummary,
              child: Text(model.loadingJobStatusSummary ? '…' : '查看状态汇总'),
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
                'HTTP probe filters',
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
                  child: const Text('按 flutter.probe 查看'),
                ),
                FilledButton.tonal(
                  onPressed: model.loadingJobs
                      ? null
                      : callbacks.onLoadJobsKindProbeStatusQueued,
                  child: const Text('查看 flutter.probe 排队中'),
                ),
                FilledButton.tonal(
                  onPressed: model.creatingJob
                      ? null
                      : callbacks.onCreateProbeJob,
                  child: Text(model.creatingJob ? '…' : '创建 probe 作业'),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 8),
        TextField(
          controller: model.jobIdController,
          onChanged: callbacks.onJobIdChanged,
          decoration: const InputDecoration(labelText: '作业 ID（点下方列表可自动填入）'),
        ),
        const SizedBox(height: 8),
        FilledButton.tonal(
          onPressed:
              (model.loadingJobById ||
                  model.jobIdController.text.trim().isEmpty)
              ? null
              : callbacks.onFetchJobById,
          child: Text(model.loadingJobById ? '…' : '查看作业详情'),
        ),
        if (model.jobByIdLine != null) ...[
          const SizedBox(height: 8),
          SelectableText(
            '作业详情：${model.jobByIdLine}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
        if (model.jobKindsLine != null) ...[
          const SizedBox(height: 8),
          SelectableText('作业类型：${model.jobKindsLine}'),
        ],
        if (model.jobKindSummaryLine != null) ...[
          const SizedBox(height: 8),
          SelectableText('类型汇总：${model.jobKindSummaryLine}'),
        ],
        if (model.jobStatusSummaryLine != null) ...[
          const SizedBox(height: 8),
          SelectableText('状态汇总：${model.jobStatusSummaryLine}'),
        ],
        if (model.jobs != null) ...[
          const SizedBox(height: 8),
          Text(
            '${model.jobs!.length} 条作业',
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
                      if (job.claimedBy != null && job.claimedBy!.isNotEmpty)
                        'claimed_by=${job.claimedBy}',
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
                                  model.retryingJobId == job.id ? '…' : '重试',
                                ),
                              ),
                            if (job.status == 'queued' ||
                                job.status == 'running')
                              TextButton(
                                onPressed: model.cancellingJobId == job.id
                                    ? null
                                    : () => callbacks.onCancelQueuedJob(job),
                                child: Text(
                                  model.cancellingJobId == job.id ? '…' : '取消',
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
