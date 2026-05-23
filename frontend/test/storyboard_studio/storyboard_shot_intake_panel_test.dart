import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openflow_app/design_system/theme.dart';
import 'package:openflow_app/l10n/app_localizations.dart';
import 'package:openflow_app/storyboard_studio/storyboard_shot_intake_panel.dart';

void main() {
  testWidgets('expands single-add form without opening a dialog', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildStudioDarkTheme(useBundledFonts: true),
        locale: const Locale('zh'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: StoryboardShotIntakePanel(
            accessToken: 'token',
            projectUuid: '00000000-0000-0000-0000-000000000001',
            scriptNumericId: 1,
            onShotsChanged: () async {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(Dialog), findsNothing);
    await tester.tap(find.text('新增分镜'));
    await tester.pumpAndSettle();
    expect(find.byType(Dialog), findsNothing);
    expect(find.text('分镜提示词'), findsOneWidget);
  });
}
