import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openflow_app/design_system/theme.dart';
import 'package:openflow_app/l10n/app_localizations.dart';
import 'package:openflow_app/l10n/app_localizations_zh.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/ui_gallery_capture.dart';
import '../support/utility_shell_fixtures.dart';

/// Help Hub studio pane with debug webhook/billing seeds (zh).
void main() {
  testWidgets('help_hub shows seeded webhook and billing audit cards', (
    WidgetTester tester,
  ) async {
    final zh = AppLocalizationsZh();
    SharedPreferences.setMockInitialValues(<String, Object>{});

    final router = buildHelpHubTestRouter();
    addTearDown(router.dispose);

    await tester.binding.setSurfaceSize(const Size(1366, 768));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp.router(
        locale: const Locale('zh'),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        theme: buildStudioDarkTheme(useGoogleFonts: false),
        routerConfig: router,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text(zh.helpHubDocsTitle), findsWidgets);
    expect(find.text(zh.opsWhLatestCreatedTitle), findsOneWidget);
    expect(find.text(zh.opsWhRecentDeliveries), findsOneWidget);
    expect(
      find.textContaining('hooks.example.com/a/really/long/webhook/path/alpha'),
      findsWidgets,
    );
    expect(find.textContaining('upstream timeout after retry'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('help_hub desktop layout golden', (tester) async {
    final zh = AppLocalizationsZh();
    SharedPreferences.setMockInitialValues(<String, Object>{});

    final router = buildHelpHubTestRouter();
    addTearDown(router.dispose);

    await tester.binding.setSurfaceSize(const Size(1366, 768));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp.router(
        locale: const Locale('zh'),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        theme: buildStudioDarkTheme(useGoogleFonts: false),
        routerConfig: router,
      ),
    );
    await tester.pumpAndSettle();

    await expectLater(
      find.text(zh.opsWhSectionTitle),
      matchesGoldenFile(goldenPathForDesktopLayout('10_help_hub')),
    );
  });
}
