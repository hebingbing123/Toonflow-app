import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openflow_app/design_system/theme.dart';
import 'package:openflow_app/l10n/app_localizations.dart';
import 'package:openflow_app/project_editor/style_pack_catalog.dart';
import 'package:openflow_app/project_studio/art_step_panel.dart';
import 'package:openflow_app/rust_api.dart';

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

    Future<StylePackCatalog> fakeCatalog(
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
        ],
      );
    }

    await tester.pumpWidget(
      MaterialApp(
        theme: buildStudioDarkTheme(useGoogleFonts: false),
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: ProjectStudioArtStepPanel(
            accessToken: 'test-token',
            catalogLoader: fakeCatalog,
            project: const ProjectRow(
              id: '00000000-0000-0000-0000-000000000001',
              numericId: 1,
              artStylePack: 'art_skills/anime_v2',
              storyStylePack: 'story_skills/narrative_warm',
              projectAccessMode: 'inherited',
              projectAccessRole: 'owner',
            ),
            onProjectUpdated: (_) {},
            onOpenProjectSettings: () {},
          ),
        ),
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
    expect(find.text('Advanced project settings'), findsOneWidget);
  });
}
