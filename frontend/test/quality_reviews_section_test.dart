import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openflow_app/l10n/app_localizations.dart';
import 'package:openflow_app/quality_reviews/controller.dart';
import 'package:openflow_app/quality_reviews/section.dart';
import 'package:openflow_app/rust_api.dart';

const _testPlatformConfig = PlatformConfigToggleSetV1.defaults;

Widget _buildTestApp(Widget child) {
  return MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    locale: const Locale('zh'),
    home: Scaffold(body: child),
  );
}

QualityReviewsController buildController({
  List<QualityReview>? qualityReviews,
  String? qualityStatsLine,
  String? qualityStagePassRateLine,
  String? qualityReviewByIdLine,
}) {
  final controller = QualityReviewsController(
    accessTokenProvider: () => 'token',
    onErrorChanged: (_) {},
  );
  controller.qualityReviews = qualityReviews;
  controller.qualityStatsLine = qualityStatsLine;
  controller.qualityStagePassRateLine = qualityStagePassRateLine;
  controller.qualityReviewByIdLine = qualityReviewByIdLine;
  return controller;
}

void main() {
  testWidgets('quality section exposes workbench entry and summary', (
    WidgetTester tester,
  ) async {
    final controller = buildController(
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
    );
    await tester.pumpWidget(
      _buildTestApp(
        QualityReviewsSection(
          accessToken: 'token',
          controller: controller,
          initialProjectNumericId: 9,
          platformConfig: _testPlatformConfig,
        ),
      ),
    );

    expect(find.text('打开质量工作台'), findsOneWidget);
    expect(find.text('评审 1 条 · auto 0 条 · output:manual:82'), findsOneWidget);
    controller.dispose();
  });

  testWidgets('quality workbench dialog shows seeded controls', (
    WidgetTester tester,
  ) async {
    final controller = buildController(
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
    );
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      _buildTestApp(
        QualityReviewsSection(
          accessToken: 'token',
          controller: controller,
          initialProjectNumericId: 9,
          platformConfig: _testPlatformConfig,
        ),
      ),
    );

    await tester.tap(find.text('打开质量工作台'));
    await tester.pumpAndSettle();

    expect(find.text('质量工作台'), findsOneWidget);
    expect(find.text('筛选与读取'), findsOneWidget);
    expect(find.text('创建评审'), findsNWidgets(2));
    expect(find.text('评审详情：r1 · output · manual'), findsNWidgets(2));
    expect(find.textContaining('Token效率：'), findsNothing);
    expect(find.text('只看 auto 样本'), findsOneWidget);
    expect(find.widgetWithText(TextField, '9'), findsNWidgets(2));
    expect(find.widgetWithText(TextField, 'output'), findsWidgets);
  });

  testWidgets('quality workbench resolves numeric project seed from uuid-only scope', (
    WidgetTester tester,
  ) async {
    final controller = buildController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      _buildTestApp(
        QualityReviewsSection(
          accessToken: 'token',
          controller: controller,
          initialProjectNumericId: null,
          initialProjectUuid: 'project-uuid-9',
          platformConfig: _testPlatformConfig,
          fetchProjectsOverride: (token) async => const [
            ProjectRow(
              id: 'project-uuid-9',
              workspaceId: 'workspace-1',
              numericId: 9,
              name: 'Project 9',
              projectAccessMode: 'inherited',
              projectAccessRole: 'member',
            ),
          ],
        ),
      ),
    );

    await tester.tap(find.text('打开质量工作台'));
    await tester.pumpAndSettle();

    expect(find.text('质量工作台'), findsOneWidget);
    expect(find.widgetWithText(TextField, '9'), findsNWidgets(2));
  });
}
