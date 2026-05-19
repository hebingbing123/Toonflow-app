import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openflow_app/account/controller.dart';
import 'package:openflow_app/api_keys/controller.dart';
import 'package:openflow_app/l10n/app_localizations_zh.dart';
import 'package:openflow_app/product_shell/settings_hub_page.dart';

import '../support/studio_golden_app.dart';

void main() {
  testWidgets('settings hub account tab renders in zh studio shell', (
    WidgetTester tester,
  ) async {
    final zh = AppLocalizationsZh();
    final accountController = AccountController(
      accessTokenProvider: () => null,
      onErrorChanged: (_) {},
      l10nProvider: () => zh,
    );
    final apiKeysController = ApiKeysController(
      accessTokenProvider: () => null,
      onErrorChanged: (_) {},
      l10nProvider: () => zh,
    );
    addTearDown(accountController.dispose);
    addTearDown(apiKeysController.dispose);

    await tester.pumpWidget(
      studioGoldenApp(
        surfaceSize: const Size(900, 700),
        child: SettingsHubPage(
          accountController: accountController,
          apiKeysController: apiKeysController,
          accessToken: null,
          onAccountDeleted: (_) async {},
          onWorkspaceContextChanged: () async {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text(zh.studioSettingsHubTitle), findsOneWidget);
    expect(find.text(zh.studioSettingsTabAccount), findsWidgets);
    expect(tester.takeException(), isNull);
  });
}
