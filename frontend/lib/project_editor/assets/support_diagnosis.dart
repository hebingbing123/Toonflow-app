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
  AppLocalizations l10n,
  AssetImagesWorkbenchRecommendedAction action,
) {
  switch (action) {
    case AssetImagesWorkbenchRecommendedAction.loadImages:
      return l10n.projectEditorAssetImagesRecommendedLoadList;
    case AssetImagesWorkbenchRecommendedAction.createImage:
      return l10n.projectEditorAssetImagesRecommendedAddImage;
    case AssetImagesWorkbenchRecommendedAction.previewSelectedImage:
      return l10n.projectEditorAssetImagesRecommendedLoadPreview;
    case AssetImagesWorkbenchRecommendedAction.updateSelectedImage:
      return l10n.projectEditorAssetImagesRecommendedSaveImage;
  }
}

String buildAssetImagesWorkbenchFollowUp({
  required AppLocalizations l10n,
  required String actionSummary,
  required AssetImagesWorkbenchDiagnosis diagnosis,
}) {
  final nextAction = describeAssetImagesWorkbenchRecommendedAction(
    l10n,
    diagnosis.recommendedAction,
  );
  return l10n.projectEditorAssetImagesFollowUp(
    actionSummary,
    nextAction,
    diagnosis.detail,
  );
}

String normalizeAssetImagesWorkbenchErrorMessage(
  AppLocalizations l10n,
  String raw,
) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) {
    return l10n.projectEditorAssetImagesNoErrorDetail;
  }
  final normalized = trimmed.replaceFirst(
    RegExp(r'^RustApiException\([^)]*\):\s*'),
    '',
  );
  if (normalized.isEmpty) {
    return l10n.projectEditorAssetImagesNoErrorDetail;
  }
  return normalized;
}

String buildAssetImagesWorkbenchFailureNotice({
  required AppLocalizations l10n,
  required String actionSummary,
  required AssetImagesWorkbenchRecommendedAction recommendedAction,
  required Object error,
  required String fallbackDetail,
}) {
  final reason = normalizeAssetImagesWorkbenchErrorMessage(l10n, error.toString());
  final nextAction = describeAssetImagesWorkbenchRecommendedAction(
    l10n,
    recommendedAction,
  );
  return l10n.projectEditorAssetImagesFailureNotice(
    actionSummary,
    nextAction,
    reason,
    fallbackDetail,
  );
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

AssetImagesWorkbenchDiagnosis diagnoseAssetImagesWorkbench(
  AppLocalizations l10n, {
  ListAssetImagesResponse? imagesResponse,
  String? selectedImageId,
  required bool hasPreviewBytes,
}) {
  if (imagesResponse == null) {
    return AssetImagesWorkbenchDiagnosis(
      summary: l10n.projectEditorAssetImagesDiagnosisNotLoadedSummary,
      detail: l10n.projectEditorAssetImagesDiagnosisNotLoadedDetail,
      recommendedAction: AssetImagesWorkbenchRecommendedAction.loadImages,
    );
  }

  if (imagesResponse.items.isEmpty) {
    return AssetImagesWorkbenchDiagnosis(
      summary: l10n.projectEditorAssetImagesDiagnosisNoImagesSummary,
      detail: l10n.projectEditorAssetImagesDiagnosisNoImagesDetail,
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
      summary: l10n.projectEditorAssetImagesDiagnosisPreviewPendingSummary(
        imagesResponse.items.length,
      ),
      detail: l10n.projectEditorAssetImagesDiagnosisPreviewPendingDetail,
      recommendedAction:
          AssetImagesWorkbenchRecommendedAction.previewSelectedImage,
    );
  }

  return AssetImagesWorkbenchDiagnosis(
    summary: l10n.projectEditorAssetImagesDiagnosisReadySummary,
    detail: l10n.projectEditorAssetImagesDiagnosisReadyDetail(
      selectedImage.sortIndex,
    ),
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
  AppLocalizations l10n,
  ListAssetImagesResponse response, {
  String? selectedImageId,
}) {
  if (response.items.isEmpty) {
    return l10n.projectEditorAssetImagesSelectionNoImages;
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
      ? l10n.projectEditorAssetImagesSelectionCoverNone
      : l10n.projectEditorAssetImagesSelectionCoverNumeric(
          response.coverNumericImageId!,
        );
  final stateLabel =
      selectedImage.state ?? l10n.projectEditorAssetImagesUnknownState;
  final focusLine = l10n.projectEditorAssetImagesSelectionFocusLine(
    selectedImage.sortIndex,
    stateLabel,
  );
  return l10n.projectEditorAssetImagesSelectionSummary(
    response.items.length,
    coverLine,
    focusLine,
  );
}
