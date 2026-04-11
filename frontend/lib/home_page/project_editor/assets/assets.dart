part of '../../../home_page.dart';

extension _HomePageProjectEditorAssets on _HomePageState {
  Widget _buildProjectAssetsSection({
    required BuildContext ctx,
    required StateSetter setDialogState,
    required String token,
    required ProjectRow p,
    required List<ScriptBrief> scriptList,
    required List<ListAssetsResponse?> assetsRef,
    required List<ListAssetsResponse?> assetsForScriptRef,
    required List<int?> assetsFilterScriptNumericId,
    required List<bool> assetsLoading,
    required List<bool> assetsScriptFilterLoading,
    required List<bool> assetsBusy,
    required Future<void> Function() reloadAssetsAndStats,
  }) {
    final visibleAssets = assetsRef[0]?.items ?? const <AssetRow>[];
    final assetsForScript = assetsForScriptRef[0]?.items;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (assetsRef[0] != null)
          _ProjectAssetsOverviewPanel(
            scriptList: scriptList,
            visibleAssets: visibleAssets,
            assetsForScript: assetsForScript,
            filterScriptNumericId: assetsFilterScriptNumericId[0],
            assetsLoading: assetsLoading[0],
            assetsScriptFilterLoading: assetsScriptFilterLoading[0],
            assetsBusy: assetsBusy[0],
            onFilterChanged: (value) async {
              setDialogState(() => assetsScriptFilterLoading[0] = true);
              assetsFilterScriptNumericId[0] = value;
              if (value == null) {
                assetsForScriptRef[0] = null;
              }
              try {
                await reloadAssetsAndStats();
              } finally {
                if (ctx.mounted) {
                  setDialogState(() => assetsScriptFilterLoading[0] = false);
                }
              }
            },
            onRefresh: () async {
              setDialogState(() => assetsLoading[0] = true);
              try {
                await reloadAssetsAndStats();
              } finally {
                if (ctx.mounted) {
                  setDialogState(() => assetsLoading[0] = false);
                }
              }
            },
            onOpenWorkbench: () => _openAssetWorkbenchDialog(
              ctx: ctx,
              setDialogState: setDialogState,
              token: token,
              p: p,
              scriptList: scriptList,
              assetsRef: assetsRef,
              assetsForScriptRef: assetsForScriptRef,
              assetsFilterScriptNumericId: assetsFilterScriptNumericId,
              assetsBusy: assetsBusy,
              reloadAssetsAndStats: reloadAssetsAndStats,
            ),
          )
        else
          Text(
            '资产列表尚未加载',
            style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
              color: Theme.of(ctx).colorScheme.outline,
            ),
          ),
        const SizedBox(height: 8),
        ExpansionTile(
          tilePadding: EdgeInsets.zero,
          childrenPadding: EdgeInsets.zero,
          title: const Text('兼容性检查'),
          subtitle: Text(
            '保留旧资产轮询、历史图片和 workbench 形检查入口，默认折叠',
            style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
              color: Theme.of(ctx).colorScheme.outline,
            ),
          ),
          children: [
            _buildProjectAssetsImagesCompatibilitySection(
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
            const SizedBox(height: 8),
            Wrap(
              spacing: 4,
              runSpacing: 0,
              children: [
                ..._buildProjectAssetsPrimaryActions(
                  ctx: ctx,
                  setDialogState: setDialogState,
                  token: token,
                  p: p,
                  assetsRef: assetsRef,
                  assetsFilterScriptNumericId: assetsFilterScriptNumericId,
                  assetsLoading: assetsLoading,
                  assetsScriptFilterLoading: assetsScriptFilterLoading,
                  assetsBusy: assetsBusy,
                  reloadAssetsAndStats: reloadAssetsAndStats,
                ),
                ..._buildProjectAssetsRelationActions(
                  ctx: ctx,
                  setDialogState: setDialogState,
                  token: token,
                  p: p,
                  scriptList: scriptList,
                  assetsRef: assetsRef,
                  assetsLoading: assetsLoading,
                  assetsScriptFilterLoading: assetsScriptFilterLoading,
                  assetsBusy: assetsBusy,
                  reloadAssetsAndStats: reloadAssetsAndStats,
                ),
                ..._buildProjectAssetsQueryCompatibilityActions(
                  ctx: ctx,
                  setDialogState: setDialogState,
                  token: token,
                  p: p,
                  assetsRef: assetsRef,
                  assetsFilterScriptNumericId: assetsFilterScriptNumericId,
                  assetsLoading: assetsLoading,
                  assetsScriptFilterLoading: assetsScriptFilterLoading,
                  assetsBusy: assetsBusy,
                  reloadAssetsAndStats: reloadAssetsAndStats,
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }
}
