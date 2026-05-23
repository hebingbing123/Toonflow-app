import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openflow_app/design_system/theme.dart';
import 'package:openflow_app/home_page.dart';
import 'package:openflow_app/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/ui_gallery_capture.dart';
import '../support/utility_shell_fixtures.dart';

/// Isolated golden for platform config (avoids binding pollution from gallery file).
void main() {
  testWidgets('platform_config desktop layout golden', (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});

    final router = buildPlatformConfigTestRouter();
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
        theme: buildStudioDarkTheme(useBundledFonts: true),
        routerConfig: router,
      ),
    );
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 200));

    await expectLater(
      find.byType(HomePage),
      matchesGoldenFile(goldenPathForDesktopLayout('13_platform_config')),
    );
  });
}
