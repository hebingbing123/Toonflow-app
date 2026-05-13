import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openflow_app/l10n/app_localizations.dart';
import 'package:openflow_app/projects/workbenches/creative_manuals.dart';

void main() {
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

    expect(find.text('创作手册工作台'), findsOneWidget);
    expect(find.text('刷新全部手册'), findsOneWidget);
    expect(find.text('新建导演手册'), findsOneWidget);
    expect(find.text('导演手册'), findsOneWidget);
    expect(find.text('视觉手册'), findsOneWidget);
    expect(find.widgetWithText(TextField, '场景|scene|\n角色|role|'), findsOneWidget);
  });
}
