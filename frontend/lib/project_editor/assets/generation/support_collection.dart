part of 'support.dart';

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
  Iterable<WorkbenchAssetPollingPromptItem> rows,
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

