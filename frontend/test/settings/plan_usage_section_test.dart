import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openflow_app/design_system/theme.dart';
import 'package:openflow_app/l10n/app_localizations.dart';
import 'package:openflow_app/settings/plan_usage/plan_usage_section.dart';

void main() {
  testWidgets('plan usage shows login hint without token', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildStudioDarkTheme(useGoogleFonts: false),
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const Scaffold(
          body: PlanUsageSection(accessToken: null),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Sign in to manage enterprise workspaces.'), findsOneWidget);
  });
}
