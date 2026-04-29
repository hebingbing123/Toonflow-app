import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openflow_app/quality_reviews/workbench_view.dart';
import 'package:openflow_app/rust_api.dart';

QualityReviewsWorkbenchDialogViewModel buildDialogModel({
  required TextEditingController targetTypeFilterCtrl,
  required TextEditingController targetIdFilterCtrl,
  required TextEditingController jobIdFilterCtrl,
  required TextEditingController reviewIdCtrl,
  required TextEditingController createProjectIdCtrl,
  required TextEditingController createScriptIdCtrl,
  required TextEditingController createTargetTypeCtrl,
  required TextEditingController createTargetIdCtrl,
  required TextEditingController createSourceCtrl,
  required TextEditingController createScoreCtrl,
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
  bool loadingStagePassRate = false,
  bool loadingReviewById = false,
  bool creatingReview = false,
}) {
  return QualityReviewsWorkbenchDialogViewModel(
    reviews: reviews,
    statsSummary: 'output: total=1, pass=100%',
    stagePassRateSummary: 'storyboard: 100%',
    reviewDetails: 'review-1 · output · manual',
    statusLine: '已读取评审详情',
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
    loadingStagePassRate: loadingStagePassRate,
    loadingReviewById: loadingReviewById,
    creatingReview: creatingReview,
    targetTypeFilterCtrl: targetTypeFilterCtrl,
    targetIdFilterCtrl: targetIdFilterCtrl,
    jobIdFilterCtrl: jobIdFilterCtrl,
    reviewIdCtrl: reviewIdCtrl,
    createProjectIdCtrl: createProjectIdCtrl,
    createScriptIdCtrl: createScriptIdCtrl,
    createTargetTypeCtrl: createTargetTypeCtrl,
    createTargetIdCtrl: createTargetIdCtrl,
    createSourceCtrl: createSourceCtrl,
    createScoreCtrl: createScoreCtrl,
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
  VoidCallback? onLoadStagePassRate = noop,
  VoidCallback? onLoadReviewById = noop,
  VoidCallback? onCreateReview = noop,
  ValueChanged<bool>? onCreatePassedChanged,
  ValueChanged<bool>? onCreateBadCaseChanged,
  ValueChanged<QualityReview>? onSelectReview,
  VoidCallback? onClose = noop,
}) {
  return QualityReviewsWorkbenchDialogViewCallbacks(
    onLoadReviews: onLoadReviews ?? noop,
    onLoadBadCases: onLoadBadCases ?? noop,
    onLoadDeliveryPriorityReviews: onLoadDeliveryPriorityReviews ?? noop,
    onLoadAutoSourceReviews: onLoadAutoSourceReviews ?? noop,
    onLoadStats: onLoadStats ?? noop,
    onLoadStagePassRate: onLoadStagePassRate ?? noop,
    onLoadReviewById: onLoadReviewById ?? noop,
    onCreateReview: onCreateReview ?? noop,
    onCreatePassedChanged: onCreatePassedChanged ?? (_) {},
    onCreateBadCaseChanged: onCreateBadCaseChanged ?? (_) {},
    onSelectReview: onSelectReview ?? (_) {},
    onClose: onClose ?? noop,
  );
}

void main() {
  late TextEditingController targetTypeFilterCtrl;
  late TextEditingController targetIdFilterCtrl;
  late TextEditingController jobIdFilterCtrl;
  late TextEditingController reviewIdCtrl;
  late TextEditingController createProjectIdCtrl;
  late TextEditingController createScriptIdCtrl;
  late TextEditingController createTargetTypeCtrl;
  late TextEditingController createTargetIdCtrl;
  late TextEditingController createSourceCtrl;
  late TextEditingController createScoreCtrl;
  late TextEditingController createCommentsCtrl;
  late TextEditingController createBadCaseCategoryCtrl;

  setUp(() {
    targetTypeFilterCtrl = TextEditingController(text: 'output');
    targetIdFilterCtrl = TextEditingController(text: 'storyboard-1');
    jobIdFilterCtrl = TextEditingController(text: 'job-1');
    reviewIdCtrl = TextEditingController(text: 'review-1');
    createProjectIdCtrl = TextEditingController(text: '7');
    createScriptIdCtrl = TextEditingController(text: '11');
    createTargetTypeCtrl = TextEditingController(text: 'output');
    createTargetIdCtrl = TextEditingController(text: 'storyboard-1');
    createSourceCtrl = TextEditingController(text: 'manual');
    createScoreCtrl = TextEditingController(text: '85');
    createCommentsCtrl = TextEditingController(text: 'looks good');
    createBadCaseCategoryCtrl = TextEditingController();
  });

  tearDown(() {
    targetTypeFilterCtrl.dispose();
    targetIdFilterCtrl.dispose();
    jobIdFilterCtrl.dispose();
    reviewIdCtrl.dispose();
    createProjectIdCtrl.dispose();
    createScriptIdCtrl.dispose();
    createTargetTypeCtrl.dispose();
    createTargetIdCtrl.dispose();
    createSourceCtrl.dispose();
    createScoreCtrl.dispose();
    createCommentsCtrl.dispose();
    createBadCaseCategoryCtrl.dispose();
  });

  testWidgets('quality reviews workbench view renders shared scaffold', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: QualityReviewsWorkbenchDialogView(
            model: buildDialogModel(
              targetTypeFilterCtrl: targetTypeFilterCtrl,
              targetIdFilterCtrl: targetIdFilterCtrl,
              jobIdFilterCtrl: jobIdFilterCtrl,
              reviewIdCtrl: reviewIdCtrl,
              createProjectIdCtrl: createProjectIdCtrl,
              createScriptIdCtrl: createScriptIdCtrl,
              createTargetTypeCtrl: createTargetTypeCtrl,
              createTargetIdCtrl: createTargetIdCtrl,
              createSourceCtrl: createSourceCtrl,
              createScoreCtrl: createScoreCtrl,
              createCommentsCtrl: createCommentsCtrl,
              createBadCaseCategoryCtrl: createBadCaseCategoryCtrl,
            ),
            callbacks: buildDialogCallbacks(),
          ),
        ),
      ),
    );

    expect(find.text('质量工作台'), findsOneWidget);
    expect(find.text('筛选与读取'), findsOneWidget);
    expect(find.text('详情查询'), findsOneWidget);
    expect(find.text('创建评审'), findsNWidgets(2));
    expect(find.text('质量统计：output: total=1, pass=100%'), findsOneWidget);
    expect(find.text('阶段通过率：storyboard: 100%'), findsOneWidget);
    expect(find.textContaining('Token效率：'), findsNothing);
    expect(find.widgetWithText(TextField, '7'), findsOneWidget);
    expect(find.widgetWithText(TextField, '11'), findsOneWidget);
    expect(find.text('评审 1 条'), findsOneWidget);
    expect(
      find.widgetWithText(ListTile, 'output · manual · score=82'),
      findsOneWidget,
    );
  });

  testWidgets('quality reviews workbench view disables actions while busy', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: QualityReviewsWorkbenchDialogView(
            model: buildDialogModel(
              targetTypeFilterCtrl: targetTypeFilterCtrl,
              targetIdFilterCtrl: targetIdFilterCtrl,
              jobIdFilterCtrl: jobIdFilterCtrl,
              reviewIdCtrl: reviewIdCtrl,
              createProjectIdCtrl: createProjectIdCtrl,
              createScriptIdCtrl: createScriptIdCtrl,
              createTargetTypeCtrl: createTargetTypeCtrl,
              createTargetIdCtrl: createTargetIdCtrl,
              createSourceCtrl: createSourceCtrl,
              createScoreCtrl: createScoreCtrl,
              createCommentsCtrl: createCommentsCtrl,
              createBadCaseCategoryCtrl: createBadCaseCategoryCtrl,
              loadingReviews: true,
              loadingBadCases: true,
              loadingStats: true,
              loadingStagePassRate: true,
              loadingReviewById: true,
              creatingReview: true,
            ),
            callbacks: buildDialogCallbacks(),
          ),
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
          .widget<SwitchListTile>(find.widgetWithText(SwitchListTile, 'passed'))
          .onChanged,
      isNull,
    );
    expect(
      tester
          .widget<SwitchListTile>(
            find.widgetWithText(SwitchListTile, 'isBadCase'),
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
      MaterialApp(
        home: Scaffold(
          body: QualityReviewsWorkbenchDialogView(
            model: buildDialogModel(
              targetTypeFilterCtrl: targetTypeFilterCtrl,
              targetIdFilterCtrl: targetIdFilterCtrl,
              jobIdFilterCtrl: jobIdFilterCtrl,
              reviewIdCtrl: reviewIdCtrl,
              createProjectIdCtrl: createProjectIdCtrl,
              createScriptIdCtrl: createScriptIdCtrl,
              createTargetTypeCtrl: createTargetTypeCtrl,
              createTargetIdCtrl: createTargetIdCtrl,
              createSourceCtrl: createSourceCtrl,
              createScoreCtrl: createScoreCtrl,
              createCommentsCtrl: createCommentsCtrl,
              createBadCaseCategoryCtrl: createBadCaseCategoryCtrl,
              filterBadCasesOnly: true,
            ),
            callbacks: buildDialogCallbacks(
              onSelectReview: (review) => selectedReview = review,
            ),
          ),
        ),
      ),
    );

    final reviewTileTitle = find.text('output · manual · score=82');
    await tester.ensureVisible(reviewTileTitle);
    await tester.tap(reviewTileTitle);
    await tester.pump();

    expect(find.text('坏例 1 条'), findsOneWidget);
    expect(selectedReview?.id, 'review-1');
    expect(selectedReview?.targetType, 'output');
  });

  testWidgets(
    'quality reviews workbench view shows prompt diagnostics for auto reviews',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: QualityReviewsWorkbenchDialogView(
              model: buildDialogModel(
                targetTypeFilterCtrl: targetTypeFilterCtrl,
                targetIdFilterCtrl: targetIdFilterCtrl,
                jobIdFilterCtrl: jobIdFilterCtrl,
                reviewIdCtrl: reviewIdCtrl,
                createProjectIdCtrl: createProjectIdCtrl,
                createScriptIdCtrl: createScriptIdCtrl,
                createTargetTypeCtrl: createTargetTypeCtrl,
                createTargetIdCtrl: createTargetIdCtrl,
                createSourceCtrl: createSourceCtrl,
                createScoreCtrl: createScoreCtrl,
                createCommentsCtrl: createCommentsCtrl,
                createBadCaseCategoryCtrl: createBadCaseCategoryCtrl,
                reviews: const [
                  QualityReview(
                    id: 'review-auto-1',
                    createdAt: '2026-04-14T08:00:00Z',
                    updatedAt: '2026-04-14T08:00:00Z',
                    userId: 'user-1',
                    targetType: 'storyboard',
                    source: 'auto',
                    overallScore: 93,
                    passed: true,
                    isBadCase: false,
                    memoryDeliveryPriorityApplied: true,
                    modelParams: {
                      'diagnostics': {
                        'promptChars': 430,
                        'memoryStyleChars': 90,
                        'memoryVisualChars': 26,
                        'memoryDeliveryChars': 44,
                        'memoryDeliveryPriorityApplied': true,
                        'autoNegativeSource': 'review+rejected_memory',
                        'directorManualYieldedToMemory': true,
                      },
                    },
                  ),
                ],
              ),
              callbacks: buildDialogCallbacks(),
            ),
          ),
        ),
      );

      expect(find.textContaining('Prompt诊断：auto诊断 1 条'), findsOneWidget);
      expect(find.textContaining('修复建议：'), findsOneWidget);
      expect(find.textContaining('负向约束=评审+坏例记忆'), findsNWidgets(2));
      expect(find.textContaining('导演让位'), findsNWidgets(2));
      expect(find.textContaining('建议：'), findsNWidgets(2));
    },
  );
}

void noop() {}
