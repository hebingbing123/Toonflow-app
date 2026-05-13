import 'package:flutter_test/flutter_test.dart';
import 'package:openflow_app/l10n/app_localizations_zh.dart';
import 'package:openflow_app/project_editor/assets/generation/support.dart';
import 'package:openflow_app/rust_api.dart';

void main() {
  final l10n = AppLocalizationsZh();
  test('sortUniqueAssetNumericIds removes duplicates and sorts ascending', () {
    expect(sortUniqueAssetNumericIds([3, 2, 3, -1, 1]), [1, 2, 3]);
  });

  test('collectAssetIdsByType groups visible assets by type', () {
    final grouped = collectAssetIdsByType(const [
      AssetRow(id: 'a', numericId: 7, name: 'Hero', assetType: 'role'),
      AssetRow(id: 'b', numericId: 3, name: 'Sword', assetType: 'props'),
      AssetRow(id: 'c', numericId: 5, name: 'Villain', assetType: 'role'),
    ]);

    expect(grouped['props'], [3]);
    expect(grouped['role'], [5, 7]);
  });

  test('collectScopedAssetNumericIds keeps only currently visible ids', () {
    final scoped = collectScopedAssetNumericIds(
      const [5, 99, 3],
      const [
        AssetRow(id: 'a', numericId: 7, name: 'Hero', assetType: 'role'),
        AssetRow(id: 'b', numericId: 3, name: 'Sword', assetType: 'props'),
        AssetRow(id: 'c', numericId: 5, name: 'Villain', assetType: 'role'),
      ],
    );

    expect(scoped, [3, 5]);
  });

  test('chooseVisibleAssetSelection keeps visible preferred ids', () {
    final selection = chooseVisibleAssetSelection(
      const [
        AssetRow(id: 'a', numericId: 7, name: 'Hero', assetType: 'role'),
        AssetRow(id: 'b', numericId: 3, name: 'Sword', assetType: 'props'),
        AssetRow(id: 'c', numericId: 5, name: 'Villain', assetType: 'role'),
      ],
      preferredIds: const [99, 5, 7],
      preferredNumericId: 3,
    );

    expect(selection, [5, 7]);
  });

  test('chooseVisibleAssetSelection falls back to focused or first asset', () {
    expect(
      chooseVisibleAssetSelection(const [
        AssetRow(id: 'a', numericId: 7, name: 'Hero', assetType: 'role'),
        AssetRow(id: 'b', numericId: 3, name: 'Sword', assetType: 'props'),
      ], preferredNumericId: 7),
      [7],
    );
    expect(
      chooseVisibleAssetSelection(const [
        AssetRow(id: 'a', numericId: 7, name: 'Hero', assetType: 'role'),
        AssetRow(id: 'b', numericId: 3, name: 'Sword', assetType: 'props'),
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
      l10n,
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
    ], l10n);

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
        WorkbenchAssetPollingPromptItem(
          id: 7,
          name: 'Hero',
          assetType: 'role',
          promptState: '生成中',
        ),
        WorkbenchAssetPollingPromptItem(
          id: 3,
          name: 'Sword',
          assetType: 'props',
          promptState: '生成中',
        ),
        WorkbenchAssetPollingPromptItem(
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

  test('workbench asset summaries describe material, batch and prompt states', () {
    expect(
      summarizeWorkbenchAssetMaterialData(
        const WorkbenchAssetMaterialDataResponse(
          data: [
            WorkbenchAssetMaterialDataItem(
              id: 1,
              name: 'Clip A',
              filePath: 'a.png',
              assetType: 'clip',
            ),
          ],
          video: [WorkbenchAssetMaterialVideoItem(id: 2, filePath: 'b.mp4')],
        ),
        l10n,
      ),
      contains('1 条图片素材 · 1 条视频素材'),
    );

    expect(
      summarizeWorkbenchBatchGenerationData(
        const WorkbenchAssetBatchGenerationResponse(
          total: 2,
          data: [
            WorkbenchAssetBatchGenerationItem(
              id: 7,
              name: 'Hero',
              assetType: 'role',
            ),
          ],
        ),
        l10n,
      ),
      contains('批量候选 1/2 条'),
    );

    expect(
      summarizeWorkbenchPromptPolling(const [
        WorkbenchAssetPollingPromptItem(
          id: 3,
          name: 'Hero',
          assetType: 'role',
          promptState: '生成中',
        ),
        WorkbenchAssetPollingPromptItem(
          id: 4,
          name: 'Sword',
          assetType: 'props',
          promptState: '',
        ),
      ], l10n),
      contains('生成中 1 条'),
    );
  });

  test(
    'summarizeAssetWorkbenchSnapshot combines selected scope and sync data',
    () {
      final line = summarizeAssetWorkbenchSnapshot(
        lead: '已发起批量出图',
        visibleAssets: const [
          AssetRow(id: '11', numericId: 11, name: 'Hero', assetType: 'role'),
          AssetRow(id: '12', numericId: 12, name: 'Sword', assetType: 'props'),
        ],
        selectedIds: const [11, 12],
        l10n: l10n,
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
          WorkbenchAssetPollingPromptItem(
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
