import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openflow_app/quality_reviews/support.dart';
import 'package:openflow_app/quality_reviews/workbench_view.dart';
import 'package:openflow_app/rust_api.dart';

QualityReviewsWorkbenchDialogViewModel buildDialogModel({
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
  List<QualityTokenEfficiencySampleRow> tokenEfficiencySamples =
      const <QualityTokenEfficiencySampleRow>[
        QualityTokenEfficiencySampleRow(
          reviewId: 'sample-1',
          createdAt: '2026-04-14T08:00:00Z',
          projectId: 1,
          scriptId: 2,
          jobId: 'job-1',
          targetType: 'output',
          targetId: 'storyboard-1',
          source: 'auto',
          overallScore: 4,
          passed: false,
          isBadCase: true,
          memoryDeliveryPriorityApplied: false,
          promptChars: 920,
          linkedTotalTokens: 640,
          memoryDeliveryChars: 60,
          memoryVisualChars: 88,
          memoryScriptScopeChars: 70,
          memoryProjectScopeChars: 220,
          memoryMixedScopeChars: 14,
          promptCharsPerScorePoint: 230,
          linkedTokensPerScorePoint: 160,
          dominantMemoryScope: 'project',
          recommendedAction: 'shift_to_delivery_memory',
          recommendedActionReason: '先把预算从泛设定移到情绪、动作和语气约束',
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
  bool loadingTokenEfficiency = false,
  bool loadingTokenEfficiencySamples = false,
  bool loadingReviewById = false,
  bool creatingReview = false,
}) {
  return QualityReviewsWorkbenchDialogViewModel(
    reviews: reviews,
    tokenEfficiencySamples: tokenEfficiencySamples,
    memoryDraft: buildQualityMemoryDraft(tokenEfficiencySamples.first),
    statsSummary: 'output: total=1, pass=100%',
    stagePassRateSummary: 'storyboard: 100%',
    tokenEfficiencySummary: 'output: linked=1/1',
    tokenEfficiencySampleSummary:
        'output:score=4,p=230.0,t=160.0,bad/project->shift-to-delivery-memory',
    reviewDetails: 'review-1 · output · manual',
    statusLine: '已读取评审详情',
    filterBadCasesOnly: filterBadCasesOnly,
    filterDeliveryPriorityOnly: filterDeliveryPriorityOnly,
    filterAutoSourceOnly: filterAutoSourceOnly,
    createPassed: createPassed,
    createBadCase: createBadCase,
    loadingReviews: loadingReviews,
    loadingBadCases: loadingBadCases,
    loadingStats: loadingStats,
    loadingStagePassRate: loadingStagePassRate,
    loadingTokenEfficiency: loadingTokenEfficiency,
    loadingTokenEfficiencySamples: loadingTokenEfficiencySamples,
    loadingReviewById: loadingReviewById,
    creatingReview: creatingReview,
    applyingMemoryDraft: false,
    targetTypeFilterCtrl: targetTypeFilterCtrl,
    targetIdFilterCtrl: targetIdFilterCtrl,
    jobIdFilterCtrl: jobIdFilterCtrl,
    reviewIdCtrl: reviewIdCtrl,
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
  VoidCallback? onLoadTokenEfficiency = noop,
  VoidCallback? onLoadTokenEfficiencySamples = noop,
  VoidCallback? onLoadReviewById = noop,
  VoidCallback? onCreateReview = noop,
  ValueChanged<bool>? onCreatePassedChanged,
  ValueChanged<bool>? onCreateBadCaseChanged,
  ValueChanged<QualityReview>? onSelectReview,
  ValueChanged<QualityTokenEfficiencySampleRow>? onSelectTokenEfficiencySample,
  VoidCallback? onApplyMemoryDraft = noop,
  VoidCallback? onClose = noop,
}) {
  return QualityReviewsWorkbenchDialogViewCallbacks(
    onLoadReviews: onLoadReviews ?? noop,
    onLoadBadCases: onLoadBadCases ?? noop,
    onLoadDeliveryPriorityReviews: onLoadDeliveryPriorityReviews ?? noop,
    onLoadAutoSourceReviews: onLoadAutoSourceReviews ?? noop,
    onLoadStats: onLoadStats ?? noop,
    onLoadStagePassRate: onLoadStagePassRate ?? noop,
    onLoadTokenEfficiency: onLoadTokenEfficiency ?? noop,
    onLoadTokenEfficiencySamples: onLoadTokenEfficiencySamples ?? noop,
    onLoadReviewById: onLoadReviewById ?? noop,
    onCreateReview: onCreateReview ?? noop,
    onCreatePassedChanged: onCreatePassedChanged ?? (_) {},
    onCreateBadCaseChanged: onCreateBadCaseChanged ?? (_) {},
    onSelectReview: onSelectReview ?? (_) {},
    onSelectTokenEfficiencySample: onSelectTokenEfficiencySample ?? (_) {},
    onApplyMemoryDraft: onApplyMemoryDraft ?? noop,
    onClose: onClose ?? noop,
  );
}

void main() {
  late TextEditingController targetTypeFilterCtrl;
  late TextEditingController targetIdFilterCtrl;
  late TextEditingController jobIdFilterCtrl;
  late TextEditingController reviewIdCtrl;
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
    expect(find.text('Token 效率：output: linked=1/1'), findsOneWidget);
    expect(find.text('记忆草案'), findsOneWidget);
    expect(find.text('写入隔离记忆'), findsOneWidget);
    expect(find.text('评审 1 条'), findsOneWidget);
    expect(find.text('低效样本 1 条'), findsOneWidget);
    expect(
      find.widgetWithText(ListTile, 'output · manual · score=82'),
      findsOneWidget,
    );
    expect(
      find.widgetWithText(
        ListTile,
        'output · score=4 · shift_to_delivery_memory',
      ),
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
              loadingTokenEfficiency: true,
              loadingTokenEfficiencySamples: true,
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
    QualityTokenEfficiencySampleRow? selectedSample;
    var applyCalls = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: QualityReviewsWorkbenchDialogView(
            model: buildDialogModel(
              targetTypeFilterCtrl: targetTypeFilterCtrl,
              targetIdFilterCtrl: targetIdFilterCtrl,
              jobIdFilterCtrl: jobIdFilterCtrl,
              reviewIdCtrl: reviewIdCtrl,
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
              onSelectTokenEfficiencySample: (sample) =>
                  selectedSample = sample,
              onApplyMemoryDraft: () => applyCalls += 1,
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

    final sampleTileTitle = find.text(
      'output · score=4 · shift_to_delivery_memory',
    );
    await tester.ensureVisible(sampleTileTitle);
    await tester.tap(sampleTileTitle);
    await tester.pump();

    expect(selectedSample?.reviewId, 'sample-1');
    expect(selectedSample?.recommendedAction, 'shift_to_delivery_memory');

    await tester.tap(find.text('写入隔离记忆'));
    await tester.pump();
    expect(applyCalls, 1);
  });
}

void noop() {}
