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

  _AssetImagesWorkbenchRequestContext get _requestContext =>
      _AssetImagesWorkbenchRequestContext(
        scope: _scope,
        assetNumericId: currentAssetNumericId(),
        selectedImageId: runtime.currentSelectedImageId,
        imagesResponse: runtime.imagesResponse(),
      );

  T _withRequestContext<T>(
    T Function(_AssetImagesWorkbenchRequestContext request) action,
  ) {
    return action(_requestContext);
  }

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
  }) {
    return _withRequestContext(
      (request) => changeAssetImagesWorkbenchAsset(
        value: value,
        scope: request.scope,
        currentAssetNumericId: request.assetNumericId,
        setState: setState,
        onAssetNumericIdChanged: onAssetNumericIdChanged,
      ),
    );
  }

  Future<void> reloadImages(StateSetter setState) {
    return _withRequestContext(
      (request) => reloadAssetImages(
        scope: request.scope,
        assetNumericId: request.assetNumericId,
        setState: setState,
      ),
    );
  }

  Future<void> loadPreview(StateSetter setState) {
    return _withRequestContext(
      (request) => loadAssetImagePreview(
        scope: request.scope,
        assetNumericId: request.assetNumericId,
        selectedImageId: request.selectedImageId,
        setState: setState,
      ),
    );
  }

  Future<void> runRecommendedAction(StateSetter setState) {
    return _withRequestContext(
      (request) => runAssetImagesRecommendedAction(
        scope: request.scope,
        assetNumericId: request.assetNumericId,
        setState: setState,
      ),
    );
  }

  Future<void> selectImage({
    required String? value,
    required StateSetter setState,
  }) {
    return _withRequestContext(
      (request) => selectAssetImagesWorkbenchImage(
        value: value,
        scope: request.scope,
        assetNumericId: request.assetNumericId,
        setState: setState,
      ),
    );
  }

  Future<void> createImage(StateSetter setState) {
    return _withRequestContext(
      (request) => createAssetImage(
        scope: request.scope,
        assetNumericId: request.assetNumericId,
        setState: setState,
      ),
    );
  }

  Future<void> patchImage(StateSetter setState) {
    return _withRequestContext(
      (request) => patchAssetImage(
        scope: request.scope,
        assetNumericId: request.assetNumericId,
        imagesResponse: request.imagesResponse,
        selectedImageId: request.selectedImageId,
        setState: setState,
      ),
    );
  }

  Future<void> deleteImage(StateSetter setState) {
    return _withRequestContext(
      (request) => deleteAssetImage(
        scope: request.scope,
        assetNumericId: request.assetNumericId,
        imagesResponse: request.imagesResponse,
        selectedImageId: request.selectedImageId,
        setState: setState,
      ),
    );
  }

  AssetImagesWorkbenchDialogCallbacks buildDialogCallbacks({
    required StateSetter setState,
  }) {
    return _withRequestContext(
      (request) => AssetImagesWorkbenchDialogCallbacks(
        onAssetChanged: (value) =>
            changeAsset(value: value, setState: setState),
        onRecommendedAction: () => runRecommendedAction(setState),
        onReloadImages: () => reloadImages(setState),
        onLoadPreview: () => loadPreview(setState),
        onImageChanged:
            (request.imagesResponse?.items ?? const <AssetImageRow>[]).isEmpty
            ? null
            : (value) => selectImage(value: value, setState: setState),
        onCreateImage: () => createImage(setState),
        onPatchImage: () => patchImage(setState),
        onDeleteImage: () => deleteImage(setState),
      ),
    );
  }
}
