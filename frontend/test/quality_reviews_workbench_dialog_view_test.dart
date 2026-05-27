import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openflow_app/l10n/app_localizations.dart';
import 'package:openflow_app/quality_reviews/workbench_view.dart';
import 'package:openflow_app/rust_api.dart';

Widget _buildTestApp(Widget child) {
  return MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    locale: const Locale('zh'),
    home: Scaffold(body: child),
  );
}

QualityReviewsWorkbenchDialogViewModel buildDialogModel({
  required TextEditingController projectIdFilterCtrl,
  required TextEditingController scriptIdFilterCtrl,
  required TextEditingController targetTypeFilterCtrl,
  required TextEditingController targetIdFilterCtrl,
  required TextEditingController jobIdFilterCtrl,
  required TextEditingController stageFilterCtrl,
  required TextEditingController gradeFilterCtrl,
  required TextEditingController suggestedActionFilterCtrl,
  required TextEditingController reviewIdCtrl,
  required TextEditingController createProjectIdCtrl,
  required TextEditingController createScriptIdCtrl,
  required TextEditingController createTargetTypeCtrl,
  required TextEditingController createTargetIdCtrl,
  required TextEditingController createSourceCtrl,
  required TextEditingController createScoreCtrl,
  required TextEditingController createStageCtrl,
  required TextEditingController createGradeCtrl,
  required TextEditingController createCommentsCtrl,
  required TextEditingController createBadCaseCategoryCtrl,
  List<QualityReview> reviews = const <QualityReview>[
    QualityReview(
      id: 'review-1',
      createdAt: '2026-04-14T08:00:00Z',
      updatedAt: '2026-04-14T08:00:00Z',
      userId: 'user-1',
      targetType: 'output',
      source: 'manual',
      overallScore: 82,
      passed: true,
      isBadCase: false,
      suggestedAction: 'patch_storyboard_items',
    ),
  ],
  bool filterBadCasesOnly = false,
  bool filterDeliveryPriorityOnly = false,
  bool filterAutoSourceOnly = false,
  bool createPassed = true,
  bool createBadCase = false,
  bool loadingReviews = false,
  bool loadingBadCases = false,
  bool loadingStats = false,
  bool loadingScopeInsights = false,
  bool loadingTokenEfficiency = false,
  bool loadingTokenEfficiencySamples = false,
  bool loadingStagePassRate = false,
  bool loadingReviewById = false,
  bool creatingReview = false,
}) {
  return QualityReviewsWorkbenchDialogViewModel(
    reviews: reviews,
    statsSummary: 'output: total=1, pass=100%',
    scopeInsightsSummary: 'P7/S11 2条 · pass=50.0% · 坏例1',
    tokenEfficiencySummary: 'output: samples=2, prompt=420, memory=88',
    tokenEfficiencyActionPlan:
        'P7/S11 独立记忆建议：storyboard 保留镜头级精选记忆的表演/情绪记忆，继续压泛风格句，别先删 delivery 片段。',
    tokenEfficiencyExecutionChecklist:
        'P7/S11 执行清单：\n1. 保留镜头级精选记忆里的表演、语气、口型和情绪记忆，只压泛风格套话。\n2. 范围：记忆只在 P7/S11 生效，不跨用户、项目或短剧复用。',
    tokenEfficiencySamplesSummary:
        '04-14 08:00 output: prompt=430, base=340, memory=90 (20.9%, delivery优先)',
    stagePassRateSummary: 'storyboard: 100%',
    stageGradeRows: const [],
    badCaseStatsSummary: null,
    badCaseStatItems: const <BadCaseStatItem>[],
    reviewDetails: 'review-1 · output · manual',
    selectedReview: reviews.isEmpty ? null : reviews.first,
    createDimensionScores: null,
    statusLine: '已读取评审详情',
    initialProjectScopeSummary: 'projectUuid=project-uuid-7 -> projectId=7',
    activeFilterQuerySummary: null,
    activeFilterRequestUrl: null,
    filterBadCasesOnly: filterBadCasesOnly,
    filterDeliveryPriorityOnly: filterDeliveryPriorityOnly,
    filterAutoSourceOnly: filterAutoSourceOnly,
    createPassed: createPassed,
    createBadCase: createBadCase,
    loadingReviews: loadingReviews,
    loadingBadCases: loadingBadCases,
    loadingStats: loadingStats,
    loadingScopeInsights: loadingScopeInsights,
    loadingTokenEfficiency: loadingTokenEfficiency,
    loadingTokenEfficiencySamples: loadingTokenEfficiencySamples,
    loadingStagePassRate: loadingStagePassRate,
    loadingBadCaseStats: false,
    loadingReviewById: loadingReviewById,
    creatingReview: creatingReview,
    projectIdFilterCtrl: projectIdFilterCtrl,
    scriptIdFilterCtrl: scriptIdFilterCtrl,
    targetTypeFilterCtrl: targetTypeFilterCtrl,
    targetIdFilterCtrl: targetIdFilterCtrl,
    jobIdFilterCtrl: jobIdFilterCtrl,
    stageFilterCtrl: stageFilterCtrl,
    gradeFilterCtrl: gradeFilterCtrl,
    suggestedActionFilterCtrl: suggestedActionFilterCtrl,
    reviewIdCtrl: reviewIdCtrl,
    createProjectIdCtrl: createProjectIdCtrl,
    createScriptIdCtrl: createScriptIdCtrl,
    createTargetTypeCtrl: createTargetTypeCtrl,
    createTargetIdCtrl: createTargetIdCtrl,
    createSourceCtrl: createSourceCtrl,
    createScoreCtrl: createScoreCtrl,
    createStageCtrl: createStageCtrl,
    createGradeCtrl: createGradeCtrl,
    createCommentsCtrl: createCommentsCtrl,
    createBadCaseCategoryCtrl: createBadCaseCategoryCtrl,
  );
}

QualityReviewsWorkbenchDialogViewCallbacks buildDialogCallbacks({
  VoidCallback? onLoadReviews = noop,
  VoidCallback? onLoadBadCases = noop,
  VoidCallback? onLoadDeliveryPriorityReviews = noop,
  VoidCallback? onLoadAutoSourceReviews = noop,
  VoidCallback? onLoadStats = noop,
  VoidCallback? onLoadScopeInsights = noop,
  VoidCallback? onLoadTokenEfficiency = noop,
  VoidCallback? onLoadTokenEfficiencySamples = noop,
  VoidCallback? onLoadStagePassRate = noop,
  VoidCallback? onLoadReviewById = noop,
  VoidCallback? onCreateReview = noop,
  ValueChanged<Map<String, int>?>? onCreateDimensionScoresChanged,
  ValueChanged<bool>? onCreatePassedChanged,
  ValueChanged<bool>? onCreateBadCaseChanged,
  ValueChanged<QualityReview>? onSelectReview,
  ValueChanged<QualityReview>? onApplySuggestedAction,
  VoidCallback? onClose = noop,
}) {
  return QualityReviewsWorkbenchDialogViewCallbacks(
    onLoadReviews: onLoadReviews ?? noop,
    onLoadBadCases: onLoadBadCases ?? noop,
    onLoadDeliveryPriorityReviews: onLoadDeliveryPriorityReviews ?? noop,
    onLoadAutoSourceReviews: onLoadAutoSourceReviews ?? noop,
    onLoadStats: onLoadStats ?? noop,
    onLoadScopeInsights: onLoadScopeInsights ?? noop,
    onLoadTokenEfficiency: onLoadTokenEfficiency ?? noop,
    onLoadTokenEfficiencySamples: onLoadTokenEfficiencySamples ?? noop,
    onLoadStagePassRate: onLoadStagePassRate ?? noop,
    onLoadBadCaseStats: noop,
    onLoadReviewById: onLoadReviewById ?? noop,
    onCreateReview: onCreateReview ?? noop,
    onCreateDimensionScoresChanged: onCreateDimensionScoresChanged ?? (_) {},
    onCreatePassedChanged: onCreatePassedChanged ?? (_) {},
    onCreateBadCaseChanged: onCreateBadCaseChanged ?? (_) {},
    onSelectReview: onSelectReview ?? (_) {},
    onApplySuggestedAction: onApplySuggestedAction ?? (_) {},
    onClose: onClose ?? noop,
  );
}

void main() {
  late TextEditingController targetTypeFilterCtrl;
  late TextEditingController targetIdFilterCtrl;
  late TextEditingController jobIdFilterCtrl;
  late TextEditingController stageFilterCtrl;
  late TextEditingController gradeFilterCtrl;
  late TextEditingController suggestedActionFilterCtrl;
  late TextEditingController projectIdFilterCtrl;
  late TextEditingController scriptIdFilterCtrl;
  late TextEditingController reviewIdCtrl;
  late TextEditingController createProjectIdCtrl;
  late TextEditingController createScriptIdCtrl;
  late TextEditingController createTargetTypeCtrl;
  late TextEditingController createTargetIdCtrl;
  late TextEditingController createSourceCtrl;
  late TextEditingController createScoreCtrl;
  late TextEditingController createStageCtrl;
  late TextEditingController createGradeCtrl;
  late TextEditingController createCommentsCtrl;
  late TextEditingController createBadCaseCategoryCtrl;

  setUp(() {
    projectIdFilterCtrl = TextEditingController(text: '7');
    scriptIdFilterCtrl = TextEditingController(text: '11');
    targetTypeFilterCtrl = TextEditingController(text: 'output');
    targetIdFilterCtrl = TextEditingController(text: 'storyboard-1');
    jobIdFilterCtrl = TextEditingController(text: 'job-1');
    stageFilterCtrl = TextEditingController();
    gradeFilterCtrl = TextEditingController();
    suggestedActionFilterCtrl = TextEditingController(text: 'all');
    reviewIdCtrl = TextEditingController(text: 'review-1');
    createProjectIdCtrl = TextEditingController(text: '7');
    createScriptIdCtrl = TextEditingController(text: '11');
    createTargetTypeCtrl = TextEditingController(text: 'output');
    createTargetIdCtrl = TextEditingController(text: 'storyboard-1');
    createSourceCtrl = TextEditingController(text: 'manual');
    createScoreCtrl = TextEditingController(text: '85');
    createStageCtrl = TextEditingController(text: 'video_prompt');
    createGradeCtrl = TextEditingController(text: 'A');
    createCommentsCtrl = TextEditingController(text: 'looks good');
    createBadCaseCategoryCtrl = TextEditingController();
  });

  tearDown(() {
    projectIdFilterCtrl.dispose();
    scriptIdFilterCtrl.dispose();
    targetTypeFilterCtrl.dispose();
    targetIdFilterCtrl.dispose();
    jobIdFilterCtrl.dispose();
    stageFilterCtrl.dispose();
    gradeFilterCtrl.dispose();
    suggestedActionFilterCtrl.dispose();
    reviewIdCtrl.dispose();
    createProjectIdCtrl.dispose();
    createScriptIdCtrl.dispose();
    createTargetTypeCtrl.dispose();
    createTargetIdCtrl.dispose();
    createSourceCtrl.dispose();
    createScoreCtrl.dispose();
    createStageCtrl.dispose();
    createGradeCtrl.dispose();
    createCommentsCtrl.dispose();
    createBadCaseCategoryCtrl.dispose();
  });

  testWidgets('quality reviews workbench view renders shared scaffold', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _buildTestApp(
        QualityReviewsWorkbenchDialogView(
          model: buildDialogModel(
            projectIdFilterCtrl: projectIdFilterCtrl,
            scriptIdFilterCtrl: scriptIdFilterCtrl,
            targetTypeFilterCtrl: targetTypeFilterCtrl,
            targetIdFilterCtrl: targetIdFilterCtrl,
            jobIdFilterCtrl: jobIdFilterCtrl,
            stageFilterCtrl: stageFilterCtrl,
            gradeFilterCtrl: gradeFilterCtrl,
            suggestedActionFilterCtrl: suggestedActionFilterCtrl,
            reviewIdCtrl: reviewIdCtrl,
            createProjectIdCtrl: createProjectIdCtrl,
            createScriptIdCtrl: createScriptIdCtrl,
            createTargetTypeCtrl: createTargetTypeCtrl,
            createTargetIdCtrl: createTargetIdCtrl,
            createSourceCtrl: createSourceCtrl,
            createScoreCtrl: createScoreCtrl,
            createStageCtrl: createStageCtrl,
            createGradeCtrl: createGradeCtrl,
            createCommentsCtrl: createCommentsCtrl,
            createBadCaseCategoryCtrl: createBadCaseCategoryCtrl,
          ),
          callbacks: buildDialogCallbacks(),
        ),
      ),
    );

    expect(find.text('质量工作台'), findsOneWidget);
    expect(
      find.text('范围种子：projectUuid=project-uuid-7 -> projectId=7'),
      findsOneWidget,
    );
    expect(find.text('筛选与读取'), findsOneWidget);
    expect(find.text('详情查询'), findsOneWidget);
    expect(find.text('创建评审'), findsNWidgets(2));
    expect(find.widgetWithText(TextField, '7'), findsNWidgets(2));
    expect(find.widgetWithText(TextField, '11'), findsNWidgets(2));
    expect(find.text('质量统计：output: total=1, pass=100%'), findsOneWidget);
    expect(find.text('Scope榜单：P7/S11 2条 · pass=50.0% · 坏例1'), findsOneWidget);
    expect(
      find.text('Token聚合：output: samples=2, prompt=420, memory=88'),
      findsOneWidget,
    );
    expect(find.textContaining('记忆动作：P7/S11 独立记忆建议'), findsOneWidget);
    expect(find.textContaining('P7/S11 执行清单：'), findsOneWidget);
    expect(find.byTooltip('复制执行清单'), findsOneWidget);
    expect(
      find.textContaining('省Token样本：04-14 08:00 output: prompt=430'),
      findsOneWidget,
    );
    expect(find.text('阶段通过率：storyboard: 100%'), findsOneWidget);
    expect(find.text('1 条评审'), findsOneWidget);
    expect(find.text('产出 · manual · score=82'), findsOneWidget);
  });

  testWidgets('quality reviews workbench view disables actions while busy', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _buildTestApp(
        QualityReviewsWorkbenchDialogView(
          model: buildDialogModel(
            projectIdFilterCtrl: projectIdFilterCtrl,
            scriptIdFilterCtrl: scriptIdFilterCtrl,
            targetTypeFilterCtrl: targetTypeFilterCtrl,
            targetIdFilterCtrl: targetIdFilterCtrl,
            jobIdFilterCtrl: jobIdFilterCtrl,
            stageFilterCtrl: stageFilterCtrl,
            gradeFilterCtrl: gradeFilterCtrl,
            suggestedActionFilterCtrl: suggestedActionFilterCtrl,
            reviewIdCtrl: reviewIdCtrl,
            createProjectIdCtrl: createProjectIdCtrl,
            createScriptIdCtrl: createScriptIdCtrl,
            createTargetTypeCtrl: createTargetTypeCtrl,
            createTargetIdCtrl: createTargetIdCtrl,
            createSourceCtrl: createSourceCtrl,
            createScoreCtrl: createScoreCtrl,
            createStageCtrl: createStageCtrl,
            createGradeCtrl: createGradeCtrl,
            createCommentsCtrl: createCommentsCtrl,
            createBadCaseCategoryCtrl: createBadCaseCategoryCtrl,
            loadingReviews: true,
            loadingBadCases: true,
            loadingStats: true,
            loadingScopeInsights: true,
            loadingTokenEfficiency: true,
            loadingTokenEfficiencySamples: true,
            loadingStagePassRate: true,
            loadingReviewById: true,
            creatingReview: true,
          ),
          callbacks: buildDialogCallbacks(),
        ),
      ),
    );

    expect(
      tester
          .widgetList<ButtonStyleButton>(find.byType(ButtonStyleButton))
          .every((button) => button.onPressed == null),
      isTrue,
    );
    expect(
      tester
          .widget<SwitchListTile>(find.widgetWithText(SwitchListTile, '是否通过'))
          .onChanged,
      isNull,
    );
    expect(
      tester
          .widget<SwitchListTile>(
            find.widgetWithText(SwitchListTile, '是否坏例'),
          )
          .onChanged,
      isNull,
    );
  });

  testWidgets('quality reviews workbench view forwards review selection', (
    WidgetTester tester,
  ) async {
    QualityReview? selectedReview;

    await tester.pumpWidget(
      _buildTestApp(
        QualityReviewsWorkbenchDialogView(
          model: buildDialogModel(
            projectIdFilterCtrl: projectIdFilterCtrl,
            scriptIdFilterCtrl: scriptIdFilterCtrl,
            targetTypeFilterCtrl: targetTypeFilterCtrl,
            targetIdFilterCtrl: targetIdFilterCtrl,
            jobIdFilterCtrl: jobIdFilterCtrl,
            stageFilterCtrl: stageFilterCtrl,
            gradeFilterCtrl: gradeFilterCtrl,
            suggestedActionFilterCtrl: suggestedActionFilterCtrl,
            reviewIdCtrl: reviewIdCtrl,
            createProjectIdCtrl: createProjectIdCtrl,
            createScriptIdCtrl: createScriptIdCtrl,
            createTargetTypeCtrl: createTargetTypeCtrl,
            createTargetIdCtrl: createTargetIdCtrl,
            createSourceCtrl: createSourceCtrl,
            createScoreCtrl: createScoreCtrl,
            createStageCtrl: createStageCtrl,
            createGradeCtrl: createGradeCtrl,
            createCommentsCtrl: createCommentsCtrl,
            createBadCaseCategoryCtrl: createBadCaseCategoryCtrl,
            filterBadCasesOnly: true,
          ),
          callbacks: buildDialogCallbacks(
            onSelectReview: (review) => selectedReview = review,
          ),
        ),
      ),
    );

    final reviewTileTitle = find.text('产出 · manual · score=82');
    await tester.ensureVisible(reviewTileTitle);
    await tester.tap(reviewTileTitle);
    await tester.pump();

    expect(find.text('坏例 1 条'), findsOneWidget);
    expect(selectedReview?.id, 'review-1');
    expect(selectedReview?.targetType, 'output');
  });

  testWidgets(
    'quality reviews workbench view forwards suggested action apply',
    (WidgetTester tester) async {
      QualityReview? appliedReview;

      await tester.pumpWidget(
        _buildTestApp(
          QualityReviewsWorkbenchDialogView(
            model: buildDialogModel(
              projectIdFilterCtrl: projectIdFilterCtrl,
              scriptIdFilterCtrl: scriptIdFilterCtrl,
              targetTypeFilterCtrl: targetTypeFilterCtrl,
              targetIdFilterCtrl: targetIdFilterCtrl,
              jobIdFilterCtrl: jobIdFilterCtrl,
              stageFilterCtrl: stageFilterCtrl,
              gradeFilterCtrl: gradeFilterCtrl,
              suggestedActionFilterCtrl: suggestedActionFilterCtrl,
              reviewIdCtrl: reviewIdCtrl,
              createProjectIdCtrl: createProjectIdCtrl,
              createScriptIdCtrl: createScriptIdCtrl,
              createTargetTypeCtrl: createTargetTypeCtrl,
              createTargetIdCtrl: createTargetIdCtrl,
              createSourceCtrl: createSourceCtrl,
              createScoreCtrl: createScoreCtrl,
              createStageCtrl: createStageCtrl,
              createGradeCtrl: createGradeCtrl,
              createCommentsCtrl: createCommentsCtrl,
              createBadCaseCategoryCtrl: createBadCaseCategoryCtrl,
            ),
            callbacks: buildDialogCallbacks(
              onApplySuggestedAction: (review) => appliedReview = review,
            ),
          ),
        ),
      );

      final actionButton = find.byTooltip('应用建议动作');
      await tester.ensureVisible(actionButton);
      await tester.tap(actionButton);
      await tester.pump();

      expect(appliedReview?.id, 'review-1');
      expect(appliedReview?.suggestedAction, 'patch_storyboard_items');
    },
  );

  testWidgets(
    'quality reviews workbench view shows prompt diagnostics for auto reviews',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        _buildTestApp(
          QualityReviewsWorkbenchDialogView(
            model: buildDialogModel(
              projectIdFilterCtrl: projectIdFilterCtrl,
              scriptIdFilterCtrl: scriptIdFilterCtrl,
              targetTypeFilterCtrl: targetTypeFilterCtrl,
              targetIdFilterCtrl: targetIdFilterCtrl,
              jobIdFilterCtrl: jobIdFilterCtrl,
              stageFilterCtrl: stageFilterCtrl,
              gradeFilterCtrl: gradeFilterCtrl,
              suggestedActionFilterCtrl: suggestedActionFilterCtrl,
              reviewIdCtrl: reviewIdCtrl,
              createProjectIdCtrl: createProjectIdCtrl,
              createScriptIdCtrl: createScriptIdCtrl,
              createTargetTypeCtrl: createTargetTypeCtrl,
              createTargetIdCtrl: createTargetIdCtrl,
              createSourceCtrl: createSourceCtrl,
              createScoreCtrl: createScoreCtrl,
              createStageCtrl: createStageCtrl,
              createGradeCtrl: createGradeCtrl,
              createCommentsCtrl: createCommentsCtrl,
              createBadCaseCategoryCtrl: createBadCaseCategoryCtrl,
              reviews: const [
                QualityReview(
                  id: 'review-auto-1',
                  createdAt: '2026-04-14T08:00:00Z',
                  updatedAt: '2026-04-14T08:00:00Z',
                  userId: 'user-1',
                  projectId: 7,
                  scriptId: 11,
                  targetType: 'storyboard',
                  source: 'auto',
                  overallScore: 93,
                  dialogueNaturalness: 76,
                  visualQuality: 78,
                  passed: true,
                  isBadCase: false,
                  comments: '台词略生硬，画面有点不自然',
                  memoryDeliveryPriorityApplied: true,
                  modelParams: {
                    'diagnostics': {
                      'promptChars': 430,
                      'memoryStyleChars': 90,
                      'memoryVisualChars': 26,
                      'memoryDeliveryChars': 44,
                      'memoryOptimizationApplied': true,
                      'memoryOptimizationRemovedChars': 96,
                      'memoryOptimizationRemovedRows': 2,
                      'memoryOptimizationRemovedVisualRows': 1,
                      'memoryOptimizationRemovedDuplicateRows': 1,
                      'memoryDeliveryPriorityApplied': true,
                      'autoNegativeSource': 'review+rejected_memory',
                      'directorManualYieldedToMemory': true,
                      'feedbackMemory': {
                        'action': 'promoted_selected_memory',
                        'storyboardId': 19,
                        'memoryName': 'selected_video_memory',
                        'clearedMemoryName': 'rejected_video_negative_memory',
                        'removedRows': 2,
                        'removedChars': 96,
                        'removedVisualRows': 1,
                        'removedDuplicateRows': 1,
                      },
                    },
                  },
                ),
              ],
            ),
            callbacks: buildDialogCallbacks(),
          ),
        ),
      );

      expect(find.textContaining('Prompt诊断：auto诊断 1 条'), findsOneWidget);
      expect(
        find.textContaining('记忆瘦身：P7/S11 1条 · slim 96 chars / 2条'),
        findsOneWidget,
      );
      expect(
        find.textContaining('优先修复：P7/S11 1条 · 情绪/台词 1 · 真实感 1'),
        findsOneWidget,
      );
      expect(find.textContaining('修复建议：'), findsOneWidget);
      expect(find.textContaining('负向约束=评审+坏例记忆'), findsNWidgets(2));
      expect(find.textContaining('导演让位'), findsNWidgets(2));
      expect(find.textContaining('正向记忆晋升'), findsOneWidget);
      expect(find.textContaining('写入=selected_video_memory'), findsOneWidget);
      expect(find.text('memory'), findsOneWidget);
    },
  );
}

void noop() {}
