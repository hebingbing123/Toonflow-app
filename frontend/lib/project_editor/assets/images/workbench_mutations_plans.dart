part of 'workbench_support.dart';

class _AssetImageMutationRequestPlan {
  const _AssetImageMutationRequestPlan({
    required this.successSummary,
    required this.failureSummary,
    required this.recommendedAction,
    required this.fallbackDetail,
  });

  final String successSummary;
  final String failureSummary;
  final AssetImagesWorkbenchRecommendedAction recommendedAction;
  final String fallbackDetail;
}

class _SelectedAssetImageMutationPlan {
  const _SelectedAssetImageMutationPlan({
    required this.missingSelectionNotice,
    required this.requestPlan,
    required this.request,
  });

  final String missingSelectionNotice;
  final _AssetImageMutationRequestPlan requestPlan;
  final Future<void> Function(AssetImageRow image) request;
}

class _AssetImageMutationPlan {
  const _AssetImageMutationPlan({
    required this.requestPlan,
    required this.request,
  });

  final _AssetImageMutationRequestPlan requestPlan;
  final Future<void> Function() request;
}

_AssetImageMutationRequestPlan _createAssetImageRequestPlan(AppLocalizations l10n) =>
    _AssetImageMutationRequestPlan(
      successSummary: l10n.projectEditorAssetImagesMutationCreateSuccess,
      failureSummary: l10n.projectEditorAssetImagesMutationCreateFailure,
      recommendedAction: AssetImagesWorkbenchRecommendedAction.createImage,
      fallbackDetail: l10n.projectEditorAssetImagesMutationCreateFallback,
    );

_AssetImageMutationRequestPlan _patchAssetImageRequestPlan(AppLocalizations l10n) =>
    _AssetImageMutationRequestPlan(
      successSummary: l10n.projectEditorAssetImagesMutationPatchSuccess,
      failureSummary: l10n.projectEditorAssetImagesMutationPatchFailure,
      recommendedAction: AssetImagesWorkbenchRecommendedAction.updateSelectedImage,
      fallbackDetail: l10n.projectEditorAssetImagesMutationPatchFallback,
    );

_AssetImageMutationRequestPlan _deleteAssetImageRequestPlan(AppLocalizations l10n) =>
    _AssetImageMutationRequestPlan(
      successSummary: l10n.projectEditorAssetImagesMutationDeleteSuccess,
      failureSummary: l10n.projectEditorAssetImagesMutationDeleteFailure,
      recommendedAction: AssetImagesWorkbenchRecommendedAction.updateSelectedImage,
      fallbackDetail: l10n.projectEditorAssetImagesMutationDeleteFallback,
    );

