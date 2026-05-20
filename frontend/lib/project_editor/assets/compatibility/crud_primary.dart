// ignore_for_file: unused_element
part of '../../../home_page.dart';

extension _HomePageProjectEditorAssetsCrudPrimaryProbe on _HomePageState {
  List<Widget> _buildProjectAssetsPrimaryActions({
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
                  final ts = DateTime.now().millisecondsSinceEpoch;
                  await createProjectAssetUnderProject(
                    token,
                    p.id,
                    name: 'role_probe_$ts',
                    type: 'role',
                  );
                  if (!ctx.mounted) return;
                  await reloadAssetsAndStats();
                  if (ctx.mounted) {
                    ScaffoldMessenger.of(
                      ctx,
                    ).showSnackBar(SnackBar(content: Text(l10n.projectEditorAssetsProbeCreateTestAssetSnack)));
                  }
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
        child: Text(l10n.projectEditorAssetsProbeCreateTestAssetButton),
      ),
      TextButton(
        onPressed:
            assetsBusy[0] ||
                assetsLoading[0] ||
                assetsScriptFilterLoading[0] ||
                assetsRef[0] == null ||
                assetsRef[0]!.items.isEmpty
            ? null
            : () async {
                setDialogState(() => assetsBusy[0] = true);
                final first = assetsRef[0]!.items.first;
                try {
                  final row = await fetchProjectAssetByProjectIds(
                    token,
                    p.id,
                    first.numericId,
                  );
                  if (!ctx.mounted) return;
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    SnackBar(
                      content: Text(
                        l10n.projectEditorAssetsProbeFetchFirstAssetSnack(
                          first.numericId,
                          row.name,
                          row.assetType,
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
        child: Text(l10n.projectEditorAssetsProbeFetchFirstAssetButton),
      ),
      TextButton(
        onPressed:
            assetsBusy[0] ||
                assetsLoading[0] ||
                assetsScriptFilterLoading[0] ||
                assetsRef[0] == null ||
                assetsRef[0]!.items.isEmpty
            ? null
            : () async {
                setDialogState(() => assetsBusy[0] = true);
                final first = assetsRef[0]!.items.first;
                try {
                  await patchProjectAssetByProjectIds(
                    token,
                    p.id,
                    first.numericId,
                    {'name': '${first.name}·patched'},
                  );
                  if (!ctx.mounted) return;
                  await reloadAssetsAndStats();
                  if (ctx.mounted) {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      SnackBar(content: Text(l10n.projectEditorAssetsProbePatchFirstNameSnack)),
                    );
                  }
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
        child: Text(l10n.projectEditorAssetsProbePatchFirstNameButton),
      ),
      TextButton(
        onPressed:
            assetsBusy[0] ||
                assetsLoading[0] ||
                assetsScriptFilterLoading[0] ||
                assetsRef[0] == null ||
                assetsRef[0]!.items.isEmpty
            ? null
            : () async {
                setDialogState(() => assetsBusy[0] = true);
                final last = assetsRef[0]!.items.last;
                try {
                  await deleteProjectAssetByProjectIds(
                    token,
                    p.id,
                    last.numericId,
                  );
                  if (!ctx.mounted) return;
                  await reloadAssetsAndStats();
                  if (ctx.mounted) {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      SnackBar(
                        content: Text(l10n.projectEditorAssetDeleteSuccessSnack(last.numericId)),
                      ),
                    );
                  }
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
        child: Text(l10n.projectEditorAssetsProbeDeleteLastAssetButton),
      ),
    ];
  }
}
