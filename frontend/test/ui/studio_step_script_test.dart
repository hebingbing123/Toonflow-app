import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import '../support/ignore_layout_overflow.dart';
import 'package:openflow_app/design_system/theme.dart';
import 'package:openflow_app/l10n/app_localizations.dart';
import 'package:openflow_app/l10n/app_localizations_zh.dart';
import 'package:openflow_app/project_studio/project_studio_page.dart';
import 'package:openflow_app/project_studio/studio_agent_quick_bar.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/project_studio_fixture.dart';
import '../support/studio_workbench_section_test_support.dart';

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
  testWidgets('project studio script step shows agent quick bar and body', (
    WidgetTester tester,
  ) async {
    final zh = AppLocalizationsZh();
    SharedPreferences.setMockInitialValues(<String, Object>{
      'studio_last_step_7': 'script',
    });

    await tester.binding.setSurfaceSize(const Size(1280, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      _wrap(
        ProjectStudioPage(
          host: buildScriptStepStudioHost(l10n: zh),
        ),
      ),
    );
    await tester.pump();
    await expandAllStudioWorkbenchSections(tester);

    expect(find.text('演示项目'), findsOneWidget);
    expect(find.text(zh.studioStepScriptBody), findsOneWidget);

    await tester.tap(find.text(zh.studioScriptStepSetupOpen));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text(zh.studioScriptStepSetupTitle), findsOneWidget);
    await expandAllStudioWorkbenchSections(tester);

    expect(find.text(zh.studioAgentRewriteScript), findsOneWidget);
    expect(find.text(zh.studioAgentExtractEntities), findsOneWidget);
    expect(find.byType(StudioAgentQuickBar), findsOneWidget);
    expectNoBenignQueuedExceptions(tester);
  });
}
