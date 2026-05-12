import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openflow_app/l10n/app_localizations.dart';
import 'package:openflow_app/project_editor/assets/support.dart';
import 'package:openflow_app/rust_api.dart';

void main() {
  final zh = lookupAppLocalizations(const Locale('zh'));

  test('diagnoseAssetImagesWorkbench suggests loading images first', () {
    final diagnosis = diagnoseAssetImagesWorkbench(zh, hasPreviewBytes: false);

    expect(diagnosis.summary, zh.projectEditorAssetImagesDiagnosisNotLoadedSummary);
    expect(
      diagnosis.recommendedAction,
      AssetImagesWorkbenchRecommendedAction.loadImages,
    );
  });

  test('diagnoseAssetImagesWorkbench suggests creating first image', () {
    final diagnosis = diagnoseAssetImagesWorkbench(
      zh,
      imagesResponse: const ListAssetImagesResponse(items: []),
      hasPreviewBytes: false,
    );

    expect(diagnosis.summary, zh.projectEditorAssetImagesDiagnosisNoImagesSummary);
    expect(
      diagnosis.recommendedAction,
      AssetImagesWorkbenchRecommendedAction.createImage,
    );
  });

  test('diagnoseAssetImagesWorkbench suggests preview before editing', () {
    final diagnosis = diagnoseAssetImagesWorkbench(
      zh,
      imagesResponse: const ListAssetImagesResponse(
        items: [AssetImageRow(id: 'img-1', assetId: 'asset-a', sortIndex: 1)],
      ),
      selectedImageId: 'img-1',
      hasPreviewBytes: false,
    );

    expect(
      diagnosis.summary,
      zh.projectEditorAssetImagesDiagnosisPreviewPendingSummary(1),
    );
    expect(
      diagnosis.recommendedAction,
      AssetImagesWorkbenchRecommendedAction.previewSelectedImage,
    );
  });

  test('diagnoseAssetImagesWorkbench suggests saving current image', () {
    final diagnosis = diagnoseAssetImagesWorkbench(
      zh,
      imagesResponse: const ListAssetImagesResponse(
        items: [
          AssetImageRow(
            id: 'img-2',
            assetId: 'asset-a',
            sortIndex: 2,
            state: 'done',
          ),
        ],
      ),
      selectedImageId: 'img-2',
      hasPreviewBytes: true,
    );

    expect(diagnosis.summary, zh.projectEditorAssetImagesDiagnosisReadySummary);
    expect(
      diagnosis.recommendedAction,
      AssetImagesWorkbenchRecommendedAction.updateSelectedImage,
    );
  });

  test('buildAssetImagesWorkbenchFollowUp appends next step guidance', () {
    final text = buildAssetImagesWorkbenchFollowUp(
      l10n: zh,
      actionSummary: '已新增资产图片。',
      diagnosis: AssetImagesWorkbenchDiagnosis(
        summary: zh.projectEditorAssetImagesDiagnosisReadySummary,
        detail: '可继续更新 file_path。',
        recommendedAction:
            AssetImagesWorkbenchRecommendedAction.updateSelectedImage,
      ),
    );

    expect(text, contains('已新增资产图片。'));
    expect(text, contains(zh.projectEditorAssetImagesRecommendedSaveImage));
    expect(text, contains('可继续更新 file_path。'));
  });

  test('parseAssetImageCreateDraft trims fields and accepts blank sort', () {
    final draft = parseAssetImageCreateDraft(
      filePath: '  /tmp/demo.png  ',
      state: '  done ',
      sortIndex: ' ',
    );

    expect(draft, isNotNull);
    expect(draft!.filePath, '/tmp/demo.png');
    expect(draft.state, 'done');
    expect(draft.sortIndex, isNull);
  });

  test('parseAssetImageCreateDraft rejects non-positive sort', () {
    final draft = parseAssetImageCreateDraft(
      filePath: '',
      state: '',
      sortIndex: '0',
    );

    expect(draft, isNull);
  });

  test('parseAssetImagePatchDraft builds sparse request body', () {
    final draft = parseAssetImagePatchDraft(
      filePath: '  /tmp/demo.png ',
      state: ' ',
      sortIndex: '7',
    );

    expect(draft, isNotNull);
    expect(draft!.body['file_path'], '/tmp/demo.png');
    expect(draft.body['state'], isNull);
    expect(draft.body['sort_index'], 7);
  });

  test('parseAssetImagePatchDraft rejects invalid sort', () {
    final draft = parseAssetImagePatchDraft(
      filePath: '',
      state: '',
      sortIndex: '-3',
    );

    expect(draft, isNull);
  });

  test('collectVisibleAssetNumericIds sorts and deduplicates ids', () {
    expect(
      collectVisibleAssetNumericIds(const [
        AssetRow(id: 'a', numericId: 9, name: 'Hero', assetType: 'role'),
        AssetRow(id: 'b', numericId: 3, name: 'Sword', assetType: 'props'),
        AssetRow(id: 'c', numericId: 9, name: 'Hero-dup', assetType: 'role'),
      ]),
      [3, 9],
    );
  });

  test('chooseInitialAssetNumericId prefers existing preferred id', () {
    expect(
      chooseInitialAssetNumericId(const [
        AssetRow(id: 'a', numericId: 9, name: 'Hero', assetType: 'role'),
        AssetRow(id: 'b', numericId: 3, name: 'Sword', assetType: 'props'),
      ], preferredNumericId: 3),
      3,
    );
    expect(
      chooseInitialAssetNumericId(const [
        AssetRow(id: 'a', numericId: 9, name: 'Hero', assetType: 'role'),
      ], preferredNumericId: 100),
      9,
    );
  });

  test('summarizeProjectAssetRows reports counts and examples', () {
    final line = summarizeProjectAssetRows(const [
      AssetRow(id: 'a', numericId: 9, name: 'Hero', assetType: 'role'),
      AssetRow(id: 'b', numericId: 3, name: 'Sword', assetType: 'props'),
      AssetRow(id: 'c', numericId: 5, name: 'Mage', assetType: 'role'),
    ]);

    expect(line, contains('Assets 3'));
    expect(line, contains('props 1'));
    expect(line, contains('role 2'));
    expect(line, contains('#9 Hero'));
  });

  test('summarizeScriptScopedAssets describes project and script scope', () {
    expect(summarizeScriptScopedAssets(null, const []), 'Managing all project assets.');
    expect(
      summarizeScriptScopedAssets(12, const []),
      'No assets linked under script #12.',
    );
    expect(
      summarizeScriptScopedAssets(12, const [
        AssetRow(id: 'a', numericId: 9, name: 'Hero', assetType: 'role'),
        AssetRow(id: 'b', numericId: 3, name: 'Sword', assetType: 'props'),
      ]),
      'Script #12 has 2 linked asset(s).',
    );
  });

  test('parseCornerScapeTypesInput trims deduplicates and sorts', () {
    expect(parseCornerScapeTypesInput(' role,clip, role ,props '), [
      'clip',
      'props',
      'role',
    ]);
    expect(parseCornerScapeTypesInput(' , , '), isNull);
  });

  test(
    'chooseInitialCornerScapeHistoryImageId keeps preferred image when valid',
    () {
      expect(
        chooseInitialCornerScapeHistoryImageId(
          const [
            CornerScapeAssetItem(
              id: 'asset-a',
              numericId: 9,
              name: 'Hero',
              assetType: 'role',
              metadata: {},
              historyImages: [
                CornerScapeHistoryImage(id: 'img-1', sortIndex: 1),
                CornerScapeHistoryImage(id: 'img-2', sortIndex: 2),
              ],
            ),
          ],
          selectedAssetNumericId: 9,
          preferredHistoryImageId: 'img-2',
        ),
        'img-2',
      );
      expect(
        chooseInitialCornerScapeHistoryImageId(
          const [
            CornerScapeAssetItem(
              id: 'asset-a',
              numericId: 9,
              name: 'Hero',
              assetType: 'role',
              metadata: {},
              historyImages: [
                CornerScapeHistoryImage(id: 'img-1', sortIndex: 1),
              ],
            ),
          ],
          selectedAssetNumericId: 9,
          preferredHistoryImageId: 'missing',
        ),
        'img-1',
      );
    },
  );

  test('summarizeCornerScapeSelection reports filters totals and focus', () {
    final line = summarizeCornerScapeSelection(
      const [
        CornerScapeAssetItem(
          id: 'asset-a',
          numericId: 9,
          name: 'Hero',
          assetType: 'role',
          metadata: {},
          historyImages: [
            CornerScapeHistoryImage(id: 'img-1', sortIndex: 1, state: 'done'),
          ],
        ),
        CornerScapeAssetItem(
          id: 'asset-b',
          numericId: 11,
          name: 'Sword',
          assetType: 'props',
          metadata: {},
          historyImages: [],
        ),
      ],
      activeTypes: const ['props', 'role'],
      selectedAssetNumericId: 9,
      selectedHistoryImageId: 'img-1',
    );

    expect(line, contains('props, role'));
    expect(line, contains('loaded 2 asset(s), 1 history image(s)'));
    expect(line, contains('Focus #9 Hero'));
    expect(line, contains('sort=1'));
    expect(line, contains('done'));
  });

  test(
    'chooseInitialAssetImageId prefers current selection then selected/cover',
    () {
      expect(
        chooseInitialAssetImageId(
          const ListAssetImagesResponse(
            coverNumericImageId: 8,
            items: [
              AssetImageRow(
                id: 'img-1',
                assetId: 'asset-a',
                sortIndex: 1,
                numericImageId: 7,
              ),
              AssetImageRow(
                id: 'img-2',
                assetId: 'asset-a',
                sortIndex: 2,
                numericImageId: 8,
                selected: true,
              ),
            ],
          ),
          preferredImageId: 'img-1',
        ),
        'img-1',
      );

      expect(
        chooseInitialAssetImageId(
          const ListAssetImagesResponse(
            coverNumericImageId: 8,
            items: [
              AssetImageRow(
                id: 'img-1',
                assetId: 'asset-a',
                sortIndex: 1,
                numericImageId: 7,
              ),
              AssetImageRow(
                id: 'img-2',
                assetId: 'asset-a',
                sortIndex: 2,
                numericImageId: 8,
                selected: true,
              ),
            ],
          ),
        ),
        'img-2',
      );

      expect(
        chooseInitialAssetImageId(
          const ListAssetImagesResponse(
            coverNumericImageId: 9,
            items: [
              AssetImageRow(
                id: 'img-1',
                assetId: 'asset-a',
                sortIndex: 1,
                numericImageId: 7,
              ),
              AssetImageRow(
                id: 'img-2',
                assetId: 'asset-a',
                sortIndex: 2,
                numericImageId: 9,
              ),
            ],
          ),
        ),
        'img-2',
      );
    },
  );

  test('summarizeAssetImageSelection reports cover and current image', () {
    final line = summarizeAssetImageSelection(
      zh,
      const ListAssetImagesResponse(
        coverNumericImageId: 8,
        items: [
          AssetImageRow(
            id: 'img-1',
            assetId: 'asset-a',
            sortIndex: 1,
            numericImageId: 7,
          ),
          AssetImageRow(
            id: 'img-2',
            assetId: 'asset-a',
            sortIndex: 2,
            state: 'done',
            numericImageId: 8,
          ),
        ],
      ),
      selectedImageId: 'img-2',
    );

    final cover = zh.projectEditorAssetImagesSelectionCoverNumeric(8);
    final focus = zh.projectEditorAssetImagesSelectionFocusLine(2, 'done');
    expect(line, zh.projectEditorAssetImagesSelectionSummary(2, cover, focus));
  });
}
