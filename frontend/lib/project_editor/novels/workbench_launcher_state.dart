part of 'workbench_launcher.dart';

class _NovelWorkbenchLocalState {
  _NovelWorkbenchLocalState({
    required this.previewRows,
    required this.importPreviewRows,
    required this.infoLine,
    required this.localBusy,
  });

  factory _NovelWorkbenchLocalState.fromItems(
    List<NovelRow> currentItems,
    AppLocalizations l10n,
  ) {
    return _NovelWorkbenchLocalState(
      previewRows: List<NovelRow>.from(currentItems.take(6)),
      importPreviewRows: const <ParsedNovelChapter>[],
      infoLine: currentItems.isEmpty
          ? l10n.projectEditorNovelsChapterWorkbenchInfoNoChapters
          : l10n.projectEditorNovelsChapterWorkbenchInfoLoaded(
              currentItems.length,
            ),
      localBusy: false,
    );
  }

  List<NovelRow> previewRows;
  List<ParsedNovelChapter> importPreviewRows;
  String infoLine;
  bool localBusy;
}
