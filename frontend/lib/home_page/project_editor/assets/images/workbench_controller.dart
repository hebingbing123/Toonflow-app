part of '../../../../home_page.dart';

class AssetImagesWorkbenchController {
  AssetImagesWorkbenchController({
    required this.token,
    required this.projectId,
    required this.runtime,
    required this.currentAssetNumericId,
    required this.onAssetNumericIdChanged,
    required this.createControllers,
    required this.patchControllers,
    required this.ctx,
    required this.setDialogState,
    required this.assetsBusy,
    required this.onBusyMutationChanged,
    required this.reloadAssetsAndStats,
  });

  final String token;
  final String projectId;
  final AssetImagesWorkbenchRuntime runtime;
  final int Function() currentAssetNumericId;
  final ValueChanged<int> onAssetNumericIdChanged;
  final AssetImagesWorkbenchFormControllers createControllers;
  final AssetImagesWorkbenchFormControllers patchControllers;
  final BuildContext ctx;
  final StateSetter setDialogState;
  final List<bool> assetsBusy;
  final ValueChanged<bool> onBusyMutationChanged;
  final Future<void> Function() reloadAssetsAndStats;

  AssetImagesWorkbenchScope get _scope => AssetImagesWorkbenchScope(
    token: token,
    projectId: projectId,
    runtime: runtime,
    createControllers: createControllers,
    patchControllers: patchControllers,
    mutation: AssetImagesWorkbenchMutationContext(
      ctx: ctx,
      setDialogState: setDialogState,
      assetsBusy: assetsBusy,
      onBusyMutationChanged: onBusyMutationChanged,
      reloadAssetsAndStats: reloadAssetsAndStats,
    ),
  );

  void scheduleInitialLoad({
    required BuildContext dialogCtx,
    required StateSetter setState,
  }) {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!dialogCtx.mounted) {
        return;
      }
      await reloadImages(setState);
    });
  }

  Future<void> changeAsset({
    required int? value,
    required StateSetter setState,
  }) => changeAssetImagesWorkbenchAsset(
    value: value,
    scope: _scope,
    currentAssetNumericId: currentAssetNumericId(),
    setState: setState,
    onAssetNumericIdChanged: onAssetNumericIdChanged,
  );

  Future<void> reloadImages(StateSetter setState) =>
      reloadAssetImages(
        scope: _scope,
        assetNumericId: currentAssetNumericId(),
        setState: setState,
      );

  Future<void> loadPreview(StateSetter setState) => loadAssetImagePreview(
    scope: _scope,
    assetNumericId: currentAssetNumericId(),
    selectedImageId: runtime.currentSelectedImageId,
    setState: setState,
  );

  Future<void> runRecommendedAction(StateSetter setState) =>
      runAssetImagesRecommendedAction(
        scope: _scope,
        assetNumericId: currentAssetNumericId(),
        setState: setState,
      );

  Future<void> selectImage({
    required String? value,
    required StateSetter setState,
  }) => selectAssetImagesWorkbenchImage(
    value: value,
    scope: _scope,
    assetNumericId: currentAssetNumericId(),
    setState: setState,
  );

  Future<void> createImage(StateSetter setState) =>
      createAssetImage(
        scope: _scope,
        assetNumericId: currentAssetNumericId(),
        setState: setState,
      );

  Future<void> patchImage(StateSetter setState) =>
      patchAssetImage(
        scope: _scope,
        assetNumericId: currentAssetNumericId(),
        imagesResponse: runtime.imagesResponse(),
        selectedImageId: runtime.currentSelectedImageId,
        setState: setState,
      );

  Future<void> deleteImage(StateSetter setState) =>
      deleteAssetImage(
        scope: _scope,
        assetNumericId: currentAssetNumericId(),
        imagesResponse: runtime.imagesResponse(),
        selectedImageId: runtime.currentSelectedImageId,
        setState: setState,
      );

  AssetImagesWorkbenchDialogCallbacks buildDialogCallbacks({
    required StateSetter setState,
  }) {
    final imageItems =
        runtime.imagesResponse()?.items ?? const <AssetImageRow>[];
    return AssetImagesWorkbenchDialogCallbacks(
      onAssetChanged: (value) => changeAsset(value: value, setState: setState),
      onRecommendedAction: () => runRecommendedAction(setState),
      onReloadImages: () => reloadImages(setState),
      onLoadPreview: () => loadPreview(setState),
      onImageChanged: imageItems.isEmpty
          ? null
          : (value) => selectImage(value: value, setState: setState),
      onCreateImage: () => createImage(setState),
      onPatchImage: () => patchImage(setState),
      onDeleteImage: () => deleteImage(setState),
    );
  }
}
