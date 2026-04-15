import 'dart:collection';

import '../../../rust_api.dart';

class AssetImagesWorkbenchDiagnosis {
  const AssetImagesWorkbenchDiagnosis({
    required this.summary,
    required this.detail,
    required this.recommendedAction,
  });

  final String summary;
  final String detail;
  final AssetImagesWorkbenchRecommendedAction recommendedAction;
}

class AssetImageCreateDraft {
  const AssetImageCreateDraft({this.filePath, this.state, this.sortIndex});

  final String? filePath;
  final String? state;
  final int? sortIndex;
}

class AssetImagePatchDraft {
  const AssetImagePatchDraft({required this.body});

  final Map<String, dynamic> body;
}

enum AssetImagesWorkbenchRecommendedAction {
  loadImages,
  createImage,
  previewSelectedImage,
  updateSelectedImage,
}

String describeAssetImagesWorkbenchRecommendedAction(
  AssetImagesWorkbenchRecommendedAction action,
) {
  switch (action) {
    case AssetImagesWorkbenchRecommendedAction.loadImages:
      return '读取图片列表';
    case AssetImagesWorkbenchRecommendedAction.createImage:
      return '新增当前图片';
    case AssetImagesWorkbenchRecommendedAction.previewSelectedImage:
      return '读取当前预览';
    case AssetImagesWorkbenchRecommendedAction.updateSelectedImage:
      return '保存当前图片';
  }
}

String buildAssetImagesWorkbenchFollowUp({
  required String actionSummary,
  required AssetImagesWorkbenchDiagnosis diagnosis,
}) {
  final nextAction = describeAssetImagesWorkbenchRecommendedAction(
    diagnosis.recommendedAction,
  );
  return '$actionSummary 下一步建议：$nextAction。${diagnosis.detail}';
}

String normalizeAssetImagesWorkbenchErrorMessage(String raw) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) {
    return '未提供额外错误信息。';
  }
  final normalized = trimmed.replaceFirst(
    RegExp(r'^RustApiException\([^)]*\):\s*'),
    '',
  );
  if (normalized.isEmpty) {
    return '未提供额外错误信息。';
  }
  return normalized;
}

String buildAssetImagesWorkbenchFailureNotice({
  required String actionSummary,
  required AssetImagesWorkbenchRecommendedAction recommendedAction,
  required Object error,
  required String fallbackDetail,
}) {
  final reason = normalizeAssetImagesWorkbenchErrorMessage(error.toString());
  final nextAction = describeAssetImagesWorkbenchRecommendedAction(
    recommendedAction,
  );
  return '$actionSummary 下一步建议：$nextAction。失败原因：$reason。$fallbackDetail';
}

String? trimAssetImageWorkbenchText(String raw) {
  final value = raw.trim();
  return value.isEmpty ? null : value;
}

int? parsePositiveWorkbenchInt(String raw) {
  if (raw.trim().isEmpty) return null;
  final parsed = int.tryParse(raw.trim());
  if (parsed == null || parsed <= 0) return null;
  return parsed;
}

AssetImageCreateDraft? parseAssetImageCreateDraft({
  required String filePath,
  required String state,
  required String sortIndex,
}) {
  final parsedSort = parsePositiveWorkbenchInt(sortIndex);
  if (sortIndex.trim().isNotEmpty && parsedSort == null) {
    return null;
  }
  return AssetImageCreateDraft(
    filePath: trimAssetImageWorkbenchText(filePath),
    state: trimAssetImageWorkbenchText(state),
    sortIndex: parsedSort,
  );
}

AssetImagePatchDraft? parseAssetImagePatchDraft({
  required String filePath,
  required String state,
  required String sortIndex,
}) {
  final body = <String, dynamic>{
    'file_path': trimAssetImageWorkbenchText(filePath),
    'state': trimAssetImageWorkbenchText(state),
  };
  final parsedSort = parsePositiveWorkbenchInt(sortIndex);
  if (sortIndex.trim().isNotEmpty && parsedSort == null) {
    return null;
  }
  if (parsedSort != null) {
    body['sort_index'] = parsedSort;
  }
  return AssetImagePatchDraft(body: body);
}

AssetImagesWorkbenchDiagnosis diagnoseAssetImagesWorkbench({
  ListAssetImagesResponse? imagesResponse,
  String? selectedImageId,
  required bool hasPreviewBytes,
}) {
  if (imagesResponse == null) {
    return const AssetImagesWorkbenchDiagnosis(
      summary: '还没有读取当前资产的图片列表。',
      detail: '先同步图片列表，确认当前资产是否已有历史图，再决定是直接预览还是新增一张图片。',
      recommendedAction: AssetImagesWorkbenchRecommendedAction.loadImages,
    );
  }

  if (imagesResponse.items.isEmpty) {
    return const AssetImagesWorkbenchDiagnosis(
      summary: '当前资产还没有图片。',
      detail: '可以直接新增一张图片，给当前资产补齐首张可编辑的历史图。',
      recommendedAction: AssetImagesWorkbenchRecommendedAction.createImage,
    );
  }

  AssetImageRow? selectedImage;
  if (selectedImageId != null) {
    for (final row in imagesResponse.items) {
      if (row.id == selectedImageId) {
        selectedImage = row;
        break;
      }
    }
  }
  selectedImage ??= imagesResponse.items.first;

  if (!hasPreviewBytes) {
    return AssetImagesWorkbenchDiagnosis(
      summary: '已读取 ${imagesResponse.items.length} 张图片，但还没加载当前预览。',
      detail: '建议先读取当前图片预览，确认 file_path 与状态是否匹配，再决定是否继续编辑或删除。',
      recommendedAction:
          AssetImagesWorkbenchRecommendedAction.previewSelectedImage,
    );
  }

  return AssetImagesWorkbenchDiagnosis(
    summary: '当前图片已就绪，可继续编辑。',
    detail:
        '当前焦点是 sort=${selectedImage.sortIndex} 的图片，可继续更新 file_path、state 或 sort_index，再根据预览决定是否删除。',
    recommendedAction:
        AssetImagesWorkbenchRecommendedAction.updateSelectedImage,
  );
}

String? chooseInitialAssetImageId(
  ListAssetImagesResponse response, {
  String? preferredImageId,
}) {
  final items = response.items;
  if (items.isEmpty) {
    return null;
  }
  if (preferredImageId != null) {
    for (final image in items) {
      if (image.id == preferredImageId) {
        return preferredImageId;
      }
    }
  }
  for (final image in items) {
    if (image.selected ?? false) {
      return image.id;
    }
  }
  final coverNumericImageId = response.coverNumericImageId;
  if (coverNumericImageId != null) {
    for (final image in items) {
      if (image.numericImageId == coverNumericImageId) {
        return image.id;
      }
    }
  }
  return items.first.id;
}

String summarizeAssetImageSelection(
  ListAssetImagesResponse response, {
  String? selectedImageId,
}) {
  if (response.items.isEmpty) {
    return '当前资产暂无图片。';
  }
  AssetImageRow? selectedImage;
  if (selectedImageId != null) {
    for (final image in response.items) {
      if (image.id == selectedImageId) {
        selectedImage = image;
        break;
      }
    }
  }
  selectedImage ??= response.items.first;
  final coverLine = response.coverNumericImageId == null
      ? '当前没有封面图'
      : '封面 numeric image #${response.coverNumericImageId}';
  final selectedLine =
      '当前焦点 sort=${selectedImage.sortIndex} · ${selectedImage.state ?? "未知状态"}';
  return '已加载 ${response.items.length} 张图片；$coverLine；$selectedLine。';
}

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
