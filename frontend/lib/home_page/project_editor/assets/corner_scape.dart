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
    await openCornerScapeWorkbenchDialog(
      ctx: ctx,
      setDialogState: setDialogState,
      token: token,
      project: p,
      assetsBusy: assetsBusy,
      preferredAssetNumericId: preferredAssetNumericId,
    );
  }
}
