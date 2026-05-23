import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openflow_app/design_system/components/studio_dropdown_field.dart';
import 'package:openflow_app/design_system/theme.dart';
import 'package:openflow_app/l10n/app_localizations.dart';
import 'package:openflow_app/project_editor/style_pack_catalog.dart';
import 'package:openflow_app/project_studio/art_step_panel.dart';
import 'package:openflow_app/rust_api.dart';

const _testProject = ProjectRow(
  id: '00000000-0000-0000-0000-000000000001',
  numericId: 1,
  projectAccessMode: 'inherited',
  projectAccessRole: 'owner',
);

Future<StylePackCatalog> _emptyCatalog(
  String accessToken,
  AppLocalizations l10n,
) async {
  return const StylePackCatalog(
    artPacks: <StylePackOption>[],
    storyPacks: <StylePackOption>[],
  );
}

Future<StylePackCatalog> _sampleCatalog(
  String accessToken,
  AppLocalizations l10n,
) async {
  return StylePackCatalog(
    artPacks: <StylePackOption>[
      StylePackOption(
        path: 'art_skills/anime_v2',
        name: 'Anime v2',
        description: 'Test art pack',
        tag: l10n.projectEditorStylePackTagArt,
      ),
    ],
    storyPacks: <StylePackOption>[
      StylePackOption(
        path: 'story_skills/narrative_warm',
        name: 'Warm narrative',
        description: 'Test story pack',
        tag: l10n.projectEditorStylePackTagStory,
      ),
      StylePackOption(
        path: 'story_skills/cool_thriller',
        name: 'Cool thriller',
        description: 'Alternate story pack',
        tag: l10n.projectEditorStylePackTagStory,
      ),
    ],
  );
}

const _fixtureHome = ProjectHome(
  project: _testProject,
  stats: ProjectStats(
    scriptCount: 0,
    storyboardCount: 0,
    roleCount: 0,
    novelCount: 0,
    videoCount: 0,
  ),
  readinessScore: 35,
  readinessSummary: 'Early setup',
  onboarding: ProjectHomeOnboarding(
    complete: false,
    nextStep: 'Complete brief',
    checklist: <ProjectHomeChecklistItem>[
      ProjectHomeChecklistItem(
        key: 'brief',
        label: 'Complete project brief',
        done: false,
        detail: 'Add premise and audience',
      ),
      ProjectHomeChecklistItem(
        key: 'source',
        label: 'Connect upstream content',
        done: true,
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

Widget _artPanelApp({
  required ProjectRow project,
  required ValueChanged<ProjectRow> onProjectUpdated,
  StylePackCatalogLoader? catalogLoader,
  ArtStepPanelSaver? saver,
  ProjectHome? projectHome,
  VoidCallback? onOpenBriefContext,
  VoidCallback? onNavigateToScriptStep,
}) {
  return MaterialApp(
    theme: buildStudioDarkTheme(useBundledFonts: true),
    locale: const Locale('en'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(
      body: ProjectStudioArtStepPanel(
        accessToken: 'test-token',
        catalogLoader: catalogLoader,
        saver: saver,
        project: project,
        onProjectUpdated: onProjectUpdated,
        projectHome: projectHome,
        onOpenBriefContext: onOpenBriefContext ?? () {},
        onNavigateToScriptStep: onNavigateToScriptStep,
      ),
    ),
  );
}

void main() {
  test('normalizeArtStylePackPath prefixes bare catalog keys', () {
    expect(
      normalizeArtStylePackPath('2D_chinese_guofeng'),
      'art_skills/2D_chinese_guofeng',
    );
    expect(
      normalizeArtStylePackPath('art_skills/foo'),
      'art_skills/foo',
    );
  });

  testWidgets('art step shows style pack pickers when catalog is injected', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(900, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      _artPanelApp(
        catalogLoader: _sampleCatalog,
        project: _testProject.copyWith(
          artStylePack: 'art_skills/anime_v2',
          storyStylePack: 'story_skills/narrative_warm',
        ),
        onProjectUpdated: (_) {},
      ),
    );
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.text('Save art direction'), findsOneWidget);
    expect(find.text('Art style pack'), findsWidgets);
    expect(find.text('Story style pack'), findsWidgets);
    expect(find.text('Anime v2'), findsOneWidget);
    expect(find.text('Warm narrative'), findsOneWidget);
    expect(find.text('Current selection'), findsOneWidget);
    expect(find.text('Reset'), findsOneWidget);
    expect(find.text('Brief & brand constraints'), findsOneWidget);
  });

  testWidgets('art step shows inline readiness checklist when home provided', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(900, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    var briefOpened = false;
    var scriptNavigated = false;

    await tester.pumpWidget(
      _artPanelApp(
        catalogLoader: _emptyCatalog,
        project: _testProject,
        projectHome: _fixtureHome,
        onProjectUpdated: (_) {},
        onOpenBriefContext: () => briefOpened = true,
        onNavigateToScriptStep: () => scriptNavigated = true,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('studio_art_step_readiness')), findsOneWidget);
    expect(find.text('Complete project brief'), findsOneWidget);
    expect(find.text('Connect upstream content'), findsOneWidget);
    expect(find.text('Add premise and audience'), findsOneWidget);
    expect(find.text('35%'), findsOneWidget);

    await tester.tap(find.text('Complete project brief'));
    await tester.pump();
    expect(briefOpened, isTrue);

    await tester.tap(find.text('Connect upstream content'));
    await tester.pump();
    expect(scriptNavigated, isFalse);
  });

  testWidgets('save invokes saver, onProjectUpdated, and success snackbar', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(900, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    ProjectRow? savedRow;
    var saverCalls = 0;

    await tester.pumpWidget(
      _artPanelApp(
        catalogLoader: _emptyCatalog,
        project: _testProject,
        saver: ({
          required String accessToken,
          required ProjectRow project,
          required String? artStylePack,
          required String? storyStylePack,
          required String artStyleText,
        }) async {
          saverCalls++;
          expect(accessToken, 'test-token');
          expect(artStyleText, 'Ink wash drama');
          return ProjectRow(
            id: project.id,
            numericId: project.numericId,
            artStyle: artStyleText,
            artStylePack: artStylePack,
            storyStylePack: storyStylePack,
            projectAccessMode: project.projectAccessMode,
            projectAccessRole: project.projectAccessRole,
          );
        },
        onProjectUpdated: (row) => savedRow = row,
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'Ink wash drama');
    await tester.pump();

    final saveKey = find.byKey(const Key('studio_art_step_save'));
    expect(tester.widget<FilledButton>(saveKey).onPressed, isNotNull);
    await tester.tap(saveKey);
    await tester.pump();
    await tester.pumpAndSettle();

    expect(saverCalls, 1);
    expect(savedRow?.artStyle, 'Ink wash drama');
    expect(
      find.text('Art direction saved for this project.'),
      findsOneWidget,
    );
  });

  testWidgets('changing story pack enables save and invokes saver', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(900, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    ProjectRow? savedRow;
    String? savedStoryPack;

    await tester.pumpWidget(
      _artPanelApp(
        catalogLoader: _sampleCatalog,
        project: _testProject.copyWith(
          artStylePack: 'art_skills/anime_v2',
          storyStylePack: 'story_skills/narrative_warm',
        ),
        saver: ({
          required String accessToken,
          required ProjectRow project,
          required String? artStylePack,
          required String? storyStylePack,
          required String artStyleText,
        }) async {
          savedStoryPack = storyStylePack;
          return ProjectRow(
            id: project.id,
            numericId: project.numericId,
            artStylePack: artStylePack,
            storyStylePack: storyStylePack,
            artStyle: artStyleText.isEmpty ? null : artStyleText,
            projectAccessMode: project.projectAccessMode,
            projectAccessRole: project.projectAccessRole,
          );
        },
        onProjectUpdated: (row) => savedRow = row,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byType(StudioDropdownButtonFormField<String>).last);
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('Cool thriller'));
    await tester.pumpAndSettle();

    final saveKey = find.byKey(const Key('studio_art_step_save'));
    expect(tester.widget<FilledButton>(saveKey).onPressed, isNotNull);
    await tester.tap(saveKey);
    await tester.pumpAndSettle();

    expect(savedStoryPack, 'story_skills/cool_thriller');
    expect(savedRow?.storyStylePack, 'story_skills/cool_thriller');
  });
}

extension on ProjectRow {
  ProjectRow copyWith({
    String? artStyle,
    String? artStylePack,
    String? storyStylePack,
  }) {
    return ProjectRow(
      id: id,
      workspaceId: workspaceId,
      numericId: numericId,
      name: name,
      intro: intro,
      projectType: projectType,
      textModel: textModel,
      multimodalModel: multimodalModel,
      imageModel: imageModel,
      imageQuality: imageQuality,
      videoModel: videoModel,
      artStyle: artStyle ?? this.artStyle,
      directorManual: directorManual,
      mode: mode,
      videoRatio: videoRatio,
      createTimeMs: createTimeMs,
      artStylePack: artStylePack ?? this.artStylePack,
      storyStylePack: storyStylePack ?? this.storyStylePack,
      targetMarket: targetMarket,
      targetPlatforms: targetPlatforms,
      durationStrategy: durationStrategy,
      voiceModel: voiceModel,
      voiceProfile: voiceProfile,
      subtitleStyle: subtitleStyle,
      bgmStrategy: bgmStrategy,
      projectAccessMode: projectAccessMode,
      projectAccessRole: projectAccessRole,
    );
  }
}
