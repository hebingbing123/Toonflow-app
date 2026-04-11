part of '../../../home_page.dart';

extension _HomePageProjectEditorNovelsLegacyActions on _HomePageState {
  List<Widget> _buildProjectLegacyNovelsProbeActions({
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
  }) {
    return [
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
                assetsScriptFilterLoading[0] ||
                novelsRef[0] == null
            ? null
            : () async {
                setDialogState(() => novelsBusy[0] = true);
                try {
                  final ids = novelsRef[0]!.items.map((e) => e.legacyId).toList();
                  final rows = await postLegacyNovelsGetNovelEventState(token, ids);
                  if (!ctx.mounted) return;
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    SnackBar(
                      content: Text(
                        'POST …/novels/get-novel-event-state：${rows.length} 条非 0 状态',
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
        child: const Text('POST get-novel-event-state'),
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
                try {
                  final ids = novelsRef[0]!.items.map((e) => e.legacyId).toList();
                  final msg = await postLegacyNovelEventsGenerateEvents(
                    token,
                    projectId: p.legacyId,
                    novelIds: ids.take(3).toList(),
                  );
                  if (!ctx.mounted) return;
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    SnackBar(
                      content: Text(
                        'POST …/novels/events/generate-events：$msg',
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
        child: const Text('POST events/generate-events'),
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
    ];
  }
}
