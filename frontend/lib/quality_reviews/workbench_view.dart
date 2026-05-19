import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../design_system/components/studio_code_dropdown_field.dart';
import '../l10n/app_localizations.dart';
import '../rust_api.dart';
import 'enum_labels.dart';
import 'dimension_score_form.dart';
import 'field_styling.dart';
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
    required this.badCaseStatItems,
    required this.reviewDetails,
    required this.selectedReview,
    required this.createDimensionScores,
    required this.statusLine,
    required this.initialProjectScopeSummary,
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
    required this.suggestedActionFilterCtrl,
    required this.reviewIdCtrl,
    required this.createProjectIdCtrl,
    required this.createScriptIdCtrl,
    required this.createTargetTypeCtrl,
    required this.createTargetIdCtrl,
    required this.createSourceCtrl,
    required this.createScoreCtrl,
    required this.createStageCtrl,
    required this.createGradeCtrl,
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
  final List<BadCaseStatItem> badCaseStatItems;
  final String? reviewDetails;
  final QualityReview? selectedReview;
  final Map<String, int>? createDimensionScores;
  final String? statusLine;
  final String? initialProjectScopeSummary;
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
  final TextEditingController suggestedActionFilterCtrl;
  final TextEditingController reviewIdCtrl;
  final TextEditingController createProjectIdCtrl;
  final TextEditingController createScriptIdCtrl;
  final TextEditingController createTargetTypeCtrl;
  final TextEditingController createTargetIdCtrl;
  final TextEditingController createSourceCtrl;
  final TextEditingController createScoreCtrl;
  final TextEditingController createStageCtrl;
  final TextEditingController createGradeCtrl;
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
    required this.onCreateDimensionScoresChanged,
    required this.onCreatePassedChanged,
    required this.onCreateBadCaseChanged,
    required this.onSelectReview,
    required this.onApplySuggestedAction,
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
  final ValueChanged<Map<String, int>?> onCreateDimensionScoresChanged;
  final ValueChanged<bool> onCreatePassedChanged;
  final ValueChanged<bool> onCreateBadCaseChanged;
  final ValueChanged<QualityReview> onSelectReview;
  final ValueChanged<QualityReview> onApplySuggestedAction;
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
    final l10n = resolveAppLocalizationsForErrors(context);
    final muted = qualityReviewsMutedColor(context);
    final tokenEfficiencySummary = summarizeTokenEfficiencyFromQualityReviews(
      model.reviews,
      l10n: l10n,
    );
    final promptDiagnosticsSummary =
        summarizePromptDiagnosticsFromQualityReviews(model.reviews, l10n: l10n);
    final memoryScopePressureSummary =
        summarizeMemoryScopePressureFromQualityReviews(
          model.reviews,
          l10n: l10n,
        );
    final memoryOptimizationSavingsSummary =
        summarizeMemoryOptimizationSavingsFromQualityReviews(
          model.reviews,
          l10n: l10n,
        );
    final scopeRepairQueueSummary = summarizeScopeRepairQueueFromQualityReviews(
      model.reviews,
      l10n: l10n,
    );
    final repairPlanSummary = summarizeQualityRepairPlanFromReviews(
      model.reviews,
      l10n: l10n,
    );
    final suggestedActionSummary = summarizeSuggestedActionHotspotsFromReviews(
      model.reviews,
      l10n: l10n,
    );
    final activeFilters = [
      if (model.filterBadCasesOnly) l10n.qualityReviewsFilterBadCase,
      if (model.filterDeliveryPriorityOnly)
        l10n.qualityReviewsFilterDeliveryPriorityHit,
      if (model.filterAutoSourceOnly) l10n.qualityReviewsFilterAutoSamples,
      if (model.stageFilterCtrl.text.trim().isNotEmpty &&
          model.stageFilterCtrl.text.trim() != 'all')
        l10n.qualityReviewsFilterStage(
          _qualityStageLabel(model.stageFilterCtrl.text.trim(), l10n),
        ),
      if (model.gradeFilterCtrl.text.trim().isNotEmpty &&
          model.gradeFilterCtrl.text.trim() != 'all')
        l10n.qualityReviewsFilterGrade(model.gradeFilterCtrl.text.trim()),
      if (model.suggestedActionFilterCtrl.text.trim().isNotEmpty &&
          model.suggestedActionFilterCtrl.text.trim() != 'all')
        'suggested=${model.suggestedActionFilterCtrl.text.trim()}',
    ];
    final viewportWidth = MediaQuery.sizeOf(context).width;
    final dialogWidth = viewportWidth.isFinite
        ? viewportWidth.clamp(320.0, 840.0)
        : 840.0;
    return Theme(
      data: qualityReviewsFormTheme(context),
      child: AlertDialog(
      title: Text(l10n.qualityReviewsWorkbenchTitle),
      content: SizedBox(
        width: dialogWidth,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                model.reviews.isEmpty
                    ? l10n.qualityReviewsWorkbenchIntro
                    : summarizeQualityReviews(model.reviews, l10n: l10n),
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: muted),
              ),
              if (model.initialProjectScopeSummary != null) ...[
                const SizedBox(height: 6),
                SelectableText(
                  l10n.qualityReviewsScopeSeedLine(
                    model.initialProjectScopeSummary!,
                  ),
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: muted),
                ),
              ],
              if (model.filterBadCasesOnly ||
                  model.filterDeliveryPriorityOnly ||
                  model.filterAutoSourceOnly) ...[
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (model.filterBadCasesOnly)
                      Chip(label: Text(l10n.qualityReviewsOnlyBadCases)),
                    if (model.filterDeliveryPriorityOnly)
                      Chip(
                        label: Text(l10n.qualityReviewsOnlyDeliveryPriorityHit),
                      ),
                    if (model.filterAutoSourceOnly)
                      Chip(label: Text(l10n.qualityReviewsSourceAuto)),
                  ],
                ),
                if (model.activeFilterQuerySummary != null) ...[
                  const SizedBox(height: 6),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: SelectableText(
                          l10n.qualityReviewsFilterQueryLine(
                            model.activeFilterQuerySummary!,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: l10n.qualityReviewsCopyFilterQuery,
                        onPressed: () async {
                          final query = model.activeFilterQuerySummary;
                          if (query == null || query.isEmpty) return;
                          await Clipboard.setData(ClipboardData(text: query));
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                l10n.qualityReviewsCopiedFilterQuery,
                              ),
                            ),
                          );
                        },
                        icon: const Icon(Icons.copy_rounded),
                      ),
                      IconButton(
                        tooltip: l10n.qualityReviewsCopyApiUrl,
                        onPressed: () async {
                          final url = model.activeFilterRequestUrl;
                          if (url == null || url.isEmpty) return;
                          await Clipboard.setData(ClipboardData(text: url));
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(l10n.qualityReviewsCopiedApiUrl),
                            ),
                          );
                        },
                        icon: const Icon(Icons.link_rounded),
                      ),
                    ],
                  ),
                ],
              ],
              const SizedBox(height: 12),
              Text(
                l10n.qualityReviewsFilterAndReadSection,
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: model.projectIdFilterCtrl,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: l10n.qualityReviewsFilterProjectId,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: model.scriptIdFilterCtrl,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: l10n.qualityReviewsFilterScriptId,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              StudioCodeDropdownField(
                width: null,
                value: model.targetTypeFilterCtrl.text.trim(),
                labelText: l10n.qualityReviewsFilterTargetType,
                codes: qualityTargetTypeFilterOptions,
                labelForValue: (code) =>
                    qualityTargetTypeFilterLabel(code, l10n),
                onChanged: (value) {
                  model.targetTypeFilterCtrl.text = value;
                },
              ),
              const SizedBox(height: 8),
              TextField(
                controller: model.targetIdFilterCtrl,
                decoration: InputDecoration(
                  labelText: l10n.qualityReviewsFilterTargetId,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: model.jobIdFilterCtrl,
                decoration: InputDecoration(
                  labelText: l10n.qualityReviewsFilterJobId,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: model.stageFilterCtrl.text.trim().isEmpty
                          ? 'all'
                          : model.stageFilterCtrl.text.trim(),
                      decoration: InputDecoration(
                        labelText: l10n.qualityReviewsFilterStageLabel,
                      ),
                      items: _qualityStageOptions
                          .map(
                            (value) => DropdownMenuItem<String>(
                              value: value,
                              child: Text(_qualityStageLabel(value, l10n)),
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
                      decoration: InputDecoration(
                        labelText: l10n.qualityReviewsFilterGradeLabel,
                      ),
                      items: _qualityGradeOptions
                          .map(
                            (value) => DropdownMenuItem<String>(
                              value: value,
                              child: Text(_qualityGradeLabel(value, l10n)),
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
              DropdownButtonFormField<String>(
                initialValue:
                    model.suggestedActionFilterCtrl.text.trim().isEmpty
                    ? 'all'
                    : model.suggestedActionFilterCtrl.text.trim(),
                decoration: InputDecoration(
                  labelText: l10n.qualityReviewsFilterSuggestedActionLabel,
                ),
                items: _qualitySuggestedActionOptions
                    .map(
                      (value) => DropdownMenuItem<String>(
                        value: value,
                        child: Text(_qualitySuggestedActionLabel(value, l10n)),
                      ),
                    )
                    .toList(growable: false),
                onChanged: (value) {
                  if (value != null) {
                    model.suggestedActionFilterCtrl.text = value;
                  }
                },
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
                    child: Text(
                      model.loadingReviews
                          ? l10n.projectsBusyProcessing
                          : l10n.qualityReviewsLoadReviewList,
                    ),
                  ),
                  OutlinedButton(
                    onPressed: model.loadingBadCases || model.creatingReview
                        ? null
                        : callbacks.onLoadBadCases,
                    child: Text(
                      model.loadingBadCases
                          ? l10n.projectsBusyProcessing
                          : l10n.qualityReviewsOnlyBadCases,
                    ),
                  ),
                  OutlinedButton(
                    onPressed:
                        model.loadingReviews ||
                            model.loadingBadCases ||
                            model.creatingReview
                        ? null
                        : callbacks.onLoadDeliveryPriorityReviews,
                    child: Text(l10n.qualityReviewsOnlyDeliveryPriorityHit),
                  ),
                  OutlinedButton(
                    onPressed:
                        model.loadingReviews ||
                            model.loadingBadCases ||
                            model.creatingReview
                        ? null
                        : callbacks.onLoadAutoSourceReviews,
                    child: Text(l10n.qualityReviewsOnlyAutoSamples),
                  ),
                  OutlinedButton(
                    onPressed: model.loadingStats
                        ? null
                        : callbacks.onLoadStats,
                    child: Text(
                      model.loadingStats
                          ? l10n.qualityReviewsSummarizing
                          : l10n.qualityReviewsLoadStats,
                    ),
                  ),
                  OutlinedButton(
                    onPressed: model.loadingScopeInsights
                        ? null
                        : callbacks.onLoadScopeInsights,
                    child: Text(
                      model.loadingScopeInsights
                          ? l10n.qualityReviewsSummarizing
                          : l10n.qualityReviewsLoadScopeLeaderboard,
                    ),
                  ),
                  OutlinedButton(
                    onPressed: model.loadingTokenEfficiency
                        ? null
                        : callbacks.onLoadTokenEfficiency,
                    child: Text(
                      model.loadingTokenEfficiency
                          ? l10n.qualityReviewsLoading
                          : l10n.qualityReviewsLoadTokenEfficiency,
                    ),
                  ),
                  OutlinedButton(
                    onPressed: model.loadingTokenEfficiencySamples
                        ? null
                        : callbacks.onLoadTokenEfficiencySamples,
                    child: Text(
                      model.loadingTokenEfficiencySamples
                          ? l10n.qualityReviewsLoading
                          : l10n.qualityReviewsLoadTokenSavingSamples,
                    ),
                  ),
                  OutlinedButton(
                    onPressed: model.loadingStagePassRate
                        ? null
                        : callbacks.onLoadStagePassRate,
                    child: Text(
                      model.loadingStagePassRate
                          ? l10n.qualityReviewsLoading
                          : l10n.qualityReviewsLoadStagePassRate,
                    ),
                  ),
                  OutlinedButton(
                    onPressed: model.loadingBadCaseStats
                        ? null
                        : callbacks.onLoadBadCaseStats,
                    child: Text(
                      model.loadingBadCaseStats
                          ? l10n.qualityReviewsLoading
                          : l10n.qualityReviewsLoadBadCaseDistribution,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                l10n.qualityReviewsDetailsQuerySection,
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 8),
              TextField(
                controller: model.reviewIdCtrl,
                decoration: InputDecoration(
                  labelText: l10n.qualityReviewsReviewId,
                ),
              ),
              const SizedBox(height: 8),
              FilledButton.tonal(
                onPressed: model.loadingReviewById || model.creatingReview
                    ? null
                    : callbacks.onLoadReviewById,
                child: Text(
                  model.loadingReviewById
                      ? l10n.qualityReviewsLoading
                      : l10n.qualityReviewsViewReviewDetails,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                l10n.qualityReviewsCreateReviewSection,
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: model.createProjectIdCtrl,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: l10n.qualityReviewsCreateProjectIdOptional,
                        helperText: l10n.qualityReviewsCreateProjectIdHelper,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: model.createScriptIdCtrl,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: l10n.qualityReviewsCreateScriptIdOptional,
                        helperText: l10n.qualityReviewsCreateScriptIdHelper,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              StudioCodeDropdownField(
                width: null,
                value: model.createTargetTypeCtrl.text.trim().isEmpty
                    ? qualityTargetTypeOptions.first
                    : model.createTargetTypeCtrl.text.trim(),
                labelText: l10n.qualityReviewsFieldTargetType,
                codes: qualityTargetTypeOptions,
                labelForValue: (code) => qualityTargetTypeLabel(code, l10n),
                onChanged: (value) {
                  model.createTargetTypeCtrl.text = value;
                },
              ),
              const SizedBox(height: 8),
              TextField(
                controller: model.createTargetIdCtrl,
                decoration: InputDecoration(
                  labelText: l10n.qualityReviewsFieldTargetId,
                ),
              ),
              const SizedBox(height: 8),
              StudioCodeDropdownField(
                width: null,
                value: model.createSourceCtrl.text.trim().isEmpty
                    ? qualitySourceOptions.first
                    : model.createSourceCtrl.text.trim(),
                labelText: l10n.qualityReviewsFieldSource,
                codes: qualitySourceOptions,
                labelForValue: (code) => qualitySourceLabel(code, l10n),
                onChanged: (value) {
                  model.createSourceCtrl.text = value;
                },
              ),
              const SizedBox(height: 8),
              TextField(
                controller: model.createScoreCtrl,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: l10n.qualityReviewsFieldOverallScore,
                ),
              ),
              const SizedBox(height: 8),
              DimensionScoreFormWidget(
                initialScores: model.createDimensionScores,
                onChanged: callbacks.onCreateDimensionScoresChanged,
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: StudioCodeDropdownField(
                      width: null,
                      value: model.createStageCtrl.text.trim().isEmpty
                          ? qualityCreateStageOptions.first
                          : model.createStageCtrl.text.trim(),
                      labelText: l10n.qualityReviewsFieldStage,
                      codes: qualityCreateStageOptions,
                      labelForValue: (code) =>
                          _qualityStageLabel(code, l10n),
                      onChanged: (value) {
                        model.createStageCtrl.text = value;
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: StudioCodeDropdownField(
                      width: null,
                      value: model.createGradeCtrl.text.trim().isEmpty
                          ? qualityCreateGradeOptions.first
                          : model.createGradeCtrl.text.trim(),
                      labelText: l10n.qualityReviewsFieldGrade,
                      codes: qualityCreateGradeOptions,
                      labelForValue: (code) =>
                          _qualityGradeLabel(code, l10n),
                      onChanged: (value) {
                        model.createGradeCtrl.text = value;
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              TextField(
                controller: model.createCommentsCtrl,
                minLines: 2,
                maxLines: 4,
                decoration: InputDecoration(
                  labelText: l10n.qualityReviewsFieldComments,
                ),
              ),
              const SizedBox(height: 8),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(l10n.qualityReviewsFieldPassed),
                value: model.createPassed,
                onChanged: model.creatingReview
                    ? null
                    : callbacks.onCreatePassedChanged,
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(l10n.qualityReviewsFieldIsBadCase),
                value: model.createBadCase,
                onChanged: model.creatingReview
                    ? null
                    : callbacks.onCreateBadCaseChanged,
              ),
              StudioCodeDropdownField(
                width: null,
                value: model.createBadCaseCategoryCtrl.text.trim(),
                labelText: l10n.qualityReviewsFieldBadCaseCategory,
                codes: qualityBadCaseCategoryCreateOptions,
                labelForValue: (code) =>
                    qualityBadCaseCategoryLabel(code, l10n),
                onChanged: (value) {
                  model.createBadCaseCategoryCtrl.text = value;
                },
              ),
              const SizedBox(height: 8),
              FilledButton.tonal(
                onPressed: model.creatingReview
                    ? null
                    : callbacks.onCreateReview,
                child: Text(
                  model.creatingReview
                      ? l10n.qualityReviewsCreating
                      : l10n.qualityReviewsCreateReview,
                ),
              ),
              if (model.statusLine != null) ...[
                const SizedBox(height: 12),
                SelectableText(
                  l10n.qualityReviewsStatusLine(model.statusLine!),
                ),
              ],
              if (model.reviewDetails != null) ...[
                const SizedBox(height: 12),
                SelectableText(
                  l10n.qualityReviewsSummaryReviewDetails(model.reviewDetails!),
                ),
              ],
              if (model.selectedReview != null) ...[
                const SizedBox(height: 8),
                DimensionScoreDisplayWidget(
                  scores: model.selectedReview!.dimensionScores,
                ),
              ],
              if (model.statsSummary != null) ...[
                const SizedBox(height: 12),
                SelectableText(
                  l10n.qualityReviewsSummaryStats(model.statsSummary!),
                ),
              ],
              if (model.scopeInsightsSummary != null) ...[
                const SizedBox(height: 12),
                SelectableText(
                  l10n.qualityReviewsSummaryScopeInsights(
                    model.scopeInsightsSummary!,
                  ),
                ),
              ],
              if (model.tokenEfficiencySummary != null) ...[
                const SizedBox(height: 12),
                SelectableText(
                  l10n.qualityReviewsSummaryTokenAggregate(
                    model.tokenEfficiencySummary!,
                  ),
                ),
              ],
              if (model.tokenEfficiencyActionPlan != null) ...[
                const SizedBox(height: 12),
                SelectableText(
                  l10n.qualityReviewsSummaryMemoryAction(
                    model.tokenEfficiencyActionPlan!,
                  ),
                ),
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
                      tooltip: l10n.qualityReviewsCopyExecutionChecklist,
                      onPressed: () async {
                        final checklist =
                            model.tokenEfficiencyExecutionChecklist;
                        if (checklist == null || checklist.isEmpty) return;
                        await Clipboard.setData(ClipboardData(text: checklist));
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              l10n.qualityReviewsCopiedExecutionChecklist,
                            ),
                          ),
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
                  l10n.qualityReviewsSummaryTokenSavingSamples(
                    model.tokenEfficiencySamplesSummary!,
                  ),
                ),
              ],
              if (model.stagePassRateSummary != null) ...[
                const SizedBox(height: 12),
                SelectableText(
                  l10n.qualityReviewsSummaryStagePassRate(
                    model.stagePassRateSummary!,
                  ),
                ),
              ],
              if (model.badCaseStatsSummary != null) ...[
                const SizedBox(height: 12),
                SelectableText(
                  l10n.qualityReviewsSummaryBadCaseDistribution(
                    model.badCaseStatsSummary!,
                  ),
                ),
              ],
              if (model.loadingBadCaseStats ||
                  model.badCaseStatItems.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  l10n.qualityReviewsLoadBadCaseDistribution,
                  style: Theme.of(context).textTheme.labelLarge,
                ),
                const SizedBox(height: 4),
                BadCaseStatsPanel(
                  items: model.badCaseStatItems,
                  loading: model.loadingBadCaseStats,
                  l10n: l10n,
                ),
              ],
              if (model.stageGradeRows.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  l10n.qualityReviewsGradeDistribution,
                  style: Theme.of(context).textTheme.labelLarge,
                ),
                const SizedBox(height: 6),
                ...model.stageGradeRows.map(
                  (row) => ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      l10n.qualityReviewsStageGradeRow(
                        _qualityStageLabel(row.stage, l10n),
                        row.gradeACount,
                        row.gradeBCount,
                        row.gradeCCount,
                        row.gradeDCount,
                      ),
                    ),
                    subtitle: Text(
                      l10n.qualityReviewsTotalAndPassRate(
                        row.totalCount,
                        row.passRatePercent.toStringAsFixed(1),
                      ),
                    ),
                  ),
                ),
              ],
              if (promptDiagnosticsSummary != null) ...[
                const SizedBox(height: 12),
                SelectableText(
                  l10n.qualityReviewsPromptDiagnostics(
                    promptDiagnosticsSummary,
                  ),
                ),
              ],
              if (memoryScopePressureSummary != null) ...[
                const SizedBox(height: 12),
                SelectableText(
                  l10n.qualityReviewsScopePressure(memoryScopePressureSummary),
                ),
              ],
              if (memoryOptimizationSavingsSummary != null) ...[
                const SizedBox(height: 12),
                SelectableText(
                  l10n.qualityReviewsMemorySlimming(
                    memoryOptimizationSavingsSummary,
                  ),
                ),
              ],
              if (scopeRepairQueueSummary != null) ...[
                const SizedBox(height: 12),
                SelectableText(
                  l10n.qualityReviewsPriorityFix(scopeRepairQueueSummary),
                ),
              ],
              if (repairPlanSummary != null) ...[
                const SizedBox(height: 12),
                SelectableText(
                  l10n.qualityReviewsRepairSuggestions(repairPlanSummary),
                ),
              ],
              if (suggestedActionSummary != null) ...[
                const SizedBox(height: 12),
                SelectableText(
                  'Suggested action hotspots: $suggestedActionSummary',
                ),
              ],
              if (tokenEfficiencySummary != null) ...[
                const SizedBox(height: 12),
                SelectableText(
                  l10n.qualityReviewsSummaryTokenEfficiency(
                    tokenEfficiencySummary,
                  ),
                ),
              ],
              if (model.reviews.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  activeFilters.isEmpty
                      ? l10n.qualityReviewsCount(model.reviews.length)
                      : l10n.qualityReviewsFilterCountLine(
                          activeFilters.join(' + '),
                          model.reviews.length,
                        ),
                  style: Theme.of(context).textTheme.labelLarge,
                ),
                const SizedBox(height: 8),
                ...model.reviews.take(8).map((review) {
                  final diagnosticSummary =
                      summarizeQualityReviewPromptDiagnostics(
                        review,
                        l10n: l10n,
                      );
                  final writebackSummary =
                      summarizeQualityReviewMemoryWriteback(review, l10n: l10n);
                  final repairSuggestions = buildQualityReviewRepairSuggestions(
                    review,
                    l10n: l10n,
                  );
                  return ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      l10n.qualityReviewsReviewRowTitle(
                        qualityTargetTypeLabel(review.targetType, l10n),
                        review.source,
                        (review.overallScore ?? l10n.qualityReviewsNotAvailable)
                            .toString(),
                      ),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          [
                            if ((review.stage ?? '').trim().isNotEmpty)
                              l10n.qualityReviewsFilterStage(
                                _qualityStageLabel(review.stage!.trim(), l10n),
                              ),
                            if ((review.grade ?? '').trim().isNotEmpty)
                              l10n.qualityReviewsFilterGrade(review.grade!),
                          ].join(' · '),
                        ),
                        Text(formatQualityReviewCoreDetails(review)),
                        if (diagnosticSummary != null)
                          Text(
                            diagnosticSummary,
                            style: Theme.of(
                              context,
                            ).textTheme.bodySmall?.copyWith(color: muted),
                          ),
                        if (writebackSummary != null)
                          Text(
                            writebackSummary,
                            style: Theme.of(
                              context,
                            ).textTheme.bodySmall?.copyWith(color: muted),
                          ),
                        if (repairSuggestions.isNotEmpty)
                          Text(
                            l10n.qualityReviewsSuggestions(
                              repairSuggestions.join(' / '),
                            ),
                            style: Theme.of(
                              context,
                            ).textTheme.bodySmall?.copyWith(color: muted),
                          ),
                      ],
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (review.memoryDeliveryPriorityApplied == true)
                          Padding(
                            padding: EdgeInsets.only(right: 8),
                            child: Chip(
                              label: Text(l10n.qualityReviewsDeliveryTag),
                              visualDensity: VisualDensity.compact,
                            ),
                          ),
                        if (review.source == 'auto')
                          Padding(
                            padding: EdgeInsets.only(right: 8),
                            child: Chip(
                              label: Text(l10n.qualityReviewsAutoTag),
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
                        if ((review.suggestedAction ?? '').trim().isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: Chip(
                              label: Text(
                                _qualitySuggestedActionLabel(
                                  review.suggestedAction!.trim(),
                                  l10n,
                                ),
                              ),
                              visualDensity: VisualDensity.compact,
                            ),
                          ),
                        if (hasDimensionRisk(review.dimensionScores))
                          Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: Chip(
                              label: Text(l10n.qualityReviewsDimensionRiskBadge),
                              visualDensity: VisualDensity.compact,
                              backgroundColor: Theme.of(
                                context,
                              ).colorScheme.errorContainer,
                            ),
                          ),
                        if (writebackSummary != null)
                          Padding(
                            padding: EdgeInsets.only(right: 8),
                            child: Chip(
                              label: Text(l10n.qualityReviewsMemoryTag),
                              visualDensity: VisualDensity.compact,
                            ),
                          ),
                        if ((review.suggestedAction ?? '').trim().isNotEmpty)
                          IconButton(
                            tooltip: l10n.qualityReviewsApplySuggestedActionTooltip,
                            visualDensity: VisualDensity.compact,
                            onPressed: () =>
                                callbacks.onApplySuggestedAction(review),
                            icon: const Icon(Icons.open_in_new_rounded),
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
                  l10n.qualityReviewsEmptyForCurrentFilters,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(color: muted),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: callbacks.onClose,
          child: Text(l10n.helpHubDialogClose),
        ),
      ],
      ),
    );
  }
}
