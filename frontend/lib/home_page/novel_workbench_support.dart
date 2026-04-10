import '../rust_api.dart';

String summarizeNovelRows(Iterable<NovelRow> rows, {int maxItems = 4}) {
  final items = rows.toList(growable: false);
  if (items.isEmpty) {
    return '当前没有小说章节';
  }
  final visible = items
      .take(maxItems)
      .map((row) => '#${row.legacyId}:${row.chapter}')
      .join(', ');
  final suffix = items.length > maxItems ? '…' : '';
  return '共 ${items.length} 条 · $visible$suffix';
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
      .map((row) => '#${row.legacyId}:${row.name}')
      .join(', ');
  final suffix = items.length > maxItems ? '…' : '';
  return '事件 ${items.length} 条 · $visible$suffix';
}
