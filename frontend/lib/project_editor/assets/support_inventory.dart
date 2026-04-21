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
      ? '全部类型'
      : activeTypes.join(', ');
  if (rows.isEmpty) {
    return '历史图过滤：$typeLine；当前没有命中资产。';
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
    return '历史图过滤：$typeLine；已加载 ${rows.length} 条资产、$totalHistories 张历史图。';
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
      ? '当前焦点 #${selectedAsset.numericId} ${selectedAsset.name}，暂无选中历史图'
      : '当前焦点 #${selectedAsset.numericId} ${selectedAsset.name} · 图 sort=${selectedImage.sortIndex} · ${selectedImage.state ?? "未知状态"}';
  return '历史图过滤：$typeLine；已加载 ${rows.length} 条资产、$totalHistories 张历史图；$focusLine。';
}
