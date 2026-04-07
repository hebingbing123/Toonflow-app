part of '../home_page.dart';

extension _HomePageProjectEditorNovels on _HomePageState {
  Widget _buildProjectNovelProbeSection({
    required BuildContext ctx,
    required StateSetter setDialogState,
    required String token,
    required ProjectRow p,
    required List<ListNovelsResponse?> novelsRef,
    required List<bool> novelsLoading,
    required List<bool> novelsBusy,
    required List<bool> assetsBusy,
    required List<bool> assetsLoading,
    required List<bool> assetsScriptFilterLoading,
    required Future<void> Function() reloadAssetsAndStats,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (novelsRef[0] != null)
          Text(
            novelsRef[0]!.items.isEmpty
                ? 'GET …/novels：total=0'
                : 'GET …/novels：total=${novelsRef[0]!.total} · ${novelsRef[0]!.items.take(4).map((n) => '#${n.legacyId}:${n.chapter}').join(', ')}${novelsRef[0]!.items.length > 4 ? '…' : ''}',
            style: Theme.of(ctx).textTheme.bodySmall,
          )
        else
          Text(
            'GET …/novels 未加载',
            style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
              color: Theme.of(ctx).colorScheme.outline,
            ),
          ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton(
            onPressed:
                novelsLoading[0] ||
                    assetsBusy[0] ||
                    assetsLoading[0] ||
                    assetsScriptFilterLoading[0]
                ? null
                : () async {
                    setDialogState(() => novelsLoading[0] = true);
                    try {
                      await reloadAssetsAndStats();
                    } finally {
                      if (ctx.mounted) {
                        setDialogState(() => novelsLoading[0] = false);
                      }
                    }
                  },
            child: Text(novelsLoading[0] ? '刷新小说…' : '刷新小说列表'),
          ),
        ),
        const SizedBox(height: 4),
        Wrap(
          spacing: 4,
          runSpacing: 0,
          children: [
            TextButton(
              onPressed:
                  novelsBusy[0] ||
                      novelsLoading[0] ||
                      assetsBusy[0] ||
                      assetsLoading[0] ||
                      assetsScriptFilterLoading[0]
                  ? null
                  : () async {
                      setDialogState(() => novelsBusy[0] = true);
                      try {
                        final ts = DateTime.now().millisecondsSinceEpoch;
                        await createProjectNovelUnderLegacy(
                          token,
                          p.legacyId,
                          chapter: 'novel_probe_$ts',
                        );
                        if (!ctx.mounted) return;
                        await reloadAssetsAndStats();
                        if (ctx.mounted) {
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            const SnackBar(content: Text('已 POST 测试章节')),
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
                          setDialogState(() => novelsBusy[0] = false);
                        }
                      }
                    },
              child: const Text('POST 测试章节'),
            ),
            TextButton(
              onPressed:
                  novelsBusy[0] ||
                      novelsLoading[0] ||
                      assetsBusy[0] ||
                      assetsLoading[0] ||
                      assetsScriptFilterLoading[0] ||
                      novelsRef[0] == null ||
                      novelsRef[0]!.items.isEmpty
                  ? null
                  : () async {
                      setDialogState(() => novelsBusy[0] = true);
                      final first = novelsRef[0]!.items.first;
                      try {
                        final row = await fetchProjectNovelByLegacyIds(
                          token,
                          p.legacyId,
                          first.legacyId,
                        );
                        if (!ctx.mounted) return;
                        ScaffoldMessenger.of(ctx).showSnackBar(
                          SnackBar(
                            content: Text(
                              'GET …/novels/${first.legacyId}：${row.chapter}',
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
                          setDialogState(() => novelsBusy[0] = false);
                        }
                      }
                    },
              child: const Text('GET 首条小说'),
            ),
            TextButton(
              onPressed:
                  novelsBusy[0] ||
                      novelsLoading[0] ||
                      assetsBusy[0] ||
                      assetsLoading[0] ||
                      assetsScriptFilterLoading[0]
                  ? null
                  : () async {
                      setDialogState(() => novelsBusy[0] = true);
                      try {
                        final pg = await fetchProjectNovelsByLegacyId(
                          token,
                          p.legacyId,
                          search: 'novel',
                          page: 1,
                          limit: 5,
                        );
                        if (!ctx.mounted) return;
                        ScaffoldMessenger.of(ctx).showSnackBar(
                          SnackBar(
                            content: Text(
                              'GET …/novels?search=novel&page=1&limit=5：total=${pg.total}，本页 ${pg.items.length} 条',
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
                          setDialogState(() => novelsBusy[0] = false);
                        }
                      }
                    },
              child: const Text('GET 小说 search+分页'),
            ),
            TextButton(
              onPressed:
                  novelsBusy[0] ||
                      novelsLoading[0] ||
                      assetsBusy[0] ||
                      assetsLoading[0] ||
                      assetsScriptFilterLoading[0] ||
                      novelsRef[0] == null ||
                      novelsRef[0]!.items.isEmpty
                  ? null
                  : () async {
                      setDialogState(() => novelsBusy[0] = true);
                      final first = novelsRef[0]!.items.first;
                      try {
                        await patchProjectNovelByLegacyIds(
                          token,
                          p.legacyId,
                          first.legacyId,
                          {'chapter': '${first.chapter}·patched'},
                        );
                        if (!ctx.mounted) return;
                        await reloadAssetsAndStats();
                        if (ctx.mounted) {
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            const SnackBar(content: Text('已 PATCH 首条小说 chapter')),
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
                          setDialogState(() => novelsBusy[0] = false);
                        }
                      }
                    },
              child: const Text('PATCH 首条小说'),
            ),
            TextButton(
              onPressed:
                  novelsBusy[0] ||
                      novelsLoading[0] ||
                      assetsBusy[0] ||
                      assetsLoading[0] ||
                      assetsScriptFilterLoading[0] ||
                      novelsRef[0] == null ||
                      novelsRef[0]!.items.isEmpty
                  ? null
                  : () async {
                      setDialogState(() => novelsBusy[0] = true);
                      final last = novelsRef[0]!.items.last;
                      try {
                        await deleteProjectNovelByLegacyIds(
                          token,
                          p.legacyId,
                          last.legacyId,
                        );
                        if (!ctx.mounted) return;
                        await reloadAssetsAndStats();
                        if (ctx.mounted) {
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            SnackBar(
                              content: Text('已 DELETE 末条小说 #${last.legacyId}'),
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
                          setDialogState(() => novelsBusy[0] = false);
                        }
                      }
                    },
              child: const Text('DELETE 末条小说'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Legacy POST …/novels/*（Electron 形）',
          style: Theme.of(ctx).textTheme.labelSmall?.copyWith(
            color: Theme.of(ctx).colorScheme.outline,
          ),
        ),
        Wrap(
          spacing: 4,
          runSpacing: 0,
          children: [
            TextButton(
              onPressed:
                  novelsBusy[0] ||
                      novelsLoading[0] ||
                      assetsBusy[0] ||
                      assetsLoading[0] ||
                      assetsScriptFilterLoading[0]
                  ? null
                  : () async {
                      setDialogState(() => novelsBusy[0] = true);
                      try {
                        final pg = await postLegacyNovelsGetNovel(
                          token,
                          p.legacyId,
                          page: 1,
                          limit: 10,
                        );
                        if (!ctx.mounted) return;
                        final first = pg.data.isNotEmpty ? pg.data.first : null;
                        ScaffoldMessenger.of(ctx).showSnackBar(
                          SnackBar(
                            content: Text(
                              first != null
                                  ? 'POST …/novels/get-novel：total=${pg.total} · 首行 #${first.legacyId} ${first.chapter}'
                                  : 'POST …/novels/get-novel：total=${pg.total}',
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
                          setDialogState(() => novelsBusy[0] = false);
                        }
                      }
                    },
              child: const Text('POST get-novel'),
            ),
            TextButton(
              onPressed:
                  novelsBusy[0] ||
                      novelsLoading[0] ||
                      assetsBusy[0] ||
                      assetsLoading[0] ||
                      assetsScriptFilterLoading[0]
                  ? null
                  : () async {
                      setDialogState(() => novelsBusy[0] = true);
                      try {
                        final rows = await postLegacyNovelsGetNovelData(
                          token,
                          p.legacyId,
                        );
                        if (!ctx.mounted) return;
                        ScaffoldMessenger.of(ctx).showSnackBar(
                          SnackBar(
                            content: Text(
                              'POST …/novels/get-novel-data：${rows.length} 条',
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
                          setDialogState(() => novelsBusy[0] = false);
                        }
                      }
                    },
              child: const Text('POST get-novel-data'),
            ),
            TextButton(
              onPressed:
                  novelsBusy[0] ||
                      novelsLoading[0] ||
                      assetsBusy[0] ||
                      assetsLoading[0] ||
                      assetsScriptFilterLoading[0]
                  ? null
                  : () async {
                      setDialogState(() => novelsBusy[0] = true);
                      try {
                        final idx = await postLegacyNovelsGetNovelIndex(
                          token,
                          p.legacyId,
                        );
                        if (!ctx.mounted) return;
                        ScaffoldMessenger.of(ctx).showSnackBar(
                          SnackBar(
                            content: Text(
                              'POST …/novels/get-novel-index：${idx.length} 条',
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
                          setDialogState(() => novelsBusy[0] = false);
                        }
                      }
                    },
              child: const Text('POST get-novel-index'),
            ),
            TextButton(
              onPressed:
                  novelsBusy[0] ||
                      novelsLoading[0] ||
                      assetsBusy[0] ||
                      assetsLoading[0] ||
                      assetsScriptFilterLoading[0]
                  ? null
                  : () async {
                      setDialogState(() => novelsBusy[0] = true);
                      try {
                        final msg = await postLegacyNovelsAddNovel(
                          token,
                          p.legacyId,
                          const [],
                        );
                        if (!ctx.mounted) return;
                        ScaffoldMessenger.of(ctx).showSnackBar(
                          SnackBar(
                            content: Text('POST …/novels/add-novel 空 data：$msg'),
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
                          setDialogState(() => novelsBusy[0] = false);
                        }
                      }
                    },
              child: const Text('POST add-novel []'),
            ),
            TextButton(
              onPressed:
                  novelsBusy[0] ||
                      novelsLoading[0] ||
                      assetsBusy[0] ||
                      assetsLoading[0] ||
                      assetsScriptFilterLoading[0]
                  ? null
                  : () async {
                      setDialogState(() => novelsBusy[0] = true);
                      try {
                        await postLegacyNovelsBatchDelete(token, const []);
                        if (!ctx.mounted) return;
                        ScaffoldMessenger.of(ctx).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'POST …/novels/batch-delete：unexpected 200',
                            ),
                          ),
                        );
                      } on RustApiException catch (e) {
                        if (!ctx.mounted) return;
                        if (e.statusCode == 400) {
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'POST …/novels/batch-delete [] -> 400 (expected)',
                              ),
                            ),
                          );
                        } else {
                          ScaffoldMessenger.of(
                            ctx,
                          ).showSnackBar(SnackBar(content: Text(e.toString())));
                        }
                      } finally {
                        if (ctx.mounted) {
                          setDialogState(() => novelsBusy[0] = false);
                        }
                      }
                    },
              child: const Text('POST batch-delete []'),
            ),
            TextButton(
              onPressed:
                  novelsBusy[0] ||
                      novelsLoading[0] ||
                      assetsBusy[0] ||
                      assetsLoading[0] ||
                      assetsScriptFilterLoading[0]
                  ? null
                  : () async {
                      setDialogState(() => novelsBusy[0] = true);
                      try {
                        await postLegacyNovelsDeleteNovel(token, 0);
                        if (!ctx.mounted) return;
                        ScaffoldMessenger.of(ctx).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'POST …/novels/delete-novel：unexpected 200',
                            ),
                          ),
                        );
                      } on RustApiException catch (e) {
                        if (!ctx.mounted) return;
                        if (e.statusCode == 400) {
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'POST …/novels/delete-novel id=0 -> 400 (expected)',
                              ),
                            ),
                          );
                        } else {
                          ScaffoldMessenger.of(
                            ctx,
                          ).showSnackBar(SnackBar(content: Text(e.toString())));
                        }
                      } finally {
                        if (ctx.mounted) {
                          setDialogState(() => novelsBusy[0] = false);
                        }
                      }
                    },
              child: const Text('POST delete-novel id=0'),
            ),
            TextButton(
              onPressed:
                  novelsBusy[0] ||
                      novelsLoading[0] ||
                      assetsBusy[0] ||
                      assetsLoading[0] ||
                      assetsScriptFilterLoading[0] ||
                      novelsRef[0] == null ||
                      novelsRef[0]!.items.isEmpty
                  ? null
                  : () async {
                      setDialogState(() => novelsBusy[0] = true);
                      final n = novelsRef[0]!.items.first;
                      try {
                        final msg = await postLegacyNovelsUpdateNovel(
                          token,
                          id: n.legacyId,
                          index: n.chapterIndex,
                          reel: n.reel ?? '',
                          chapter: n.chapter,
                          chapterData: n.chapterData,
                          event: n.event ?? '',
                        );
                        if (!ctx.mounted) return;
                        ScaffoldMessenger.of(ctx).showSnackBar(
                          SnackBar(
                            content: Text(
                              'POST …/novels/update-novel noop #${n.legacyId}：$msg',
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
                          setDialogState(() => novelsBusy[0] = false);
                        }
                      }
                    },
              child: const Text('POST update-novel (noop)'),
            ),
          ],
        ),
      ],
    );
  }
}
