import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openflow_app/design_system/theme.dart';
import 'package:openflow_app/l10n/app_localizations.dart';
import 'package:openflow_app/l10n/app_localizations_zh.dart';
import 'package:openflow_app/project_studio/project_studio_host.dart';
import 'package:openflow_app/project_studio/project_studio_page.dart';
import 'package:openflow_app/project_studio/studio_step.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/ignore_layout_overflow.dart';
import '../support/project_studio_fixture.dart';

void main() {
  testWidgets('script step prep sheet opens from compact bar', (
    WidgetTester tester,
  ) async {
    final zh = AppLocalizationsZh();
    SharedPreferences.setMockInitialValues(<String, Object>{
      'studio_last_step_7': 'script',
    });
    await tester.binding.setSurfaceSize(const Size(1400, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        theme: buildStudioDarkTheme(useBundledFonts: true),
        locale: const Locale('zh'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: ProjectStudioPage(
            host: buildScriptStepStudioHost(l10n: zh),
          ),
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.text(zh.studioScriptStepSetupOpen));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text(zh.studioScriptStepSetupTitle), findsOneWidget);
    expectNoBenignQueuedExceptions(tester);
  });

  testWidgets('compact bar unfold workflow sheet opens on script step', (
    WidgetTester tester,
  ) async {
    final zh = AppLocalizationsZh();
    SharedPreferences.setMockInitialValues(<String, Object>{
      'studio_last_step_7': 'script',
    });
    await tester.binding.setSurfaceSize(const Size(1400, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        theme: buildStudioDarkTheme(useBundledFonts: true),
        locale: const Locale('zh'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: ProjectStudioPage(
            host: buildScriptStepStudioHost(l10n: zh),
          ),
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.byIcon(Icons.unfold_more_rounded));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.byType(Dialog), findsOneWidget);
    expect(find.text(zh.studioCreatorJourneyCompactExpandTitle), findsOneWidget);
    expectNoBenignQueuedExceptions(tester);
  });

  testWidgets('art step step prep sheet opens when home is available', (
    WidgetTester tester,
  ) async {
    final zh = AppLocalizationsZh();
    SharedPreferences.setMockInitialValues(<String, Object>{
      'studio_last_step_7': 'art',
    });
    await tester.binding.setSurfaceSize(const Size(1400, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final host = ProjectStudioHost(
      projectNumericId: 7,
      projectUuid: '550e8400-e29b-41d4-a716-446655440007',
      projectName: '演示项目',
      accessToken: 'token',
      home: fixtureScriptStepProjectHome(l10n: zh),
      initialStep: StudioStep.art,
      completedSteps: 2,
      onExit: () {},
      onStepChanged: (_) {},
      onOpenAgentDrawer: () {},
      onRunHarnessAgent: (_) async {},
      buildStepBody: (step) => const SizedBox.shrink(),
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: buildStudioDarkTheme(useBundledFonts: true),
        locale: const Locale('zh'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: ProjectStudioPage(host: host)),
      ),
    );
    await tester.pump();

    await tester.tap(find.text(zh.studioScriptStepSetupOpen));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text(zh.studioStepPrepSheetSubtitle), findsOneWidget);
    expectNoBenignQueuedExceptions(tester);
  });
}
