part of '../../../../home_page.dart';

extension _HomePageProjectEditorAssetsCrudProbe on _HomePageState {
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
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    SnackBar(
                      content: Text(
                        'GET …/assets?page=1&limit=2：total=${page.total}，本页 ${page.items.length} 条'
                        '${ids.isEmpty ? '' : ' · $ids'}',
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
        child: const Text('GET 分页 page=1&limit=2'),
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
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    SnackBar(
                      content: Text(
                        'GET …/assets?asset_type=role&name=probe：total=${r.total}，返回 ${r.items.length} 条'
                        '${ids.isEmpty ? '' : ' · $ids'}',
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
        child: const Text('GET 筛选 type+name'),
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
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    SnackBar(
                      content: Text(
                        'GET …/assets?script_numeric_id=$sid&page=1&limit=2：total=${pg.total}，本页 ${pg.items.length} 条'
                        '${ids.isEmpty ? '' : ' · $ids'}',
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
        child: const Text('GET 当前剧本+分页'),
      ),
    ];
  }
}
