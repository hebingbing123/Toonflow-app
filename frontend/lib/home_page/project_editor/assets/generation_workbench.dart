part of '../../../home_page.dart';

extension _HomePageProjectEditorAssetsGenerationWorkbench on _HomePageState {
  Future<void> _openAssetGenerationWorkbenchDialog({
    required BuildContext ctx,
    required StateSetter setDialogState,
    required String token,
    required ProjectRow p,
    required List<ScriptBrief> scriptList,
    required List<ListAssetsResponse?> assetsRef,
    required List<ListAssetsResponse?> assetsForScriptRef,
    required List<int?> assetsFilterScriptLegacyId,
    required List<bool> assetsBusy,
    required Future<void> Function() reloadAssetsAndStats,
    int? preferredAssetLegacyId,
  }) async {
    List<AssetRow> visibleAssets() {
      final filtered = assetsFilterScriptLegacyId[0] == null
          ? null
          : assetsForScriptRef[0];
      return (filtered ?? assetsRef[0])?.items ?? const <AssetRow>[];
    }

    final seededAssets = visibleAssets();
    if (seededAssets.isEmpty) {
      ScaffoldMessenger.of(
        ctx,
      ).showSnackBar(const SnackBar(content: Text('请先加载资产列表再打开出图工作台')));
      return;
    }
    if (scriptList.isEmpty) {
      ScaffoldMessenger.of(
        ctx,
      ).showSnackBar(const SnackBar(content: Text('请先创建剧本再发起资产出图')));
      return;
    }

    final initialFocusedAssetLegacyId = chooseInitialAssetLegacyId(
      seededAssets,
      preferredLegacyId: preferredAssetLegacyId,
    );
    final initialSelectedIds = chooseVisibleAssetSelection(
      seededAssets,
      preferredLegacyId: initialFocusedAssetLegacyId,
    );

    await showDialog<void>(
      context: ctx,
      builder: (dialogCtx) {
        return _AssetGenerationWorkbenchDialog(
          token: token,
          project: p,
          scriptList: scriptList,
          visibleAssets: visibleAssets,
          assetsFilterScriptLegacyId: assetsFilterScriptLegacyId,
          initialSelectedIds: initialSelectedIds,
          initialFocusedAssetLegacyId: initialFocusedAssetLegacyId,
          initialScriptLegacyId:
              assetsFilterScriptLegacyId[0] ?? scriptList.first.legacyId,
          onMutationStart: () => setDialogState(() => assetsBusy[0] = true),
          onMutationEnd: () {
            if (ctx.mounted) setDialogState(() => assetsBusy[0] = false);
          },
          reloadAssetsAndStats: reloadAssetsAndStats,
        );
      },
    );
  }
}
