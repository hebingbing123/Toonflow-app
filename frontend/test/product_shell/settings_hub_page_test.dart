import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import '../support/ignore_layout_overflow.dart';
import 'package:openflow_app/account/controller.dart';
import 'package:openflow_app/api_keys/controller.dart';
import 'package:openflow_app/design_system/theme.dart';
import 'package:openflow_app/l10n/app_localizations.dart';
import 'package:openflow_app/product_shell/settings_hub_page.dart';

Widget _wrapApp({required Widget child}) {
  return MaterialApp(
    theme: buildStudioDarkTheme(useBundledFonts: true),
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
  testWidgets('settings hub stays stable on narrow layouts', (tester) async {
    final accountController = _buildAccountController();
    final apiKeysController = _buildApiKeysController();
    addTearDown(accountController.dispose);
    addTearDown(apiKeysController.dispose);

    await tester.binding.setSurfaceSize(const Size(360, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

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
    expect(find.text('Account'), findsWidgets);
    expect(find.text('Data export'), findsOneWidget);
    final exportPanel = find.ancestor(
      of: find.text('Data export'),
      matching: find.byType(DecoratedBox),
    );
    expect(exportPanel, findsOneWidget);
    expect(tester.getSize(exportPanel).width, greaterThan(300));
    final tabBar = find.byType(TabBar);
    final accountTabLabel = find
        .descendant(of: tabBar, matching: find.text('Account'))
        .first;
    final tabBarLeft = tester.getTopLeft(tabBar).dx;
    final accountTabLeft = tester.getTopLeft(accountTabLabel).dx;
    expect(accountTabLeft - tabBarLeft, lessThan(48));
    expectNoBenignQueuedExceptions(tester);
  });

  testWidgets(
    'settings hub switches across account, plan usage, api keys, and workspaces',
    (tester) async {
      final accountController = _buildAccountController();
      final apiKeysController = _buildApiKeysController();
      addTearDown(accountController.dispose);
      addTearDown(apiKeysController.dispose);

      await tester.binding.setSurfaceSize(const Size(1280, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

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
      expect(find.text('Account'), findsWidgets);
      expect(find.text('Plan & usage'), findsWidgets);
      expect(find.text('API & models'), findsWidgets);
      expect(find.text('Workspaces'), findsWidgets);
      expect(find.text('Data export'), findsOneWidget);
      expect(find.text('Delete account'), findsOneWidget);

      await tester.tap(
        find
            .descendant(
              of: find.byType(TabBar),
              matching: find.text('Plan & usage'),
            )
            .first,
      );
      await tester.pumpAndSettle();
      expect(
        find.text('Sign in to manage enterprise workspaces.'),
        findsOneWidget,
      );

      await tester.tap(
        find
            .descendant(
              of: find.byType(TabBar),
              matching: find.text('API & models'),
            )
            .first,
      );
      await tester.pumpAndSettle();
      expect(find.text('API keys'), findsOneWidget);

      await tester.tap(
        find
            .descendant(
              of: find.byType(TabBar),
              matching: find.text('Workspaces'),
            )
            .first,
      );
      await tester.pumpAndSettle();
      expect(
        find.text('Sign in to manage enterprise workspaces.'),
        findsOneWidget,
      );
      expectNoBenignQueuedExceptions(tester);
    },
  );

  testWidgets('settings hub expands on wide desktop layouts', (tester) async {
    final accountController = _buildAccountController();
    final apiKeysController = _buildApiKeysController();
    addTearDown(accountController.dispose);
    addTearDown(apiKeysController.dispose);

    await tester.binding.setSurfaceSize(const Size(1600, 960));
    addTearDown(() => tester.binding.setSurfaceSize(null));

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

    expect(find.byType(TabBar), findsOneWidget);
    expect(tester.getSize(find.byType(TabBar)).width, greaterThan(1200));
    expectNoBenignQueuedExceptions(tester);
  });

  testWidgets('settings hub delete confirmation accepts normalized phrase', (
    tester,
  ) async {
    final accountController = _buildAccountController();
    final apiKeysController = _buildApiKeysController();
    addTearDown(accountController.dispose);
    addTearDown(apiKeysController.dispose);

    await tester.binding.setSurfaceSize(const Size(1280, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

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

    await tester.enterText(find.byType(TextField), '  delete   my   account  ');
    await tester.tap(find.byType(Checkbox));
    await tester.pumpAndSettle();

    final deleteButton = tester.widget<FilledButton>(
      find.ancestor(
        of: find.byIcon(Icons.delete_forever_outlined),
        matching: find.byWidgetPredicate((widget) => widget is FilledButton),
      ),
    );
    expect(deleteButton.onPressed, isNotNull);
    expectNoBenignQueuedExceptions(tester);
  });
}
