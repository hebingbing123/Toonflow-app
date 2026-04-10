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
  required int? selectedAssetLegacyId,
  String? preferredHistoryImageId,
}) {
  if (selectedAssetLegacyId == null) {
    return null;
  }
  for (final asset in assets) {
    if (asset.legacyId != selectedAssetLegacyId) {
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
  int? selectedAssetLegacyId,
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
  if (selectedAssetLegacyId != null) {
    for (final asset in rows) {
      if (asset.legacyId == selectedAssetLegacyId) {
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
      ? '当前焦点 #${selectedAsset.legacyId} ${selectedAsset.name}，暂无选中历史图'
      : '当前焦点 #${selectedAsset.legacyId} ${selectedAsset.name} · 图 sort=${selectedImage.sortIndex} · ${selectedImage.state ?? "未知状态"}';
  return '历史图过滤：$typeLine；已加载 ${rows.length} 条资产、$totalHistories 张历史图；$focusLine。';
}
