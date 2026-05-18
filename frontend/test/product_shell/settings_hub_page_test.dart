import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openflow_app/account/controller.dart';
import 'package:openflow_app/api_keys/controller.dart';
import 'package:openflow_app/design_system/theme.dart';
import 'package:openflow_app/l10n/app_localizations.dart';
import 'package:openflow_app/product_shell/settings_hub_page.dart';

Widget _wrapApp({required Widget child}) {
  return MaterialApp(
    theme: buildStudioDarkTheme(useGoogleFonts: false),
    locale: const Locale('en'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(body: child),
  );
}

AccountController _buildAccountController() {
  return AccountController(
    accessTokenProvider: () => null,
    onErrorChanged: (_) {},
    l10nProvider: () => null,
  );
}

ApiKeysController _buildApiKeysController() {
  return ApiKeysController(
    accessTokenProvider: () => null,
    onErrorChanged: (_) {},
    l10nProvider: () => null,
  );
}

void main() {
  testWidgets(
    'settings hub switches across account, plan usage, api keys, and workspaces',
    (tester) async {
      final accountController = _buildAccountController();
      final apiKeysController = _buildApiKeysController();

      await tester.pumpWidget(
        _wrapApp(
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

      expect(find.text('Settings'), findsOneWidget);
      expect(find.text('Account'), findsOneWidget);
      expect(find.text('Plan & usage'), findsOneWidget);
      expect(find.text('API & models'), findsOneWidget);
      expect(find.text('Workspaces'), findsOneWidget);
      expect(find.text('Account section title'), findsOneWidget);

      await tester.tap(find.text('Plan & usage'));
      await tester.pumpAndSettle();
      expect(find.text('Sign in to manage enterprise workspaces.'), findsOneWidget);

      await tester.tap(find.text('API & models'));
      await tester.pumpAndSettle();
      expect(find.text('API keys'), findsOneWidget);

      await tester.tap(find.text('Workspaces'));
      await tester.pumpAndSettle();
      expect(
        find.text('Sign in to manage enterprise workspaces.'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );
}
