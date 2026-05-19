import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openflow_app/l10n/app_localizations.dart';
import 'package:openflow_app/l10n/app_localizations_zh.dart';
import 'package:openflow_app/platform/studio_load_state.dart';
import 'package:openflow_app/quality_reviews/controller.dart';
import 'package:openflow_app/quality_reviews/field_styling.dart';
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
  final zh = AppLocalizationsZh();

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

    expect(find.text(zh.qualityReviewsOpenWorkbench), findsOneWidget);
    expect(
      find.text(zh.qualityReviewsSummaryLine(1, 0, 'output:manual:82')),
      findsOneWidget,
    );
    controller.dispose();
  });

  testWidgets('product studio hides compatibility regression panel', (
    WidgetTester tester,
  ) async {
    final controller = buildController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      _buildTestApp(
        QualityReviewsSection(
          studioPresentation: true,
          accessToken: 'token',
          controller: controller,
          initialProjectNumericId: 9,
          platformConfig: _testPlatformConfig,
        ),
      ),
    );

    expect(find.text(zh.qualityReviewsCompatibilityCheck), findsNothing);
    expect(find.text(zh.qualityReviewsRunReadOnlyRegressionCheck), findsNothing);
  });

  testWidgets('product studio shows loaded-empty footer and aligned lookup row', (
    WidgetTester tester,
  ) async {
    final controller = buildController(qualityReviews: const []);
    controller.qualityReviewsLoadState = StudioLoadState.success;
    controller.qualityDashboardLoadState = StudioLoadState.success;
    addTearDown(controller.dispose);

    await tester.binding.setSurfaceSize(const Size(900, 720));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      _buildTestApp(
        QualityReviewsSection(
          studioPresentation: true,
          accessToken: 'token',
          controller: controller,
          initialProjectNumericId: 9,
          platformConfig: _testPlatformConfig,
        ),
      ),
    );
    await tester.pump();

    expect(find.text(zh.qualityReviewsEmptyForCurrentFilters), findsOneWidget);
    expect(find.text(zh.qualityReviewsCount(0)), findsOneWidget);
    expect(find.text(zh.qualityReviewsSummaryNotLoaded), findsNothing);

    final row = tester.widget<Row>(
      find.descendant(
        of: find.byType(QualityReviewIdLookupRow),
        matching: find.byType(Row),
      ),
    );
    expect(row.crossAxisAlignment, CrossAxisAlignment.end);
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

    await tester.tap(find.text(zh.qualityReviewsOpenWorkbench));
    await tester.pumpAndSettle();

    expect(find.text(zh.qualityReviewsWorkbenchTitle), findsOneWidget);
    expect(find.byType(Dialog), findsOneWidget);
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

    await tester.tap(find.text(zh.qualityReviewsOpenWorkbench));
    await tester.pumpAndSettle();

    expect(find.text(zh.qualityReviewsWorkbenchTitle), findsOneWidget);
    expect(find.byType(Dialog), findsOneWidget);
    expect(
      find.text(
        zh.qualityReviewsScopeSeedLine('projectUuid=project-uuid-9 -> projectId=9'),
      ),
      findsOneWidget,
    );
  });
}
