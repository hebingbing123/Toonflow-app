part of '../../../../home_page.dart';

extension _HomePageProjectEditorAssetsCrudQueryProbe on _HomePageState {
  List<Widget> _buildProjectAssetsQueryCompatibilityActions({
    required BuildContext ctx,
    required StateSetter setDialogState,
    required String token,
    required ProjectRow p,
    required List<ListAssetsResponse?> assetsRef,
    required List<int?> assetsFilterScriptNumericId,
    required List<bool> assetsLoading,
    required List<bool> assetsScriptFilterLoading,
    required List<bool> assetsBusy,
    required Future<void> Function() reloadAssetsAndStats,
  }) {
    final l10n = resolveAppLocalizationsForErrors(ctx);
    return [
      TextButton(
        onPressed:
            assetsBusy[0] || assetsLoading[0] || assetsScriptFilterLoading[0]
            ? null
            : () async {
                setDialogState(() => assetsBusy[0] = true);
                try {
                  final page = await fetchProjectAssetsByProjectId(
                    token,
                    p.id,
                    page: 1,
                    limit: 2,
                  );
                  if (!ctx.mounted) return;
                  final ids = page.items
                      .map((a) => '#${a.numericId}:${a.assetType}')
                      .join(', ');
                  final idPart = ids.isEmpty ? '' : ' · $ids';
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    SnackBar(
                      content: Text(
                        l10n.projectEditorAssetsProbeQueryPageSnack(
                          page.total,
                          page.items.length,
                          idPart,
                        ),
                      ),
                    ),
                  );
                } catch (e) {
                  if (ctx.mounted) {
                    ScaffoldMessenger.of(
                      ctx,
                    ).showSnackBar(SnackBar(content: Text(describeUserVisibleApiErrorResolved(ctx, e))));
                  }
                } finally {
                  if (ctx.mounted) {
                    setDialogState(() => assetsBusy[0] = false);
                  }
                }
              },
        child: Text(l10n.projectEditorAssetsProbeQueryPageButton),
      ),
      TextButton(
        onPressed:
            assetsBusy[0] || assetsLoading[0] || assetsScriptFilterLoading[0]
            ? null
            : () async {
                setDialogState(() => assetsBusy[0] = true);
                try {
                  final r = await fetchProjectAssetsByProjectId(
                    token,
                    p.id,
                    assetType: 'role',
                    name: 'probe',
                  );
                  if (!ctx.mounted) return;
                  final ids = r.items
                      .take(4)
                      .map((a) => '#${a.numericId}:${a.name}')
                      .join(', ');
                  final idPart = ids.isEmpty ? '' : ' · $ids';
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    SnackBar(
                      content: Text(
                        l10n.projectEditorAssetsProbeQueryFilterSnack(
                          r.total,
                          r.items.length,
                          idPart,
                        ),
                      ),
                    ),
                  );
                } catch (e) {
                  if (ctx.mounted) {
                    ScaffoldMessenger.of(
                      ctx,
                    ).showSnackBar(SnackBar(content: Text(describeUserVisibleApiErrorResolved(ctx, e))));
                  }
                } finally {
                  if (ctx.mounted) {
                    setDialogState(() => assetsBusy[0] = false);
                  }
                }
              },
        child: Text(l10n.projectEditorAssetsProbeQueryFilterButton),
      ),
      TextButton(
        onPressed:
            assetsBusy[0] ||
                assetsLoading[0] ||
                assetsScriptFilterLoading[0] ||
                assetsFilterScriptNumericId[0] == null
            ? null
            : () async {
                setDialogState(() => assetsBusy[0] = true);
                final sid = assetsFilterScriptNumericId[0]!;
                try {
                  final pg = await fetchProjectAssetsByProjectId(
                    token,
                    p.id,
                    scriptNumericId: sid,
                    page: 1,
                    limit: 2,
                  );
                  if (!ctx.mounted) return;
                  final ids = pg.items
                      .map((a) => '#${a.numericId}:${a.assetType}')
                      .join(', ');
                  final idPart = ids.isEmpty ? '' : ' · $ids';
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    SnackBar(
                      content: Text(
                        l10n.projectEditorAssetsProbeQueryScriptSnack(
                          sid,
                          pg.total,
                          pg.items.length,
                          idPart,
                        ),
                      ),
                    ),
                  );
                } catch (e) {
                  if (ctx.mounted) {
                    ScaffoldMessenger.of(
                      ctx,
                    ).showSnackBar(SnackBar(content: Text(describeUserVisibleApiErrorResolved(ctx, e))));
                  }
                } finally {
                  if (ctx.mounted) {
                    setDialogState(() => assetsBusy[0] = false);
                  }
                }
              },
        child: Text(l10n.projectEditorAssetsProbeQueryScriptScopedButton),
      ),
    ];
  }
}
