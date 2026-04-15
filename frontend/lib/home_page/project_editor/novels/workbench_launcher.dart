import 'package:flutter/material.dart';

import '../../../../rust_api.dart';

Future<void> openNovelWorkbenchDialog({
  required BuildContext ctx,
  required StateSetter setDialogState,
  required String token,
  required ProjectRow project,
  required List<ListNovelsResponse?> novelsRef,
  required List<bool> novelsBusy,
  required Future<void> Function() reloadAssetsAndStats,
  required List<int> Function(String raw) parseNumericIdList,
  required Widget Function({
    required BuildContext context,
    required List<NovelRow> previewRows,
  })
  buildPreviewSection,
  required Widget Function({
    required BuildContext ctx,
    required StateSetter setDialogState,
    required StateSetter setLocalState,
    required String token,
    required ProjectRow project,
    required List<bool> novelsBusy,
    required TextEditingController searchCtrl,
    required bool localBusy,
    required void Function(bool value) setLocalBusy,
    required Future<void> Function(StateSetter setLocalState) refreshWorkbench,
    required void Function(List<NovelRow> rows, String message) applyResult,
  })
  buildSearchSection,
  required Widget Function({
    required BuildContext ctx,
    required StateSetter setDialogState,
    required StateSetter setLocalState,
    required String token,
    required ProjectRow project,
    required List<bool> novelsBusy,
    required bool localBusy,
    required void Function(bool value) setLocalBusy,
    required void Function(String value) updateInfoLine,
    required TextEditingController createChapterCtrl,
    required TextEditingController createBodyCtrl,
    required TextEditingController selectedNovelIdCtrl,
    required TextEditingController patchChapterCtrl,
    required TextEditingController patchBodyCtrl,
    required Future<void> Function(StateSetter setLocalState) refreshWorkbench,
  })
  buildCreateSection,
  required Widget Function({
    required BuildContext ctx,
    required StateSetter setDialogState,
    required StateSetter setLocalState,
    required String token,
    required ProjectRow project,
    required List<bool> novelsBusy,
    required bool localBusy,
    required void Function(bool value) setLocalBusy,
    required void Function(String value) updateInfoLine,
    required TextEditingController selectedNovelIdCtrl,
    required TextEditingController patchChapterCtrl,
    required TextEditingController patchBodyCtrl,
    required Future<void> Function(StateSetter setLocalState) refreshWorkbench,
  })
  buildEditSection,
  required Widget Function({
    required BuildContext ctx,
    required StateSetter setDialogState,
    required StateSetter setLocalState,
    required String token,
    required ProjectRow project,
    required List<bool> novelsBusy,
    required bool localBusy,
    required void Function(bool value) setLocalBusy,
    required void Function(String value) updateInfoLine,
    required TextEditingController deleteNovelIdCtrl,
    required TextEditingController generateIdsCtrl,
    required Future<void> Function(StateSetter setLocalState) refreshWorkbench,
  })
  buildDeleteSection,
  required Widget Function({
    required BuildContext ctx,
    required StateSetter setDialogState,
    required StateSetter setLocalState,
    required String token,
    required ProjectRow project,
    required List<bool> novelsBusy,
    required bool localBusy,
    required void Function(bool value) setLocalBusy,
    required void Function(String value) updateInfoLine,
    required TextEditingController numericIdsCtrl,
    required TextEditingController batchDeleteIdsCtrl,
    required Future<void> Function(StateSetter setLocalState) refreshWorkbench,
  })
  buildSnapshotSection,
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
    text: first?.numericId.toString() ?? '',
  );
  final patchChapterCtrl = TextEditingController(text: first?.chapter ?? '');
  final patchBodyCtrl = TextEditingController(text: first?.chapterData ?? '');
  final deleteNovelIdCtrl = TextEditingController(
    text: last?.numericId.toString() ?? '',
  );
  final generateIdsCtrl = TextEditingController(
    text: currentItems.take(3).map((e) => e.numericId).join(','),
  );
  final numericIdsCtrl = TextEditingController(
    text: currentItems.take(3).map((e) => e.numericId).join(','),
  );
  final batchDeleteIdsCtrl = TextEditingController(
    text: currentItems.skip(1).take(2).map((e) => e.numericId).join(','),
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
        selectedNovelIdCtrl.text = refreshed.first.numericId.toString();
        patchChapterCtrl.text = refreshed.first.chapter;
        patchBodyCtrl.text = refreshed.first.chapterData;
      }
      if (deleteNovelIdCtrl.text.trim().isEmpty && refreshed.isNotEmpty) {
        deleteNovelIdCtrl.text = refreshed.last.numericId.toString();
      }
      if (generateIdsCtrl.text.trim().isEmpty && refreshed.isNotEmpty) {
        generateIdsCtrl.text = refreshed
            .take(3)
            .map((e) => e.numericId)
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
            void setLocalBusy(bool value) {
              setLocalState(() => localBusy = value);
            }

            void updateInfoLine(String value) {
              setLocalState(() => infoLine = value);
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
                      buildPreviewSection(
                        context: dialogCtx,
                        previewRows: previewRows,
                      ),
                      const SizedBox(height: 12),
                      buildSearchSection(
                        ctx: ctx,
                        setDialogState: setDialogState,
                        setLocalState: setLocalState,
                        token: token,
                        project: project,
                        novelsBusy: novelsBusy,
                        searchCtrl: searchCtrl,
                        localBusy: localBusy,
                        setLocalBusy: setLocalBusy,
                        refreshWorkbench: refreshWorkbench,
                        applyResult: (rows, message) {
                          setLocalState(() {
                            previewRows = rows;
                            infoLine = message;
                          });
                        },
                      ),
                      const SizedBox(height: 16),
                      buildCreateSection(
                        ctx: dialogCtx,
                        setDialogState: setDialogState,
                        setLocalState: setLocalState,
                        token: token,
                        project: project,
                        novelsBusy: novelsBusy,
                        localBusy: localBusy,
                        setLocalBusy: setLocalBusy,
                        updateInfoLine: updateInfoLine,
                        createChapterCtrl: createChapterCtrl,
                        createBodyCtrl: createBodyCtrl,
                        selectedNovelIdCtrl: selectedNovelIdCtrl,
                        patchChapterCtrl: patchChapterCtrl,
                        patchBodyCtrl: patchBodyCtrl,
                        refreshWorkbench: refreshWorkbench,
                      ),
                      const SizedBox(height: 16),
                      buildEditSection(
                        ctx: dialogCtx,
                        setDialogState: setDialogState,
                        setLocalState: setLocalState,
                        token: token,
                        project: project,
                        novelsBusy: novelsBusy,
                        localBusy: localBusy,
                        setLocalBusy: setLocalBusy,
                        updateInfoLine: updateInfoLine,
                        selectedNovelIdCtrl: selectedNovelIdCtrl,
                        patchChapterCtrl: patchChapterCtrl,
                        patchBodyCtrl: patchBodyCtrl,
                        refreshWorkbench: refreshWorkbench,
                      ),
                      const SizedBox(height: 16),
                      buildDeleteSection(
                        ctx: dialogCtx,
                        setDialogState: setDialogState,
                        setLocalState: setLocalState,
                        token: token,
                        project: project,
                        novelsBusy: novelsBusy,
                        localBusy: localBusy,
                        setLocalBusy: setLocalBusy,
                        updateInfoLine: updateInfoLine,
                        deleteNovelIdCtrl: deleteNovelIdCtrl,
                        generateIdsCtrl: generateIdsCtrl,
                        refreshWorkbench: refreshWorkbench,
                      ),
                      const SizedBox(height: 16),
                      buildSnapshotSection(
                        ctx: dialogCtx,
                        setDialogState: setDialogState,
                        setLocalState: setLocalState,
                        token: token,
                        project: project,
                        novelsBusy: novelsBusy,
                        localBusy: localBusy,
                        setLocalBusy: setLocalBusy,
                        updateInfoLine: updateInfoLine,
                        numericIdsCtrl: numericIdsCtrl,
                        batchDeleteIdsCtrl: batchDeleteIdsCtrl,
                        refreshWorkbench: refreshWorkbench,
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
    numericIdsCtrl.dispose();
    batchDeleteIdsCtrl.dispose();
  }
}
