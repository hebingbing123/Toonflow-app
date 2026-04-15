import '../../rust_api.dart';

String summarizeQualityReviews(Iterable<QualityReview> rows, {int maxItems = 4}) {
  final items = rows.toList(growable: false);
  if (items.isEmpty) {
    return '当前没有质量评审';
  }
  final visible = items.take(maxItems).map((row) {
    final score = row.overallScore?.toString() ?? 'n/a';
    return '${row.targetType}:${row.source}:$score';
  }).join(', ');
  final suffix = items.length > maxItems ? '…' : '';
  return '评审 ${items.length} 条 · $visible$suffix';
}

String summarizeQualityStatsRows(
  Iterable<QualityStatsRow> rows, {
  int maxItems = 3,
}) {
  final items = rows.toList(growable: false);
  if (items.isEmpty) {
    return '当前没有质量统计';
  }
  final visible = items.take(maxItems).map((row) {
    return '${row.targetType}: total=${row.totalReviews}, pass=${row.passRatePercent.toStringAsFixed(1)}%';
  }).join(' | ');
  final suffix = items.length > maxItems ? ' | …' : '';
  return '$visible$suffix';
}

String summarizeStagePassRateRows(
  Iterable<StagePassRateRow> rows, {
  int maxItems = 4,
}) {
  final items = rows.toList(growable: false);
  if (items.isEmpty) {
    return '当前没有阶段通过率';
  }
  final visible = items.take(maxItems).map((row) {
    final date = row.reviewDate.length >= 10
        ? row.reviewDate.substring(0, 10)
        : row.reviewDate;
    final passRate = row.passRatePercent?.toStringAsFixed(1) ?? 'n/a';
    return '$date ${row.targetType}:$passRate%';
  }).join(' | ');
  final suffix = items.length > maxItems ? ' | …' : '';
  return '$visible$suffix';
}

String formatQualityReviewDetails(QualityReview row) {
  return [
    row.id,
    row.targetType,
    row.source,
    if (row.targetId != null && row.targetId!.isNotEmpty) 'target=${row.targetId}',
    if (row.overallScore != null) 'score=${row.overallScore}',
    if (row.passed != null) 'passed=${row.passed}',
    if (row.isBadCase) 'bad_case',
    if (row.badCaseCategory != null) 'category=${row.badCaseCategory}',
  ].join(' · ');
}
