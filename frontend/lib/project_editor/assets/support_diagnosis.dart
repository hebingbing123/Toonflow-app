part of 'support.dart';

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
      return 'Load image list';
    case AssetImagesWorkbenchRecommendedAction.createImage:
      return 'Add image';
    case AssetImagesWorkbenchRecommendedAction.previewSelectedImage:
      return 'Load current preview';
    case AssetImagesWorkbenchRecommendedAction.updateSelectedImage:
      return 'Save current image';
  }
}

String buildAssetImagesWorkbenchFollowUp({
  required String actionSummary,
  required AssetImagesWorkbenchDiagnosis diagnosis,
}) {
  final nextAction = describeAssetImagesWorkbenchRecommendedAction(
    diagnosis.recommendedAction,
  );
  return '$actionSummary Next step: $nextAction. ${diagnosis.detail}';
}

String normalizeAssetImagesWorkbenchErrorMessage(String raw) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) {
    return 'No additional error detail.';
  }
  final normalized = trimmed.replaceFirst(
    RegExp(r'^RustApiException\([^)]*\):\s*'),
    '',
  );
  if (normalized.isEmpty) {
    return 'No additional error detail.';
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
  return '$actionSummary Next step: $nextAction. Reason: $reason. $fallbackDetail';
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
      summary: 'Image list for this asset has not been loaded yet.',
      detail:
          'Sync the image list first to see whether history images exist, then preview or add a new image.',
      recommendedAction: AssetImagesWorkbenchRecommendedAction.loadImages,
    );
  }

  if (imagesResponse.items.isEmpty) {
    return const AssetImagesWorkbenchDiagnosis(
      summary: 'This asset has no images yet.',
      detail:
          'Add an image to create the first editable history row for this asset.',
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
      summary:
          'Loaded ${imagesResponse.items.length} image(s); preview not loaded yet.',
      detail:
          'Load the current image preview and verify file_path and state before editing or deleting.',
      recommendedAction:
          AssetImagesWorkbenchRecommendedAction.previewSelectedImage,
    );
  }

  return AssetImagesWorkbenchDiagnosis(
    summary: 'Current image is ready to edit.',
    detail:
        'Focused image sort=${selectedImage.sortIndex}; you can update file_path, state, or sort_index, then delete if needed.',
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
    return 'This asset has no images.';
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
      ? 'No cover image'
      : 'Cover numeric image #${response.coverNumericImageId}';
  final selectedLine =
      'Focus sort=${selectedImage.sortIndex} · ${selectedImage.state ?? "unknown state"}';
  return 'Loaded ${response.items.length} image(s); $coverLine; $selectedLine.';
}
