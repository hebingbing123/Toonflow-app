import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openflow_app/design_system/theme.dart';
import 'package:openflow_app/l10n/app_localizations.dart';
import 'package:openflow_app/l10n/app_localizations_zh.dart';
import 'package:openflow_app/team_workspaces/section.dart';

/// Team workspaces section studio smoke (no network when logged out).
void main() {
  testWidgets('team workspaces shows login required without token', (
    WidgetTester tester,
  ) async {
    final zh = AppLocalizationsZh();

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('zh'),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        theme: buildStudioDarkTheme(useGoogleFonts: false),
        home: const Scaffold(
          body: TeamWorkspacesSection(accessToken: null),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text(zh.teamWorkspaceLoginRequired), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
