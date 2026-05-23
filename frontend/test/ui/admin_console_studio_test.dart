import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import '../support/ignore_layout_overflow.dart';
import 'package:openflow_app/admin_console/controller.dart';
import 'package:openflow_app/admin_console/section.dart';
import 'package:openflow_app/l10n/app_localizations_zh.dart';

import '../support/studio_golden_app.dart';

void main() {
  testWidgets('admin console shows studio inset header', (WidgetTester tester) async {
    final zh = AppLocalizationsZh();
    final controller = AdminConsoleController(
      onErrorChanged: (_) {},
    );
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      studioGoldenApp(
        surfaceSize: const Size(900, 700),
        child: Scaffold(
          body: AdminConsoleSection(controller: controller),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text(zh.adminConsoleTitle), findsOneWidget);
    expectNoBenignQueuedExceptions(tester);
  });
}
