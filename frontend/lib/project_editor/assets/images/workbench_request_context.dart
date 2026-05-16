part of 'workbench_support.dart';

class _AssetImagesWorkbenchRequestContext {
  const _AssetImagesWorkbenchRequestContext({
    required this.scope,
    required this.assetNumericId,
    required this.selectedImageId,
    required this.imagesResponse,
  });

  final AssetImagesWorkbenchScope scope;
  final int assetNumericId;
  final String? selectedImageId;
  final ListAssetImagesResponse? imagesResponse;
}

