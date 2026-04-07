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
            TextButton(
              onPressed:
                  assetsBusy[0] ||
                      assetsLoading[0] ||
                      assetsScriptFilterLoading[0]
                  ? null
                  : () async {
                      setDialogState(() => assetsBusy[0] = true);
                      try {
                        final r = await fetchCornerScapeAssetsByLegacyId(
                          token,
                          p.legacyId,
                        );
                        Uint8List? cornerThumb;
                        if (r.items.isNotEmpty &&
                            r.items.first.historyImages.isNotEmpty) {
                          final a = r.items.first;
                          cornerThumb =
                              await fetchCornerScapeHistoryImagePreviewBytes(
                                token,
                                p.legacyId,
                                a.legacyId,
                                a.historyImages.first,
                              );
                        }
                        if (!ctx.mounted) return;
                        final h0 = r.items.isEmpty
                            ? 0
                            : r.items.first.historyImages.length;
                        ScaffoldMessenger.of(ctx).showSnackBar(
                          SnackBar(
                            duration: const Duration(seconds: 6),
                            content: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (cornerThumb != null) ...[
                                  SizedBox(
                                    width: 56,
                                    height: 56,
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(4),
                                      child: Image.memory(
                                        cornerThumb,
                                        fit: BoxFit.cover,
                                        gaplessPlayback: true,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                ],
                                Expanded(
                                  child: Text(
                                    'POST …/assets/corner-scape：'
                                    '${r.items.length} 条'
                                    '${r.items.isEmpty ? "" : "，首条 history_images=$h0"}'
                                    '${cornerThumb == null ? "" : "（预览）"}',
                                  ),
                                ),
                              ],
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
              child: const Text('POST corner-scape'),
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
                        final ts = DateTime.now().millisecondsSinceEpoch;
                        final row = await createProjectAssetImage(
                          token,
                          p.legacyId,
                          first.legacyId,
                          filePath: 'probe/hist_$ts.png',
                        );
                        if (!ctx.mounted) return;
                        ScaffoldMessenger.of(ctx).showSnackBar(
                          SnackBar(
                            content: Text(
                              'POST …/assets/${first.legacyId}/images：${row.id.substring(0, 8)}…',
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
              child: const Text('POST 首条资产图片'),
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
                        final list = await fetchProjectAssetImagesByLegacyIds(
                          token,
                          p.legacyId,
                          first.legacyId,
                        );
                        if (list.items.isEmpty) {
                          if (!ctx.mounted) return;
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'GET …/images：0 条，可先点「POST 首条资产图片」',
                              ),
                            ),
                          );
                          return;
                        }
                        final img = list.items.first;
                        final one = await fetchProjectAssetImageByLegacyIds(
                          token,
                          p.legacyId,
                          first.legacyId,
                          img.id,
                        );
                        var fileSuffix = '';
                        try {
                          final bytes =
                              await fetchProjectAssetImageFileByLegacyIds(
                                token,
                                p.legacyId,
                                first.legacyId,
                                one.id,
                              );
                          fileSuffix = ' …/file ${bytes.length}B';
                        } on RustApiException catch (fe) {
                          fileSuffix = ' …/file ${fe.statusCode ?? "?"}';
                        }
                        if (!ctx.mounted) return;
                        final idShort = one.id.length <= 8
                            ? one.id
                            : '${one.id.substring(0, 8)}…';
                        ScaffoldMessenger.of(ctx).showSnackBar(
                          SnackBar(
                            content: Text(
                              'GET …/images/$idShort：sort=${one.sortIndex} '
                              'state=${one.state ?? "-"}$fileSuffix',
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
              child: const Text('GET 资产图片(单条)'),
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
                        final ts = DateTime.now().millisecondsSinceEpoch;
                        final row = await createProjectAssetImage(
                          token,
                          p.legacyId,
                          first.legacyId,
                          filePath: 'probe/patch_del_$ts.png',
                        );
                        final patched =
                            await patchProjectAssetImageByLegacyIds(
                              token,
                              p.legacyId,
                              first.legacyId,
                              row.id,
                              {
                                'state': '已完成',
                                'sort_index': row.sortIndex + 1,
                              },
                            );
                        await deleteProjectAssetImageByLegacyIds(
                          token,
                          p.legacyId,
                          first.legacyId,
                          row.id,
                        );
                        if (!ctx.mounted) return;
                        await reloadAssetsAndStats();
                        if (!ctx.mounted) return;
                        ScaffoldMessenger.of(ctx).showSnackBar(
                          SnackBar(
                            content: Text(
                              'POST→PATCH→DEL 资产图片：sort ${row.sortIndex}→${patched.sortIndex} '
                              'state=${patched.state ?? "-"} 已删',
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
              child: const Text('POST→PATCH→DEL 图'),
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
