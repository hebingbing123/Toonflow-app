part of '../../../home_page.dart';

extension _HomePageProjectEditorAssetsClipUploadWorkbench on _HomePageState {
  Future<void> _openClipUploadDialog({
    required BuildContext ctx,
    required StateSetter setDialogState,
    required String token,
    required ProjectRow p,
    required List<bool> assetsBusy,
    required Future<void> Function() reloadAssetsAndStats,
  }) async {
    await openProjectAssetClipUploadDialog(
      ctx: ctx,
      setDialogState: setDialogState,
      token: token,
      project: p,
      assetsBusy: assetsBusy,
      reloadAssetsAndStats: reloadAssetsAndStats,
    );
  }
}
