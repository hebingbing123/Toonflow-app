part of '../../../home_page.dart';

extension _HomePageProjectEditorNovelsWorkbench on _HomePageState {
  Widget _buildProjectNovelsWorkbenchSection({
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
    final novels = novelsRef[0]?.items ?? const <NovelRow>[];
    final first = novels.isNotEmpty ? novels.first : null;
    final last = novels.isNotEmpty ? novels.last : null;
    final summaryLine = summarizeNovelRows(novels);
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
          Text('章节工作台', style: Theme.of(ctx).textTheme.titleSmall),
          const SizedBox(height: 4),
          Text(
            first == null
                ? '用显式表单完成章节新增、搜索、查看、更新、删除和事件生成，不再依赖首条/末条 probe 按钮。'
                : '$summaryLine；首条 #${first.legacyId} ${first.chapter}，末条 #${last!.legacyId} ${last.chapter}。',
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
                        assetsBusy[0] ||
                        assetsLoading[0] ||
                        assetsScriptFilterLoading[0]
                    ? null
                    : () => _openNovelWorkbenchDialog(
                        ctx: ctx,
                        setDialogState: setDialogState,
                        token: token,
                        p: p,
                        novelsRef: novelsRef,
                        novelsBusy: novelsBusy,
                        reloadAssetsAndStats: reloadAssetsAndStats,
                      ),
                child: const Text('打开章节工作台'),
              ),
              OutlinedButton(
                onPressed:
                    novelsBusy[0] ||
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
                child: Text(novelsLoading[0] ? '刷新章节…' : '刷新章节'),
              ),
              OutlinedButton(
                onPressed:
                    novelsBusy[0] ||
                        novelsLoading[0] ||
                        novels.isEmpty ||
                        assetsBusy[0] ||
                        assetsLoading[0] ||
                        assetsScriptFilterLoading[0]
                    ? null
                    : () async {
                        setDialogState(() => novelsBusy[0] = true);
                        try {
                          final ids = novels
                              .take(3)
                              .map((e) => e.legacyId)
                              .toList();
                          final message =
                              await postLegacyNovelEventsGenerateEvents(
                                token,
                                projectId: p.legacyId,
                                novelIds: ids,
                              );
                          if (!ctx.mounted) return;
                          await reloadAssetsAndStats();
                          if (!ctx.mounted) return;
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            SnackBar(
                              content: Text(
                                '已为章节 ${ids.join(', ')} 触发事件生成：$message',
                              ),
                            ),
                          );
                        } on RustApiException catch (e) {
                          if (ctx.mounted) {
                            ScaffoldMessenger.of(
                              ctx,
                            ).showSnackBar(SnackBar(content: Text('$e')));
                          }
                        } finally {
                          if (ctx.mounted) {
                            setDialogState(() => novelsBusy[0] = false);
                          }
                        }
                      },
                child: const Text('为前 3 条生成事件'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _openNovelWorkbenchDialog({
    required BuildContext ctx,
    required StateSetter setDialogState,
    required String token,
    required ProjectRow p,
    required List<ListNovelsResponse?> novelsRef,
    required List<bool> novelsBusy,
    required Future<void> Function() reloadAssetsAndStats,
  }) async {
    final currentItems = novelsRef[0]?.items ?? const <NovelRow>[];
    final first = currentItems.isNotEmpty ? currentItems.first : null;
    final last = currentItems.isNotEmpty ? currentItems.last : null;
    final searchCtrl = TextEditingController();
    final createChapterCtrl = TextEditingController(
      text: '章节_${DateTime.now().millisecondsSinceEpoch}',
    );
    final createBodyCtrl = TextEditingController(text: '在这里填写章节正文。');
    final selectedNovelIdCtrl = TextEditingController(
      text: first?.legacyId.toString() ?? '',
    );
    final patchChapterCtrl = TextEditingController(text: first?.chapter ?? '');
    final patchBodyCtrl = TextEditingController(text: first?.chapterData ?? '');
    final deleteNovelIdCtrl = TextEditingController(
      text: last?.legacyId.toString() ?? '',
    );
    final generateIdsCtrl = TextEditingController(
      text: currentItems.take(3).map((e) => e.legacyId).join(','),
    );
    final legacyIdsCtrl = TextEditingController(
      text: currentItems.take(3).map((e) => e.legacyId).join(','),
    );
    final batchDeleteIdsCtrl = TextEditingController(
      text: currentItems.skip(1).take(2).map((e) => e.legacyId).join(','),
    );

    List<NovelRow> previewRows = List<NovelRow>.from(currentItems.take(6));
    String infoLine = currentItems.isEmpty
        ? '当前项目还没有章节。'
        : '已载入 ${currentItems.length} 条章节。';
    bool localBusy = false;

    Future<void> refreshWorkbench(StateSetter setLocalState) async {
      await reloadAssetsAndStats();
      final refreshed = novelsRef[0]?.items ?? const <NovelRow>[];
      setLocalState(() {
        previewRows = List<NovelRow>.from(refreshed.take(6));
        infoLine = refreshed.isEmpty
            ? '章节列表为空。'
            : '已刷新，共 ${refreshed.length} 条章节。';
        if (selectedNovelIdCtrl.text.trim().isEmpty && refreshed.isNotEmpty) {
          selectedNovelIdCtrl.text = refreshed.first.legacyId.toString();
          patchChapterCtrl.text = refreshed.first.chapter;
          patchBodyCtrl.text = refreshed.first.chapterData;
        }
        if (deleteNovelIdCtrl.text.trim().isEmpty && refreshed.isNotEmpty) {
          deleteNovelIdCtrl.text = refreshed.last.legacyId.toString();
        }
        if (generateIdsCtrl.text.trim().isEmpty && refreshed.isNotEmpty) {
          generateIdsCtrl.text = refreshed
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
                title: const Text('章节工作台'),
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
                                  '当前章节预览',
                                  style: Theme.of(
                                    dialogCtx,
                                  ).textTheme.labelLarge,
                                ),
                                const SizedBox(height: 8),
                                ...previewRows.map(
                                  (row) => Padding(
                                    padding: const EdgeInsets.only(bottom: 6),
                                    child: Text(
                                      '#${row.legacyId} · ${row.chapter} · 事件状态 ${row.eventState}',
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
                            labelText: '搜索章节关键字',
                            helperText:
                                '调用 GET /projects/{project_uuid}/novels?search=',
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
                                          await fetchProjectNovelsByProjectId(
                                            token,
                                            p.id,
                                            search: searchCtrl.text.trim(),
                                            page: 1,
                                            limit: 10,
                                          );
                                      setLocalState(() {
                                        previewRows = List<NovelRow>.from(
                                          rows.items,
                                        );
                                        infoLine =
                                            '搜索命中 ${rows.total} 条，当前展示 ${rows.items.length} 条。';
                                      });
                                    }),
                              child: const Text('搜索'),
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
                          '新增章节',
                          style: Theme.of(dialogCtx).textTheme.labelLarge,
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: createChapterCtrl,
                          decoration: const InputDecoration(labelText: '章节标题'),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: createBodyCtrl,
                          minLines: 3,
                          maxLines: 6,
                          decoration: const InputDecoration(labelText: '章节正文'),
                        ),
                        const SizedBox(height: 8),
                        FilledButton(
                          onPressed: localBusy
                              ? null
                              : () => runAction(() async {
                                  final created =
                                      await createProjectNovelUnderProject(
                                        token,
                                        p.id,
                                        chapter: createChapterCtrl.text.trim(),
                                        chapterData: createBodyCtrl.text.trim(),
                                      );
                                  await refreshWorkbench(setLocalState);
                                  setLocalState(() {
                                    infoLine =
                                        '已新增章节 #${created.legacyId} ${created.chapter}。';
                                    selectedNovelIdCtrl.text = created.legacyId
                                        .toString();
                                    patchChapterCtrl.text = created.chapter;
                                    patchBodyCtrl.text = created.chapterData;
                                  });
                                }),
                          child: const Text('新增章节'),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          '读取 / 更新章节',
                          style: Theme.of(dialogCtx).textTheme.labelLarge,
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: selectedNovelIdCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: '章节 legacy id',
                          ),
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
                                      final id = int.parse(
                                        selectedNovelIdCtrl.text.trim(),
                                      );
                                      final row =
                                          await fetchProjectNovelByProjectIds(
                                            token,
                                            p.id,
                                            id,
                                          );
                                      setLocalState(() {
                                        patchChapterCtrl.text = row.chapter;
                                        patchBodyCtrl.text = row.chapterData;
                                        infoLine = '已读取章节 #${row.legacyId}。';
                                      });
                                    }),
                              child: const Text('读取章节'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: patchChapterCtrl,
                          decoration: const InputDecoration(
                            labelText: '更新后的章节标题',
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: patchBodyCtrl,
                          minLines: 3,
                          maxLines: 6,
                          decoration: const InputDecoration(
                            labelText: '更新后的章节正文',
                          ),
                        ),
                        const SizedBox(height: 8),
                        FilledButton.tonal(
                          onPressed: localBusy
                              ? null
                              : () => runAction(() async {
                                  final id = int.parse(
                                    selectedNovelIdCtrl.text.trim(),
                                  );
                                  final row =
                                      await patchProjectNovelByProjectIds(
                                        token,
                                        p.id,
                                        id,
                                        {
                                          'chapter': patchChapterCtrl.text
                                              .trim(),
                                          'chapter_data': patchBodyCtrl.text
                                              .trim(),
                                        },
                                      );
                                  await refreshWorkbench(setLocalState);
                                  setLocalState(() {
                                    infoLine = '已更新章节 #${row.legacyId}。';
                                  });
                                }),
                          child: const Text('保存章节'),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          '删除 / 生成事件',
                          style: Theme.of(dialogCtx).textTheme.labelLarge,
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: deleteNovelIdCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: '待删除章节 legacy id',
                          ),
                        ),
                        const SizedBox(height: 8),
                        OutlinedButton(
                          onPressed: localBusy
                              ? null
                              : () => runAction(() async {
                                  final id = int.parse(
                                    deleteNovelIdCtrl.text.trim(),
                                  );
                                  await deleteProjectNovelByProjectIds(
                                    token,
                                    p.id,
                                    id,
                                  );
                                  await refreshWorkbench(setLocalState);
                                  setLocalState(() {
                                    infoLine = '已删除章节 #$id。';
                                  });
                                }),
                          child: const Text('删除章节'),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: generateIdsCtrl,
                          decoration: const InputDecoration(
                            labelText: '生成事件章节 IDs',
                            helperText: '用逗号分隔，如 1,2,3',
                          ),
                        ),
                        const SizedBox(height: 8),
                        FilledButton.tonal(
                          onPressed: localBusy
                              ? null
                              : () => runAction(() async {
                                  final ids = _parseLegacyIdList(
                                    generateIdsCtrl.text,
                                  );
                                  if (ids.isEmpty) {
                                    throw const FormatException('至少提供一个章节 ID');
                                  }
                                  final message =
                                      await postLegacyNovelEventsGenerateEvents(
                                        token,
                                        projectId: p.legacyId,
                                        novelIds: ids,
                                      );
                                  await refreshWorkbench(setLocalState);
                                  setLocalState(() {
                                    infoLine = '已触发事件生成：$message';
                                  });
                                }),
                          child: const Text('生成章节事件'),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Legacy 快照 / 批量动作',
                          style: Theme.of(dialogCtx).textTheme.labelLarge,
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: legacyIdsCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Legacy 查询章节 IDs',
                            helperText:
                                '用于 get-novel-event-state；用逗号分隔，如 1,2,3',
                          ),
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
                                      final rows =
                                          await postLegacyNovelsGetNovelData(
                                            token,
                                            p.legacyId,
                                          );
                                      final sample = rows.isEmpty
                                          ? '空列表'
                                          : rows
                                                .take(2)
                                                .map(
                                                  (row) =>
                                                      '#${row.legacyId} ${row.chapter}',
                                                )
                                                .join(' · ');
                                      setLocalState(() {
                                        infoLine =
                                            'legacy get-novel-data 返回 ${rows.length} 条：$sample';
                                      });
                                    }),
                              child: const Text('读取 get-novel-data'),
                            ),
                            OutlinedButton(
                              onPressed: localBusy
                                  ? null
                                  : () => runAction(() async {
                                      final rows =
                                          await postLegacyNovelsGetNovelIndex(
                                            token,
                                            p.legacyId,
                                          );
                                      final sample = rows.isEmpty
                                          ? '空列表'
                                          : rows
                                                .take(3)
                                                .map(
                                                  (row) =>
                                                      '#${row.legacyId}:${row.chapterIndex}',
                                                )
                                                .join(' · ');
                                      setLocalState(() {
                                        infoLine =
                                            'legacy get-novel-index 返回 ${rows.length} 条：$sample';
                                      });
                                    }),
                              child: const Text('读取 get-novel-index'),
                            ),
                            OutlinedButton(
                              onPressed: localBusy
                                  ? null
                                  : () => runAction(() async {
                                      final ids = _parseLegacyIdList(
                                        legacyIdsCtrl.text,
                                      );
                                      if (ids.isEmpty) {
                                        throw const FormatException(
                                          '至少提供一个章节 ID',
                                        );
                                      }
                                      final rows =
                                          await postLegacyNovelsGetNovelEventState(
                                            token,
                                            ids,
                                          );
                                      final sample = rows.isEmpty
                                          ? '当前均为 0'
                                          : rows
                                                .take(3)
                                                .map(
                                                  (row) =>
                                                      '#${row.legacyId}:${row.eventState}',
                                                )
                                                .join(' · ');
                                      setLocalState(() {
                                        infoLine =
                                            'legacy get-novel-event-state 返回 ${rows.length} 条：$sample';
                                      });
                                    }),
                              child: const Text('读取 event-state'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: batchDeleteIdsCtrl,
                          decoration: const InputDecoration(
                            labelText: '批量删除章节 IDs',
                            helperText:
                                '调用 legacy batch-delete；用逗号分隔，删除后会回刷工作台。',
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
                                  if (ids.isEmpty) {
                                    throw const FormatException('至少提供一个章节 ID');
                                  }
                                  final message =
                                      await postLegacyNovelsBatchDelete(
                                        token,
                                        ids,
                                      );
                                  await refreshWorkbench(setLocalState);
                                  setLocalState(() {
                                    infoLine =
                                        '已批量删除 ${ids.length} 条章节：$message';
                                  });
                                }),
                          child: const Text('批量删除章节'),
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
      createChapterCtrl.dispose();
      createBodyCtrl.dispose();
      selectedNovelIdCtrl.dispose();
      patchChapterCtrl.dispose();
      patchBodyCtrl.dispose();
      deleteNovelIdCtrl.dispose();
      generateIdsCtrl.dispose();
      legacyIdsCtrl.dispose();
      batchDeleteIdsCtrl.dispose();
    }
  }

  List<int> _parseLegacyIdList(String raw) {
    return raw
        .split(',')
        .map((part) => part.trim())
        .where((part) => part.isNotEmpty)
        .map(int.parse)
        .toList();
  }
}
