part of '../../../../home_page.dart';

extension _HomePageProjectEditorAssetsGenerationWorkbench on _HomePageState {
  Future<void> _openAssetGenerationWorkbenchDialog({
    required BuildContext ctx,
    required StateSetter setDialogState,
    required String token,
    required ProjectRow p,
    required List<ScriptBrief> scriptList,
    required List<ListAssetsResponse?> assetsRef,
    required List<ListAssetsResponse?> assetsForScriptRef,
    required List<int?> assetsFilterScriptNumericId,
    required List<bool> assetsBusy,
    required Future<void> Function() reloadAssetsAndStats,
    int? preferredAssetNumericId,
  }) async {
    await openAssetGenerationWorkbenchDialog(
      ctx: ctx,
      setDialogState: setDialogState,
      token: token,
      project: p,
      scriptList: scriptList,
      assetsRef: assetsRef,
      assetsForScriptRef: assetsForScriptRef,
      assetsFilterScriptNumericId: assetsFilterScriptNumericId,
      assetsBusy: assetsBusy,
      reloadAssetsAndStats: reloadAssetsAndStats,
      preferredAssetNumericId: preferredAssetNumericId,
    );
  }
}
