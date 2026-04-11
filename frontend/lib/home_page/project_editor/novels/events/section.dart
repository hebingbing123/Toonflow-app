part of '../../../../home_page.dart';

extension _HomePageProjectEditorNovelEventsWorkbench on _HomePageState {
  Widget _buildProjectNovelEventsWorkbenchSection({
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
    final events = novelEventsRef[0]?.items ?? const <NovelEventRow>[];
    final first = events.isNotEmpty ? events.first : null;
    final summaryLine = summarizeNovelEventRows(events);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(ctx).colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(12),
        color: Theme.of(
          ctx,
        ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('事件工作台', style: Theme.of(ctx).textTheme.titleSmall),
          const SizedBox(height: 4),
          Text(
            first == null
                ? '用显式表单管理事件搜索、创建、更新、删除和批量删除，减少对 legacy probe 按钮的依赖。'
                : '$summaryLine；首条 #${first.legacyId} ${first.name}。',
            style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
              color: Theme.of(ctx).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.tonal(
                onPressed:
                    novelsBusy[0] ||
                        novelsLoading[0] ||
                        novelEventsLoading[0] ||
                        assetsBusy[0] ||
                        assetsLoading[0] ||
                        assetsScriptFilterLoading[0]
                    ? null
                    : () => _openNovelEventsWorkbenchDialog(
                        ctx: ctx,
                        setDialogState: setDialogState,
                        token: token,
                        p: p,
                        novelsRef: novelsRef,
                        novelEventsRef: novelEventsRef,
                        novelsBusy: novelsBusy,
                        novelEventsLoading: novelEventsLoading,
                      ),
                child: const Text('打开事件工作台'),
              ),
              OutlinedButton(
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
                          novelEventsRef[0] =
                              await fetchProjectNovelEventsByLegacyId(
                                token,
                                p.legacyId,
                              );
                        } on RustApiException catch (e) {
                          if (ctx.mounted) {
                            ScaffoldMessenger.of(ctx).showSnackBar(
                              SnackBar(content: Text(e.toString())),
                            );
                          }
                        } finally {
                          if (ctx.mounted) {
                            setDialogState(() => novelEventsLoading[0] = false);
                          }
                        }
                      },
                child: Text(novelEventsLoading[0] ? '刷新事件…' : '刷新事件'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _openNovelEventsWorkbenchDialog({
    required BuildContext ctx,
    required StateSetter setDialogState,
    required String token,
    required ProjectRow p,
    required List<ListNovelsResponse?> novelsRef,
    required List<ListNovelEventsResponse?> novelEventsRef,
    required List<bool> novelsBusy,
    required List<bool> novelEventsLoading,
  }) async {
    final chapters = novelsRef[0]?.items ?? const <NovelRow>[];
    final events = novelEventsRef[0]?.items ?? const <NovelEventRow>[];
    final firstEvent = events.isNotEmpty ? events.first : null;
    final searchCtrl = TextEditingController();
    final createNameCtrl = TextEditingController(
      text: '事件_${DateTime.now().millisecondsSinceEpoch}',
    );
    final createDetailCtrl = TextEditingController(text: '在这里描述事件。');
    final createChapterIdsCtrl = TextEditingController(
      text: chapters.take(2).map((e) => e.legacyId).join(','),
    );
    final selectedEventIdCtrl = TextEditingController(
      text: firstEvent?.legacyId.toString() ?? '',
    );
    final patchNameCtrl = TextEditingController(text: firstEvent?.name ?? '');
    final patchDetailCtrl = TextEditingController(
      text: firstEvent?.detail ?? '',
    );
    final patchChapterIdsCtrl = TextEditingController(
      text: _chapterIndexesToLegacyIds(
        chapters: chapters,
        indexes: firstEvent?.chapterIndexes ?? const <int>[],
      ).join(','),
    );
    final batchDeleteIdsCtrl = TextEditingController(
      text: events.take(3).map((e) => e.legacyId).join(','),
    );

    List<NovelEventRow> previewRows = List<NovelEventRow>.from(events.take(6));
    String infoLine = events.isEmpty
        ? '当前项目还没有事件。'
        : '已载入 ${events.length} 条事件。';
    bool localBusy = false;

    Future<void> refreshWorkbench(StateSetter setLocalState) async {
      setDialogState(() => novelEventsLoading[0] = true);
      try {
        novelEventsRef[0] = await fetchProjectNovelEventsByLegacyId(
          token,
          p.legacyId,
        );
      } finally {
        if (ctx.mounted) {
          setDialogState(() => novelEventsLoading[0] = false);
        }
      }
      final refreshed = novelEventsRef[0]?.items ?? const <NovelEventRow>[];
      setLocalState(() {
        previewRows = List<NovelEventRow>.from(refreshed.take(6));
        infoLine = refreshed.isEmpty
            ? '事件列表为空。'
            : '已刷新，共 ${refreshed.length} 条事件。';
        if (selectedEventIdCtrl.text.trim().isEmpty && refreshed.isNotEmpty) {
          final row = refreshed.first;
          selectedEventIdCtrl.text = row.legacyId.toString();
          patchNameCtrl.text = row.name;
          patchDetailCtrl.text = row.detail;
          patchChapterIdsCtrl.text = _chapterIndexesToLegacyIds(
            chapters: novelsRef[0]?.items ?? const <NovelRow>[],
            indexes: row.chapterIndexes,
          ).join(',');
        }
        if (batchDeleteIdsCtrl.text.trim().isEmpty && refreshed.isNotEmpty) {
          batchDeleteIdsCtrl.text = refreshed
              .take(3)
              .map((e) => e.legacyId)
              .join(',');
        }
      });
    }

    try {
      await showDialog<void>(
        context: ctx,
        builder: (dialogCtx) {
          return StatefulBuilder(
            builder: (dialogCtx, setLocalState) {
              Future<void> runAction(Future<void> Function() action) async {
                setLocalState(() => localBusy = true);
                setDialogState(() => novelsBusy[0] = true);
                try {
                  await action();
                } on RustApiException catch (e) {
                  if (ctx.mounted) {
                    ScaffoldMessenger.of(
                      ctx,
                    ).showSnackBar(SnackBar(content: Text('$e')));
                  }
                } catch (e) {
                  if (ctx.mounted) {
                    ScaffoldMessenger.of(
                      ctx,
                    ).showSnackBar(SnackBar(content: Text('$e')));
                  }
                } finally {
                  if (ctx.mounted) {
                    setDialogState(() => novelsBusy[0] = false);
                  }
                  setLocalState(() => localBusy = false);
                }
              }

              return AlertDialog(
                title: const Text('事件工作台'),
                content: SizedBox(
                  width: 760,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          infoLine,
                          style: Theme.of(dialogCtx).textTheme.bodySmall,
                        ),
                        const SizedBox(height: 8),
                        if (previewRows.isNotEmpty)
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: Theme.of(
                                  dialogCtx,
                                ).colorScheme.outlineVariant,
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '当前事件预览',
                                  style: Theme.of(
                                    dialogCtx,
                                  ).textTheme.labelLarge,
                                ),
                                const SizedBox(height: 8),
                                ...previewRows.map(
                                  (row) => Padding(
                                    padding: const EdgeInsets.only(bottom: 6),
                                    child: Text(
                                      '#${row.legacyId} · ${row.name} · 章节索引 ${row.chapterIndexes.join('/')}',
                                      style: Theme.of(
                                        dialogCtx,
                                      ).textTheme.bodySmall,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: searchCtrl,
                          decoration: const InputDecoration(
                            labelText: '搜索事件关键字',
                            helperText: '同时调用 REST 和 legacy get-events 搜索',
                          ),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            FilledButton.tonal(
                              onPressed: localBusy
                                  ? null
                                  : () => runAction(() async {
                                      final rows =
                                          await fetchProjectNovelEventsByLegacyId(
                                            token,
                                            p.legacyId,
                                            search: searchCtrl.text.trim(),
                                            page: 1,
                                            limit: 10,
                                          );
                                      final legacy =
                                          await postLegacyNovelEventsGetEvents(
                                            token,
                                            p.legacyId,
                                            page: 1,
                                            limit: 10,
                                            search: searchCtrl.text.trim(),
                                          );
                                      setLocalState(() {
                                        previewRows = List<NovelEventRow>.from(
                                          rows.items,
                                        );
                                        infoLine =
                                            'REST 命中 ${rows.total} 条，legacy 命中 ${legacy.total} 条。';
                                      });
                                    }),
                              child: const Text('搜索事件'),
                            ),
                            OutlinedButton(
                              onPressed: localBusy
                                  ? null
                                  : () => runAction(() async {
                                      await refreshWorkbench(setLocalState);
                                    }),
                              child: const Text('刷新列表'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          '新增事件',
                          style: Theme.of(dialogCtx).textTheme.labelLarge,
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: createNameCtrl,
                          decoration: const InputDecoration(labelText: '事件名称'),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: createDetailCtrl,
                          minLines: 3,
                          maxLines: 5,
                          decoration: const InputDecoration(labelText: '事件描述'),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: createChapterIdsCtrl,
                          decoration: const InputDecoration(
                            labelText: '关联章节 IDs',
                            helperText: '用逗号分隔，按章节 legacy id 填写',
                          ),
                        ),
                        const SizedBox(height: 8),
                        FilledButton(
                          onPressed: localBusy
                              ? null
                              : () => runAction(() async {
                                  final created =
                                      await createProjectNovelEventUnderLegacy(
                                        token,
                                        p.legacyId,
                                        name: createNameCtrl.text.trim(),
                                        detail: createDetailCtrl.text.trim(),
                                        chapterIds: _parseLegacyIdList(
                                          createChapterIdsCtrl.text,
                                        ),
                                      );
                                  await refreshWorkbench(setLocalState);
                                  setLocalState(() {
                                    final legacyId = (created['id'] as num?)
                                        ?.toInt();
                                    infoLine = legacyId == null
                                        ? '已新增事件。'
                                        : '已新增事件 #$legacyId。';
                                    if (legacyId != null) {
                                      selectedEventIdCtrl.text = legacyId
                                          .toString();
                                    }
                                    patchNameCtrl.text = createNameCtrl.text
                                        .trim();
                                    patchDetailCtrl.text = createDetailCtrl.text
                                        .trim();
                                    patchChapterIdsCtrl.text =
                                        createChapterIdsCtrl.text.trim();
                                  });
                                }),
                          child: const Text('新增事件'),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          '更新事件',
                          style: Theme.of(dialogCtx).textTheme.labelLarge,
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: selectedEventIdCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: '事件 legacy id',
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: patchNameCtrl,
                          decoration: const InputDecoration(
                            labelText: '更新后的事件名称',
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: patchDetailCtrl,
                          minLines: 3,
                          maxLines: 5,
                          decoration: const InputDecoration(
                            labelText: '更新后的事件描述',
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: patchChapterIdsCtrl,
                          decoration: const InputDecoration(
                            labelText: '更新后的章节 IDs',
                            helperText: '按章节 legacy id 填写；内部会映射为 chapterIds',
                          ),
                        ),
                        const SizedBox(height: 8),
                        FilledButton.tonal(
                          onPressed: localBusy
                              ? null
                              : () => runAction(() async {
                                  final eventId = int.parse(
                                    selectedEventIdCtrl.text.trim(),
                                  );
                                  final message =
                                      await patchProjectNovelEventByLegacyIds(
                                        token,
                                        p.legacyId,
                                        eventId,
                                        {
                                          'name': patchNameCtrl.text.trim(),
                                          'detail': patchDetailCtrl.text.trim(),
                                          'chapterIds': _parseLegacyIdList(
                                            patchChapterIdsCtrl.text,
                                          ),
                                        },
                                      );
                                  await refreshWorkbench(setLocalState);
                                  setLocalState(() {
                                    infoLine = '已更新事件 #$eventId：$message';
                                  });
                                }),
                          child: const Text('保存事件'),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          '删除 / 批量删除',
                          style: Theme.of(dialogCtx).textTheme.labelLarge,
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            OutlinedButton(
                              onPressed: localBusy
                                  ? null
                                  : () => runAction(() async {
                                      final eventId = int.parse(
                                        selectedEventIdCtrl.text.trim(),
                                      );
                                      final message =
                                          await deleteProjectNovelEventByLegacyIds(
                                            token,
                                            p.legacyId,
                                            eventId,
                                          );
                                      await refreshWorkbench(setLocalState);
                                      setLocalState(() {
                                        infoLine = '已删除事件 #$eventId：$message';
                                      });
                                    }),
                              child: const Text('删除当前事件'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: batchDeleteIdsCtrl,
                          decoration: const InputDecoration(
                            labelText: '批量删除事件 IDs',
                            helperText: '调用 legacy batch-delete；用逗号分隔',
                          ),
                        ),
                        const SizedBox(height: 8),
                        FilledButton.tonal(
                          onPressed: localBusy
                              ? null
                              : () => runAction(() async {
                                  final ids = _parseLegacyIdList(
                                    batchDeleteIdsCtrl.text,
                                  );
                                  final message =
                                      await postLegacyNovelEventsBatchDelete(
                                        token,
                                        ids,
                                      );
                                  await refreshWorkbench(setLocalState);
                                  setLocalState(() {
                                    infoLine =
                                        '已批量删除 ${ids.length} 条事件：$message';
                                  });
                                }),
                          child: const Text('批量删除事件'),
                        ),
                      ],
                    ),
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: localBusy
                        ? null
                        : () => Navigator.of(dialogCtx).pop(),
                    child: const Text('关闭'),
                  ),
                ],
              );
            },
          );
        },
      );
    } finally {
      searchCtrl.dispose();
      createNameCtrl.dispose();
      createDetailCtrl.dispose();
      createChapterIdsCtrl.dispose();
      selectedEventIdCtrl.dispose();
      patchNameCtrl.dispose();
      patchDetailCtrl.dispose();
      patchChapterIdsCtrl.dispose();
      batchDeleteIdsCtrl.dispose();
    }
  }

  List<int> _chapterIndexesToLegacyIds({
    required List<NovelRow> chapters,
    required List<int> indexes,
  }) {
    if (chapters.isEmpty || indexes.isEmpty) {
      return const <int>[];
    }
    final byIndex = <int, int>{
      for (final chapter in chapters) chapter.chapterIndex: chapter.legacyId,
    };
    return indexes.map((index) => byIndex[index]).whereType<int>().toList();
  }
}
