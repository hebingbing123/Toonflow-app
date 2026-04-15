import 'package:flutter_test/flutter_test.dart';
import 'package:openflow_app/project_editor/assets/support.dart';
import 'package:openflow_app/rust_api.dart';

void main() {
  test('diagnoseAssetImagesWorkbench suggests loading images first', () {
    final diagnosis = diagnoseAssetImagesWorkbench(hasPreviewBytes: false);

    expect(diagnosis.summary, '还没有读取当前资产的图片列表。');
    expect(
      diagnosis.recommendedAction,
      AssetImagesWorkbenchRecommendedAction.loadImages,
    );
  });

  test('diagnoseAssetImagesWorkbench suggests creating first image', () {
    final diagnosis = diagnoseAssetImagesWorkbench(
      imagesResponse: const ListAssetImagesResponse(items: []),
      hasPreviewBytes: false,
    );

    expect(diagnosis.summary, '当前资产还没有图片。');
    expect(
      diagnosis.recommendedAction,
      AssetImagesWorkbenchRecommendedAction.createImage,
    );
  });

  test('diagnoseAssetImagesWorkbench suggests preview before editing', () {
    final diagnosis = diagnoseAssetImagesWorkbench(
      imagesResponse: const ListAssetImagesResponse(
        items: [AssetImageRow(id: 'img-1', assetId: 'asset-a', sortIndex: 1)],
      ),
      selectedImageId: 'img-1',
      hasPreviewBytes: false,
    );

    expect(diagnosis.summary, '已读取 1 张图片，但还没加载当前预览。');
    expect(
      diagnosis.recommendedAction,
      AssetImagesWorkbenchRecommendedAction.previewSelectedImage,
    );
  });

  test('diagnoseAssetImagesWorkbench suggests saving current image', () {
    final diagnosis = diagnoseAssetImagesWorkbench(
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

    expect(diagnosis.summary, '当前图片已就绪，可继续编辑。');
    expect(
      diagnosis.recommendedAction,
      AssetImagesWorkbenchRecommendedAction.updateSelectedImage,
    );
  });

  test('buildAssetImagesWorkbenchFollowUp appends next step guidance', () {
    final text = buildAssetImagesWorkbenchFollowUp(
      actionSummary: '已新增资产图片。',
      diagnosis: const AssetImagesWorkbenchDiagnosis(
        summary: '当前图片已就绪，可继续编辑。',
        detail: '可继续更新 file_path。',
        recommendedAction:
            AssetImagesWorkbenchRecommendedAction.updateSelectedImage,
      ),
    );

    expect(text, contains('已新增资产图片。'));
    expect(text, contains('下一步建议：保存当前图片。'));
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

    expect(line, contains('资产 3 条'));
    expect(line, contains('props 1 条'));
    expect(line, contains('role 2 条'));
    expect(line, contains('#9 Hero'));
  });

  test('summarizeScriptScopedAssets describes project and script scope', () {
    expect(summarizeScriptScopedAssets(null, const []), '当前按项目全量资产管理。');
    expect(summarizeScriptScopedAssets(12, const []), '当前剧本 #12 下没有关联资产。');
    expect(
      summarizeScriptScopedAssets(12, const [
        AssetRow(id: 'a', numericId: 9, name: 'Hero', assetType: 'role'),
        AssetRow(id: 'b', numericId: 3, name: 'Sword', assetType: 'props'),
      ]),
      '当前剧本 #12 下关联 2 条资产。',
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
    expect(line, contains('2 条资产、1 张历史图'));
    expect(line, contains('当前焦点 #9 Hero'));
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

    expect(line, contains('已加载 2 张图片'));
    expect(line, contains('封面 numeric image #8'));
    expect(line, contains('sort=2'));
    expect(line, contains('done'));
  });
}
