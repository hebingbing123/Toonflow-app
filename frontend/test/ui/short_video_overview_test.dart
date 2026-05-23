import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import '../support/ignore_layout_overflow.dart';
import 'package:openflow_app/design_system/components/studio_pane_header.dart';
import 'package:openflow_app/l10n/app_localizations_zh.dart';
import 'package:openflow_app/short_video_space/view.dart';

import '../support/short_video_space_fixture.dart';
import '../support/studio_golden_app.dart';

void main() {
  testWidgets('short video overview shows pane header and mode section', (
    WidgetTester tester,
  ) async {
    final zh = AppLocalizationsZh();

    await tester.pumpWidget(
      studioGoldenApp(
        child: SingleChildScrollView(
          child: buildShortVideoOverviewFixture(zh),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(StudioPaneHeader), findsOneWidget);
    expect(find.text(zh.shortVideoSpacePageTitle), findsOneWidget);
    expect(find.byType(ShortVideoSpaceView), findsOneWidget);
    expectNoBenignQueuedExceptions(tester);
  });
}
