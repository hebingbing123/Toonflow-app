part of 'support.dart';

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
  final negativeSavedChars = _diagnosticInt(diagnostics, 'negativeSavedChars');
  final negativeSavedFragments = _diagnosticInt(
    diagnostics,
    'negativeSavedFragmentCount',
  );
  final projectScopeRows = _diagnosticInt(
    diagnostics,
    'memoryProjectScopeRowCount',
  );
  final scriptScopeRows = _diagnosticInt(
    diagnostics,
    'memoryScriptScopeRowCount',
  );
  final roleScopeRows = _diagnosticInt(diagnostics, 'memoryRoleScopeRowCount');
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
  if (negativeSavedChars > 0 || negativeSavedFragments > 0) {
    parts.add('负向精简=${negativeSavedFragments}条/$negativeSavedChars chars');
  }
  final scopeSummary = _describeMemoryScopeRows(
    projectScopeRows: projectScopeRows,
    scriptScopeRows: scriptScopeRows,
    roleScopeRows: roleScopeRows,
  );
  if (scopeSummary != null) {
    parts.add('记忆层级=$scopeSummary');
  }
  if (continuityCount > 0) {
    parts.add('连续性$continuityCount');
  }
  if (_diagnosticBool(diagnostics, 'usesReferenceFrame')) {
    parts.add('参考帧');
  }
  return parts.join(' · ');
}

String? summarizeQualityReviewMemoryWriteback(QualityReview row) {
  final feedback = _feedbackMemoryMap(row);
  if (feedback == null) return null;

  final action = _diagnosticString(feedback, 'action');
  final memoryName = _diagnosticString(feedback, 'memoryName');
  final clearedMemoryName = _diagnosticString(feedback, 'clearedMemoryName');
  final storyboardId = _diagnosticInt(feedback, 'storyboardId');
  final removedRows = _diagnosticInt(feedback, 'removedRows');
  final removedChars = _diagnosticInt(feedback, 'removedChars');
  final removedVisualRows = _diagnosticInt(feedback, 'removedVisualRows');
  final removedDuplicateRows = _diagnosticInt(feedback, 'removedDuplicateRows');
  final focusTags = _diagnosticStringList(feedback, 'focusTags');

  final parts = <String>[];
  switch (action) {
    case 'promoted_selected_memory':
      parts.add('正向记忆晋升');
      break;
    case 'persisted_rejected_memory':
      parts.add('坏例记忆回写');
      break;
    case 'replaced_summary_memory':
      parts.add('评审摘要回写');
      break;
    case 'promoted_selected_memory_missing_prompt_seed':
      parts.add('正向记忆待补 prompt seed');
      break;
    case 'promoted_selected_memory_empty':
      parts.add('正向记忆未提炼出有效片段');
      break;
    default:
      if (action != null) parts.add(action);
  }
  if (storyboardId > 0) {
    parts.add('镜头$storyboardId');
  }
  if (memoryName != null) {
    parts.add('写入=$memoryName');
  }
  if (clearedMemoryName != null) {
    parts.add('清理=$clearedMemoryName');
  }
  if (removedChars > 0 || removedRows > 0) {
    parts.add(
      'slim ${removedChars} chars / ${removedRows}条'
      '（重复 $removedDuplicateRows / 纯视觉 $removedVisualRows）',
    );
  }
  final focusSummary = _summarizeFeedbackFocusTags(focusTags);
  if (focusSummary != null) {
    parts.add('关注=$focusSummary');
  }
  return parts.isEmpty ? null : parts.join(' · ');
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

