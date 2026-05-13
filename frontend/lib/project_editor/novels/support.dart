import '../../l10n/app_localizations.dart';
import '../../rust_api.dart';

String summarizeNovelRows(
  AppLocalizations l10n,
  Iterable<NovelRow> rows, {
  int maxItems = 4,
}) {
  final items = rows.toList(growable: false);
  if (items.isEmpty) {
    return l10n.projectEditorNovelsSummaryNoChapters;
  }
  final visible = items
      .take(maxItems)
      .map((row) => '#${row.numericId}:${row.chapter}')
      .join(', ');
  final suffix = items.length > maxItems ? '…' : '';
  return l10n.projectEditorNovelsSummaryChaptersLine(
    items.length,
    visible,
    suffix,
  );
}

String summarizeNovelIntakeRows(AppLocalizations l10n, Iterable<NovelRow> rows) {
  final items = rows.toList(growable: false);
  if (items.isEmpty) {
    return l10n.projectEditorNovelsSummaryIntakeEmptyBaseline;
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
  return l10n.projectEditorNovelsSummaryIntakeCounts(
    admittedCount,
    pendingCount,
    rejectedCount,
    manualCount,
    importCount,
    crawlerClientCount,
    crawlerServerCount,
  );
}

String summarizeNovelEventRows(
  AppLocalizations l10n,
  Iterable<NovelEventRow> rows, {
  int maxItems = 3,
}) {
  final items = rows.toList(growable: false);
  if (items.isEmpty) {
    return l10n.projectEditorNovelsSummaryNoEvents;
  }
  final visible = items
      .take(maxItems)
      .map((row) => '#${row.numericId}:${row.name}')
      .join(', ');
  final suffix = items.length > maxItems ? '…' : '';
  return l10n.projectEditorNovelsSummaryEventsLine(
    items.length,
    visible,
    suffix,
  );
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
