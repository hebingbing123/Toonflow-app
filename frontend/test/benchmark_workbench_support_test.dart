import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:openflow_app/benchmark/workbench_cases.dart';
import 'package:openflow_app/benchmark/workbench_experiments.dart';
import 'package:openflow_app/benchmark/workbench_gate.dart';
import 'package:openflow_app/benchmark/workbench_review_queue.dart';
import 'package:openflow_app/l10n/app_localizations.dart';
import 'package:openflow_app/rust_api.dart';

Widget appWithZh(Widget child) => MaterialApp(
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('zh'),
      home: Scaffold(body: child),
    );

void main() {
  testWidgets('BenchmarkCasesWorkbench renders without error', (tester) async {
    await tester.pumpWidget(
      appWithZh(
        SingleChildScrollView(
          child: BenchmarkCasesWorkbench(
            cases: const [],
            projectIdController: TextEditingController(),
            qualityReviewIdController: TextEditingController(),
            promoteSummaryController: TextEditingController(),
            promoteTagsController: TextEditingController(),
            promoteCaseType: 'bad_case',
            busy: false,
            onFetchCases: () {},
            onPromoteCase: () {},
            onPromoteCaseTypeChanged: (_) {},
          ),
        ),
      ),
    );

    expect(find.byType(BenchmarkCasesWorkbench), findsOneWidget);
    expect(find.text('拉取样本池'), findsOneWidget);
  });

  testWidgets('BenchmarkExperimentsWorkbench renders without error',
      (tester) async {
    await tester.pumpWidget(
      appWithZh(
        SingleChildScrollView(
          child: BenchmarkExperimentsWorkbench(
            experiments: const [],
            experimentDetail: null,
            roiSummary: null,
            experimentIdController: TextEditingController(),
            experimentNameController: TextEditingController(),
            stageScopeController: TextEditingController(),
            baselineLabelController: TextEditingController(),
            variantsJsonController: TextEditingController(),
            sampleTier: 'smoke',
            busy: false,
            onFetchExperiments: () {},
            onFetchExperimentDetail: () {},
            onStartExperiment: () {},
            onCancelExperiment: () {},
            onFetchRoi: () {},
            onCreateExperiment: () {},
            onSampleTierChanged: (_) {},
            onExperimentSelected: (_) {},
          ),
        ),
      ),
    );

    expect(find.byType(BenchmarkExperimentsWorkbench), findsOneWidget);
    expect(find.text('拉取实验列表'), findsOneWidget);
  });

  testWidgets('BenchmarkReviewQueueWorkbench renders without error',
      (tester) async {
    await tester.pumpWidget(
      appWithZh(
        SingleChildScrollView(
          child: BenchmarkReviewQueueWorkbench(
            reviewQueue: const [],
            reviewQueueIdController: TextEditingController(),
            reviewScoreJsonController: TextEditingController(),
            reviewSkipReasonController: TextEditingController(),
            busy: false,
            onFetchReviewQueue: () {},
            onSubmitReview: () {},
            onSkipReview: () {},
            onReviewSelected: (_) {},
          ),
        ),
      ),
    );

    expect(find.byType(BenchmarkReviewQueueWorkbench), findsOneWidget);
    expect(find.text('拉取复核队列'), findsOneWidget);
  });

  testWidgets('BenchmarkGateWorkbench renders without error', (tester) async {
    await tester.pumpWidget(
      appWithZh(
        SingleChildScrollView(
          child: BenchmarkGateWorkbench(
            gateSummary: null,
            trends: null,
            experimentIdController: TextEditingController(),
            gateVariantIdController: TextEditingController(),
            gateDecisionController: TextEditingController(),
            gateNoteController: TextEditingController(),
            promoteToBaseline: false,
            busy: false,
            onFetchGate: () {},
            onFetchTrends: () {},
            onSubmitGateDecision: () {},
            onPromoteToBaselineChanged: (_) {},
          ),
        ),
      ),
    );

    expect(find.byType(BenchmarkGateWorkbench), findsOneWidget);
  });

  testWidgets('BenchmarkCasesWorkbench displays cases when provided',
      (tester) async {
    await tester.pumpWidget(
      appWithZh(
        SingleChildScrollView(
          child: BenchmarkCasesWorkbench(
            cases: const [
              BenchmarkCaseV1(
                id: 'case-1',
                projectId: 7,
                scriptId: 3,
                stage: 'video_prompt',
                caseType: 'bad_case',
                issueTags: ['人物一致性'],
                weight: 3,
                summary: '脸漂了',
                lastVerifiedAt: null,
              ),
            ],
            projectIdController: TextEditingController(),
            qualityReviewIdController: TextEditingController(),
            promoteSummaryController: TextEditingController(),
            promoteTagsController: TextEditingController(),
            promoteCaseType: 'bad_case',
            busy: false,
            onFetchCases: () {},
            onPromoteCase: () {},
            onPromoteCaseTypeChanged: (_) {},
          ),
        ),
      ),
    );

    expect(find.text('bad_case · P7 · video_prompt'), findsOneWidget);
  });

  testWidgets('BenchmarkGateWorkbench displays gate summary when provided',
      (tester) async {
    await tester.pumpWidget(
      appWithZh(
        SingleChildScrollView(
          child: BenchmarkGateWorkbench(
            gateSummary: const GateDecisionEnvelopeV1(
              experimentRunId: 'exp-1',
              assessments: [
                GateAssessmentV1(
                  variantId: 'v1',
                  variantLabel: 'baseline',
                  autoDecision: 'approved',
                  avgQualityScore: 8.1,
                  qualityScoreDelta: 0.0,
                  totalTokens: 1000,
                  tokenDeltaPercent: 0,
                  severeGuardFailures: 0,
                ),
              ],
              latestDecisions: [],
            ),
            trends: null,
            experimentIdController: TextEditingController(),
            gateVariantIdController: TextEditingController(),
            gateDecisionController: TextEditingController(),
            gateNoteController: TextEditingController(),
            promoteToBaseline: false,
            busy: false,
            onFetchGate: () {},
            onFetchTrends: () {},
            onSubmitGateDecision: () {},
            onPromoteToBaselineChanged: (_) {},
          ),
        ),
      ),
    );

    expect(find.textContaining('baseline'), findsWidgets);
    expect(find.textContaining('approved'), findsWidgets);
  });
}
