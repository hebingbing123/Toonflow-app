import 'dart:collection';

import '../rust_api.dart';

List<int> collectVisibleAssetLegacyIds(Iterable<AssetRow> assets) {
  final ids = SplayTreeSet<int>();
  for (final asset in assets) {
    if (asset.legacyId > 0) {
      ids.add(asset.legacyId);
    }
  }
  return ids.toList(growable: false);
}

int? chooseInitialAssetLegacyId(
  Iterable<AssetRow> assets, {
  int? preferredLegacyId,
}) {
  final rows = assets.toList(growable: false);
  if (rows.isEmpty) {
    return null;
  }
  if (preferredLegacyId != null) {
    for (final asset in rows) {
      if (asset.legacyId == preferredLegacyId) {
        return preferredLegacyId;
      }
    }
  }
  return rows.first.legacyId;
}

String summarizeProjectAssetRows(Iterable<AssetRow> assets) {
  final rows = assets.toList(growable: false);
  if (rows.isEmpty) {
    return '当前没有资产';
  }
  final typeCounts = SplayTreeMap<String, int>();
  for (final asset in rows) {
    final type = asset.assetType.trim().isEmpty ? 'unknown' : asset.assetType;
    typeCounts[type] = (typeCounts[type] ?? 0) + 1;
  }
  final typeLine = typeCounts.entries
      .map((entry) => '${entry.key} ${entry.value} 条')
      .join(' · ');
  final sampleLine = rows
      .take(3)
      .map((asset) => '#${asset.legacyId} ${asset.name}')
      .join(', ');
  return '资产 ${rows.length} 条 · $typeLine · 示例：$sampleLine';
}

String summarizeScriptScopedAssets(int? scriptLegacyId, Iterable<AssetRow> assets) {
  if (scriptLegacyId == null) {
    return '当前按项目全量资产管理。';
  }
  final rows = assets.toList(growable: false);
  if (rows.isEmpty) {
    return '当前剧本 #$scriptLegacyId 下没有关联资产。';
  }
  return '当前剧本 #$scriptLegacyId 下关联 ${rows.length} 条资产。';
}
