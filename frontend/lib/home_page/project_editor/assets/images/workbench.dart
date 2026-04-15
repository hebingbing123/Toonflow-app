part of '../../../../home_page.dart';

extension _HomePageProjectEditorAssetsImagesWorkbench on _HomePageState {
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
    await openAssetImagesWorkbenchDialog(
      ctx: ctx,
      setDialogState: setDialogState,
      token: token,
      project: p,
      assetsRef: assetsRef,
      assetsBusy: assetsBusy,
      reloadAssetsAndStats: reloadAssetsAndStats,
      preferredAssetNumericId: preferredAssetNumericId,
    );
  }
}
