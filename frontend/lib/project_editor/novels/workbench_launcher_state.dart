part of 'workbench_launcher.dart';

class _NovelWorkbenchLocalState {
  _NovelWorkbenchLocalState({
    required this.previewRows,
    required this.importPreviewRows,
    required this.infoLine,
    required this.localBusy,
  });

  factory _NovelWorkbenchLocalState.fromItems(List<NovelRow> currentItems) {
    return _NovelWorkbenchLocalState(
      previewRows: List<NovelRow>.from(currentItems.take(6)),
      importPreviewRows: const <ParsedNovelChapter>[],
      infoLine: currentItems.isEmpty
          ? '当前项目还没有章节。'
          : '已载入 ${currentItems.length} 条章节。',
      localBusy: false,
    );
  }

  List<NovelRow> previewRows;
  List<ParsedNovelChapter> importPreviewRows;
  String infoLine;
  bool localBusy;
}
