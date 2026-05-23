import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import '../support/ignore_layout_overflow.dart';
import 'package:openflow_app/design_system/theme.dart';
import 'package:openflow_app/l10n/app_localizations.dart';
import 'package:openflow_app/l10n/app_localizations_zh.dart';
import 'package:openflow_app/project_studio/project_studio_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/project_studio_fixture.dart';

Widget _wrap(Widget child) {
  return MaterialApp(
    theme: buildStudioDarkTheme(useBundledFonts: true),
    locale: const Locale('zh'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(body: child),
  );
}

void main() {
  testWidgets('project studio art step shows art panel in shell', (
    WidgetTester tester,
  ) async {
    final zh = AppLocalizationsZh();
    SharedPreferences.setMockInitialValues(<String, Object>{
      'studio_last_step_7': 'art',
    });

    await tester.binding.setSurfaceSize(const Size(1280, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      _wrap(
        ProjectStudioPage(
          host: buildArtStepStudioHost(l10n: zh),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('演示项目'), findsOneWidget);
    expect(find.byKey(const Key('studio_art_step_panel')), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const Key('studio_art_step_panel')),
        matching: find.text(zh.studioStepArtTitle),
      ),
      findsOneWidget,
    );
    expect(find.text(zh.studioArtStepSaveButton), findsOneWidget);
    expect(find.text('国风二维'), findsOneWidget);
    expect(find.text('家庭温情'), findsOneWidget);
    expectNoBenignQueuedExceptions(tester);
  });

}
