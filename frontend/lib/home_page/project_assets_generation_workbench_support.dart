import 'dart:collection';

import '../rust_api.dart';

List<int> sortUniqueAssetLegacyIds(Iterable<int> ids) {
  final sorted = SplayTreeSet<int>();
  for (final id in ids) {
    if (id > 0) {
      sorted.add(id);
    }
  }
  return sorted.toList(growable: false);
}

Map<String, List<int>> collectAssetIdsByType(Iterable<AssetRow> assets) {
  final grouped = SplayTreeMap<String, List<int>>();
  for (final asset in assets) {
    final type = asset.assetType.trim();
    if (type.isEmpty) continue;
    grouped.putIfAbsent(type, () => <int>[]).add(asset.legacyId);
  }
  return <String, List<int>>{
    for (final entry in grouped.entries)
      entry.key: sortUniqueAssetLegacyIds(entry.value),
  };
}

String summarizeProductionAssetData(AssetsDataResponseV1 response) {
  if (response.assets.isEmpty) {
    return 'production 资产数据为空';
  }
  final typeCounts = SplayTreeMap<String, int>();
  for (final asset in response.assets) {
    final type = asset.type.trim().isEmpty ? 'unknown' : asset.type.trim();
    typeCounts[type] = (typeCounts[type] ?? 0) + 1;
  }
  final typesLine = typeCounts.entries
      .map((entry) => '${entry.key} ${entry.value} 条')
      .join(' · ');
  final sampleLine = response.assets
      .take(3)
      .map((asset) => '#${asset.id} ${asset.name}')
      .join(', ');
  return 'production 资产 ${response.total} 条 · $typesLine · 示例：$sampleLine';
}

String summarizeAssetPollingStatuses(Iterable<AssetImageStatusV1> statuses) {
  final rows = statuses.toList(growable: false);
  if (rows.isEmpty) {
    return '未返回选中资产的图片状态';
  }
  final states = SplayTreeMap<String, int>();
  for (final row in rows) {
    final state = row.latestState?.trim();
    final key = (state == null || state.isEmpty) ? 'unknown' : state;
    states[key] = (states[key] ?? 0) + 1;
  }
  final stateLine = states.entries
      .map((entry) => '${entry.key} ${entry.value} 条')
      .join(' · ');
  final sampleLine = rows
      .take(3)
      .map((row) => '#${row.assetId}: ${row.imageCount} 张')
      .join(', ');
  return '已轮询 ${rows.length} 条资产 · $stateLine · 示例：$sampleLine';
}
