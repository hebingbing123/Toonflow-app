import 'package:flutter_test/flutter_test.dart';
import 'package:toonflow_app/home_page/project_editor_assets/generation_workbench_support.dart';
import 'package:toonflow_app/rust_api.dart';

void main() {
  test('sortUniqueAssetLegacyIds removes duplicates and sorts ascending', () {
    expect(sortUniqueAssetLegacyIds([3, 2, 3, -1, 1]), [1, 2, 3]);
  });

  test('collectAssetIdsByType groups visible assets by type', () {
    final grouped = collectAssetIdsByType(const [
      AssetRow(id: 'a', legacyId: 7, name: 'Hero', assetType: 'role'),
      AssetRow(id: 'b', legacyId: 3, name: 'Sword', assetType: 'props'),
      AssetRow(id: 'c', legacyId: 5, name: 'Villain', assetType: 'role'),
    ]);

    expect(grouped['props'], [3]);
    expect(grouped['role'], [5, 7]);
  });

  test('collectScopedAssetLegacyIds keeps only currently visible ids', () {
    final scoped = collectScopedAssetLegacyIds(
      const [5, 99, 3],
      const [
        AssetRow(id: 'a', legacyId: 7, name: 'Hero', assetType: 'role'),
        AssetRow(id: 'b', legacyId: 3, name: 'Sword', assetType: 'props'),
        AssetRow(id: 'c', legacyId: 5, name: 'Villain', assetType: 'role'),
      ],
    );

    expect(scoped, [3, 5]);
  });

  test('chooseVisibleAssetSelection keeps visible preferred ids', () {
    final selection = chooseVisibleAssetSelection(
      const [
        AssetRow(id: 'a', legacyId: 7, name: 'Hero', assetType: 'role'),
        AssetRow(id: 'b', legacyId: 3, name: 'Sword', assetType: 'props'),
        AssetRow(id: 'c', legacyId: 5, name: 'Villain', assetType: 'role'),
      ],
      preferredIds: const [99, 5, 7],
      preferredLegacyId: 3,
    );

    expect(selection, [5, 7]);
  });

  test('chooseVisibleAssetSelection falls back to focused or first asset', () {
    expect(
      chooseVisibleAssetSelection(const [
        AssetRow(id: 'a', legacyId: 7, name: 'Hero', assetType: 'role'),
        AssetRow(id: 'b', legacyId: 3, name: 'Sword', assetType: 'props'),
      ], preferredLegacyId: 7),
      [7],
    );
    expect(
      chooseVisibleAssetSelection(const [
        AssetRow(id: 'a', legacyId: 7, name: 'Hero', assetType: 'role'),
        AssetRow(id: 'b', legacyId: 3, name: 'Sword', assetType: 'props'),
      ]),
      [3],
    );
  });

  test('summarizeProductionAssetData reports counts and sample rows', () {
    final line = summarizeProductionAssetData(
      const AssetsDataResponseV1(
        total: 3,
        assets: [
          AssetDataItemV1(id: 1, name: 'Hero', type: 'role'),
          AssetDataItemV1(id: 2, name: 'Sword', type: 'props'),
          AssetDataItemV1(id: 3, name: 'Mage', type: 'role'),
        ],
      ),
    );

    expect(line, contains('production 资产 3 条'));
    expect(line, contains('props 1 条'));
    expect(line, contains('role 2 条'));
    expect(line, contains('#1 Hero'));
  });

  test('summarizeAssetPollingStatuses reports state buckets and samples', () {
    final line = summarizeAssetPollingStatuses(const [
      AssetImageStatusV1(assetId: 11, imageCount: 2, latestState: 'done'),
      AssetImageStatusV1(assetId: 12, imageCount: 0, latestState: 'queued'),
      AssetImageStatusV1(assetId: 13, imageCount: 1),
    ]);

    expect(line, contains('已轮询 3 条资产'));
    expect(line, contains('done 1 条'));
    expect(line, contains('queued 1 条'));
    expect(line, contains('unknown 1 条'));
    expect(line, contains('#11: 2 张'));
  });

  test('collect image and prompt state groups for quick selection', () {
    expect(
      collectAssetIdsByImageState(const [
        AssetImageStatusV1(assetId: 12, imageCount: 0, latestState: 'queued'),
        AssetImageStatusV1(assetId: 11, imageCount: 1, latestState: 'queued'),
        AssetImageStatusV1(assetId: 13, imageCount: 2),
      ]),
      {
        'queued': [11, 12],
        'unknown': [13],
      },
    );

    expect(
      collectAssetIdsByPromptState(const [
        LegacyAssetPollingPromptAssetsItem(
          id: 7,
          name: 'Hero',
          assetType: 'role',
          promptState: '生成中',
        ),
        LegacyAssetPollingPromptAssetsItem(
          id: 3,
          name: 'Sword',
          assetType: 'props',
          promptState: '生成中',
        ),
        LegacyAssetPollingPromptAssetsItem(
          id: 9,
          name: 'Mage',
          assetType: 'role',
          promptState: '',
        ),
      ]),
      {
        'unknown': [9],
        '生成中': [3, 7],
      },
    );
  });

  test('legacy asset summaries describe material, batch and prompt states', () {
    expect(
      summarizeLegacyAssetMaterialData(
        const LegacyAssetMaterialDataResponse(
          data: [
            LegacyAssetMaterialDataItem(
              id: 1,
              name: 'Clip A',
              filePath: 'a.png',
              assetType: 'clip',
            ),
          ],
          video: [LegacyAssetMaterialVideoItem(id: 2, filePath: 'b.mp4')],
        ),
      ),
      contains('1 条图片素材 · 1 条视频素材'),
    );

    expect(
      summarizeLegacyBatchGenerationData(
        const LegacyAssetBatchGenerationDataResponse(
          total: 2,
          data: [
            LegacyAssetBatchGenerationDataItem(
              id: 7,
              name: 'Hero',
              assetType: 'role',
            ),
          ],
        ),
      ),
      contains('批量候选 1/2 条'),
    );

    expect(
      summarizeLegacyPromptPolling(const [
        LegacyAssetPollingPromptAssetsItem(
          id: 3,
          name: 'Hero',
          assetType: 'role',
          promptState: '生成中',
        ),
        LegacyAssetPollingPromptAssetsItem(
          id: 4,
          name: 'Sword',
          assetType: 'props',
          promptState: '',
        ),
      ]),
      contains('生成中 1 条'),
    );
  });

  test(
    'summarizeAssetWorkbenchSnapshot combines selected scope and sync data',
    () {
      final line = summarizeAssetWorkbenchSnapshot(
        lead: '已发起批量出图',
        visibleAssets: const [
          AssetRow(id: '11', legacyId: 11, name: 'Hero', assetType: 'role'),
          AssetRow(id: '12', legacyId: 12, name: 'Sword', assetType: 'props'),
        ],
        selectedIds: const [11, 12],
        productionData: const AssetsDataResponseV1(
          total: 2,
          assets: [
            AssetDataItemV1(id: 11, name: 'Hero', type: 'role'),
            AssetDataItemV1(id: 12, name: 'Sword', type: 'props'),
          ],
        ),
        pollingData: const AssetsPollingImageResponseV1(
          statuses: [
            AssetImageStatusV1(
              assetId: 11,
              imageCount: 1,
              latestState: 'queued',
            ),
          ],
        ),
        promptPollingData: const [
          LegacyAssetPollingPromptAssetsItem(
            id: 11,
            name: 'Hero',
            assetType: 'role',
            promptState: '已完成',
          ),
        ],
      );

      expect(line, contains('已发起批量出图'));
      expect(line, contains('当前选择 2 条资产：#11 Hero, #12 Sword'));
      expect(line, contains('production 资产 2 条'));
      expect(line, contains('queued 1 条'));
      expect(line, contains('prompt 轮询 1 条'));
    },
  );
}
