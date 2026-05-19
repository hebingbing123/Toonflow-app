import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openflow_app/l10n/app_localizations_zh.dart';

import '../support/short_video_space_fixture.dart';
import '../support/studio_golden_app.dart';

void main() {
  testWidgets('overview and migration share one panel in a row on wide screens', (
    WidgetTester tester,
  ) async {
    final zh = AppLocalizationsZh();
    await tester.binding.setSurfaceSize(const Size(1280, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      studioGoldenApp(
        child: SingleChildScrollView(
          child: buildShortVideoOverviewFixture(zh),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text(zh.shortVideoSpaceCurrentProjectOverview), findsOneWidget);
    expect(find.text(zh.shortVideoSpaceSectionMigrationOrder), findsOneWidget);
    expect(find.byType(IntrinsicHeight), findsWidgets);
    expect(find.byType(VerticalDivider), findsOneWidget);

    final overviewTitle = find.text(zh.shortVideoSpaceCurrentProjectOverview);
    final migrationTitle = find.text(zh.shortVideoSpaceSectionMigrationOrder);
    final sharedRow = find.ancestor(
      of: overviewTitle,
      matching: find.ancestor(
        of: migrationTitle,
        matching: find.byType(Row),
      ),
    );
    expect(sharedRow, findsOneWidget);
  });

  testWidgets('overview and migration stack below two-column breakpoint', (
    WidgetTester tester,
  ) async {
    final zh = AppLocalizationsZh();
    await tester.binding.setSurfaceSize(const Size(969, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      studioGoldenApp(
        child: SingleChildScrollView(
          child: buildShortVideoOverviewFixture(zh),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text(zh.shortVideoSpaceCurrentProjectOverview), findsOneWidget);
    expect(find.text(zh.shortVideoSpaceSectionMigrationOrder), findsOneWidget);
    expect(find.byType(VerticalDivider), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('overview and migration stack on narrow screens', (
    WidgetTester tester,
  ) async {
    final zh = AppLocalizationsZh();
    await tester.binding.setSurfaceSize(const Size(390, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      studioGoldenApp(
        child: SingleChildScrollView(
          child: buildShortVideoOverviewFixture(zh),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text(zh.shortVideoSpaceCurrentProjectOverview), findsOneWidget);
    expect(find.text(zh.shortVideoSpaceSectionMigrationOrder), findsOneWidget);
    expect(find.byType(VerticalDivider), findsNothing);
    expect(find.byIcon(Icons.arrow_forward_rounded), findsWidgets);
  });
}
