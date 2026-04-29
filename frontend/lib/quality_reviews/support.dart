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

String? summarizeMemoryOptimizationSavingsFromQualityReviews(
  Iterable<QualityReview> rows, {
  int maxScopes = 3,
}) {
  final scopes =
      <
        String,
        ({
          int reviews,
          int removedRows,
          int removedChars,
          int removedVisualRows,
          int removedDuplicateRows,
        })
      >{};
  for (final row in rows.where((item) => item.source == 'auto')) {
    final diagnostics = _qualityDiagnosticsMap(row);
    if (diagnostics == null) continue;
    final removedChars = _diagnosticInt(
      diagnostics,
      'memoryOptimizationRemovedChars',
    );
    final removedRows = _diagnosticInt(
      diagnostics,
      'memoryOptimizationRemovedRows',
    );
    final removedVisualRows = _diagnosticInt(
      diagnostics,
      'memoryOptimizationRemovedVisualRows',
    );
    final removedDuplicateRows = _diagnosticInt(
      diagnostics,
      'memoryOptimizationRemovedDuplicateRows',
    );
    if (removedChars <= 0 && removedRows <= 0) continue;
    final scope = _formatQualityScopeLabel(row);
    final current =
        scopes[scope] ??
        (
          reviews: 0,
          removedRows: 0,
          removedChars: 0,
          removedVisualRows: 0,
          removedDuplicateRows: 0,
        );
    scopes[scope] = (
      reviews: current.reviews + 1,
      removedRows: current.removedRows + removedRows,
      removedChars: current.removedChars + removedChars,
      removedVisualRows: current.removedVisualRows + removedVisualRows,
      removedDuplicateRows: current.removedDuplicateRows + removedDuplicateRows,
    );
  }

  if (scopes.isEmpty) return null;
  final items = scopes.entries.toList()
    ..sort((a, b) {
      final byChars = b.value.removedChars.compareTo(a.value.removedChars);
      if (byChars != 0) return byChars;
      return b.value.removedRows.compareTo(a.value.removedRows);
    });
  return items
      .take(maxScopes)
      .map((entry) {
        final value = entry.value;
        return '${entry.key} ${value.reviews}条 · slim ${value.removedChars} chars / ${value.removedRows}条'
            '（重复 ${value.removedDuplicateRows} / 纯视觉 ${value.removedVisualRows}）';
      })
      .join(' | ');
}

String? summarizeScopeRepairQueueFromQualityReviews(
  Iterable<QualityReview> rows, {
  int maxScopes = 3,
  int maxSuggestionsPerScope = 2,
}) {
  final scopes =
      <
        String,
        ({
          int reviews,
          int badCases,
          int dialogueRiskHits,
          int visualRiskHits,
          int removedChars,
          Map<String, int> suggestions,
        })
      >{};

  bool hasDialogueRisk(QualityReview row) {
    final comments = (row.comments ?? '').toLowerCase();
    return (row.dialogueNaturalness != null && row.dialogueNaturalness! < 80) ||
        comments.contains('生硬') ||
        comments.contains('朗读') ||
        comments.contains('没情绪') ||
        comments.contains('无情绪');
  }

  bool hasVisualRisk(QualityReview row) {
    final comments = (row.comments ?? '').toLowerCase();
    return (row.visualQuality != null && row.visualQuality! < 80) ||
        comments.contains('穿帮') ||
        comments.contains('不自然') ||
        comments.contains('ai') ||
        comments.contains('假');
  }

  for (final row in rows) {
    final scope = _formatQualityScopeLabel(row);
    final diagnostics = _qualityDiagnosticsMap(row);
    final removedChars = diagnostics == null
        ? 0
        : _diagnosticInt(diagnostics, 'memoryOptimizationRemovedChars');
    final suggestions = buildQualityReviewRepairSuggestions(row);
    final dialogueRisk = hasDialogueRisk(row);
    final visualRisk = hasVisualRisk(row);
    if (!row.isBadCase &&
        suggestions.isEmpty &&
        !dialogueRisk &&
        !visualRisk &&
        removedChars <= 0) {
      continue;
    }
    final current =
        scopes[scope] ??
        (
          reviews: 0,
          badCases: 0,
          dialogueRiskHits: 0,
          visualRiskHits: 0,
          removedChars: 0,
          suggestions: <String, int>{},
        );
    final nextSuggestions = Map<String, int>.from(current.suggestions);
    for (final suggestion in suggestions) {
      nextSuggestions.update(
        suggestion,
        (count) => count + 1,
        ifAbsent: () => 1,
      );
    }
    scopes[scope] = (
      reviews: current.reviews + 1,
      badCases: current.badCases + (row.isBadCase ? 1 : 0),
      dialogueRiskHits: current.dialogueRiskHits + (dialogueRisk ? 1 : 0),
      visualRiskHits: current.visualRiskHits + (visualRisk ? 1 : 0),
      removedChars: current.removedChars + removedChars,
      suggestions: nextSuggestions,
    );
  }

  if (scopes.isEmpty) return null;
  final items = scopes.entries.toList()
    ..sort((a, b) {
      int pressureScore(
        ({
          int reviews,
          int badCases,
          int dialogueRiskHits,
          int visualRiskHits,
          int removedChars,
          Map<String, int> suggestions,
        })
        value,
      ) {
        final suggestionHits = value.suggestions.values.fold<int>(
          0,
          (sum, count) => sum + count,
        );
        return value.badCases * 100 +
            value.dialogueRiskHits * 30 +
            value.visualRiskHits * 30 +
            suggestionHits * 10 +
            value.removedChars;
      }

      return pressureScore(b.value).compareTo(pressureScore(a.value));
    });
  return items
      .take(maxScopes)
      .map((entry) {
        final value = entry.value;
        final rankedSuggestions = value.suggestions.entries.toList()
          ..sort((a, b) {
            final byCount = b.value.compareTo(a.value);
            if (byCount != 0) return byCount;
            return a.key.compareTo(b.key);
          });
        final nextStep = rankedSuggestions
            .take(maxSuggestionsPerScope)
            .map((item) => item.key)
            .join(' / ');
        final parts = <String>[
          '${entry.key} ${value.reviews}条',
          if (value.badCases > 0) '坏例 ${value.badCases}',
          if (value.dialogueRiskHits > 0) '情绪/台词 ${value.dialogueRiskHits}',
          if (value.visualRiskHits > 0) '真实感 ${value.visualRiskHits}',
          if (value.removedChars > 0) 'slim ${value.removedChars} chars',
        ];
        if (nextStep.isNotEmpty) {
          parts.add('下一步 $nextStep');
        }
        return parts.join(' · ');
      })
      .join(' | ');
}

List<String> buildQualityReviewRepairSuggestions(QualityReview row) {
  final diagnostics = _qualityDiagnosticsMap(row);
  final suggestions = <String>[];
  final tags = <String>{};

  void addTagged(String tag, String suggestion) {
    if (tags.add(tag)) suggestions.add(suggestion);
  }

  final badCaseCategory = (row.badCaseCategory ?? '').toLowerCase();
  final comments = (row.comments ?? '').toLowerCase();
  final overallScore = row.overallScore ?? 100;
  final dialogueNaturalness = row.dialogueNaturalness ?? overallScore;
  final visualQuality = row.visualQuality ?? overallScore;

  if (diagnostics != null) {
    final usesReferenceFrame = _diagnosticBool(
      diagnostics,
      'usesReferenceFrame',
    );
    final continuityCount = _diagnosticInt(diagnostics, 'continuityNoteCount');
    final promptChars = _diagnosticInt(diagnostics, 'promptChars');
    final memoryStyleChars = _diagnosticInt(diagnostics, 'memoryStyleChars');
    final negativePromptChars = _diagnosticInt(
      diagnostics,
      'negativePromptChars',
    );
    final directorSaved = _diagnosticInt(
      diagnostics,
      'directorAnchorSavedChars',
    );
    final hitCounts = _diagnosticStringIntMap(
      diagnostics,
      'memoryHitBucketCounts',
    );
    final suppressedCounts = _diagnosticStringIntMap(
      diagnostics,
      'memorySuppressedBucketCounts',
    );
    final autoNegativeSource = _diagnosticString(
      diagnostics,
      'autoNegativeSource',
    );

    final hitBuckets = {
      ..._diagnosticStringList(diagnostics, 'memoryHitBuckets'),
      ...hitCounts.keys,
    };
    final suppressedBuckets = {
      ..._diagnosticStringList(diagnostics, 'memorySuppressedBuckets'),
      ...suppressedCounts.keys,
    };

    if (!usesReferenceFrame &&
        (visualQuality < 80 ||
            continuityCount > 0 ||
            badCaseCategory.contains('continuity'))) {
      addTagged('reference_frame', '先补参考帧和上一镜衔接，锁定脸、服化道和站位连续性。');
    }
    if (continuityCount > 0 || badCaseCategory.contains('continuity')) {
      addTagged('continuity', '把连续性约束压成 1-2 条硬规则，只留机位、服化道和角色位置。');
    }
    if (hitBuckets.contains('表演') ||
        hitBuckets.contains('语气') ||
        dialogueNaturalness < 80 ||
        comments.contains('生硬') ||
        comments.contains('朗读') ||
        comments.contains('没情绪') ||
        comments.contains('无情绪')) {
      addTagged('delivery', '保留表演/语气记忆，补可演的情绪动作，别先删 delivery 记忆。');
    }
    if (suppressedBuckets.contains('动作') ||
        suppressedBuckets.contains('光影') ||
        promptChars >= 520 ||
        memoryStyleChars >= 96) {
      addTagged('trim_generic', '继续压动作/光影这类泛句，把预算留给表情、口型和人物一致性。');
    }
    if (autoNegativeSource != null && negativePromptChars > 0) {
      addTagged('negative_reuse', '沿用现有坏例负向约束，手动补词前先去重，避免同义词重复烧 token。');
    }
    if (_diagnosticBool(diagnostics, 'directorManualYieldedToMemory') ||
        directorSaved > 0) {
      addTagged('director_trim', '导演描述已经让位给记忆，优先回收重复导演句，不动关键表演锚点。');
    }
  }

  if (row.isBadCase &&
      (badCaseCategory.contains('emotion') ||
          badCaseCategory.contains('dialogue') ||
          badCaseCategory.contains('performance') ||
          comments.contains('情绪') ||
          comments.contains('台词'))) {
    addTagged('emotion', '下一轮把情绪弧线写成可观察动作，避免只剩解释性台词。');
  }
  if (row.isBadCase &&
      (badCaseCategory.contains('visual') ||
          badCaseCategory.contains('consistency') ||
          comments.contains('穿帮') ||
          comments.contains('不自然'))) {
    addTagged('visual', '优先补人物外观和镜头真实感约束，再决定是否继续加风格描述。');
  }
  if (overallScore < 70 && suggestions.isEmpty) {
    addTagged('general', '先锁定人物情绪、连续性和坏例约束，再做下一轮生成。');
  }
  return suggestions;
}

String? summarizeQualityRepairPlanFromReviews(
  Iterable<QualityReview> rows, {
  int maxItems = 3,
}) {
  final counts = <String, int>{};
  for (final row in rows) {
    for (final suggestion in buildQualityReviewRepairSuggestions(row)) {
      counts.update(suggestion, (count) => count + 1, ifAbsent: () => 1);
    }
  }
  if (counts.isEmpty) return null;
  final ranked = counts.entries.toList()
    ..sort((a, b) {
      final byCount = b.value.compareTo(a.value);
      if (byCount != 0) return byCount;
      return a.key.compareTo(b.key);
    });
  return ranked
      .take(maxItems)
      .map((entry) => '${entry.key} ${entry.value}次')
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

String summarizeQualityScopeInsightRows(
  Iterable<QualityScopeInsightRow> rows, {
  int maxItems = 3,
}) {
  final items = rows.toList(growable: false);
  if (items.isEmpty) {
    return '当前没有 scope 榜单';
  }
  final visible = items
      .take(maxItems)
      .map((row) {
        final parts = <String>[
          '${row.scopeLabel} ${row.totalReviews}条',
          'pass=${row.passRatePercent.toStringAsFixed(1)}%',
        ];
        if (row.badCaseCount > 0) {
          parts.add('坏例${row.badCaseCount}');
        }
        if (row.dialogueRiskCount > 0) {
          parts.add('情绪${row.dialogueRiskCount}');
        }
        if (row.visualRiskCount > 0) {
          parts.add('真实感${row.visualRiskCount}');
        }
        if (row.autoReviews > 0) {
          parts.add(
            'auto=${row.avgPromptChars.toStringAsFixed(0)}/${row.avgMemoryChars.toStringAsFixed(0)}/${row.avgMemoryDeliveryChars.toStringAsFixed(0)}',
          );
          if (row.memoryRemovedChars > 0 || row.memoryRemovedRows > 0) {
            parts.add(
              'slim ${row.memoryRemovedChars}c/${row.memoryRemovedRows}条',
            );
          }
        }
        return parts.join(' · ');
      })
      .join(' | ');
  final suffix = items.length > maxItems ? ' | …' : '';
  return visible + suffix;
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
  final repairSuggestions = buildQualityReviewRepairSuggestions(row);
  if (repairSuggestions.isNotEmpty) {
    parts.add('建议=${repairSuggestions.join(" / ")}');
  }
  return parts.join(' · ');
}
