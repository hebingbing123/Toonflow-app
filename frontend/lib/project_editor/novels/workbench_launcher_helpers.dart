// ignore_for_file: library_private_types_in_public_api

part of 'workbench_launcher.dart';

Future<void> refreshNovelWorkbenchLocalState({
  required StateSetter setLocalState,
  required Future<void> Function() reloadAssetsAndStats,
  required List<ListNovelsResponse?> novelsRef,
  required _NovelWorkbenchControllers ctrls,
  required _NovelWorkbenchLocalState local,
}) async {
  await reloadAssetsAndStats();
  final refreshed = novelsRef[0]?.items ?? const <NovelRow>[];
  setLocalState(() {
    local.previewRows = List<NovelRow>.from(refreshed.take(6));
    local.infoLine = refreshed.isEmpty
        ? '章节列表为空。'
        : '已刷新，共 ${refreshed.length} 条章节。';
    if (ctrls.selectedNovelIdCtrl.text.trim().isEmpty && refreshed.isNotEmpty) {
      ctrls.selectedNovelIdCtrl.text = refreshed.first.numericId.toString();
      ctrls.patchChapterCtrl.text = refreshed.first.chapter;
      ctrls.patchBodyCtrl.text = refreshed.first.chapterData;
      ctrls.patchIntakeStatusCtrl.text =
          refreshed.first.intakeStatus ?? 'admitted';
      ctrls.patchIntakeSourceUrlCtrl.text =
          refreshed.first.intakeSourceUrl ?? '';
      ctrls.patchIntakeNoteCtrl.text = refreshed.first.intakeNote ?? '';
    }
    if (ctrls.deleteNovelIdCtrl.text.trim().isEmpty && refreshed.isNotEmpty) {
      ctrls.deleteNovelIdCtrl.text = refreshed.last.numericId.toString();
    }
    if (ctrls.generateIdsCtrl.text.trim().isEmpty && refreshed.isNotEmpty) {
      final generateIds = pickEventGeneratableNovelIds(refreshed, maxCount: 3);
      ctrls.generateIdsCtrl.text = generateIds.join(',');
    }
    if (ctrls.batchAdmissionIdsCtrl.text.trim().isEmpty &&
        refreshed.isNotEmpty) {
      ctrls.batchAdmissionIdsCtrl.text = refreshed
          .take(3)
          .map((e) => e.numericId)
          .join(',');
    }
  });
}

void applyNovelWorkbenchSearchResult({
  required StateSetter setLocalState,
  required _NovelWorkbenchLocalState local,
  required List<NovelRow> rows,
  required String message,
}) {
  setLocalState(() {
    local.previewRows = rows;
    local.infoLine = message;
  });
}
