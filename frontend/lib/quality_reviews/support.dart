import '../../rust_api.dart';

String summarizeQualityReviews(
  Iterable<QualityReview> rows, {
  int maxItems = 4,
}) {
  final items = rows.toList(growable: false);
  if (items.isEmpty) {
    return '当前没有质量评审';
  }
  final visible = items
      .take(maxItems)
      .map((row) {
        final score = row.overallScore?.toString() ?? 'n/a';
        return '${row.targetType}:${row.source}:$score';
      })
      .join(', ');
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
  final visible = items
      .take(maxItems)
      .map((row) {
        final delivery = row.deliveryPriorityTotalReviews == 0
            ? 'delivery=n/a'
            : 'delivery=${row.deliveryPriorityPassRatePercent.toStringAsFixed(1)}%';
        final nonDelivery = row.nonDeliveryPriorityTotalReviews == 0
            ? 'non=n/a'
            : 'non=${row.nonDeliveryPriorityPassRatePercent.toStringAsFixed(1)}%';
        return '${row.targetType}: total=${row.totalReviews}, pass=${row.passRatePercent.toStringAsFixed(1)}% ($delivery, $nonDelivery)';
      })
      .join(' | ');
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
  final visible = items
      .take(maxItems)
      .map((row) {
        final date = row.reviewDate.length >= 10
            ? row.reviewDate.substring(0, 10)
            : row.reviewDate;
        final passRate = row.passRatePercent?.toStringAsFixed(1) ?? 'n/a';
        final delivery = row.deliveryPriorityTotalReviews == 0
            ? 'delivery=n/a'
            : 'delivery=${row.deliveryPriorityPassRatePercent.toStringAsFixed(1)}%';
        final nonDelivery = row.nonDeliveryPriorityTotalReviews == 0
            ? 'non=n/a'
            : 'non=${row.nonDeliveryPriorityPassRatePercent.toStringAsFixed(1)}%';
        return '$date ${row.targetType}:$passRate% ($delivery, $nonDelivery)';
      })
      .join(' | ');
  final suffix = items.length > maxItems ? ' | …' : '';
  return '$visible$suffix';
}

String summarizeQualityTokenEfficiencyRows(
  Iterable<QualityTokenEfficiencyRow> rows, {
  int maxItems = 3,
}) {
  final items = rows.toList(growable: false);
  if (items.isEmpty) {
    return '当前没有 token 效率统计';
  }
  final visible = items
      .take(maxItems)
      .map((row) {
        final linked = '${row.linkedLlmReviewCount}/${row.totalReviews}';
        final avgScore = row.avgOverallScore.toStringAsFixed(1);
        final promptPerScore = row.avgPromptCharsPerScorePoint.toStringAsFixed(
          1,
        );
        final tokenPerScore = row.avgLinkedTokensPerScorePoint.toStringAsFixed(
          1,
        );
        final deliveryTokenPerScore = row
            .deliveryPriorityAvgLinkedTokensPerScorePoint
            .toStringAsFixed(1);
        final nonDeliveryTokenPerScore = row
            .nonDeliveryPriorityAvgLinkedTokensPerScorePoint
            .toStringAsFixed(1);
        return '${row.targetType}: linked=$linked, avgScore=$avgScore, prompt/score=$promptPerScore, token/score=$tokenPerScore (delivery=$deliveryTokenPerScore, non=$nonDeliveryTokenPerScore)';
      })
      .join(' | ');
  final suffix = items.length > maxItems ? ' | …' : '';
  return '$visible$suffix';
}

String formatQualityReviewDetails(QualityReview row) {
  return [
    row.id,
    row.targetType,
    row.source,
    if (row.memoryDeliveryPriorityApplied != null)
      'delivery_priority=${row.memoryDeliveryPriorityApplied}',
    if (row.targetId != null && row.targetId!.isNotEmpty)
      'target=${row.targetId}',
    if (row.overallScore != null) 'score=${row.overallScore}',
    if (row.passed != null) 'passed=${row.passed}',
    if (row.isBadCase) 'bad_case',
    if (row.badCaseCategory != null) 'category=${row.badCaseCategory}',
  ].join(' · ');
}
