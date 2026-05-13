part of '../../../../home_page.dart';

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
    final l10n = AppLocalizations.of(ctx)!;
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
                final sid = scriptList.first.numericId;
                final aid = assetsRef[0]!.items.first.numericId;
                try {
                  await linkScriptToAssetByProjectIds(
                    token,
                    p.id,
                    sid,
                    aid,
                  );
                  if (!ctx.mounted) return;
                  await reloadAssetsAndStats();
                  if (ctx.mounted) {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      SnackBar(
                        content: Text(l10n.projectEditorAssetLinkSuccessLinked(sid, aid)),
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
        child: Text(l10n.projectEditorAssetsProbeLinkFirstPairButton),
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
                final sid = scriptList.first.numericId;
                final aid = assetsRef[0]!.items.first.numericId;
                try {
                  await unlinkScriptFromAssetByProjectIds(
                    token,
                    p.id,
                    sid,
                    aid,
                  );
                  if (!ctx.mounted) return;
                  await reloadAssetsAndStats();
                  if (ctx.mounted) {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      SnackBar(
                        content: Text(l10n.projectEditorAssetLinkSuccessUnlinked(sid, aid)),
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
        child: Text(l10n.projectEditorAssetsProbeUnlinkFirstPairButton),
      ),
    ];
  }
}
