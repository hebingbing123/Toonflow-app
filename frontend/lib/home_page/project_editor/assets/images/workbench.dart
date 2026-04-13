part of '../../../../home_page.dart';

extension _HomePageProjectEditorAssetsImagesWorkbench on _HomePageState {
  /// Keep the dialog entry focused on orchestration while helpers own the
  /// image-list state sync, loading, and mutation branches.
  Future<void> _openAssetImagesWorkbenchDialog({
    required BuildContext ctx,
    required StateSetter setDialogState,
    required String token,
    required ProjectRow p,
    required List<ListAssetsResponse?> assetsRef,
    required List<bool> assetsBusy,
    required Future<void> Function() reloadAssetsAndStats,
    int? preferredAssetNumericId,
  }) async {
    final assets = assetsRef[0]?.items ?? const <AssetRow>[];
    if (assets.isEmpty) {
      ScaffoldMessenger.of(
        ctx,
      ).showSnackBar(const SnackBar(content: Text('请先创建资产再管理图片')));
      return;
    }
    final session = AssetImagesWorkbenchSession.initialize(
      assets: assets,
      preferredAssetNumericId: preferredAssetNumericId,
    );

    final createControllers = AssetImagesWorkbenchFormControllers();
    final patchControllers = AssetImagesWorkbenchFormControllers();
    final runtime = session.buildRuntime();
    final controller = AssetImagesWorkbenchController(
      token: token,
      projectId: p.id,
      runtime: runtime,
      currentAssetNumericId: () => session.selectedAssetNumericId,
      onAssetNumericIdChanged: (value) => session.selectedAssetNumericId = value,
      createControllers: createControllers,
      patchControllers: patchControllers,
      ctx: ctx,
      setDialogState: setDialogState,
      assetsBusy: assetsBusy,
      onBusyMutationChanged: (busy) => session.busyMutation = busy,
      reloadAssetsAndStats: reloadAssetsAndStats,
    );

    try {
      await showDialog<void>(
        context: ctx,
        builder: (dialogCtx) {
          return StatefulBuilder(
            builder: (dialogCtx, setState) {
              if (!session.initialLoadTriggered) {
                session.initialLoadTriggered = true;
                controller.scheduleInitialLoad(
                  dialogCtx: dialogCtx,
                  setState: setState,
                );
              }
              final dialogState = session.captureDialogState(
                assets: assets,
                createControllers: createControllers,
                patchControllers: patchControllers,
              );
              return _buildAssetImagesWorkbenchDialog(
                ctx: ctx,
                dialogCtx: dialogCtx,
                state: dialogState,
                callbacks: controller.buildDialogCallbacks(setState: setState),
              );
            },
          );
        },
      );
    } finally {
      createControllers.dispose();
      patchControllers.dispose();
    }
  }
}
