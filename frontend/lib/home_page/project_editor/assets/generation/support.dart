import 'dart:collection';

import '../../../../rust_api.dart';

List<int> sortUniqueAssetNumericIds(Iterable<int> ids) {
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
    grouped.putIfAbsent(type, () => <int>[]).add(asset.numericId);
  }
  return <String, List<int>>{
    for (final entry in grouped.entries)
      entry.key: sortUniqueAssetNumericIds(entry.value),
  };
}

List<int> collectScopedAssetNumericIds(
  Iterable<int> candidateIds,
  Iterable<AssetRow> visibleAssets,
) {
  final visibleSet = visibleAssets.map((asset) => asset.numericId).toSet();
  return sortUniqueAssetNumericIds(candidateIds.where(visibleSet.contains));
}

Map<String, List<int>> collectAssetIdsByImageState(
  Iterable<AssetImageStatusV1> statuses,
) {
  final grouped = SplayTreeMap<String, List<int>>();
  for (final row in statuses) {
    final state = row.latestState?.trim();
    final key = (state == null || state.isEmpty) ? 'unknown' : state;
    grouped.putIfAbsent(key, () => <int>[]).add(row.assetId);
  }
  return <String, List<int>>{
    for (final entry in grouped.entries)
      entry.key: sortUniqueAssetNumericIds(entry.value),
  };
}

Map<String, List<int>> collectAssetIdsByPromptState(
  Iterable<LegacyAssetPollingPromptAssetsItem> rows,
) {
  final grouped = SplayTreeMap<String, List<int>>();
  for (final row in rows) {
    final key = row.promptState.trim().isEmpty ? 'unknown' : row.promptState;
    grouped.putIfAbsent(key, () => <int>[]).add(row.id);
  }
  return <String, List<int>>{
    for (final entry in grouped.entries)
      entry.key: sortUniqueAssetNumericIds(entry.value),
  };
}

List<int> chooseVisibleAssetSelection(
  Iterable<AssetRow> assets, {
  Iterable<int>? preferredIds,
  int? preferredNumericId,
}) {
  final visibleIds = sortUniqueAssetNumericIds(
    assets.map((asset) => asset.numericId),
  );
  if (visibleIds.isEmpty) {
    return const <int>[];
  }
  final visibleSet = visibleIds.toSet();
  final keptIds = sortUniqueAssetNumericIds(
    (preferredIds ?? const <int>[]).where(visibleSet.contains),
  );
  if (keptIds.isNotEmpty) {
    return keptIds;
  }
  if (preferredNumericId != null && visibleSet.contains(preferredNumericId)) {
    return <int>[preferredNumericId];
  }
  return <int>[visibleIds.first];
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

String summarizeLegacyAssetMaterialData(LegacyAssetMaterialDataResponse data) {
  return '素材上下文 ${data.data.length} 条图片素材 · ${data.video.length} 条视频素材';
}

String summarizeLegacyBatchGenerationData(
  LegacyAssetBatchGenerationDataResponse data,
) {
  if (data.data.isEmpty) {
    return '批量候选为空';
  }
  final sampleLine = data.data
      .take(3)
      .map((row) => '#${row.id} ${row.name}')
      .join(', ');
  return '批量候选 ${data.data.length}/${data.total} 条 · 示例：$sampleLine';
}

String summarizeLegacyPromptPolling(
  Iterable<LegacyAssetPollingPromptAssetsItem> rows,
) {
  final items = rows.toList(growable: false);
  if (items.isEmpty) {
    return '未返回 prompt 状态';
  }
  final states = SplayTreeMap<String, int>();
  for (final row in items) {
    final key = row.promptState.trim().isEmpty ? 'unknown' : row.promptState;
    states[key] = (states[key] ?? 0) + 1;
  }
  final stateLine = states.entries
      .map((entry) => '${entry.key} ${entry.value} 条')
      .join(' · ');
  return 'prompt 轮询 ${items.length} 条 · $stateLine';
}

String summarizeAssetWorkbenchSnapshot({
  required Iterable<AssetRow> visibleAssets,
  required Iterable<int> selectedIds,
  AssetsDataResponseV1? productionData,
  AssetsPollingImageResponseV1? pollingData,
  Iterable<LegacyAssetPollingPromptAssetsItem>? promptPollingData,
  String? lead,
}) {
  final visibleById = <int, AssetRow>{
    for (final asset in visibleAssets) asset.numericId: asset,
  };
  final scopedSelection = sortUniqueAssetNumericIds(
    selectedIds.where(visibleById.containsKey),
  );
  final selectionLine = switch (scopedSelection.length) {
    0 => '当前未选择资产',
    1 =>
      '当前选择 #${scopedSelection.first} ${visibleById[scopedSelection.first]?.name ?? ""}'
          .trim(),
    _ =>
      '当前选择 ${scopedSelection.length} 条资产：${scopedSelection.take(3).map((id) => "#$id ${visibleById[id]?.name ?? ""}".trim()).join(", ")}',
  };
  final parts = <String>[
    if (lead != null && lead.trim().isNotEmpty) lead.trim(),
    selectionLine,
    if (productionData != null) summarizeProductionAssetData(productionData),
    if (pollingData != null)
      summarizeAssetPollingStatuses(pollingData.statuses),
    if (promptPollingData != null)
      summarizeLegacyPromptPolling(promptPollingData),
  ];
  return parts.join('；');
}
