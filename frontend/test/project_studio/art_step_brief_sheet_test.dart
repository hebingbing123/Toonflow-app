import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openflow_app/design_system/theme.dart';
import 'package:openflow_app/l10n/app_localizations.dart';
import 'package:openflow_app/project_studio/art_step_brief_sheet.dart';
import 'package:openflow_app/project_studio/art_step_checklist_actions.dart';
import 'package:openflow_app/rust_api.dart';

const _testProject = ProjectRow(
  id: '00000000-0000-0000-0000-000000000001',
  numericId: 1,
  projectAccessMode: 'inherited',
  projectAccessRole: 'owner',
);

const _testHome = ProjectHome(
  project: _testProject,
  stats: ProjectStats(
    scriptCount: 0,
    storyboardCount: 0,
    roleCount: 0,
    novelCount: 0,
    videoCount: 0,
  ),
  readinessScore: 25,
  readinessSummary: 'Early',
  onboarding: ProjectHomeOnboarding(
    complete: false,
    checklist: <ProjectHomeChecklistItem>[
      ProjectHomeChecklistItem(
        key: ArtStepChecklistKey.brief,
        label: 'Complete project brief',
        done: false,
      ),
      ProjectHomeChecklistItem(
        key: ArtStepChecklistKey.brandBible,
        label: 'Complete brand bible',
        done: false,
      ),
      ProjectHomeChecklistItem(
        key: ArtStepChecklistKey.source,
        label: 'Connect upstream content',
        done: false,
      ),
    ],
  ),
  styleBibleReady: false,
  cockpit: ProjectHomeCockpit(
    headline: 'Headline',
    subheadline: 'Sub',
    primaryAction: ProjectHomeAction(
      key: 'finish_onboarding',
      title: 'Finish',
      detail: '',
      targetStep: 'art',
      ctaLabel: 'Continue',
    ),
    secondaryActions: <ProjectHomeAction>[],
    metrics: <ProjectHomeMetric>[],
    starterTemplates: <ProjectHomeStarterTemplate>[],
  ),
);

void main() {
  testWidgets('brief sheet checklist brief item focuses premise field', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(900, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        theme: buildStudioDarkTheme(useGoogleFonts: false),
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) {
            return Scaffold(
              body: Center(
                child: FilledButton(
                  onPressed: () {
                    showArtStepBriefContextSheet(
                      context: context,
                      accessToken: 'token',
                      project: _testProject,
                      home: _testHome,
                      onOpenFullProjectSettings: () {},
                    );
                  },
                  child: const Text('Open'),
                ),
              ),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('studio_art_checklist_brief')));
    await tester.pumpAndSettle();

    expect(find.text('Brief & visual constraints'), findsOneWidget);
    final premiseField = find.widgetWithText(
      TextField,
      'Premise',
    );
    expect(premiseField, findsOneWidget);
    expect(tester.widget<TextField>(premiseField).focusNode?.hasFocus, isTrue);
  });

  testWidgets('brief sheet checklist source item closes and navigates', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(900, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    var scriptNavigated = false;

    await tester.pumpWidget(
      MaterialApp(
        theme: buildStudioDarkTheme(useGoogleFonts: false),
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) {
            return Scaffold(
              body: Center(
                child: FilledButton(
                  onPressed: () {
                    showArtStepBriefContextSheet(
                      context: context,
                      accessToken: 'token',
                      project: _testProject,
                      home: _testHome,
                      onOpenFullProjectSettings: () {},
                      onNavigateToScriptStep: () => scriptNavigated = true,
                    );
                  },
                  child: const Text('Open'),
                ),
              ),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('studio_art_checklist_source')));
    await tester.pumpAndSettle();

    expect(scriptNavigated, isTrue);
    expect(find.text('Brief & visual constraints'), findsNothing);
  });
}
