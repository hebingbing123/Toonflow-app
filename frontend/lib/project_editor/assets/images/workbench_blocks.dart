part of 'workbench_support.dart';

Future<(int, int)> _decodeImageDimensions(Uint8List bytes) async {
  final codec = await instantiateImageCodec(bytes);
  try {
    final frame = await codec.getNextFrame();
    try {
      return (frame.image.width, frame.image.height);
    } finally {
      frame.image.dispose();
    }
  } finally {
    codec.dispose();
  }
}

Future<void> reloadAssetBlocks({
  required AssetImagesWorkbenchScope scope,
  required int assetNumericId,
  required StateSetter setState,
}) async {
  setState(() => scope.runtime.onLoadingBlocksChanged(true));
  try {
    final rows = await listProjectAssetBlocksByProjectIds(
      scope.token,
      scope.projectId,
      assetNumericId,
    );
    setState(() {
      scope.runtime.onAssetBlocksChanged(rows);
      scope.runtime.onStatusChanged(null);
    });
  } catch (error) {
    setState(() {
      scope.runtime.onStatusChanged(
        buildAssetImagesWorkbenchFailureNotice(
          l10n: scope.mutation.l10n,
          actionSummary: scope.mutation.l10n.projectEditorAssetImagesBlockRegisterFailed,
          recommendedAction: AssetImagesWorkbenchRecommendedAction.loadImages,
          error: error,
          fallbackDetail: scope.mutation.l10n.projectEditorAssetImagesBlockRegisterFailed,
        ),
      );
    });
  } finally {
    setState(() => scope.runtime.onLoadingBlocksChanged(false));
  }
}

Future<void> registerPreviewAsAssetBlock({
  required AssetImagesWorkbenchScope scope,
  required int assetNumericId,
  required StateSetter setState,
}) async {
  final bytes = scope.runtime.previewBytes();
  final blockKey = scope.blockKeyController.text.trim();
  final l10n = scope.mutation.l10n;
  if (bytes == null || bytes.isEmpty) {
    setState(() {
      scope.runtime.onStatusChanged(l10n.projectEditorAssetImagesNoPreviewCleared);
    });
    return;
  }
  if (blockKey.isEmpty) {
    setState(() {
      scope.runtime.onStatusChanged(l10n.projectEditorAssetImagesBlockKeyLabel);
    });
    return;
  }

  scope.mutation.onBusyMutationChanged(true);
  setState(() {});
  try {
    final (width, height) = await _decodeImageDimensions(bytes);
    await createProjectAssetBlockForProject(
      scope.token,
      scope.projectId,
      assetNumericId,
      blockKey: blockKey,
      width: width,
      height: height,
      pngBase64: base64Encode(bytes),
      warmLocalCache: true,
    );
    await reloadAssetBlocks(
      scope: scope,
      assetNumericId: assetNumericId,
      setState: setState,
    );
    setState(() {
      scope.runtime.onStatusChanged(l10n.projectEditorAssetImagesBlockRegistered);
    });
  } catch (error) {
    setState(() {
      scope.runtime.onStatusChanged(
        buildAssetImagesWorkbenchFailureNotice(
          l10n: l10n,
          actionSummary: l10n.projectEditorAssetImagesBlockRegisterFailed,
          recommendedAction: AssetImagesWorkbenchRecommendedAction.previewSelectedImage,
          error: error,
          fallbackDetail: l10n.projectEditorAssetImagesBlockRegisterFailed,
        ),
      );
    });
  } finally {
    scope.mutation.onBusyMutationChanged(false);
    setState(() {});
  }
}
