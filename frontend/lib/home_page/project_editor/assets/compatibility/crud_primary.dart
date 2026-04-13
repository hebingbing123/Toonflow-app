part of '../../../../home_page.dart';

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
                    ).showSnackBar(const SnackBar(content: Text('已新增测试资产')));
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
        child: const Text('新增资产'),
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
                        '已读取资产 #${first.numericId}：${row.name} (${row.assetType})',
                      ),
                    ),
                  );
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
        child: const Text('查看首条资产'),
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
                      const SnackBar(content: Text('已 PATCH 首条资产名称')),
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
        child: const Text('更新首条资产'),
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
                      SnackBar(content: Text('已 DELETE 资产 #${last.numericId}')),
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
        child: const Text('删除末条资产'),
      ),
    ];
  }
}
