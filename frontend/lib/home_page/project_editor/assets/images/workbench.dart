part of '../../../../home_page.dart';

class _AssetImagesWorkbenchDialogDeps {
  _AssetImagesWorkbenchDialogDeps._({
    required this.session,
    required this.createControllers,
    required this.patchControllers,
    required this.controller,
  });

  factory _AssetImagesWorkbenchDialogDeps.build({
    required String token,
    required ProjectRow project,
    required BuildContext ctx,
    required StateSetter setDialogState,
    required List<bool> assetsBusy,
    required Future<void> Function() reloadAssetsAndStats,
    required List<AssetRow> assets,
    required int? preferredAssetNumericId,
  }) {
    final session = AssetImagesWorkbenchSession.initialize(
      assets: assets,
      preferredAssetNumericId: preferredAssetNumericId,
    );
    final createControllers = AssetImagesWorkbenchFormControllers();
    final patchControllers = AssetImagesWorkbenchFormControllers();
    final runtime = session.buildRuntime();
    return _AssetImagesWorkbenchDialogDeps._(
      session: session,
      createControllers: createControllers,
      patchControllers: patchControllers,
      controller: AssetImagesWorkbenchController(
        token: token,
        projectId: project.id,
        runtime: runtime,
        currentAssetNumericId: () => session.selectedAssetNumericId,
        onAssetNumericIdChanged: (value) =>
            session.selectedAssetNumericId = value,
        createControllers: createControllers,
        patchControllers: patchControllers,
        ctx: ctx,
        setDialogState: setDialogState,
        assetsBusy: assetsBusy,
        onBusyMutationChanged: (busy) => session.busyMutation = busy,
        reloadAssetsAndStats: reloadAssetsAndStats,
      ),
    );
  }

  final AssetImagesWorkbenchSession session;
  final AssetImagesWorkbenchFormControllers createControllers;
  final AssetImagesWorkbenchFormControllers patchControllers;
  final AssetImagesWorkbenchController controller;

  AssetImagesWorkbenchDialogState captureDialogState({
    required List<AssetRow> assets,
  }) {
    return session.captureDialogState(
      assets: assets,
      createControllers: createControllers,
      patchControllers: patchControllers,
    );
  }

  void dispose() {
    createControllers.dispose();
    patchControllers.dispose();
  }
}

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
    final deps = _AssetImagesWorkbenchDialogDeps.build(
      token: token,
      project: p,
      ctx: ctx,
      setDialogState: setDialogState,
      assetsBusy: assetsBusy,
      reloadAssetsAndStats: reloadAssetsAndStats,
      assets: assets,
      preferredAssetNumericId: preferredAssetNumericId,
    );

    try {
      await showDialog<void>(
        context: ctx,
        builder: (dialogCtx) {
          return StatefulBuilder(
            builder: (dialogCtx, setState) {
              if (!deps.session.initialLoadTriggered) {
                deps.session.initialLoadTriggered = true;
                deps.controller.scheduleInitialLoad(
                  dialogCtx: dialogCtx,
                  setState: setState,
                );
              }
              final dialogState = deps.captureDialogState(
                assets: assets,
              );
              return _buildAssetImagesWorkbenchDialog(
                ctx: ctx,
                dialogCtx: dialogCtx,
                state: dialogState,
                callbacks: deps.controller.buildDialogCallbacks(
                  setState: setState,
                ),
              );
            },
          );
        },
      );
    } finally {
      deps.dispose();
    }
  }
}
