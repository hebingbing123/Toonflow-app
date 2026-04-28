import '../../rust_api.dart';

String? summarizeTokenEfficiencyFromQualityReviews(
  Iterable<QualityReview> rows, {
  int maxSamples = 40,
}) {
  final samples = rows
      .where((row) => row.source == 'auto')
      .take(maxSamples)
      .toList(growable: false);
  if (samples.isEmpty) return null;

  int sumPrompt = 0;
  int sumMemory = 0;
  int sumVisual = 0;
  int sumDelivery = 0;
  int deliveryPriorityHits = 0;
  int parsed = 0;

  for (final row in samples) {
    final params = row.modelParams;
    if (params == null) continue;
    final diagnostics = params['diagnostics'];
    if (diagnostics is! Map) continue;
    final map = Map<String, dynamic>.from(diagnostics);
    int asInt(String key) {
      final v = map[key];
      if (v is num) return v.toInt();
      return 0;
    }

    final prompt = asInt('promptChars');
    final memory = asInt('memoryStyleChars');
    final visual = asInt('memoryVisualChars');
    final delivery = asInt('memoryDeliveryChars');
    final deliveryPriority = map['memoryDeliveryPriorityApplied'] == true;
    if (prompt == 0 && memory == 0 && visual == 0 && delivery == 0) continue;

    sumPrompt += prompt;
    sumMemory += memory;
    sumVisual += visual;
    sumDelivery += delivery;
    if (deliveryPriority) deliveryPriorityHits += 1;
    parsed += 1;
  }

  if (parsed == 0) return null;
  final avgPrompt = (sumPrompt / parsed).toStringAsFixed(0);
  final avgMemory = (sumMemory / parsed).toStringAsFixed(0);
  final avgVisual = (sumVisual / parsed).toStringAsFixed(0);
  final avgDelivery = (sumDelivery / parsed).toStringAsFixed(0);
  final hitRate = (deliveryPriorityHits * 100.0 / parsed).toStringAsFixed(1);
  return 'auto样本 $parsed 条 · 平均 prompt=$avgPrompt chars · memory=$avgMemory (visual=$avgVisual, delivery=$avgDelivery) · delivery优先命中 $hitRate%';
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
        final prompt = row.avgPromptChars.toStringAsFixed(0);
        final base = row.avgNonMemoryPromptChars.toStringAsFixed(0);
        final memory = row.avgMemoryStyleChars.toStringAsFixed(0);
        final share = row.avgMemorySharePercent.toStringAsFixed(1);
        final delivery = row.avgMemoryDeliveryChars.toStringAsFixed(0);
        final deliveryShare = row.avgDeliveryMemorySharePercent.toStringAsFixed(
          1,
        );
        final hitRate = row.deliveryPriorityHitRatePercent.toStringAsFixed(1);
        return '${row.targetType}: prompt=$prompt, base=$base, memory=$memory ($share%, delivery=$delivery/$deliveryShare%, hit=$hitRate%)';
      })
      .join(' | ');
  final suffix = items.length > maxItems ? ' | …' : '';
  return '$visible$suffix';
}

String summarizeQualityTokenEfficiencySamples(
  Iterable<QualityTokenEfficiencySampleRow> rows, {
  int maxItems = 4,
}) {
  final items = rows.toList(growable: false);
  if (items.isEmpty) {
    return '当前没有 token 效率样本';
  }
  final visible = items
      .take(maxItems)
      .map((row) {
        final date = row.createdAt.length >= 16
            ? row.createdAt.substring(5, 16).replaceFirst('T', ' ')
            : row.createdAt;
        final deliveryFlag = row.memoryDeliveryPriorityApplied
            ? 'delivery优先'
            : '常规';
        return '$date ${row.targetType}: prompt=${row.promptChars}, base=${row.nonMemoryPromptChars}, memory=${row.memoryStyleChars} (${row.memorySharePercent.toStringAsFixed(1)}%, $deliveryFlag)';
      })
      .join(' | ');
  final suffix = items.length > maxItems ? ' | …' : '';
  return '$visible$suffix';
}

String summarizeQualityReviews(
  Iterable<QualityReview> rows, {
  int maxItems = 4,
}) {
  final items = rows.toList(growable: false);
  if (items.isEmpty) {
    return '当前没有质量评审';
  }
  final autoCount = items.where((row) => row.source == 'auto').length;
  final visible = items
      .take(maxItems)
      .map((row) {
        final score = row.overallScore?.toString() ?? 'n/a';
        return '${row.targetType}:${row.source}:$score';
      })
      .join(', ');
  final suffix = items.length > maxItems ? '…' : '';
  return '评审 ${items.length} 条 · auto $autoCount 条 · $visible$suffix';
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
