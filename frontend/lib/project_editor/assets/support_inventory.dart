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

String summarizeProjectAssetRows(
  Iterable<AssetRow> assets, {
  required AppLocalizations l10n,
}) {
  final rows = assets.toList(growable: false);
  if (rows.isEmpty) {
    return l10n.projectEditorAssetsInventoryNone;
  }
  final typeCounts = SplayTreeMap<String, int>();
  for (final asset in rows) {
    final type = asset.assetType.trim().isEmpty
        ? studioUnknownCodeLabel(l10n, 'unknown')
        : asset.assetType.trim();
    typeCounts[type] = (typeCounts[type] ?? 0) + 1;
  }
  final typeLine = typeCounts.entries
      .map((entry) => '${entry.key} ${entry.value}')
      .join(' · ');
  final sampleLine = rows
      .take(3)
      .map((asset) => '#${asset.numericId} ${asset.name}')
      .join(', ');
  return l10n.projectEditorAssetsInventorySummary(
    rows.length,
    typeLine,
    sampleLine,
  );
}

String summarizeScriptScopedAssets(
  int? scriptNumericId,
  Iterable<AssetRow> assets, {
  required AppLocalizations l10n,
}) {
  if (scriptNumericId == null) {
    return l10n.projectEditorAssetsInventoryManagingAll;
  }
  final rows = assets.toList(growable: false);
  if (rows.isEmpty) {
    return l10n.projectEditorAssetsInventoryNoLinkedUnderScript(scriptNumericId);
  }
  return l10n.projectEditorAssetsInventoryScriptLinkedCount(
    scriptNumericId,
    rows.length,
  );
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
  required AppLocalizations l10n,
}) {
  final rows = assets.toList(growable: false);
  final typeLine = activeTypes == null || activeTypes.isEmpty
      ? l10n.projectEditorAssetsCornerScapeAllTypes
      : activeTypes.join(', ');
  if (rows.isEmpty) {
    return l10n.projectEditorAssetsCornerScapeNoMatching(typeLine);
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
    return l10n.projectEditorAssetsCornerScapeLoaded(
      typeLine,
      rows.length,
      totalHistories,
    );
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
      ? l10n.projectEditorAssetsCornerScapeFocusNoImage(
          selectedAsset.numericId,
          selectedAsset.name,
        )
      : l10n.projectEditorAssetsCornerScapeFocusWithImage(
          selectedAsset.numericId,
          selectedAsset.name,
          selectedImage.sortIndex,
          selectedImage.state ??
              studioUnknownCodeLabel(l10n, 'unknown state'),
        );
  return l10n.projectEditorAssetsCornerScapeLoadedWithFocus(
    typeLine,
    rows.length,
    totalHistories,
    focusLine,
  );
}
