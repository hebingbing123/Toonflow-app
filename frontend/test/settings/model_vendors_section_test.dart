import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import '../support/ignore_layout_overflow.dart';
import 'package:openflow_app/design_system/theme.dart';
import 'package:openflow_app/l10n/app_localizations.dart';
import 'package:openflow_app/settings/model_vendors/model_vendors_section.dart';

void main() {
  testWidgets('model vendors renders empty catalog state without token', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildStudioDarkTheme(useGoogleFonts: false),
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const Scaffold(
          body: ModelVendorsSection(accessToken: null),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Model providers'), findsOneWidget);
    expect(find.text('No model providers in the catalog.'), findsOneWidget);
    expectNoBenignQueuedExceptions(tester);
  });
}
