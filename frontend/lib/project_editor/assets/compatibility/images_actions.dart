part of '../../../../home_page.dart';

extension _HomePageProjectEditorAssetsImagesProbeActions on _HomePageState {
  // Compatibility probes stay in a sibling part so this section file remains
  // focused on layout, while the compatibility subdomain owns its actions.
  List<Widget> _buildProjectAssetsImagesProbeActions({
    required BuildContext ctx,
    required StateSetter setDialogState,
    required String token,
    required ProjectRow p,
    required List<ListAssetsResponse?> assetsRef,
    required List<bool> assetsLoading,
    required List<bool> assetsScriptFilterLoading,
    required List<bool> assetsBusy,
    required Future<void> Function() reloadAssetsAndStats,
  }) {
    return [
      ..._buildProjectAssetsImagesCrudProbeActions(
        ctx: ctx,
        setDialogState: setDialogState,
        token: token,
        p: p,
        assetsRef: assetsRef,
        assetsLoading: assetsLoading,
        assetsScriptFilterLoading: assetsScriptFilterLoading,
        assetsBusy: assetsBusy,
        reloadAssetsAndStats: reloadAssetsAndStats,
      ),
      ..._buildProjectAssetsImagesWorkbenchProbeActions(
        ctx: ctx,
        setDialogState: setDialogState,
        token: token,
        p: p,
        assetsRef: assetsRef,
        assetsLoading: assetsLoading,
        assetsScriptFilterLoading: assetsScriptFilterLoading,
        assetsBusy: assetsBusy,
        reloadAssetsAndStats: reloadAssetsAndStats,
      ),
    ];
  }
}
