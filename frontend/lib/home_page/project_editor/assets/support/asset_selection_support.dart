part of '../support.dart';

List<int> collectVisibleAssetNumericIds(Iterable<AssetRow> assets) {
  final ids = SplayTreeSet<int>();
  for (final asset in assets) {
    if (asset.numericId > 0) {
      ids.add(asset.numericId);
    }
  }
  return ids.toList(growable: false);
}

int? chooseInitialAssetNumericId(
  Iterable<AssetRow> assets, {
  int? preferredNumericId,
}) {
  final rows = assets.toList(growable: false);
  if (rows.isEmpty) {
    return null;
  }
  if (preferredNumericId != null) {
    for (final asset in rows) {
      if (asset.numericId == preferredNumericId) {
        return preferredNumericId;
      }
    }
  }
  return rows.first.numericId;
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
      .map((asset) => '#${asset.numericId} ${asset.name}')
      .join(', ');
  return '资产 ${rows.length} 条 · $typeLine · 示例：$sampleLine';
}

String summarizeScriptScopedAssets(
  int? scriptNumericId,
  Iterable<AssetRow> assets,
) {
  if (scriptNumericId == null) {
    return '当前按项目全量资产管理。';
  }
  final rows = assets.toList(growable: false);
  if (rows.isEmpty) {
    return '当前剧本 #$scriptNumericId 下没有关联资产。';
  }
  return '当前剧本 #$scriptNumericId 下关联 ${rows.length} 条资产。';
}
