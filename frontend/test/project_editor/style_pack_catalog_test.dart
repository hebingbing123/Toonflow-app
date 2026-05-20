import 'package:flutter_test/flutter_test.dart';
import 'package:openflow_app/l10n/app_localizations_en.dart';
import 'package:openflow_app/project_editor/style_pack_catalog.dart';
import 'package:openflow_app/rust_api.dart';

void main() {
  test('buildStylePackCatalogFromResponses normalizes API style paths', () {
    final l10n = AppLocalizationsEn();
    final catalog = buildStylePackCatalogFromResponses(
      visualManual: VisualManualResponseV1(
        styles: <VisualManualStyleV1>[
          VisualManualStyleV1(
            name: 'Guofeng 2D',
            image: const <String>[],
            stylePath: '2D_chinese_guofeng',
            data: const <VisualManualEntryV1>[
              VisualManualEntryV1(
                label: 'scene',
                value: 'scene',
                data: 'Ink lines with muted palette',
              ),
            ],
          ),
        ],
      ),
      directorManual: DirectorManualListResponse(
        data: <DirectorManualStyleRow>[
          DirectorManualStyleRow(
            name: 'Family warmth',
            image: const <String>[],
            directorManual: 'Family_warmth',
            data: const <DirectorManualDataSlot>[
              DirectorManualDataSlot(
                label: 'tone',
                value: 'tone',
                data: 'Warm family narrative pacing',
              ),
            ],
          ),
        ],
      ),
      l10n: l10n,
    );

    expect(catalog.artPacks, hasLength(1));
    expect(catalog.artPacks.first.path, 'art_skills/2D_chinese_guofeng');
    expect(catalog.artPacks.first.description, 'Ink lines with muted palette');

    expect(catalog.storyPacks, hasLength(1));
    expect(catalog.storyPacks.first.path, 'story_skills/Family_warmth');
    expect(
      catalog.storyPacks.first.description,
      'Warm family narrative pacing',
    );

    expect(
      findArtStylePackOption(
        catalog.artPacks,
        '2D_chinese_guofeng',
      )?.name,
      'Guofeng 2D',
    );
  });
}
