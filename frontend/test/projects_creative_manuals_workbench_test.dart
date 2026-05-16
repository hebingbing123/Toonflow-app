import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openflow_app/l10n/app_localizations.dart';
import 'package:openflow_app/l10n/app_localizations_zh.dart';
import 'package:openflow_app/projects/workbenches/creative_manuals.dart';

void main() {
  final zh = AppLocalizationsZh();

  testWidgets('creative manuals workbench renders seeded defaults', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('zh'),
        home: Scaffold(
          body: ProjectsCreativeManualsWorkbenchDialog(accessToken: 'token'),
        ),
      ),
    );

    expect(find.text(zh.projectsCreativeManualTitle), findsOneWidget);
    expect(find.text(zh.projectsCreativeManualReloadAll), findsOneWidget);
    expect(find.text(zh.projectsCreativeManualCreateDirector), findsOneWidget);
    expect(find.text(zh.projectsCreativeManualSegmentDirector), findsOneWidget);
    expect(find.text(zh.projectsCreativeManualSegmentVisual), findsOneWidget);
    expect(find.widgetWithText(TextField, '场景|scene|\n角色|role|'), findsOneWidget);
  });
}
