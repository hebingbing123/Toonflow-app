import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:toonflow_app/home_page/quality_reviews_section.dart';
import 'package:toonflow_app/rust_api.dart';

void main() {
  testWidgets('quality section exposes workbench entry and summary', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: QualityReviewsSection(
            accessToken: 'token',
            loadingQualityReviews: false,
            loadingQualityBadCases: false,
            loadingQualityStats: false,
            loadingQualityStagePassRate: false,
            creatingQualityReview: false,
            loadingQualityReviewById: false,
            qualityReviewIdController: TextEditingController(),
            qualityReviews: const [
              QualityReview(
                id: 'r1',
                createdAt: '2026-04-10T00:00:00Z',
                updatedAt: '2026-04-10T00:00:00Z',
                userId: 'u1',
                targetType: 'output',
                source: 'manual',
                overallScore: 82,
                isBadCase: false,
              ),
            ],
            qualityStatsLine: 'output: total=1, pass=100%',
            qualityStagePassRateLine: '2026-04-10 output:100%',
            qualityReviewByIdLine: null,
            onQualityReviewIdChanged: (_) {},
            onLoadQualityReviews: () {},
            onLoadQualityBadCases: () {},
            onLoadQualityStats: () {},
            onLoadQualityStagePassRate: () {},
            onCreateQualityReviewProbe: () {},
            onFetchQualityReviewById: () {},
            onSelectQualityReview: (_) {},
          ),
        ),
      ),
    );

    expect(find.text('打开质量工作台'), findsOneWidget);
    expect(find.text('评审 1 条 · output:manual:82'), findsOneWidget);
  });

  testWidgets('quality workbench dialog shows seeded controls', (
    WidgetTester tester,
  ) async {
    final reviewIdController = TextEditingController();
    addTearDown(reviewIdController.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: QualityReviewsSection(
            accessToken: 'token',
            loadingQualityReviews: false,
            loadingQualityBadCases: false,
            loadingQualityStats: false,
            loadingQualityStagePassRate: false,
            creatingQualityReview: false,
            loadingQualityReviewById: false,
            qualityReviewIdController: reviewIdController,
            qualityReviews: const [
              QualityReview(
                id: 'r1',
                createdAt: '2026-04-10T00:00:00Z',
                updatedAt: '2026-04-10T00:00:00Z',
                userId: 'u1',
                targetType: 'output',
                source: 'manual',
                overallScore: 82,
                isBadCase: false,
              ),
            ],
            qualityStatsLine: 'output: total=1, pass=100%',
            qualityStagePassRateLine: '2026-04-10 output:100%',
            qualityReviewByIdLine: 'r1 · output · manual',
            onQualityReviewIdChanged: (_) {},
            onLoadQualityReviews: () {},
            onLoadQualityBadCases: () {},
            onLoadQualityStats: () {},
            onLoadQualityStagePassRate: () {},
            onCreateQualityReviewProbe: () {},
            onFetchQualityReviewById: () {},
            onSelectQualityReview: (_) {},
          ),
        ),
      ),
    );

    await tester.tap(find.text('打开质量工作台'));
    await tester.pumpAndSettle();

    expect(find.text('质量工作台'), findsOneWidget);
    expect(find.text('筛选与读取'), findsOneWidget);
    expect(find.text('创建评审'), findsNWidgets(2));
    expect(find.text('评审详情：r1 · output · manual'), findsNWidgets(2));
    expect(find.widgetWithText(TextField, 'output'), findsWidgets);
  });
}
