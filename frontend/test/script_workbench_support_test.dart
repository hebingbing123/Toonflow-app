import 'package:flutter_test/flutter_test.dart';
import 'package:toonflow_app/home_page/script_workbench_support.dart';
import 'package:toonflow_app/rust_api.dart';

void main() {
  test('findScriptContextByLegacyId returns matching row', () {
    final row = findScriptContextByLegacyId(const [
      LegacyScriptsGetScriptApiItem(legacyId: 1, relatedAssets: []),
      LegacyScriptsGetScriptApiItem(
        legacyId: 7,
        name: 'target',
        relatedAssets: [],
      ),
    ], 7);

    expect(row?.name, 'target');
  });

  test('findScriptExtractStateByLegacyId returns matching row', () {
    final row = findScriptExtractStateByLegacyId(const [
      ScriptExtractStatePollRow(legacyId: 3, extractState: 0),
      ScriptExtractStatePollRow(
        legacyId: 9,
        extractState: -1,
        errorReason: 'llm_not_configured',
      ),
    ], 9);

    expect(row?.extractState, -1);
    expect(row?.errorReason, 'llm_not_configured');
  });

  test('summarizeRelatedScriptAssets compacts long asset list', () {
    final summary = summarizeRelatedScriptAssets(const [
      LegacyScriptRelatedAssetBrief(legacyId: 1, name: '角色 A'),
      LegacyScriptRelatedAssetBrief(legacyId: 2, name: '场景 B'),
      LegacyScriptRelatedAssetBrief(legacyId: 3, name: '道具 C'),
      LegacyScriptRelatedAssetBrief(legacyId: 4, name: '镜头 D'),
      LegacyScriptRelatedAssetBrief(legacyId: 5, name: '音乐 E'),
    ]);

    expect(summary, '角色 A、场景 B、道具 C、镜头 D 等 5 项');
  });

  test('formatBinarySize formats bytes into readable units', () {
    expect(formatBinarySize(512), '512 B');
    expect(formatBinarySize(1536), '1.5 KB');
    expect(formatBinarySize(2 * 1024 * 1024), '2.0 MB');
  });
}
