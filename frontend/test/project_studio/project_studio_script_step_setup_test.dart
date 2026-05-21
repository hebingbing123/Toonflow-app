import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openflow_app/design_system/theme.dart';
import 'package:openflow_app/l10n/app_localizations.dart';
import 'package:openflow_app/l10n/app_localizations_zh.dart';
import 'package:openflow_app/project_studio/project_studio_script_step_setup.dart';
import 'package:openflow_app/project_studio/studio_agent_quick_bar.dart';

import '../support/project_studio_fixture.dart';

void main() {
  testWidgets('script step setup panel starts collapsed', (
    WidgetTester tester,
  ) async {
    final zh = AppLocalizationsZh();

    await tester.pumpWidget(
      MaterialApp(
        theme: buildStudioDarkTheme(useGoogleFonts: false),
        locale: const Locale('zh'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: ProjectStudioScriptStepSetupPanel(
            accessToken: 'token',
            projectUuid: fixtureArtStepProject(l10n: zh).id,
            home: fixtureScriptStepProjectHome(l10n: zh),
            visibleAgentActions: const <StudioAgentAction>{
              StudioAgentAction.rewriteScript,
            },
            onRunHarnessAgent: (_) {},
            onExecuteHomeAction: (_) {},
            metricActionBuilder: (_) => null,
            onExecuteStarter: (_) {},
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text(zh.studioScriptStepSetupTitle), findsOneWidget);
    final toggle = find.byKey(const Key('studio_workbench_section_toggle'));
    expect(toggle, findsOneWidget);

    await tester.tap(toggle);
    await tester.pumpAndSettle();

    expect(find.text(zh.studioAgentRewriteScript), findsOneWidget);
  });
}
