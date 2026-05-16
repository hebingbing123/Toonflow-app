part of 'support.dart';

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
    return 'No assets';
  }
  final typeCounts = SplayTreeMap<String, int>();
  for (final asset in rows) {
    final type = asset.assetType.trim().isEmpty ? 'unknown' : asset.assetType;
    typeCounts[type] = (typeCounts[type] ?? 0) + 1;
  }
  final typeLine = typeCounts.entries
      .map((entry) => '${entry.key} ${entry.value}')
      .join(' · ');
  final sampleLine = rows
      .take(3)
      .map((asset) => '#${asset.numericId} ${asset.name}')
      .join(', ');
  return 'Assets ${rows.length} · $typeLine · sample: $sampleLine';
}

String summarizeScriptScopedAssets(
  int? scriptNumericId,
  Iterable<AssetRow> assets,
) {
  if (scriptNumericId == null) {
    return 'Managing all project assets.';
  }
  final rows = assets.toList(growable: false);
  if (rows.isEmpty) {
    return 'No assets linked under script #$scriptNumericId.';
  }
  return 'Script #$scriptNumericId has ${rows.length} linked asset(s).';
}

List<String>? parseCornerScapeTypesInput(String raw) {
  final items = raw
      .split(',')
      .map((segment) => segment.trim())
      .where((segment) => segment.isNotEmpty)
      .toSet()
      .toList(growable: false);
  if (items.isEmpty) {
    return null;
  }
  items.sort();
  return items;
}

String? chooseInitialCornerScapeHistoryImageId(
  Iterable<CornerScapeAssetItem> assets, {
  required int? selectedAssetNumericId,
  String? preferredHistoryImageId,
}) {
  if (selectedAssetNumericId == null) {
    return null;
  }
  for (final asset in assets) {
    if (asset.numericId != selectedAssetNumericId) {
      continue;
    }
    if (asset.historyImages.isEmpty) {
      return null;
    }
    if (preferredHistoryImageId != null) {
      for (final image in asset.historyImages) {
        if (image.id == preferredHistoryImageId) {
          return preferredHistoryImageId;
        }
      }
    }
    return asset.historyImages.first.id;
  }
  return null;
}

String summarizeCornerScapeSelection(
  Iterable<CornerScapeAssetItem> assets, {
  List<String>? activeTypes,
  int? selectedAssetNumericId,
  String? selectedHistoryImageId,
}) {
  final rows = assets.toList(growable: false);
  final typeLine = activeTypes == null || activeTypes.isEmpty
      ? 'All types'
      : activeTypes.join(', ');
  if (rows.isEmpty) {
    return 'History filter: $typeLine; no matching assets.';
  }
  final totalHistories = rows.fold<int>(
    0,
    (sum, asset) => sum + asset.historyImages.length,
  );
  CornerScapeAssetItem? selectedAsset;
  if (selectedAssetNumericId != null) {
    for (final asset in rows) {
      if (asset.numericId == selectedAssetNumericId) {
        selectedAsset = asset;
        break;
      }
    }
  }
  if (selectedAsset == null) {
    return 'History filter: $typeLine; loaded ${rows.length} asset(s), $totalHistories history image(s).';
  }
  CornerScapeHistoryImage? selectedImage;
  if (selectedHistoryImageId != null) {
    for (final image in selectedAsset.historyImages) {
      if (image.id == selectedHistoryImageId) {
        selectedImage = image;
        break;
      }
    }
  }
  final focusLine = selectedImage == null
      ? 'Focus #${selectedAsset.numericId} ${selectedAsset.name}, no history image selected'
      : 'Focus #${selectedAsset.numericId} ${selectedAsset.name} · image sort=${selectedImage.sortIndex} · ${selectedImage.state ?? "unknown state"}';
  return 'History filter: $typeLine; loaded ${rows.length} asset(s), $totalHistories history image(s); $focusLine.';
}
