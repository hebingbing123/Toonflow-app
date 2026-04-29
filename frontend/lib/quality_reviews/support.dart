import '../../rust_api.dart';

Map<String, dynamic>? _qualityDiagnosticsMap(QualityReview row) {
  final params = row.modelParams;
  if (params == null) return null;
  final diagnostics = params['diagnostics'];
  if (diagnostics is! Map) return null;
  return Map<String, dynamic>.from(diagnostics);
}

int _diagnosticInt(Map<String, dynamic> map, String key) {
  final value = map[key];
  if (value is num) return value.toInt();
  return 0;
}

String? _diagnosticString(Map<String, dynamic> map, String key) {
  final value = map[key];
  if (value is String && value.isNotEmpty) return value;
  return null;
}

bool _diagnosticBool(Map<String, dynamic> map, String key) => map[key] == true;

List<String> _diagnosticStringList(Map<String, dynamic> map, String key) {
  final value = map[key];
  if (value is! List) return const <String>[];
  return value.whereType<String>().where((item) => item.isNotEmpty).toList();
}

Map<String, int> _diagnosticStringIntMap(Map<String, dynamic> map, String key) {
  final value = map[key];
  if (value is! Map) return const <String, int>{};
  final result = <String, int>{};
  for (final entry in value.entries) {
    final bucket = entry.key;
    final count = entry.value;
    if (bucket is String && bucket.isNotEmpty && count is num && count > 0) {
      result[bucket] = count.toInt();
    }
  }
  return result;
}

String _describeAutoNegativeSource(String source) {
  switch (source) {
    case 'review+rejected_memory':
      return '负向约束=评审+坏例记忆';
    case 'review':
      return '负向约束=近期评审';
    case 'rejected_memory':
      return '负向约束=坏例记忆';
    case 'pending_observation_note':
      return '负向约束=待观察坏例';
    case 'pending_rejected_observation':
      return '负向约束=待观察拒绝项';
    default:
      return '负向约束=$source';
  }
}

String _joinTopBucketCounts(Map<String, int> counts, {int maxItems = 3}) {
  if (counts.isEmpty) return '';
  return (counts.entries.toList()..sort((a, b) => b.value.compareTo(a.value)))
      .take(maxItems)
      .map((entry) => '${entry.key}${entry.value}次')
      .join(' / ');
}

String _joinBucketListWithCounts(
  List<String> buckets,
  Map<String, int> counts,
) {
  if (buckets.isEmpty) return '';
  return buckets
      .map((bucket) {
        final count = counts[bucket];
        return count == null || count <= 1 ? bucket : '$bucket$count次';
      })
      .join('/');
}

String _formatQualityScopeLabel(QualityReview row) {
  if (row.projectId != null && row.scriptId != null) {
    return 'P${row.projectId}/S${row.scriptId}';
  }
  if (row.projectId != null) {
    return 'P${row.projectId}';
  }
  if (row.targetId != null && row.targetId!.isNotEmpty) {
    return row.targetId!;
  }
  return row.targetType;
}

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

String? summarizePromptDiagnosticsFromQualityReviews(
  Iterable<QualityReview> rows, {
  int maxSamples = 16,
}) {
  final samples = rows
      .where((row) => row.source == 'auto')
      .map((row) => _qualityDiagnosticsMap(row))
      .whereType<Map<String, dynamic>>()
      .take(maxSamples)
      .toList(growable: false);
  if (samples.isEmpty) return null;

  var totalPrompt = 0;
  var totalMemory = 0;
  var totalVisual = 0;
  var totalDelivery = 0;
  var deliveryPriorityHits = 0;
  var directorYieldHits = 0;
  var referenceFrameHits = 0;
  var continuityHits = 0;
  final negativeSources = <String, int>{};
  final memoryHitBuckets = <String, int>{};
  final suppressedBuckets = <String, int>{};

  for (final sample in samples) {
    totalPrompt += _diagnosticInt(sample, 'promptChars');
    totalMemory += _diagnosticInt(sample, 'memoryStyleChars');
    totalVisual += _diagnosticInt(sample, 'memoryVisualChars');
    totalDelivery += _diagnosticInt(sample, 'memoryDeliveryChars');
    if (_diagnosticBool(sample, 'memoryDeliveryPriorityApplied')) {
      deliveryPriorityHits += 1;
    }
    if (_diagnosticBool(sample, 'directorManualYieldedToMemory')) {
      directorYieldHits += 1;
    }
    if (_diagnosticBool(sample, 'usesReferenceFrame')) {
      referenceFrameHits += 1;
    }
    if (_diagnosticInt(sample, 'continuityNoteCount') > 0) {
      continuityHits += 1;
    }
    final source = _diagnosticString(sample, 'autoNegativeSource');
    if (source != null) {
      negativeSources.update(source, (count) => count + 1, ifAbsent: () => 1);
    }
    final hitCounts = _diagnosticStringIntMap(sample, 'memoryHitBucketCounts');
    if (hitCounts.isNotEmpty) {
      for (final entry in hitCounts.entries) {
        memoryHitBuckets.update(
          entry.key,
          (count) => count + entry.value,
          ifAbsent: () => entry.value,
        );
      }
    } else {
      for (final bucket in _diagnosticStringList(sample, 'memoryHitBuckets')) {
        memoryHitBuckets.update(
          bucket,
          (count) => count + 1,
          ifAbsent: () => 1,
        );
      }
    }
    final suppressedCounts = _diagnosticStringIntMap(
      sample,
      'memorySuppressedBucketCounts',
    );
    if (suppressedCounts.isNotEmpty) {
      for (final entry in suppressedCounts.entries) {
        suppressedBuckets.update(
          entry.key,
          (count) => count + entry.value,
          ifAbsent: () => entry.value,
        );
      }
    } else {
      for (final bucket in _diagnosticStringList(
        sample,
        'memorySuppressedBuckets',
      )) {
        suppressedBuckets.update(
          bucket,
          (count) => count + 1,
          ifAbsent: () => 1,
        );
      }
    }
  }

  final topNegativeSource = negativeSources.entries.isEmpty
      ? null
      : (negativeSources.entries.toList()
              ..sort((a, b) => b.value.compareTo(a.value)))
            .first;
  final avgPrompt = (totalPrompt / samples.length).toStringAsFixed(0);
  final avgMemory = (totalMemory / samples.length).toStringAsFixed(0);
  final avgVisual = (totalVisual / samples.length).toStringAsFixed(0);
  final avgDelivery = (totalDelivery / samples.length).toStringAsFixed(0);
  final deliveryHitRate = (deliveryPriorityHits * 100.0 / samples.length)
      .toStringAsFixed(1);
  final parts = <String>[
    'auto诊断 ${samples.length} 条',
    '平均 prompt=$avgPrompt chars',
    'memory=$avgMemory (visual=$avgVisual, delivery=$avgDelivery)',
    'delivery优先 $deliveryHitRate%',
  ];
  if (topNegativeSource != null) {
    parts.add(
      '${_describeAutoNegativeSource(topNegativeSource.key)} ${topNegativeSource.value} 次',
    );
  }
  final hitBucketSummary = _joinTopBucketCounts(memoryHitBuckets);
  if (hitBucketSummary.isNotEmpty) {
    parts.add('命中记忆 $hitBucketSummary');
  }
  final suppressedBucketSummary = _joinTopBucketCounts(suppressedBuckets);
  if (suppressedBucketSummary.isNotEmpty) {
    parts.add('压缩桶 $suppressedBucketSummary');
  }
  if (directorYieldHits > 0) {
    parts.add('导演让位 $directorYieldHits/${samples.length}');
  }
  if (continuityHits > 0) {
    parts.add('连续性约束 $continuityHits/${samples.length}');
  }
  if (referenceFrameHits > 0) {
    parts.add('参考帧 $referenceFrameHits/${samples.length}');
  }
  return parts.join(' · ');
}

String? summarizeQualityReviewPromptDiagnostics(QualityReview row) {
  final diagnostics = _qualityDiagnosticsMap(row);
  if (diagnostics == null) return null;

  final promptChars = _diagnosticInt(diagnostics, 'promptChars');
  final memoryChars = _diagnosticInt(diagnostics, 'memoryStyleChars');
  final visualChars = _diagnosticInt(diagnostics, 'memoryVisualChars');
  final deliveryChars = _diagnosticInt(diagnostics, 'memoryDeliveryChars');
  final directorSaved = _diagnosticInt(diagnostics, 'directorAnchorSavedChars');
  final continuityCount = _diagnosticInt(diagnostics, 'continuityNoteCount');
  final parts = <String>[
    'prompt=$promptChars',
    'memory=$memoryChars(v=$visualChars,d=$deliveryChars)',
  ];

  final negativeSource = _diagnosticString(diagnostics, 'autoNegativeSource');
  if (negativeSource != null) {
    parts.add(_describeAutoNegativeSource(negativeSource));
  }
  if (_diagnosticBool(diagnostics, 'memoryDeliveryPriorityApplied')) {
    parts.add('delivery优先');
  }
  final memoryHitBucketCounts = _diagnosticStringIntMap(
    diagnostics,
    'memoryHitBucketCounts',
  );
  final memoryHitBuckets = _diagnosticStringList(
    diagnostics,
    'memoryHitBuckets',
  );
  if (memoryHitBuckets.isNotEmpty) {
    parts.add(
      '命中=${_joinBucketListWithCounts(memoryHitBuckets, memoryHitBucketCounts)}',
    );
  }
  final memorySuppressedBucketCounts = _diagnosticStringIntMap(
    diagnostics,
    'memorySuppressedBucketCounts',
  );
  final memorySuppressedBuckets = _diagnosticStringList(
    diagnostics,
    'memorySuppressedBuckets',
  );
  if (memorySuppressedBuckets.isNotEmpty) {
    parts.add(
      '压缩=${_joinBucketListWithCounts(memorySuppressedBuckets, memorySuppressedBucketCounts)}',
    );
  }
  if (_diagnosticBool(diagnostics, 'directorManualYieldedToMemory')) {
    parts.add('导演让位');
  }
  if (directorSaved > 0) {
    parts.add('省下$directorSaved chars');
  }
  if (continuityCount > 0) {
    parts.add('连续性$continuityCount');
  }
  if (_diagnosticBool(diagnostics, 'usesReferenceFrame')) {
    parts.add('参考帧');
  }
  return parts.join(' · ');
}

String? summarizeMemoryScopePressureFromQualityReviews(
  Iterable<QualityReview> rows, {
  int maxScopes = 3,
}) {
  final scopes =
      <
        String,
        ({int reviews, Map<String, int> hits, Map<String, int> suppressed})
      >{};
  for (final row in rows.where((item) => item.source == 'auto')) {
    final diagnostics = _qualityDiagnosticsMap(row);
    if (diagnostics == null) continue;
    final scope = _formatQualityScopeLabel(row);
    final current =
        scopes[scope] ??
        (reviews: 0, hits: <String, int>{}, suppressed: <String, int>{});
    final nextReviews = current.reviews + 1;
    final nextHits = Map<String, int>.from(current.hits);
    final nextSuppressed = Map<String, int>.from(current.suppressed);

    final hitCounts = _diagnosticStringIntMap(
      diagnostics,
      'memoryHitBucketCounts',
    );
    if (hitCounts.isNotEmpty) {
      for (final entry in hitCounts.entries) {
        nextHits.update(
          entry.key,
          (count) => count + entry.value,
          ifAbsent: () => entry.value,
        );
      }
    }
    final suppressedCounts = _diagnosticStringIntMap(
      diagnostics,
      'memorySuppressedBucketCounts',
    );
    if (suppressedCounts.isNotEmpty) {
      for (final entry in suppressedCounts.entries) {
        nextSuppressed.update(
          entry.key,
          (count) => count + entry.value,
          ifAbsent: () => entry.value,
        );
      }
    }
    if (hitCounts.isEmpty && suppressedCounts.isEmpty) continue;
    scopes[scope] = (
      reviews: nextReviews,
      hits: nextHits,
      suppressed: nextSuppressed,
    );
  }

  if (scopes.isEmpty) return null;
  final items = scopes.entries.toList()
    ..sort((a, b) {
      final aPressure =
          a.value.hits.values.fold<int>(0, (sum, count) => sum + count) +
          a.value.suppressed.values.fold<int>(0, (sum, count) => sum + count);
      final bPressure =
          b.value.hits.values.fold<int>(0, (sum, count) => sum + count) +
          b.value.suppressed.values.fold<int>(0, (sum, count) => sum + count);
      return bPressure.compareTo(aPressure);
    });
  return items
      .take(maxScopes)
      .map((entry) {
        final hitSummary = _joinTopBucketCounts(entry.value.hits, maxItems: 2);
        final suppressedSummary = _joinTopBucketCounts(
          entry.value.suppressed,
          maxItems: 2,
        );
        final parts = <String>['${entry.key} ${entry.value.reviews}条'];
        if (hitSummary.isNotEmpty) {
          parts.add('命中 $hitSummary');
        }
        if (suppressedSummary.isNotEmpty) {
          parts.add('压缩 $suppressedSummary');
        }
        return parts.join(' · ');
      })
      .join(' | ');
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

String formatQualityReviewCoreDetails(QualityReview row) {
  return [
    row.id,
    row.targetType,
    row.source,
    if (row.projectId != null) 'project=${row.projectId}',
    if (row.scriptId != null) 'script=${row.scriptId}',
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

String formatQualityReviewDetails(QualityReview row) {
  final parts = [formatQualityReviewCoreDetails(row)];
  final diagnosticSummary = summarizeQualityReviewPromptDiagnostics(row);
  if (diagnosticSummary != null) {
    parts.add('诊断=$diagnosticSummary');
  }
  return parts.join(' · ');
}
