part of '../../../../home_page.dart';

class AssetImagesWorkbenchController {
  AssetImagesWorkbenchController({
    required this.token,
    required this.projectId,
    required this.runtime,
    required this.currentAssetNumericId,
    required this.onAssetNumericIdChanged,
    required this.currentImagesResponse,
    required this.currentSelectedImageId,
    required this.currentPreviewBytes,
    required this.createFilePathCtrl,
    required this.createStateCtrl,
    required this.createSortCtrl,
    required this.patchFilePathCtrl,
    required this.patchStateCtrl,
    required this.patchSortCtrl,
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
  final ListAssetImagesResponse? Function() currentImagesResponse;
  final String? Function() currentSelectedImageId;
  final Uint8List? Function() currentPreviewBytes;
  final TextEditingController createFilePathCtrl;
  final TextEditingController createStateCtrl;
  final TextEditingController createSortCtrl;
  final TextEditingController patchFilePathCtrl;
  final TextEditingController patchStateCtrl;
  final TextEditingController patchSortCtrl;
  final BuildContext ctx;
  final StateSetter setDialogState;
  final List<bool> assetsBusy;
  final ValueChanged<bool> onBusyMutationChanged;
  final Future<void> Function() reloadAssetsAndStats;

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
    patchFilePathCtrl: patchFilePathCtrl,
    patchStateCtrl: patchStateCtrl,
    patchSortCtrl: patchSortCtrl,
  );

  Future<void> reloadImages(StateSetter setState) => reloadAssetImages(
    token: token,
    projectId: projectId,
    assetNumericId: currentAssetNumericId(),
    runtime: runtime,
    setState: setState,
    patchFilePathCtrl: patchFilePathCtrl,
    patchStateCtrl: patchStateCtrl,
    patchSortCtrl: patchSortCtrl,
  );

  Future<void> loadPreview(StateSetter setState) => loadAssetImagePreview(
    token: token,
    projectId: projectId,
    assetNumericId: currentAssetNumericId(),
    runtime: runtime,
    selectedImageId: currentSelectedImageId(),
    setState: setState,
  );

  Future<void> runRecommendedAction(StateSetter setState) =>
      runAssetImagesRecommendedAction(
        token: token,
        projectId: projectId,
        assetNumericId: currentAssetNumericId(),
        runtime: runtime,
        setState: setState,
        patchFilePathCtrl: patchFilePathCtrl,
        patchStateCtrl: patchStateCtrl,
        patchSortCtrl: patchSortCtrl,
        createFilePathCtrl: createFilePathCtrl,
        createStateCtrl: createStateCtrl,
        createSortCtrl: createSortCtrl,
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
    patchFilePathCtrl: patchFilePathCtrl,
    patchStateCtrl: patchStateCtrl,
    patchSortCtrl: patchSortCtrl,
  );

  Future<void> createImage(StateSetter setState) => createAssetImage(
    token: token,
    projectId: projectId,
    assetNumericId: currentAssetNumericId(),
    createFilePathCtrl: createFilePathCtrl,
    createStateCtrl: createStateCtrl,
    createSortCtrl: createSortCtrl,
    setState: setState,
    ctx: ctx,
    setDialogState: setDialogState,
    assetsBusy: assetsBusy,
    onBusyMutationChanged: onBusyMutationChanged,
    reloadAssetsAndStats: reloadAssetsAndStats,
    runtime: runtime,
    patchFilePathCtrl: patchFilePathCtrl,
    patchStateCtrl: patchStateCtrl,
    patchSortCtrl: patchSortCtrl,
  );

  Future<void> patchImage(StateSetter setState) => patchAssetImage(
    token: token,
    projectId: projectId,
    assetNumericId: currentAssetNumericId(),
    imagesResponse: currentImagesResponse(),
    selectedImageId: currentSelectedImageId(),
    patchFilePathCtrl: patchFilePathCtrl,
    patchStateCtrl: patchStateCtrl,
    patchSortCtrl: patchSortCtrl,
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
    imagesResponse: currentImagesResponse(),
    selectedImageId: currentSelectedImageId(),
    setState: setState,
    ctx: ctx,
    setDialogState: setDialogState,
    assetsBusy: assetsBusy,
    onBusyMutationChanged: onBusyMutationChanged,
    reloadAssetsAndStats: reloadAssetsAndStats,
    runtime: runtime,
    patchFilePathCtrl: patchFilePathCtrl,
    patchStateCtrl: patchStateCtrl,
    patchSortCtrl: patchSortCtrl,
  );
}
