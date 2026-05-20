import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openflow_app/design_system/theme.dart';
import 'package:openflow_app/l10n/app_localizations.dart';
import 'package:openflow_app/l10n/app_localizations_zh.dart';
import 'package:openflow_app/project_studio/project_studio_scope.dart';
import 'package:openflow_app/project_studio/studio_readiness.dart';
import 'package:openflow_app/project_studio/studio_step.dart';

import '../support/project_studio_fixture.dart';

void main() {
  testWidgets('project studio scope loads art step panel from host factory', (
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
          body: ProjectStudioScope(
            accessToken: 'token',
            projectNumericId: 7,
            projectUuid: fixtureArtStepProject(l10n: zh).id,
            projectName: '演示项目',
            initialStep: StudioStep.art,
            loadSnapshot: (accessToken, projectUuid) async =>
                const StudioReadinessSnapshot(completedSteps: 2),
            hostFactory: (readiness, refreshSnapshot) =>
                buildArtStepStudioHost(l10n: zh),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.descendant(
        of: find.byKey(const Key('studio_art_step_panel')),
        matching: find.text(zh.studioStepArtTitle),
      ),
      findsOneWidget,
    );
    expect(find.byKey(const Key('studio_art_step_panel')), findsOneWidget);
    expect(find.text('2/6'), findsOneWidget);
  });
}
