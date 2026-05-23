import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import '../support/ignore_layout_overflow.dart';
import 'package:openflow_app/account/controller.dart';
import 'package:openflow_app/account/section.dart';
import 'package:openflow_app/l10n/app_localizations_zh.dart';

import '../support/studio_golden_app.dart';

void main() {
  testWidgets('account section shows studio inset header', (
    WidgetTester tester,
  ) async {
    final zh = AppLocalizationsZh();
    final controller = AccountController(
      accessTokenProvider: () => null,
      onErrorChanged: (_) {},
      l10nProvider: () => zh,
    );
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      studioGoldenApp(
        surfaceSize: const Size(900, 700),
        child: Scaffold(
          body: AccountSection(
            controller: controller,
            onAccountDeleted: (_) async {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text(zh.accountSectionTitle), findsOneWidget);
    expect(find.text(zh.accountExportTitle), findsOneWidget);
    expectNoBenignQueuedExceptions(tester);
  });
}
