import 'package:flutter_test/flutter_test.dart';
import 'package:toonflow_app/home_page/project_editor_assets_workbench_support.dart';
import 'package:toonflow_app/rust_api.dart';

void main() {
  test('collectVisibleAssetLegacyIds sorts and deduplicates ids', () {
    expect(
      collectVisibleAssetLegacyIds(const [
        AssetRow(id: 'a', legacyId: 9, name: 'Hero', assetType: 'role'),
        AssetRow(id: 'b', legacyId: 3, name: 'Sword', assetType: 'props'),
        AssetRow(id: 'c', legacyId: 9, name: 'Hero-dup', assetType: 'role'),
      ]),
      [3, 9],
    );
  });

  test('chooseInitialAssetLegacyId prefers existing preferred id', () {
    expect(
      chooseInitialAssetLegacyId(const [
        AssetRow(id: 'a', legacyId: 9, name: 'Hero', assetType: 'role'),
        AssetRow(id: 'b', legacyId: 3, name: 'Sword', assetType: 'props'),
      ], preferredLegacyId: 3),
      3,
    );
    expect(
      chooseInitialAssetLegacyId(const [
        AssetRow(id: 'a', legacyId: 9, name: 'Hero', assetType: 'role'),
      ], preferredLegacyId: 100),
      9,
    );
  });

  test('summarizeProjectAssetRows reports counts and examples', () {
    final line = summarizeProjectAssetRows(const [
      AssetRow(id: 'a', legacyId: 9, name: 'Hero', assetType: 'role'),
      AssetRow(id: 'b', legacyId: 3, name: 'Sword', assetType: 'props'),
      AssetRow(id: 'c', legacyId: 5, name: 'Mage', assetType: 'role'),
    ]);

    expect(line, contains('资产 3 条'));
    expect(line, contains('props 1 条'));
    expect(line, contains('role 2 条'));
    expect(line, contains('#9 Hero'));
  });

  test('summarizeScriptScopedAssets describes project and script scope', () {
    expect(
      summarizeScriptScopedAssets(null, const []),
      '当前按项目全量资产管理。',
    );
    expect(
      summarizeScriptScopedAssets(12, const []),
      '当前剧本 #12 下没有关联资产。',
    );
    expect(
      summarizeScriptScopedAssets(12, const [
        AssetRow(id: 'a', legacyId: 9, name: 'Hero', assetType: 'role'),
        AssetRow(id: 'b', legacyId: 3, name: 'Sword', assetType: 'props'),
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

  test('chooseInitialCornerScapeHistoryImageId keeps preferred image when valid', () {
    expect(
      chooseInitialCornerScapeHistoryImageId(
        const [
          CornerScapeAssetItem(
            id: 'asset-a',
            legacyId: 9,
            name: 'Hero',
            assetType: 'role',
            metadata: {},
            historyImages: [
              CornerScapeHistoryImage(id: 'img-1', sortIndex: 1),
              CornerScapeHistoryImage(id: 'img-2', sortIndex: 2),
            ],
          ),
        ],
        selectedAssetLegacyId: 9,
        preferredHistoryImageId: 'img-2',
      ),
      'img-2',
    );
    expect(
      chooseInitialCornerScapeHistoryImageId(
        const [
          CornerScapeAssetItem(
            id: 'asset-a',
            legacyId: 9,
            name: 'Hero',
            assetType: 'role',
            metadata: {},
            historyImages: [
              CornerScapeHistoryImage(id: 'img-1', sortIndex: 1),
            ],
          ),
        ],
        selectedAssetLegacyId: 9,
        preferredHistoryImageId: 'missing',
      ),
      'img-1',
    );
  });

  test('summarizeCornerScapeSelection reports filters totals and focus', () {
    final line = summarizeCornerScapeSelection(
      const [
        CornerScapeAssetItem(
          id: 'asset-a',
          legacyId: 9,
          name: 'Hero',
          assetType: 'role',
          metadata: {},
          historyImages: [
            CornerScapeHistoryImage(id: 'img-1', sortIndex: 1, state: 'done'),
          ],
        ),
        CornerScapeAssetItem(
          id: 'asset-b',
          legacyId: 11,
          name: 'Sword',
          assetType: 'props',
          metadata: {},
          historyImages: [],
        ),
      ],
      activeTypes: const ['props', 'role'],
      selectedAssetLegacyId: 9,
      selectedHistoryImageId: 'img-1',
    );

    expect(line, contains('props, role'));
    expect(line, contains('2 条资产、1 张历史图'));
    expect(line, contains('当前焦点 #9 Hero'));
    expect(line, contains('sort=1'));
    expect(line, contains('done'));
  });

  test('chooseInitialAssetImageId prefers current selection then selected/cover', () {
    expect(
      chooseInitialAssetImageId(
        const ListAssetImagesResponse(
          coverLegacyImageId: 8,
          items: [
            AssetImageRow(
              id: 'img-1',
              assetId: 'asset-a',
              sortIndex: 1,
              legacyImageId: 7,
            ),
            AssetImageRow(
              id: 'img-2',
              assetId: 'asset-a',
              sortIndex: 2,
              legacyImageId: 8,
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
          coverLegacyImageId: 8,
          items: [
            AssetImageRow(
              id: 'img-1',
              assetId: 'asset-a',
              sortIndex: 1,
              legacyImageId: 7,
            ),
            AssetImageRow(
              id: 'img-2',
              assetId: 'asset-a',
              sortIndex: 2,
              legacyImageId: 8,
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
          coverLegacyImageId: 9,
          items: [
            AssetImageRow(
              id: 'img-1',
              assetId: 'asset-a',
              sortIndex: 1,
              legacyImageId: 7,
            ),
            AssetImageRow(
              id: 'img-2',
              assetId: 'asset-a',
              sortIndex: 2,
              legacyImageId: 9,
            ),
          ],
        ),
      ),
      'img-2',
    );
  });

  test('summarizeAssetImageSelection reports cover and current image', () {
    final line = summarizeAssetImageSelection(
      const ListAssetImagesResponse(
        coverLegacyImageId: 8,
        items: [
          AssetImageRow(
            id: 'img-1',
            assetId: 'asset-a',
            sortIndex: 1,
            legacyImageId: 7,
          ),
          AssetImageRow(
            id: 'img-2',
            assetId: 'asset-a',
            sortIndex: 2,
            state: 'done',
            legacyImageId: 8,
          ),
        ],
      ),
      selectedImageId: 'img-2',
    );

    expect(line, contains('已加载 2 张图片'));
    expect(line, contains('封面 legacy image #8'));
    expect(line, contains('sort=2'));
    expect(line, contains('done'));
  });
}
