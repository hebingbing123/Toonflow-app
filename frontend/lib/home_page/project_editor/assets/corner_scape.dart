part of '../../../home_page.dart';

extension _HomePageProjectEditorAssetsCornerScapeWorkbench on _HomePageState {
  Future<void> _openCornerScapeWorkbenchDialog({
    required BuildContext ctx,
    required StateSetter setDialogState,
    required String token,
    required ProjectRow p,
    required List<bool> assetsBusy,
    int? preferredAssetNumericId,
  }) async {
    final session = CornerScapeWorkbenchSession();
    final controller = CornerScapeWorkbenchController(
      ctx: ctx,
      token: token,
      project: p,
      setDialogState: setDialogState,
      assetsBusy: assetsBusy,
      preferredAssetNumericId: preferredAssetNumericId,
      session: session,
    );

    try {
      await showDialog<void>(
        context: ctx,
        builder: (dialogCtx) {
          return StatefulBuilder(
            builder: (dialogCtx, setState) {
              if (!session.initialLoadTriggered) {
                session.initialLoadTriggered = true;
                WidgetsBinding.instance.addPostFrameCallback((_) async {
                  if (!dialogCtx.mounted) return;
                  await controller.refreshAssets(setState);
                });
              }
              return CornerScapeWorkbenchDialogView(
                model: CornerScapeWorkbenchDialogViewModel(
                  typesCtrl: session.typesCtrl,
                  busy: assetsBusy[0],
                  assets: session.assets,
                  selectedAssetNumericId: session.selectedAssetNumericId,
                  selectedHistoryImageId: session.selectedHistoryImageId,
                  selectedPreviewBytes: session.selectedPreviewBytes,
                  loading: session.loading,
                  loadingPreview: session.loadingPreview,
                  summaryLine: session.summaryLine,
                  selectedAsset: session.selectedAsset(),
                  selectedImage: session.selectedHistoryImage(),
                ),
                callbacks: CornerScapeWorkbenchDialogViewCallbacks(
                  onRefresh: () => controller.refreshAssets(setState),
                  onClearFilter: () => controller.clearFilter(setState),
                  onPresetType: (type) => controller.presetType(setState, type),
                  onAssetSelected: (assetNumericId) =>
                      controller.selectAsset(setState, assetNumericId),
                  onHistoryImageSelected: (historyImageId) =>
                      controller.selectHistoryImage(setState, historyImageId),
                  onClose: () => Navigator.of(dialogCtx).pop(),
                ),
              );
            },
          );
        },
      );
    } finally {
      session.dispose();
    }
  }
}
