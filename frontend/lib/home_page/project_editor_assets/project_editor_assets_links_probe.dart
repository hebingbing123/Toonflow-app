part of '../../home_page.dart';

extension _HomePageProjectEditorAssetsLinksProbe on _HomePageState {
  List<Widget> _buildProjectAssetsRelationActions({
    required BuildContext ctx,
    required StateSetter setDialogState,
    required String token,
    required ProjectRow p,
    required List<ScriptBrief> scriptList,
    required List<ListAssetsResponse?> assetsRef,
    required List<bool> assetsLoading,
    required List<bool> assetsScriptFilterLoading,
    required List<bool> assetsBusy,
    required Future<void> Function() reloadAssetsAndStats,
  }) {
    return [
      TextButton(
        onPressed:
            assetsBusy[0] ||
                assetsLoading[0] ||
                assetsScriptFilterLoading[0] ||
                scriptList.isEmpty ||
                assetsRef[0] == null ||
                assetsRef[0]!.items.isEmpty
            ? null
            : () async {
                setDialogState(() => assetsBusy[0] = true);
                final sid = scriptList.first.legacyId;
                final aid = assetsRef[0]!.items.first.legacyId;
                try {
                  await linkScriptToAssetByLegacyIds(
                    token,
                    p.legacyId,
                    sid,
                    aid,
                  );
                  if (!ctx.mounted) return;
                  await reloadAssetsAndStats();
                  if (ctx.mounted) {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      SnackBar(
                        content: Text('已 PUT 关联 script#$sid · asset#$aid'),
                      ),
                    );
                  }
                } on RustApiException catch (e) {
                  if (ctx.mounted) {
                    ScaffoldMessenger.of(
                      ctx,
                    ).showSnackBar(SnackBar(content: Text(e.toString())));
                  }
                } finally {
                  if (ctx.mounted) {
                    setDialogState(() => assetsBusy[0] = false);
                  }
                }
              },
        child: const Text('关联首剧本与首资产'),
      ),
      TextButton(
        onPressed:
            assetsBusy[0] ||
                assetsLoading[0] ||
                assetsScriptFilterLoading[0] ||
                scriptList.isEmpty ||
                assetsRef[0] == null ||
                assetsRef[0]!.items.isEmpty
            ? null
            : () async {
                setDialogState(() => assetsBusy[0] = true);
                final sid = scriptList.first.legacyId;
                final aid = assetsRef[0]!.items.first.legacyId;
                try {
                  await unlinkScriptFromAssetByLegacyIds(
                    token,
                    p.legacyId,
                    sid,
                    aid,
                  );
                  if (!ctx.mounted) return;
                  await reloadAssetsAndStats();
                  if (ctx.mounted) {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      const SnackBar(content: Text('已 DELETE 剧本–资产关联')),
                    );
                  }
                } on RustApiException catch (e) {
                  if (ctx.mounted) {
                    ScaffoldMessenger.of(
                      ctx,
                    ).showSnackBar(SnackBar(content: Text(e.toString())));
                  }
                } finally {
                  if (ctx.mounted) {
                    setDialogState(() => assetsBusy[0] = false);
                  }
                }
              },
        child: const Text('取消首条关联'),
      ),
    ];
  }
}
