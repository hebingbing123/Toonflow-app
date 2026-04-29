import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../rust_api.dart';
import 'support.dart';

class QualityReviewsWorkbenchDialogViewModel {
  const QualityReviewsWorkbenchDialogViewModel({
    required this.reviews,
    required this.statsSummary,
    required this.stagePassRateSummary,
    required this.reviewDetails,
    required this.statusLine,
    required this.activeFilterQuerySummary,
    required this.activeFilterRequestUrl,
    required this.filterBadCasesOnly,
    required this.filterDeliveryPriorityOnly,
    required this.filterAutoSourceOnly,
    required this.createPassed,
    required this.createBadCase,
    required this.loadingReviews,
    required this.loadingBadCases,
    required this.loadingStats,
    required this.loadingStagePassRate,
    required this.loadingReviewById,
    required this.creatingReview,
    required this.targetTypeFilterCtrl,
    required this.targetIdFilterCtrl,
    required this.jobIdFilterCtrl,
    required this.reviewIdCtrl,
    required this.createProjectIdCtrl,
    required this.createScriptIdCtrl,
    required this.createTargetTypeCtrl,
    required this.createTargetIdCtrl,
    required this.createSourceCtrl,
    required this.createScoreCtrl,
    required this.createCommentsCtrl,
    required this.createBadCaseCategoryCtrl,
  });

  final List<QualityReview> reviews;
  final String? statsSummary;
  final String? stagePassRateSummary;
  final String? reviewDetails;
  final String? statusLine;
  final String? activeFilterQuerySummary;
  final String? activeFilterRequestUrl;
  final bool filterBadCasesOnly;
  final bool filterDeliveryPriorityOnly;
  final bool filterAutoSourceOnly;
  final bool createPassed;
  final bool createBadCase;
  final bool loadingReviews;
  final bool loadingBadCases;
  final bool loadingStats;
  final bool loadingStagePassRate;
  final bool loadingReviewById;
  final bool creatingReview;
  final TextEditingController targetTypeFilterCtrl;
  final TextEditingController targetIdFilterCtrl;
  final TextEditingController jobIdFilterCtrl;
  final TextEditingController reviewIdCtrl;
  final TextEditingController createProjectIdCtrl;
  final TextEditingController createScriptIdCtrl;
  final TextEditingController createTargetTypeCtrl;
  final TextEditingController createTargetIdCtrl;
  final TextEditingController createSourceCtrl;
  final TextEditingController createScoreCtrl;
  final TextEditingController createCommentsCtrl;
  final TextEditingController createBadCaseCategoryCtrl;
}

class QualityReviewsWorkbenchDialogViewCallbacks {
  const QualityReviewsWorkbenchDialogViewCallbacks({
    required this.onLoadReviews,
    required this.onLoadBadCases,
    required this.onLoadDeliveryPriorityReviews,
    required this.onLoadAutoSourceReviews,
    required this.onLoadStats,
    required this.onLoadStagePassRate,
    required this.onLoadReviewById,
    required this.onCreateReview,
    required this.onCreatePassedChanged,
    required this.onCreateBadCaseChanged,
    required this.onSelectReview,
    required this.onClose,
  });

  final VoidCallback onLoadReviews;
  final VoidCallback onLoadBadCases;
  final VoidCallback onLoadDeliveryPriorityReviews;
  final VoidCallback onLoadAutoSourceReviews;
  final VoidCallback onLoadStats;
  final VoidCallback onLoadStagePassRate;
  final VoidCallback onLoadReviewById;
  final VoidCallback onCreateReview;
  final ValueChanged<bool> onCreatePassedChanged;
  final ValueChanged<bool> onCreateBadCaseChanged;
  final ValueChanged<QualityReview> onSelectReview;
  final VoidCallback onClose;
}

class QualityReviewsWorkbenchDialogView extends StatelessWidget {
  const QualityReviewsWorkbenchDialogView({
    super.key,
    required this.model,
    required this.callbacks,
  });

  final QualityReviewsWorkbenchDialogViewModel model;
  final QualityReviewsWorkbenchDialogViewCallbacks callbacks;

  @override
  Widget build(BuildContext context) {
    final outline = Theme.of(context).colorScheme.outline;
    final tokenEfficiencySummary = summarizeTokenEfficiencyFromQualityReviews(
      model.reviews,
    );
    final promptDiagnosticsSummary =
        summarizePromptDiagnosticsFromQualityReviews(model.reviews);
    final memoryScopePressureSummary =
        summarizeMemoryScopePressureFromQualityReviews(model.reviews);
    final repairPlanSummary = summarizeQualityRepairPlanFromReviews(
      model.reviews,
    );
    final activeFilters = [
      if (model.filterBadCasesOnly) '坏例',
      if (model.filterDeliveryPriorityOnly) '命中表演/语气优先',
      if (model.filterAutoSourceOnly) 'auto 样本',
    ];
    final viewportWidth = MediaQuery.sizeOf(context).width;
    final dialogWidth = viewportWidth.isFinite
        ? viewportWidth.clamp(320.0, 840.0)
        : 840.0;
    return AlertDialog(
      title: const Text('质量工作台'),
      content: SizedBox(
        width: dialogWidth,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                model.reviews.isEmpty
                    ? '用同一入口完成评审筛选、坏例查看、统计读取、详情查询和手动创建。'
                    : summarizeQualityReviews(model.reviews),
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: outline),
              ),
              if (model.filterBadCasesOnly ||
                  model.filterDeliveryPriorityOnly ||
                  model.filterAutoSourceOnly) ...[
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (model.filterBadCasesOnly)
                      const Chip(label: Text('只看坏例')),
                    if (model.filterDeliveryPriorityOnly)
                      const Chip(label: Text('只看命中表演/语气优先')),
                    if (model.filterAutoSourceOnly)
                      const Chip(label: Text('source=auto')),
                  ],
                ),
                if (model.activeFilterQuerySummary != null) ...[
                  const SizedBox(height: 6),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: SelectableText(
                          '筛选查询：${model.activeFilterQuerySummary}',
                        ),
                      ),
                      IconButton(
                        tooltip: '复制筛选查询',
                        onPressed: () async {
                          final query = model.activeFilterQuerySummary;
                          if (query == null || query.isEmpty) return;
                          await Clipboard.setData(ClipboardData(text: query));
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('已复制筛选查询')),
                          );
                        },
                        icon: const Icon(Icons.copy_rounded),
                      ),
                      IconButton(
                        tooltip: '复制完整 API URL',
                        onPressed: () async {
                          final url = model.activeFilterRequestUrl;
                          if (url == null || url.isEmpty) return;
                          await Clipboard.setData(ClipboardData(text: url));
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('已复制 API URL')),
                          );
                        },
                        icon: const Icon(Icons.link_rounded),
                      ),
                    ],
                  ),
                ],
              ],
              const SizedBox(height: 12),
              Text('筛选与读取', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 8),
              TextField(
                controller: model.targetTypeFilterCtrl,
                decoration: const InputDecoration(labelText: '筛选 targetType'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: model.targetIdFilterCtrl,
                decoration: const InputDecoration(labelText: '筛选 targetId'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: model.jobIdFilterCtrl,
                decoration: const InputDecoration(labelText: '筛选 jobId'),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton.tonal(
                    onPressed: model.loadingReviews || model.creatingReview
                        ? null
                        : callbacks.onLoadReviews,
                    child: Text(model.loadingReviews ? '加载中…' : '加载评审列表'),
                  ),
                  OutlinedButton(
                    onPressed: model.loadingBadCases || model.creatingReview
                        ? null
                        : callbacks.onLoadBadCases,
                    child: Text(model.loadingBadCases ? '加载中…' : '只看坏例'),
                  ),
                  OutlinedButton(
                    onPressed:
                        model.loadingReviews ||
                            model.loadingBadCases ||
                            model.creatingReview
                        ? null
                        : callbacks.onLoadDeliveryPriorityReviews,
                    child: const Text('只看命中表演/语气优先'),
                  ),
                  OutlinedButton(
                    onPressed:
                        model.loadingReviews ||
                            model.loadingBadCases ||
                            model.creatingReview
                        ? null
                        : callbacks.onLoadAutoSourceReviews,
                    child: const Text('只看 auto 样本'),
                  ),
                  OutlinedButton(
                    onPressed: model.loadingStats
                        ? null
                        : callbacks.onLoadStats,
                    child: Text(model.loadingStats ? '统计中…' : '读取质量统计'),
                  ),
                  OutlinedButton(
                    onPressed: model.loadingStagePassRate
                        ? null
                        : callbacks.onLoadStagePassRate,
                    child: Text(
                      model.loadingStagePassRate ? '读取中…' : '读取阶段通过率',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text('详情查询', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 8),
              TextField(
                controller: model.reviewIdCtrl,
                decoration: const InputDecoration(labelText: '评审 ID'),
              ),
              const SizedBox(height: 8),
              FilledButton.tonal(
                onPressed: model.loadingReviewById || model.creatingReview
                    ? null
                    : callbacks.onLoadReviewById,
                child: Text(model.loadingReviewById ? '读取中…' : '查看评审详情'),
              ),
              const SizedBox(height: 12),
              Text('创建评审', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: model.createProjectIdCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'projectId（可空）',
                        helperText: '填写后低分/坏例可自动写入项目隔离记忆',
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: model.createScriptIdCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'scriptId（可空）',
                        helperText: '与 projectId 一起填写，才会落到脚本级记忆',
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              TextField(
                controller: model.createTargetTypeCtrl,
                decoration: const InputDecoration(labelText: 'targetType'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: model.createTargetIdCtrl,
                decoration: const InputDecoration(labelText: 'targetId'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: model.createSourceCtrl,
                decoration: const InputDecoration(labelText: 'source'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: model.createScoreCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'overallScore'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: model.createCommentsCtrl,
                minLines: 2,
                maxLines: 4,
                decoration: const InputDecoration(labelText: 'comments'),
              ),
              const SizedBox(height: 8),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('passed'),
                value: model.createPassed,
                onChanged: model.creatingReview
                    ? null
                    : callbacks.onCreatePassedChanged,
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('isBadCase'),
                value: model.createBadCase,
                onChanged: model.creatingReview
                    ? null
                    : callbacks.onCreateBadCaseChanged,
              ),
              TextField(
                controller: model.createBadCaseCategoryCtrl,
                decoration: const InputDecoration(labelText: 'badCaseCategory'),
              ),
              const SizedBox(height: 8),
              FilledButton.tonal(
                onPressed: model.creatingReview
                    ? null
                    : callbacks.onCreateReview,
                child: Text(model.creatingReview ? '创建中…' : '创建评审'),
              ),
              if (model.statusLine != null) ...[
                const SizedBox(height: 12),
                SelectableText('状态：${model.statusLine}'),
              ],
              if (model.reviewDetails != null) ...[
                const SizedBox(height: 12),
                SelectableText('评审详情：${model.reviewDetails}'),
              ],
              if (model.statsSummary != null) ...[
                const SizedBox(height: 12),
                SelectableText('质量统计：${model.statsSummary}'),
              ],
              if (model.stagePassRateSummary != null) ...[
                const SizedBox(height: 12),
                SelectableText('阶段通过率：${model.stagePassRateSummary}'),
              ],
              if (promptDiagnosticsSummary != null) ...[
                const SizedBox(height: 12),
                SelectableText('Prompt诊断：$promptDiagnosticsSummary'),
              ],
              if (memoryScopePressureSummary != null) ...[
                const SizedBox(height: 12),
                SelectableText('Scope压力：$memoryScopePressureSummary'),
              ],
              if (repairPlanSummary != null) ...[
                const SizedBox(height: 12),
                SelectableText('修复建议：$repairPlanSummary'),
              ],
              if (tokenEfficiencySummary != null) ...[
                const SizedBox(height: 12),
                SelectableText('Token效率：$tokenEfficiencySummary'),
              ],
              if (model.reviews.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  activeFilters.isEmpty
                      ? '评审 ${model.reviews.length} 条'
                      : '${activeFilters.join(' + ')} ${model.reviews.length} 条',
                  style: Theme.of(context).textTheme.labelLarge,
                ),
                const SizedBox(height: 8),
                ...model.reviews.take(8).map((review) {
                  final diagnosticSummary =
                      summarizeQualityReviewPromptDiagnostics(review);
                  final repairSuggestions =
                      buildQualityReviewRepairSuggestions(review);
                  return ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      '${review.targetType} · ${review.source} · score=${review.overallScore ?? "n/a"}',
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(formatQualityReviewCoreDetails(review)),
                        if (diagnosticSummary != null)
                          Text(
                            diagnosticSummary,
                            style: Theme.of(
                              context,
                            ).textTheme.bodySmall?.copyWith(color: outline),
                          ),
                        if (repairSuggestions.isNotEmpty)
                          Text(
                            '建议：${repairSuggestions.join(' / ')}',
                            style: Theme.of(
                              context,
                            ).textTheme.bodySmall?.copyWith(color: outline),
                          ),
                      ],
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (review.memoryDeliveryPriorityApplied == true)
                          const Padding(
                            padding: EdgeInsets.only(right: 8),
                            child: Chip(
                              label: Text('delivery'),
                              visualDensity: VisualDensity.compact,
                            ),
                          ),
                        if (review.source == 'auto')
                          const Padding(
                            padding: EdgeInsets.only(right: 8),
                            child: Chip(
                              label: Text('auto'),
                              visualDensity: VisualDensity.compact,
                            ),
                          ),
                        const Icon(Icons.chevron_right),
                      ],
                    ),
                    onTap: () => callbacks.onSelectReview(review),
                  );
                }),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: callbacks.onClose, child: const Text('关闭')),
      ],
    );
  }
}
