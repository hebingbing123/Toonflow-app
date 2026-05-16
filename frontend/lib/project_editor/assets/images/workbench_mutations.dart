part of 'workbench_support.dart';

Future<void> createAssetImage({
  required AssetImagesWorkbenchScope scope,
  required int assetNumericId,
  required StateSetter setState,
}) async {
  final plan = _buildCreateAssetImageMutationPlan(
    scope: scope,
    assetNumericId: assetNumericId,
    setState: setState,
  );
  if (plan == null) {
    return;
  }
  await _runAssetImageMutationPlan(
    scope: scope,
    assetNumericId: assetNumericId,
    setState: setState,
    plan: plan.requestPlan,
    request: plan.request,
  );
}

Future<void> patchAssetImage({
  required AssetImagesWorkbenchScope scope,
  required int assetNumericId,
  required ListAssetImagesResponse? imagesResponse,
  required String? selectedImageId,
  required StateSetter setState,
}) async {
  await _runSelectedAssetImageMutation(
    scope: scope,
    assetNumericId: assetNumericId,
    imagesResponse: imagesResponse,
    selectedImageId: selectedImageId,
    setState: setState,
    plan: _buildPatchAssetImageMutationPlan(
      scope: scope,
      assetNumericId: assetNumericId,
      setState: setState,
    ),
  );
}

Future<void> deleteAssetImage({
  required AssetImagesWorkbenchScope scope,
  required int assetNumericId,
  required ListAssetImagesResponse? imagesResponse,
  required String? selectedImageId,
  required StateSetter setState,
}) async {
  await _runSelectedAssetImageMutation(
    scope: scope,
    assetNumericId: assetNumericId,
    imagesResponse: imagesResponse,
    selectedImageId: selectedImageId,
    setState: setState,
    plan: _buildDeleteAssetImageMutationPlan(
      scope: scope,
      assetNumericId: assetNumericId,
    ),
  );
}
