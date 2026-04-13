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
    token: token,
    projectId: projectId,
    currentAssetNumericId: currentAssetNumericId(),
    runtime: runtime,
    setState: setState,
    onAssetNumericIdChanged: onAssetNumericIdChanged,
    patchControllers: patchControllers,
  );

  Future<void> reloadImages(StateSetter setState) => reloadAssetImages(
    token: token,
    projectId: projectId,
    assetNumericId: currentAssetNumericId(),
    runtime: runtime,
    setState: setState,
    patchControllers: patchControllers,
  );

  Future<void> loadPreview(StateSetter setState) => loadAssetImagePreview(
    token: token,
    projectId: projectId,
    assetNumericId: currentAssetNumericId(),
    runtime: runtime,
    selectedImageId: runtime.currentSelectedImageId,
    setState: setState,
  );

  Future<void> runRecommendedAction(StateSetter setState) =>
      runAssetImagesRecommendedAction(
        token: token,
        projectId: projectId,
        assetNumericId: currentAssetNumericId(),
        runtime: runtime,
        setState: setState,
        createControllers: createControllers,
        patchControllers: patchControllers,
        ctx: ctx,
        setDialogState: setDialogState,
        assetsBusy: assetsBusy,
        onBusyMutationChanged: onBusyMutationChanged,
        reloadAssetsAndStats: reloadAssetsAndStats,
      );

  Future<void> selectImage({
    required String? value,
    required StateSetter setState,
  }) => selectAssetImagesWorkbenchImage(
    value: value,
    token: token,
    projectId: projectId,
    assetNumericId: currentAssetNumericId(),
    runtime: runtime,
    setState: setState,
    patchControllers: patchControllers,
  );

  Future<void> createImage(StateSetter setState) => createAssetImage(
    token: token,
    projectId: projectId,
    assetNumericId: currentAssetNumericId(),
    createControllers: createControllers,
    setState: setState,
    ctx: ctx,
    setDialogState: setDialogState,
    assetsBusy: assetsBusy,
    onBusyMutationChanged: onBusyMutationChanged,
    reloadAssetsAndStats: reloadAssetsAndStats,
    runtime: runtime,
    patchControllers: patchControllers,
  );

  Future<void> patchImage(StateSetter setState) => patchAssetImage(
    token: token,
    projectId: projectId,
    assetNumericId: currentAssetNumericId(),
    imagesResponse: runtime.imagesResponse(),
    selectedImageId: runtime.currentSelectedImageId,
    patchControllers: patchControllers,
    setState: setState,
    ctx: ctx,
    setDialogState: setDialogState,
    assetsBusy: assetsBusy,
    onBusyMutationChanged: onBusyMutationChanged,
    reloadAssetsAndStats: reloadAssetsAndStats,
    runtime: runtime,
  );

  Future<void> deleteImage(StateSetter setState) => deleteAssetImage(
    token: token,
    projectId: projectId,
    assetNumericId: currentAssetNumericId(),
    imagesResponse: runtime.imagesResponse(),
    selectedImageId: runtime.currentSelectedImageId,
    setState: setState,
    ctx: ctx,
    setDialogState: setDialogState,
    assetsBusy: assetsBusy,
    onBusyMutationChanged: onBusyMutationChanged,
    reloadAssetsAndStats: reloadAssetsAndStats,
    runtime: runtime,
    patchControllers: patchControllers,
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
