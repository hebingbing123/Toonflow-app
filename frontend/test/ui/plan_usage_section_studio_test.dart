import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openflow_app/l10n/app_localizations_zh.dart';
import 'package:openflow_app/settings/plan_usage/plan_usage_section.dart';

import '../support/studio_golden_app.dart';

void main() {
  testWidgets('plan usage section shows studio inset title', (
    WidgetTester tester,
  ) async {
    final zh = AppLocalizationsZh();

    await tester.pumpWidget(
      studioGoldenApp(
        surfaceSize: const Size(900, 700),
        child: const Scaffold(
          body: PlanUsageSection(accessToken: null),
        ),
      ),
    );
    await tester.pump();

    expect(find.text(zh.teamWorkspaceLoginRequired), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
