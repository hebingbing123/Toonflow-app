import '../../../rust_api.dart';

String summarizeNovelRows(Iterable<NovelRow> rows, {int maxItems = 4}) {
  final items = rows.toList(growable: false);
  if (items.isEmpty) {
    return '当前没有小说章节';
  }
  final visible = items
      .take(maxItems)
      .map((row) => '#${row.numericId}:${row.chapter}')
      .join(', ');
  final suffix = items.length > maxItems ? '…' : '';
  return '共 ${items.length} 条 · $visible$suffix';
}

String summarizeNovelIntakeRows(Iterable<NovelRow> rows) {
  final items = rows.toList(growable: false);
  if (items.isEmpty) {
    return '准入 admitted 0 / pending 0 / rejected 0 · source manual 0 / import 0 / crawler_client 0 / crawler_server 0';
  }
  final admittedCount = items
      .where((row) => row.intakeStatus == 'admitted')
      .length;
  final pendingCount = items
      .where((row) => row.intakeStatus == 'pending_review')
      .length;
  final rejectedCount = items
      .where((row) => row.intakeStatus == 'rejected')
      .length;
  int countBySource(String source) =>
      items.where((row) => row.intakeSource == source).length;
  final manualCount = countBySource('manual');
  final importCount = countBySource('whole_book_import');
  final crawlerClientCount = countBySource('crawler_client');
  final crawlerServerCount = countBySource('crawler_server');
  return '准入 admitted $admittedCount / pending $pendingCount / rejected $rejectedCount · source manual $manualCount / import $importCount / crawler_client $crawlerClientCount / crawler_server $crawlerServerCount';
}

String summarizeNovelEventRows(
  Iterable<NovelEventRow> rows, {
  int maxItems = 3,
}) {
  final items = rows.toList(growable: false);
  if (items.isEmpty) {
    return '当前没有小说事件';
  }
  final visible = items
      .take(maxItems)
      .map((row) => '#${row.numericId}:${row.name}')
      .join(', ');
  final suffix = items.length > maxItems ? '…' : '';
  return '事件 ${items.length} 条 · $visible$suffix';
}

List<int> parseNumericIdList(String raw) {
  return raw
      .split(',')
      .map((part) => part.trim())
      .where((part) => part.isNotEmpty)
      .map(int.parse)
      .toList();
}

List<int> chapterIndexesToNumericIds({
  required List<NovelRow> chapters,
  required List<int> indexes,
}) {
  if (chapters.isEmpty || indexes.isEmpty) {
    return const <int>[];
  }
  final byIndex = <int, int>{
    for (final chapter in chapters) chapter.chapterIndex: chapter.numericId,
  };
  return indexes.map((index) => byIndex[index]).whereType<int>().toList();
}

List<int> pickEventGeneratableNovelIds(
  Iterable<NovelRow> chapters, {
  int maxCount = 3,
}) {
  if (maxCount <= 0) {
    return const <int>[];
  }
  return chapters
      .where((row) => row.intakeStatus == 'admitted')
      .take(maxCount)
      .map((row) => row.numericId)
      .toList(growable: false);
}
