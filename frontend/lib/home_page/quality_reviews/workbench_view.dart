part of 'section.dart';

extension _QualityReviewsWorkbenchDialogView
    on _QualityReviewsWorkbenchDialogState {
  AlertDialog _buildQualityReviewsWorkbenchDialogView({
    required BuildContext context,
    required List<QualityReview> reviews,
    required String? statsSummary,
    required String? stagePassRateSummary,
    required String? reviewDetails,
    required String? statusLine,
    required bool filterBadCasesOnly,
    required bool createPassed,
    required bool createBadCase,
    required bool loadingReviews,
    required bool loadingBadCases,
    required bool loadingStats,
    required bool loadingStagePassRate,
    required bool loadingReviewById,
    required bool creatingReview,
    required TextEditingController targetTypeFilterCtrl,
    required TextEditingController targetIdFilterCtrl,
    required TextEditingController jobIdFilterCtrl,
    required TextEditingController reviewIdCtrl,
    required TextEditingController createTargetTypeCtrl,
    required TextEditingController createTargetIdCtrl,
    required TextEditingController createSourceCtrl,
    required TextEditingController createScoreCtrl,
    required TextEditingController createCommentsCtrl,
    required TextEditingController createBadCaseCategoryCtrl,
    required Future<void> Function() onLoadReviews,
    required Future<void> Function() onLoadBadCases,
    required Future<void> Function() onLoadStats,
    required Future<void> Function() onLoadStagePassRate,
    required Future<void> Function() onLoadReviewById,
    required Future<void> Function() onCreateReview,
    required ValueChanged<bool> onCreatePassedChanged,
    required ValueChanged<bool> onCreateBadCaseChanged,
    required ValueChanged<QualityReview> onSelectReview,
    required VoidCallback onClose,
  }) {
    final outline = Theme.of(context).colorScheme.outline;
    return AlertDialog(
      title: const Text('质量工作台'),
      content: SizedBox(
        width: 840,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                reviews.isEmpty
                    ? '用同一入口完成评审筛选、坏例查看、统计读取、详情查询和手动创建。'
                    : summarizeQualityReviews(reviews),
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: outline),
              ),
              const SizedBox(height: 12),
              Text('筛选与读取', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 8),
              TextField(
                controller: targetTypeFilterCtrl,
                decoration: const InputDecoration(labelText: '筛选 targetType'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: targetIdFilterCtrl,
                decoration: const InputDecoration(labelText: '筛选 targetId'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: jobIdFilterCtrl,
                decoration: const InputDecoration(labelText: '筛选 jobId'),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton.tonal(
                    onPressed: loadingReviews || creatingReview
                        ? null
                        : onLoadReviews,
                    child: Text(loadingReviews ? '加载中…' : '加载评审列表'),
                  ),
                  OutlinedButton(
                    onPressed: loadingBadCases || creatingReview
                        ? null
                        : onLoadBadCases,
                    child: Text(loadingBadCases ? '加载中…' : '只看坏例'),
                  ),
                  OutlinedButton(
                    onPressed: loadingStats ? null : onLoadStats,
                    child: Text(loadingStats ? '统计中…' : '读取质量统计'),
                  ),
                  OutlinedButton(
                    onPressed: loadingStagePassRate
                        ? null
                        : onLoadStagePassRate,
                    child: Text(loadingStagePassRate ? '读取中…' : '读取阶段通过率'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text('详情查询', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 8),
              TextField(
                controller: reviewIdCtrl,
                decoration: const InputDecoration(labelText: '评审 ID'),
              ),
              const SizedBox(height: 8),
              FilledButton.tonal(
                onPressed: loadingReviewById || creatingReview
                    ? null
                    : onLoadReviewById,
                child: Text(loadingReviewById ? '读取中…' : '查看评审详情'),
              ),
              const SizedBox(height: 12),
              Text('创建评审', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 8),
              TextField(
                controller: createTargetTypeCtrl,
                decoration: const InputDecoration(labelText: 'targetType'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: createTargetIdCtrl,
                decoration: const InputDecoration(labelText: 'targetId'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: createSourceCtrl,
                decoration: const InputDecoration(labelText: 'source'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: createScoreCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'overallScore'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: createCommentsCtrl,
                minLines: 2,
                maxLines: 4,
                decoration: const InputDecoration(labelText: 'comments'),
              ),
              const SizedBox(height: 8),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('passed'),
                value: createPassed,
                onChanged: creatingReview ? null : onCreatePassedChanged,
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('isBadCase'),
                value: createBadCase,
                onChanged: creatingReview ? null : onCreateBadCaseChanged,
              ),
              TextField(
                controller: createBadCaseCategoryCtrl,
                decoration: const InputDecoration(labelText: 'badCaseCategory'),
              ),
              const SizedBox(height: 8),
              FilledButton.tonal(
                onPressed: creatingReview ? null : onCreateReview,
                child: Text(creatingReview ? '创建中…' : '创建评审'),
              ),
              if (statusLine != null) ...[
                const SizedBox(height: 12),
                SelectableText('状态：$statusLine'),
              ],
              if (reviewDetails != null) ...[
                const SizedBox(height: 12),
                SelectableText('评审详情：$reviewDetails'),
              ],
              if (statsSummary != null) ...[
                const SizedBox(height: 12),
                SelectableText('质量统计：$statsSummary'),
              ],
              if (stagePassRateSummary != null) ...[
                const SizedBox(height: 12),
                SelectableText('阶段通过率：$stagePassRateSummary'),
              ],
              if (reviews.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  filterBadCasesOnly
                      ? '坏例 ${reviews.length} 条'
                      : '评审 ${reviews.length} 条',
                  style: Theme.of(context).textTheme.labelLarge,
                ),
                const SizedBox(height: 8),
                ...reviews
                    .take(8)
                    .map(
                      (review) => ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          '${review.targetType} · ${review.source} · score=${review.overallScore ?? "n/a"}',
                        ),
                        subtitle: Text(formatQualityReviewDetails(review)),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => onSelectReview(review),
                      ),
                    ),
              ],
            ],
          ),
        ),
      ),
      actions: [TextButton(onPressed: onClose, child: const Text('关闭'))],
    );
  }
}
