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
    return '准入 admitted 0 / pending 0 / rejected 0 · crawler 0 条';
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
  final crawlerCount = items
      .where((row) => row.intakeSource == 'crawler_client')
      .length;
  return '准入 admitted $admittedCount / pending $pendingCount / rejected $rejectedCount · crawler $crawlerCount 条';
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
