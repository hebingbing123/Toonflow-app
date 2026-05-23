import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openflow_app/api_keys/controller.dart';
import 'package:openflow_app/api_keys/section.dart';
import 'package:openflow_app/l10n/app_localizations_zh.dart';

import '../support/studio_golden_app.dart';

void main() {
  testWidgets('api keys section shows studio inset header', (
    WidgetTester tester,
  ) async {
    final zh = AppLocalizationsZh();
    final controller = ApiKeysController(
      accessTokenProvider: () => null,
      onErrorChanged: (_) {},
      l10nProvider: () => zh,
    );
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      studioGoldenApp(
        surfaceSize: const Size(900, 700),
        child: Scaffold(
          body: ApiKeysSection(controller: controller),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text(zh.apiKeysSectionTitle), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
