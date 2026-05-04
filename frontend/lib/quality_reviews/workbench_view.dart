import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../rust_api.dart';
import 'support.dart';

part 'workbench_view/review_widgets.dart';

class QualityReviewsWorkbenchDialogViewModel {
  const QualityReviewsWorkbenchDialogViewModel({
    required this.reviews,
    required this.statsSummary,
    required this.scopeInsightsSummary,
    required this.tokenEfficiencySummary,
    required this.tokenEfficiencyActionPlan,
    required this.tokenEfficiencyExecutionChecklist,
    required this.tokenEfficiencySamplesSummary,
    required this.stagePassRateSummary,
    required this.stageGradeRows,
    required this.badCaseStatsSummary,
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
    required this.loadingScopeInsights,
    required this.loadingTokenEfficiency,
    required this.loadingTokenEfficiencySamples,
    required this.loadingStagePassRate,
    required this.loadingBadCaseStats,
    required this.loadingReviewById,
    required this.creatingReview,
    required this.projectIdFilterCtrl,
    required this.scriptIdFilterCtrl,
    required this.targetTypeFilterCtrl,
    required this.targetIdFilterCtrl,
    required this.jobIdFilterCtrl,
    required this.stageFilterCtrl,
    required this.gradeFilterCtrl,
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
  final String? scopeInsightsSummary;
  final String? tokenEfficiencySummary;
  final String? tokenEfficiencyActionPlan;
  final String? tokenEfficiencyExecutionChecklist;
  final String? tokenEfficiencySamplesSummary;
  final String? stagePassRateSummary;
  final List<StageGradeDistributionRow> stageGradeRows;
  final String? badCaseStatsSummary;
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
  final bool loadingScopeInsights;
  final bool loadingTokenEfficiency;
  final bool loadingTokenEfficiencySamples;
  final bool loadingStagePassRate;
  final bool loadingBadCaseStats;
  final bool loadingReviewById;
  final bool creatingReview;
  final TextEditingController projectIdFilterCtrl;
  final TextEditingController scriptIdFilterCtrl;
  final TextEditingController targetTypeFilterCtrl;
  final TextEditingController targetIdFilterCtrl;
  final TextEditingController jobIdFilterCtrl;
  final TextEditingController stageFilterCtrl;
  final TextEditingController gradeFilterCtrl;
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
    required this.onLoadScopeInsights,
    required this.onLoadTokenEfficiency,
    required this.onLoadTokenEfficiencySamples,
    required this.onLoadStagePassRate,
    required this.onLoadBadCaseStats,
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
  final VoidCallback onLoadScopeInsights;
  final VoidCallback onLoadTokenEfficiency;
  final VoidCallback onLoadTokenEfficiencySamples;
  final VoidCallback onLoadStagePassRate;
  final VoidCallback onLoadBadCaseStats;
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
    final memoryOptimizationSavingsSummary =
        summarizeMemoryOptimizationSavingsFromQualityReviews(model.reviews);
    final scopeRepairQueueSummary = summarizeScopeRepairQueueFromQualityReviews(
      model.reviews,
    );
    final repairPlanSummary = summarizeQualityRepairPlanFromReviews(
      model.reviews,
    );
    final activeFilters = [
      if (model.filterBadCasesOnly) '坏例',
      if (model.filterDeliveryPriorityOnly) '命中表演/语气优先',
      if (model.filterAutoSourceOnly) 'auto 样本',
      if (model.stageFilterCtrl.text.trim().isNotEmpty &&
          model.stageFilterCtrl.text.trim() != 'all')
        '阶段 ${_qualityStageLabel(model.stageFilterCtrl.text.trim())}',
      if (model.gradeFilterCtrl.text.trim().isNotEmpty &&
          model.gradeFilterCtrl.text.trim() != 'all')
        '等级 ${model.gradeFilterCtrl.text.trim()}',
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
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: model.projectIdFilterCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: '筛选 projectId',
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: model.scriptIdFilterCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: '筛选 scriptId',
                      ),
                    ),
                  ),
                ],
              ),
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
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: model.stageFilterCtrl.text.trim().isEmpty
                          ? 'all'
                          : model.stageFilterCtrl.text.trim(),
                      decoration: const InputDecoration(labelText: '阶段筛选'),
                      items: _qualityStageOptions
                          .map(
                            (value) => DropdownMenuItem<String>(
                              value: value,
                              child: Text(_qualityStageLabel(value)),
                            ),
                          )
                          .toList(growable: false),
                      onChanged: (value) {
                        if (value != null) {
                          model.stageFilterCtrl.text = value;
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: model.gradeFilterCtrl.text.trim().isEmpty
                          ? 'all'
                          : model.gradeFilterCtrl.text.trim(),
                      decoration: const InputDecoration(labelText: '等级筛选'),
                      items: _qualityGradeOptions
                          .map(
                            (value) => DropdownMenuItem<String>(
                              value: value,
                              child: Text(value == 'all' ? '全部' : value),
                            ),
                          )
                          .toList(growable: false),
                      onChanged: (value) {
                        if (value != null) {
                          model.gradeFilterCtrl.text = value;
                        }
                      },
                    ),
                  ),
                ],
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
                    onPressed: model.loadingScopeInsights
                        ? null
                        : callbacks.onLoadScopeInsights,
                    child: Text(
                      model.loadingScopeInsights ? '汇总中…' : '读取Scope榜单',
                    ),
                  ),
                  OutlinedButton(
                    onPressed: model.loadingTokenEfficiency
                        ? null
                        : callbacks.onLoadTokenEfficiency,
                    child: Text(
                      model.loadingTokenEfficiency ? '读取中…' : '读取Token效率',
                    ),
                  ),
                  OutlinedButton(
                    onPressed: model.loadingTokenEfficiencySamples
                        ? null
                        : callbacks.onLoadTokenEfficiencySamples,
                    child: Text(
                      model.loadingTokenEfficiencySamples
                          ? '读取中…'
                          : '读取省Token样本',
                    ),
                  ),
                  OutlinedButton(
                    onPressed: model.loadingStagePassRate
                        ? null
                        : callbacks.onLoadStagePassRate,
                    child: Text(
                      model.loadingStagePassRate ? '读取中…' : '读取阶段通过率',
                    ),
                  ),
                  OutlinedButton(
                    onPressed: model.loadingBadCaseStats
                        ? null
                        : callbacks.onLoadBadCaseStats,
                    child: Text(model.loadingBadCaseStats ? '读取中…' : '读取坏例分布'),
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
              if (model.scopeInsightsSummary != null) ...[
                const SizedBox(height: 12),
                SelectableText('Scope榜单：${model.scopeInsightsSummary}'),
              ],
              if (model.tokenEfficiencySummary != null) ...[
                const SizedBox(height: 12),
                SelectableText('Token聚合：${model.tokenEfficiencySummary}'),
              ],
              if (model.tokenEfficiencyActionPlan != null) ...[
                const SizedBox(height: 12),
                SelectableText('记忆动作：${model.tokenEfficiencyActionPlan}'),
              ],
              if (model.tokenEfficiencyExecutionChecklist != null) ...[
                const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: SelectableText(
                        model.tokenEfficiencyExecutionChecklist!,
                      ),
                    ),
                    IconButton(
                      tooltip: '复制执行清单',
                      onPressed: () async {
                        final checklist =
                            model.tokenEfficiencyExecutionChecklist;
                        if (checklist == null || checklist.isEmpty) return;
                        await Clipboard.setData(ClipboardData(text: checklist));
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('已复制执行清单')),
                        );
                      },
                      icon: const Icon(Icons.copy_all_rounded),
                    ),
                  ],
                ),
              ],
              if (model.tokenEfficiencySamplesSummary != null) ...[
                const SizedBox(height: 12),
                SelectableText(
                  '省Token样本：${model.tokenEfficiencySamplesSummary}',
                ),
              ],
              if (model.stagePassRateSummary != null) ...[
                const SizedBox(height: 12),
                SelectableText('阶段通过率：${model.stagePassRateSummary}'),
              ],
              if (model.badCaseStatsSummary != null) ...[
                const SizedBox(height: 12),
                SelectableText('坏例分布：${model.badCaseStatsSummary}'),
              ],
              if (model.stageGradeRows.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text('等级分布', style: Theme.of(context).textTheme.labelLarge),
                const SizedBox(height: 6),
                ...model.stageGradeRows.map(
                  (row) => ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      '${_qualityStageLabel(row.stage)} · A ${row.gradeACount} / B ${row.gradeBCount} / C ${row.gradeCCount} / D ${row.gradeDCount}',
                    ),
                    subtitle: Text(
                      '总计 ${row.totalCount} · A+B 通过率 ${row.passRatePercent.toStringAsFixed(1)}%',
                    ),
                  ),
                ),
              ],
              if (promptDiagnosticsSummary != null) ...[
                const SizedBox(height: 12),
                SelectableText('Prompt诊断：$promptDiagnosticsSummary'),
              ],
              if (memoryScopePressureSummary != null) ...[
                const SizedBox(height: 12),
                SelectableText('Scope压力：$memoryScopePressureSummary'),
              ],
              if (memoryOptimizationSavingsSummary != null) ...[
                const SizedBox(height: 12),
                SelectableText('记忆瘦身：$memoryOptimizationSavingsSummary'),
              ],
              if (scopeRepairQueueSummary != null) ...[
                const SizedBox(height: 12),
                SelectableText('优先修复：$scopeRepairQueueSummary'),
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
                  final writebackSummary =
                      summarizeQualityReviewMemoryWriteback(review);
                  final repairSuggestions = buildQualityReviewRepairSuggestions(
                    review,
                  );
                  return ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      '${review.targetType} · ${review.source} · score=${review.overallScore ?? "n/a"}',
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          [
                            if ((review.stage ?? '').trim().isNotEmpty)
                              '阶段 ${_qualityStageLabel(review.stage!.trim())}',
                            if ((review.grade ?? '').trim().isNotEmpty)
                              '等级 ${review.grade}',
                          ].join(' · '),
                        ),
                        Text(formatQualityReviewCoreDetails(review)),
                        if (diagnosticSummary != null)
                          Text(
                            diagnosticSummary,
                            style: Theme.of(
                              context,
                            ).textTheme.bodySmall?.copyWith(color: outline),
                          ),
                        if (writebackSummary != null)
                          Text(
                            writebackSummary,
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
                        if ((review.grade ?? '').trim().isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: Chip(
                              label: Text(review.grade!.trim()),
                              backgroundColor: _qualityGradeColor(
                                context,
                                review.grade!.trim(),
                              ),
                              visualDensity: VisualDensity.compact,
                            ),
                          ),
                        if (writebackSummary != null)
                          const Padding(
                            padding: EdgeInsets.only(right: 8),
                            child: Chip(
                              label: Text('memory'),
                              visualDensity: VisualDensity.compact,
                            ),
                          ),
                        const Icon(Icons.chevron_right),
                      ],
                    ),
                    onTap: () => callbacks.onSelectReview(review),
                  );
                }),
              ] else if (activeFilters.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  '当前筛选条件下无评审记录',
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(color: outline),
                ),
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
