import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import '../support/ignore_layout_overflow.dart';
import 'package:openflow_app/design_system/theme.dart';
import 'package:openflow_app/l10n/app_localizations.dart';
import 'package:openflow_app/l10n/app_localizations_zh.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/utility_shell_fixtures.dart';

/// Notifications utility pane via product shell routing (zh).
void main() {
  testWidgets('notifications utility pane shows center title', (
    WidgetTester tester,
  ) async {
    final zh = AppLocalizationsZh();
    SharedPreferences.setMockInitialValues(<String, Object>{});

    final router = buildNotificationsUtilityTestRouter();
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

    expect(find.text(zh.notificationsCenterTitle), findsWidgets);
    expect(find.text(zh.notificationsEmptyFiltered), findsOneWidget);
    expect(
      router.routeInformationProvider.value.uri.toString(),
      '/?pane=notifications',
    );
    expectNoBenignQueuedExceptions(tester);
  });
}
