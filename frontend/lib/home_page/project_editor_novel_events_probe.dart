part of '../home_page.dart';

extension _HomePageProjectEditorNovelEventsProbe on _HomePageState {
  Widget _buildProjectNovelEventsProbeSection({
    required BuildContext ctx,
    required StateSetter setDialogState,
    required String token,
    required ProjectRow p,
    required List<ListNovelsResponse?> novelsRef,
    required List<ListNovelEventsResponse?> novelEventsRef,
    required List<bool> novelsLoading,
    required List<bool> novelsBusy,
    required List<bool> novelEventsLoading,
    required List<bool> assetsBusy,
    required List<bool> assetsLoading,
    required List<bool> assetsScriptFilterLoading,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (novelEventsRef[0] != null)
          Text(
            novelEventsRef[0]!.items.isEmpty
                ? 'GET …/novel-events：total=0'
                : 'GET …/novel-events：total=${novelEventsRef[0]!.total} · ${novelEventsRef[0]!.items.take(3).map((e) => '#${e.legacyId}:${e.name}').join(', ')}${novelEventsRef[0]!.items.length > 3 ? '…' : ''}',
            style: Theme.of(ctx).textTheme.bodySmall,
          )
        else
          Text(
            'GET …/novel-events 未加载',
            style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
              color: Theme.of(ctx).colorScheme.outline,
            ),
          ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton(
            onPressed:
                novelsBusy[0] ||
                    novelsLoading[0] ||
                    novelEventsLoading[0] ||
                    assetsBusy[0] ||
                    assetsLoading[0] ||
                    assetsScriptFilterLoading[0]
                ? null
                : () async {
                    setDialogState(() => novelEventsLoading[0] = true);
                    try {
                      novelEventsRef[0] = await fetchProjectNovelEventsByLegacyId(
                        token,
                        p.legacyId,
                      );
                    } on RustApiException catch (e) {
                      if (ctx.mounted) {
                        ScaffoldMessenger.of(
                          ctx,
                        ).showSnackBar(SnackBar(content: Text(e.toString())));
                      }
                    } finally {
                      if (ctx.mounted) {
                        setDialogState(() => novelEventsLoading[0] = false);
                      }
                    }
                  },
            child: Text(novelEventsLoading[0] ? '刷新事件…' : '刷新事件列表'),
          ),
        ),
        Text(
          'Novel events / outline（Rust parity）',
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
                      novelEventsLoading[0] ||
                      assetsBusy[0] ||
                      assetsLoading[0] ||
                      assetsScriptFilterLoading[0]
                  ? null
                  : () async {
                      setDialogState(() => novelsBusy[0] = true);
                      final probeName =
                          'event_probe_${DateTime.now().millisecondsSinceEpoch}';
                      final chapterIds = novelsRef[0]?.items.isNotEmpty == true
                          ? [novelsRef[0]!.items.first.legacyId]
                          : const <int>[];
                      try {
                        final created = await createProjectNovelEventUnderLegacy(
                          token,
                          p.legacyId,
                          name: probeName,
                          detail: 'flutter probe',
                          chapterIds: chapterIds,
                        );
                        final legacyId = (created['id'] as num).toInt();
                        final patchMessage =
                            await patchProjectNovelEventByLegacyIds(
                              token,
                              p.legacyId,
                              legacyId,
                              {'detail': 'flutter probe patched'},
                            );
                        final deleteMessage =
                            await deleteProjectNovelEventByLegacyIds(
                              token,
                              p.legacyId,
                              legacyId,
                            );
                        novelEventsRef[0] =
                            await fetchProjectNovelEventsByLegacyId(
                              token,
                              p.legacyId,
                            );
                        if (!ctx.mounted) return;
                        ScaffoldMessenger.of(ctx).showSnackBar(
                          SnackBar(
                            content: Text(
                              '事件 CRUD 探针完成：#$legacyId，$patchMessage，$deleteMessage',
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
              child: const Text('REST 事件 CRUD 探针'),
            ),
            TextButton(
              onPressed:
                  novelsBusy[0] ||
                      novelsLoading[0] ||
                      novelEventsLoading[0] ||
                      assetsBusy[0] ||
                      assetsLoading[0] ||
                      assetsScriptFilterLoading[0]
                  ? null
                  : () async {
                      setDialogState(() => novelsBusy[0] = true);
                      try {
                        final pg = await postLegacyNovelEventsGetEvents(
                          token,
                          p.legacyId,
                          page: 1,
                          limit: 10,
                        );
                        if (!ctx.mounted) return;
                        final first = pg.list.isNotEmpty ? pg.list.first : null;
                        ScaffoldMessenger.of(ctx).showSnackBar(
                          SnackBar(
                            content: Text(
                              first != null
                                  ? 'POST …/novels/events/get-events：total=${pg.total} · 首条 #${first.legacyId} ${first.eventName}'
                                  : 'POST …/novels/events/get-events：total=${pg.total}',
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
              child: const Text('POST events/get-events'),
            ),
            TextButton(
              onPressed:
                  novelsBusy[0] ||
                      novelsLoading[0] ||
                      novelEventsLoading[0] ||
                      assetsBusy[0] ||
                      assetsLoading[0] ||
                      assetsScriptFilterLoading[0]
                  ? null
                  : () async {
                      setDialogState(() => novelsBusy[0] = true);
                      try {
                        await postLegacyNovelEventsBatchDelete(token, const []);
                        if (!ctx.mounted) return;
                        ScaffoldMessenger.of(ctx).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'POST …/novels/events/batch-delete：unexpected 200',
                            ),
                          ),
                        );
                      } on RustApiException catch (e) {
                        if (!ctx.mounted) return;
                        if (e.statusCode == 400) {
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'POST …/novels/events/batch-delete [] -> 400 (expected)',
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
              child: const Text('POST events/batch-delete []'),
            ),
          ],
        ),
      ],
    );
  }
}
