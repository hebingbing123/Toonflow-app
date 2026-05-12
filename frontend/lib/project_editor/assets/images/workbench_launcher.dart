import 'package:flutter/material.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../../rust_api.dart';
import 'workbench_dialog_view.dart';
import 'workbench_support.dart';

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
    required AppLocalizations l10n,
    required List<AssetRow> assets,
  }) {
    return session.captureDialogState(
      l10n: l10n,
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

Future<void> openAssetImagesWorkbenchDialog({
  required BuildContext ctx,
  required StateSetter setDialogState,
  required String token,
  required ProjectRow project,
  required List<ListAssetsResponse?> assetsRef,
  required List<bool> assetsBusy,
  required Future<void> Function() reloadAssetsAndStats,
  int? preferredAssetNumericId,
}) async {
  final assets = assetsRef[0]?.items ?? const <AssetRow>[];
  if (assets.isEmpty) {
    final l10n = AppLocalizations.of(ctx)!;
    ScaffoldMessenger.of(ctx).showSnackBar(
      SnackBar(content: Text(l10n.projectEditorAssetImagesCreateAssetFirst)),
    );
    return;
  }
  final deps = _AssetImagesWorkbenchDialogDeps.build(
    token: token,
    project: project,
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
            final l10n = AppLocalizations.of(dialogCtx)!;
            final dialogState = deps.captureDialogState(l10n: l10n, assets: assets);
            final callbacks = deps.controller.buildDialogCallbacks(
              setState: setState,
            );
            final recommendedActionDisabled =
                dialogState.loadingList ||
                dialogState.loadingPreview ||
                dialogState.busyMutation;
            final mutationDisabled = dialogState.busyMutation;
            return AssetImagesWorkbenchDialogView(
              model: AssetImagesWorkbenchDialogViewModel(
                assets: dialogState.assets,
                imageItems: dialogState.imageItems,
                selectedAssetNumericId: dialogState.selectedAssetNumericId,
                selectedImageId: dialogState.selectedImageId,
                diagnosis: dialogState.diagnosis,
                loadingList: dialogState.loadingList,
                loadingPreview: dialogState.loadingPreview,
                busyMutation: dialogState.busyMutation,
                statusLine: dialogState.statusLine,
                previewBytes: dialogState.previewBytes,
                createFilePathController:
                    dialogState.createControllers.filePathCtrl,
                createStateController: dialogState.createControllers.stateCtrl,
                createSortController: dialogState.createControllers.sortCtrl,
                patchFilePathController:
                    dialogState.patchControllers.filePathCtrl,
                patchStateController: dialogState.patchControllers.stateCtrl,
                patchSortController: dialogState.patchControllers.sortCtrl,
              ),
              callbacks: AssetImagesWorkbenchDialogViewCallbacks(
                onAssetChanged: (value) {
                  callbacks.onAssetChanged(value);
                },
                onRecommendedAction: recommendedActionDisabled
                    ? null
                    : () {
                        callbacks.onRecommendedAction();
                      },
                onReloadImages: dialogState.loadingList || mutationDisabled
                    ? null
                    : () {
                        callbacks.onReloadImages();
                      },
                onLoadPreview: dialogState.loadingPreview || mutationDisabled
                    ? null
                    : () {
                        callbacks.onLoadPreview();
                      },
                onImageChanged: (value) {
                  callbacks.onImageChanged?.call(value);
                },
                onCreateImage: mutationDisabled
                    ? null
                    : () {
                        callbacks.onCreateImage();
                      },
                onPatchImage: mutationDisabled
                    ? null
                    : () {
                        callbacks.onPatchImage();
                      },
                onDeleteImage: mutationDisabled
                    ? null
                    : () {
                        callbacks.onDeleteImage();
                      },
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
