part of '../home_page.dart';

extension _HomePageProjectEditorAssets on _HomePageState {
  Widget _buildProjectAssetsProbeSection({
    required BuildContext ctx,
    required StateSetter setDialogState,
    required String token,
    required ProjectRow p,
    required List<ScriptBrief> scriptList,
    required List<ListAssetsResponse?> assetsRef,
    required List<ListAssetsResponse?> assetsForScriptRef,
    required List<int?> assetsFilterScriptLegacyId,
    required List<bool> assetsLoading,
    required List<bool> assetsScriptFilterLoading,
    required List<bool> assetsBusy,
    required Future<void> Function() reloadAssetsAndStats,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (assetsRef[0] != null)
          Text(
            assetsRef[0]!.items.isEmpty
                ? 'GET …/assets：total=0'
                : 'GET …/assets：total=${assetsRef[0]!.total} · ${assetsRef[0]!.items.take(6).map((a) => '#${a.legacyId}:${a.assetType}').join(', ')}${assetsRef[0]!.items.length > 6 ? '…' : ''}',
            style: Theme.of(ctx).textTheme.bodySmall,
          )
        else
          Text(
            'GET …/assets 未加载',
            style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
              color: Theme.of(ctx).colorScheme.outline,
            ),
          ),
        if (assetsFilterScriptLegacyId[0] != null) ...[
          const SizedBox(height: 6),
          if (assetsScriptFilterLoading[0])
            Text(
              'GET …/assets?script_legacy_id=${assetsFilterScriptLegacyId[0]} …',
              style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                color: Theme.of(ctx).colorScheme.outline,
              ),
            )
          else if (assetsForScriptRef[0] != null)
            Text(
              assetsForScriptRef[0]!.items.isEmpty
                  ? 'GET …/assets?script_legacy_id=${assetsFilterScriptLegacyId[0]}：total=0'
                  : 'GET …/assets?script_legacy_id=${assetsFilterScriptLegacyId[0]}：total=${assetsForScriptRef[0]!.total} · ${assetsForScriptRef[0]!.items.take(6).map((a) => '#${a.legacyId}:${a.assetType}').join(', ')}${assetsForScriptRef[0]!.items.length > 6 ? '…' : ''}',
              style: Theme.of(ctx).textTheme.bodySmall,
            )
          else
            Text(
              'GET …/assets?script_legacy_id=${assetsFilterScriptLegacyId[0]} 未加载',
              style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                color: Theme.of(ctx).colorScheme.outline,
              ),
            ),
        ],
        if (scriptList.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: DropdownButton<int?>(
              value: assetsFilterScriptLegacyId[0],
              isExpanded: true,
              hint: const Text('按剧本筛选资产列表'),
              items: [
                const DropdownMenuItem<int?>(
                  value: null,
                  child: Text('（全部，不按剧本筛选）'),
                ),
                ...scriptList.map(
                  (s) => DropdownMenuItem<int?>(
                    value: s.legacyId,
                    child: Text(
                      '#${s.legacyId} ${s.name ?? ""}',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ],
              onChanged:
                  assetsBusy[0] ||
                      assetsLoading[0] ||
                      assetsScriptFilterLoading[0]
                  ? null
                  : (v) async {
                      setDialogState(() => assetsScriptFilterLoading[0] = true);
                      assetsFilterScriptLegacyId[0] = v;
                      if (v == null) {
                        assetsForScriptRef[0] = null;
                      }
                      try {
                        await reloadAssetsAndStats();
                      } finally {
                        if (ctx.mounted) {
                          setDialogState(
                            () => assetsScriptFilterLoading[0] = false,
                          );
                        }
                      }
                    },
            ),
          ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton(
            onPressed: assetsLoading[0] || assetsScriptFilterLoading[0]
                ? null
                : () async {
                    setDialogState(() => assetsLoading[0] = true);
                    try {
                      await reloadAssetsAndStats();
                    } finally {
                      if (ctx.mounted) {
                        setDialogState(() => assetsLoading[0] = false);
                      }
                    }
                  },
            child: Text(assetsLoading[0] ? '刷新资产…' : '刷新资产列表'),
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 4,
          runSpacing: 0,
          children: [
            _buildProjectAssetsImagesProbeSection(
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
            TextButton(
              onPressed:
                  assetsBusy[0] ||
                      assetsLoading[0] ||
                      assetsScriptFilterLoading[0]
                  ? null
                  : () async {
                      setDialogState(() => assetsBusy[0] = true);
                      try {
                        final ts = DateTime.now().millisecondsSinceEpoch;
                        await createProjectAssetUnderLegacy(
                          token,
                          p.legacyId,
                          name: 'role_probe_$ts',
                          type: 'role',
                        );
                        if (!ctx.mounted) return;
                        await reloadAssetsAndStats();
                        if (ctx.mounted) {
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            const SnackBar(content: Text('已 POST 测试资产')),
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
              child: const Text('POST 测试资产'),
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
                        final row = await fetchProjectAssetByLegacyIds(
                          token,
                          p.legacyId,
                          first.legacyId,
                        );
                        if (!ctx.mounted) return;
                        ScaffoldMessenger.of(ctx).showSnackBar(
                          SnackBar(
                            content: Text(
                              'GET …/assets/${first.legacyId}：${row.name} (${row.assetType})',
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
              child: const Text('GET 首条资产详情'),
            ),
            TextButton(
              onPressed:
                  assetsBusy[0] ||
                      assetsLoading[0] ||
                      assetsScriptFilterLoading[0]
                  ? null
                  : () async {
                      setDialogState(() => assetsBusy[0] = true);
                      try {
                        final page = await fetchProjectAssetsByLegacyId(
                          token,
                          p.legacyId,
                          page: 1,
                          limit: 2,
                        );
                        if (!ctx.mounted) return;
                        final ids = page.items
                            .map((a) => '#${a.legacyId}:${a.assetType}')
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
                  assetsBusy[0] ||
                      assetsLoading[0] ||
                      assetsScriptFilterLoading[0]
                  ? null
                  : () async {
                      setDialogState(() => assetsBusy[0] = true);
                      try {
                        final r = await fetchProjectAssetsByLegacyId(
                          token,
                          p.legacyId,
                          assetType: 'role',
                          name: 'probe',
                        );
                        if (!ctx.mounted) return;
                        final ids = r.items
                            .take(4)
                            .map((a) => '#${a.legacyId}:${a.name}')
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
                      assetsFilterScriptLegacyId[0] == null
                  ? null
                  : () async {
                      setDialogState(() => assetsBusy[0] = true);
                      final sid = assetsFilterScriptLegacyId[0]!;
                      try {
                        final pg = await fetchProjectAssetsByLegacyId(
                          token,
                          p.legacyId,
                          scriptLegacyId: sid,
                          page: 1,
                          limit: 2,
                        );
                        if (!ctx.mounted) return;
                        final ids = pg.items
                            .map((a) => '#${a.legacyId}:${a.assetType}')
                            .join(', ');
                        ScaffoldMessenger.of(ctx).showSnackBar(
                          SnackBar(
                            content: Text(
                              'GET …/assets?script_legacy_id=$sid&page=1&limit=2：total=${pg.total}，本页 ${pg.items.length} 条'
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
                        await patchProjectAssetByLegacyIds(
                          token,
                          p.legacyId,
                          first.legacyId,
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
              child: const Text('PATCH 首条'),
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
                        await deleteProjectAssetByLegacyIds(
                          token,
                          p.legacyId,
                          last.legacyId,
                        );
                        if (!ctx.mounted) return;
                        await reloadAssetsAndStats();
                        if (ctx.mounted) {
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            SnackBar(
                              content: Text('已 DELETE 资产 #${last.legacyId}'),
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
              child: const Text('DELETE 末条'),
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
              child: const Text('PUT 关联首剧本·首资产'),
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
              child: const Text('DELETE 取消关联'),
            ),
          ],
        ),
      ],
    );
  }
}
