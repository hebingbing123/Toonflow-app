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
}
