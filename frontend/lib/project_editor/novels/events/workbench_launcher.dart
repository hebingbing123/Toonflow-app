import 'package:flutter/material.dart';

import '../../../../../rust_api.dart';
import 'workbench_view.dart';

Future<void> openNovelEventsWorkbenchDialog({
  required BuildContext ctx,
  required StateSetter setDialogState,
  required String token,
  required ProjectRow project,
  required List<ListNovelsResponse?> novelsRef,
  required List<ListNovelEventsResponse?> novelEventsRef,
  required List<bool> novelsBusy,
  required List<bool> novelEventsLoading,
  required List<int> Function(String raw) parseNumericIdList,
  required List<int> Function({
    required List<NovelRow> chapters,
    required List<int> indexes,
  })
  chapterIndexesToNumericIds,
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
    text: chapters.take(2).map((e) => e.numericId).join(','),
  );
  final selectedEventIdCtrl = TextEditingController(
    text: firstEvent?.numericId.toString() ?? '',
  );
  final patchNameCtrl = TextEditingController(text: firstEvent?.name ?? '');
  final patchDetailCtrl = TextEditingController(text: firstEvent?.detail ?? '');
  final patchChapterIdsCtrl = TextEditingController(
    text: chapterIndexesToNumericIds(
      chapters: chapters,
      indexes: firstEvent?.chapterIndexes ?? const <int>[],
    ).join(','),
  );
  final batchDeleteIdsCtrl = TextEditingController(
    text: events.take(3).map((e) => e.numericId).join(','),
  );

  List<NovelEventRow> previewRows = List<NovelEventRow>.from(events.take(6));
  String infoLine = events.isEmpty ? '当前项目还没有事件。' : '已载入 ${events.length} 条事件。';
  bool localBusy = false;

  Future<void> refreshWorkbench(StateSetter setLocalState) async {
    setDialogState(() => novelEventsLoading[0] = true);
    try {
      novelEventsRef[0] = await fetchProjectNovelEventsByProjectId(
        token,
        project.id,
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
        selectedEventIdCtrl.text = row.numericId.toString();
        patchNameCtrl.text = row.name;
        patchDetailCtrl.text = row.detail;
        patchChapterIdsCtrl.text = chapterIndexesToNumericIds(
          chapters: novelsRef[0]?.items ?? const <NovelRow>[],
          indexes: row.chapterIndexes,
        ).join(',');
      }
      if (batchDeleteIdsCtrl.text.trim().isEmpty && refreshed.isNotEmpty) {
        batchDeleteIdsCtrl.text = refreshed.take(3).map((e) => e.numericId).join(',');
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

            return NovelEventsWorkbenchDialogView(
              model: NovelEventsWorkbenchDialogViewModel(
                infoLine: infoLine,
                previewRows: previewRows,
                localBusy: localBusy,
                searchCtrl: searchCtrl,
                createNameCtrl: createNameCtrl,
                createDetailCtrl: createDetailCtrl,
                createChapterIdsCtrl: createChapterIdsCtrl,
                selectedEventIdCtrl: selectedEventIdCtrl,
                patchNameCtrl: patchNameCtrl,
                patchDetailCtrl: patchDetailCtrl,
                patchChapterIdsCtrl: patchChapterIdsCtrl,
                batchDeleteIdsCtrl: batchDeleteIdsCtrl,
              ),
              callbacks: NovelEventsWorkbenchDialogViewCallbacks(
                onSearch: localBusy
                    ? null
                    : () => runAction(() async {
                        final rows = await fetchProjectNovelEventsByProjectId(
                          token,
                          project.id,
                          search: searchCtrl.text.trim(),
                          page: 1,
                          limit: 10,
                        );
                        final workbenchPage = await fetchNovelEventsPaged(
                          token,
                          project.numericId,
                          page: 1,
                          limit: 10,
                          search: searchCtrl.text.trim(),
                        );
                        setLocalState(() {
                          previewRows = List<NovelEventRow>.from(rows.items);
                          infoLine =
                              'REST 命中 ${rows.total} 条，workbench 命中 ${workbenchPage.total} 条。';
                        });
                      }),
                onRefresh: localBusy
                    ? null
                    : () => runAction(() async {
                        await refreshWorkbench(setLocalState);
                      }),
                onCreate: localBusy
                    ? null
                    : () => runAction(() async {
                        final created = await createProjectNovelEventUnderProject(
                          token,
                          project.id,
                          name: createNameCtrl.text.trim(),
                          detail: createDetailCtrl.text.trim(),
                          chapterIds: parseNumericIdList(createChapterIdsCtrl.text),
                        );
                        await refreshWorkbench(setLocalState);
                        setLocalState(() {
                          final numericId = (created['id'] as num?)?.toInt();
                          infoLine = numericId == null ? '已新增事件。' : '已新增事件 #$numericId。';
                          if (numericId != null) {
                            selectedEventIdCtrl.text = numericId.toString();
                          }
                          patchNameCtrl.text = createNameCtrl.text.trim();
                          patchDetailCtrl.text = createDetailCtrl.text.trim();
                          patchChapterIdsCtrl.text = createChapterIdsCtrl.text.trim();
                        });
                      }),
                onSave: localBusy
                    ? null
                    : () => runAction(() async {
                        final eventId = int.parse(selectedEventIdCtrl.text.trim());
                        final message = await patchProjectNovelEventByProjectIds(
                          token,
                          project.id,
                          eventId,
                          {
                            'name': patchNameCtrl.text.trim(),
                            'detail': patchDetailCtrl.text.trim(),
                            'chapterIds': parseNumericIdList(
                              patchChapterIdsCtrl.text,
                            ),
                          },
                        );
                        await refreshWorkbench(setLocalState);
                        setLocalState(() {
                          infoLine = '已更新事件 #$eventId：$message';
                        });
                      }),
                onDeleteCurrent: localBusy
                    ? null
                    : () => runAction(() async {
                        final eventId = int.parse(selectedEventIdCtrl.text.trim());
                        final message = await deleteProjectNovelEventByProjectIds(
                          token,
                          project.id,
                          eventId,
                        );
                        await refreshWorkbench(setLocalState);
                        setLocalState(() {
                          infoLine = '已删除事件 #$eventId：$message';
                        });
                      }),
                onBatchDelete: localBusy
                    ? null
                    : () => runAction(() async {
                        final ids = parseNumericIdList(batchDeleteIdsCtrl.text);
                        final message =
                            await postProjectNovelEventsBatchDeleteByProjectId(
                              token,
                              project.id,
                              ids,
                            );
                        await refreshWorkbench(setLocalState);
                        setLocalState(() {
                          infoLine = '已批量删除 ${ids.length} 条事件：$message';
                        });
                      }),
                onClose: localBusy ? null : () => Navigator.of(dialogCtx).pop(),
              ),
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
