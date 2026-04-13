part of '../support.dart';

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
      ? '当前未记录封面 numeric image'
      : '封面 numeric image #${response.coverNumericImageId}';
  return '已加载 ${response.items.length} 张图片；$coverLine；当前图片 sort=${selectedImage.sortIndex} · ${selectedImage.state ?? "未知状态"}。';
}
