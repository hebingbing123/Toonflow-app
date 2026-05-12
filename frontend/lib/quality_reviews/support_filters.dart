import '../../rust_api.dart';
import '../l10n/app_localizations.dart';
import 'support_models.dart';
import 'support_actions.dart';

String? summarizeTokenEfficiencyFromQualityReviews(
  Iterable<QualityReview> rows, {
  int maxSamples = 40,
  AppLocalizations? l10n,
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
  return l10n?.qualityReviewsAutoSampleSummary(
        parsed,
        avgPrompt,
        avgMemory,
        avgVisual,
        avgDelivery,
        hitRate,
      ) ??
      'auto samples $parsed · avg prompt=$avgPrompt chars · memory=$avgMemory (visual=$avgVisual, delivery=$avgDelivery) · delivery-priority hit $hitRate%';
}

String? summarizePromptDiagnosticsFromQualityReviews(
  Iterable<QualityReview> rows, {
  int maxSamples = 16,
  AppLocalizations? l10n,
}) {
  final samples = rows
      .where((row) => row.source == 'auto')
      .map((row) => qualityDiagnosticsMap(row))
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
    totalPrompt += diagnosticInt(sample, 'promptChars');
    totalMemory += diagnosticInt(sample, 'memoryStyleChars');
    totalVisual += diagnosticInt(sample, 'memoryVisualChars');
    totalDelivery += diagnosticInt(sample, 'memoryDeliveryChars');
    if (diagnosticBool(sample, 'memoryDeliveryPriorityApplied')) {
      deliveryPriorityHits += 1;
    }
    if (diagnosticBool(sample, 'directorManualYieldedToMemory')) {
      directorYieldHits += 1;
    }
    if (diagnosticBool(sample, 'usesReferenceFrame')) {
      referenceFrameHits += 1;
    }
    if (diagnosticInt(sample, 'continuityNoteCount') > 0) {
      continuityHits += 1;
    }
    final source = diagnosticString(sample, 'autoNegativeSource');
    if (source != null) {
      negativeSources.update(source, (count) => count + 1, ifAbsent: () => 1);
    }
    final hitCounts = diagnosticStringIntMap(sample, 'memoryHitBucketCounts');
    if (hitCounts.isNotEmpty) {
      for (final entry in hitCounts.entries) {
        memoryHitBuckets.update(
          entry.key,
          (count) => count + entry.value,
          ifAbsent: () => entry.value,
        );
      }
    } else {
      for (final bucket in diagnosticStringList(sample, 'memoryHitBuckets')) {
        memoryHitBuckets.update(
          bucket,
          (count) => count + 1,
          ifAbsent: () => 1,
        );
      }
    }
    final suppressedCounts = diagnosticStringIntMap(
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
      for (final bucket in diagnosticStringList(
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
    l10n?.qualityReviewsAutoDiagnosticsCount(samples.length) ??
        'auto diagnostics ${samples.length}',
    l10n?.qualityReviewsAveragePrompt(avgPrompt) ??
        'avg prompt=$avgPrompt chars',
    'memory=$avgMemory (visual=$avgVisual, delivery=$avgDelivery)',
    l10n?.qualityReviewsDeliveryPriorityRate(deliveryHitRate) ??
        'delivery-priority $deliveryHitRate%',
  ];
  if (topNegativeSource != null) {
    parts.add(
      '${describeAutoNegativeSource(topNegativeSource.key, l10n: l10n)} ${topNegativeSource.value}${l10n?.qualityReviewsTimesUnit ?? ' times'}',
    );
  }
  final hitBucketSummary = joinTopBucketCounts(memoryHitBuckets, l10n: l10n);
  if (hitBucketSummary.isNotEmpty) {
    parts.add(
      l10n?.qualityReviewsHitMemoryBuckets(hitBucketSummary) ??
          'hit memory $hitBucketSummary',
    );
  }
  final suppressedBucketSummary = joinTopBucketCounts(
    suppressedBuckets,
    l10n: l10n,
  );
  if (suppressedBucketSummary.isNotEmpty) {
    parts.add(
      l10n?.qualityReviewsSuppressedBuckets(suppressedBucketSummary) ??
          'suppressed buckets $suppressedBucketSummary',
    );
  }
  if (directorYieldHits > 0) {
    parts.add(
      l10n?.qualityReviewsDirectorYieldCount(
            directorYieldHits,
            samples.length,
          ) ??
          'director yield $directorYieldHits/${samples.length}',
    );
  }
  if (continuityHits > 0) {
    parts.add(
      l10n?.qualityReviewsContinuityConstraintCount(
            continuityHits,
            samples.length,
          ) ??
          'continuity constraints $continuityHits/${samples.length}',
    );
  }
  if (referenceFrameHits > 0) {
    parts.add(
      l10n?.qualityReviewsReferenceFrameCount(
            referenceFrameHits,
            samples.length,
          ) ??
          'reference frame $referenceFrameHits/${samples.length}',
    );
  }
  return parts.join(' · ');
}

String? summarizeQualityReviewPromptDiagnostics(
  QualityReview row, {
  AppLocalizations? l10n,
}) {
  final diagnostics = qualityDiagnosticsMap(row);
  if (diagnostics == null) return null;

  final promptChars = diagnosticInt(diagnostics, 'promptChars');
  final memoryChars = diagnosticInt(diagnostics, 'memoryStyleChars');
  final visualChars = diagnosticInt(diagnostics, 'memoryVisualChars');
  final deliveryChars = diagnosticInt(diagnostics, 'memoryDeliveryChars');
  final directorSaved = diagnosticInt(diagnostics, 'directorAnchorSavedChars');
  final continuityCount = diagnosticInt(diagnostics, 'continuityNoteCount');
  final negativeSavedChars = diagnosticInt(diagnostics, 'negativeSavedChars');
  final negativeSavedFragments = diagnosticInt(
    diagnostics,
    'negativeSavedFragmentCount',
  );
  final projectScopeRows = diagnosticInt(
    diagnostics,
    'memoryProjectScopeRowCount',
  );
  final scriptScopeRows = diagnosticInt(
    diagnostics,
    'memoryScriptScopeRowCount',
  );
  final roleScopeRows = diagnosticInt(diagnostics, 'memoryRoleScopeRowCount');
  final parts = <String>[
    'prompt=$promptChars',
    'memory=$memoryChars(v=$visualChars,d=$deliveryChars)',
  ];

  final negativeSource = diagnosticString(diagnostics, 'autoNegativeSource');
  if (negativeSource != null) {
    parts.add(describeAutoNegativeSource(negativeSource, l10n: l10n));
  }
  if (diagnosticBool(diagnostics, 'memoryDeliveryPriorityApplied')) {
    parts.add(l10n?.qualityReviewsDeliveryPriority ?? 'delivery-priority');
  }
  final memoryHitBucketCounts = diagnosticStringIntMap(
    diagnostics,
    'memoryHitBucketCounts',
  );
  final memoryHitBuckets = diagnosticStringList(
    diagnostics,
    'memoryHitBuckets',
  );
  if (memoryHitBuckets.isNotEmpty) {
    parts.add(
      l10n?.qualityReviewsHitBucketsInline(
            joinBucketListWithCounts(
              memoryHitBuckets,
              memoryHitBucketCounts,
              l10n: l10n,
            ),
          ) ??
          'hit=${joinBucketListWithCounts(memoryHitBuckets, memoryHitBucketCounts, l10n: l10n)}',
    );
  }
  final memorySuppressedBucketCounts = diagnosticStringIntMap(
    diagnostics,
    'memorySuppressedBucketCounts',
  );
  final memorySuppressedBuckets = diagnosticStringList(
    diagnostics,
    'memorySuppressedBuckets',
  );
  if (memorySuppressedBuckets.isNotEmpty) {
    parts.add(
      l10n?.qualityReviewsSuppressedBucketsInline(
            joinBucketListWithCounts(
              memorySuppressedBuckets,
              memorySuppressedBucketCounts,
              l10n: l10n,
            ),
          ) ??
          'suppressed=${joinBucketListWithCounts(memorySuppressedBuckets, memorySuppressedBucketCounts, l10n: l10n)}',
    );
  }
  if (diagnosticBool(diagnostics, 'directorManualYieldedToMemory')) {
    parts.add(l10n?.qualityReviewsDirectorYield ?? 'director yield');
  }
  if (directorSaved > 0) {
    parts.add(
      l10n?.qualityReviewsSavedChars(directorSaved) ??
          'saved $directorSaved chars',
    );
  }
  if (negativeSavedChars > 0 || negativeSavedFragments > 0) {
    parts.add(
      l10n?.qualityReviewsNegativeSlim(
            negativeSavedFragments,
            negativeSavedChars,
          ) ??
          'negative slim=$negativeSavedFragments items/$negativeSavedChars chars',
    );
  }
  final scopeSummary = describeMemoryScopeRows(
    projectScopeRows: projectScopeRows,
    scriptScopeRows: scriptScopeRows,
    roleScopeRows: roleScopeRows,
  );
  if (scopeSummary != null) {
    parts.add(
      l10n?.qualityReviewsMemoryScopeLevel(scopeSummary) ??
          'memory scope=$scopeSummary',
    );
  }
  if (continuityCount > 0) {
    parts.add(
      l10n?.qualityReviewsContinuityCount(continuityCount) ??
          'continuity $continuityCount',
    );
  }
  if (diagnosticBool(diagnostics, 'usesReferenceFrame')) {
    parts.add(l10n?.qualityReviewsReferenceFrame ?? 'reference frame');
  }
  return parts.join(' · ');
}

String? summarizeQualityReviewMemoryWriteback(
  QualityReview row, {
  AppLocalizations? l10n,
}) {
  final feedback = feedbackMemoryMap(row);
  if (feedback == null) return null;

  final action = diagnosticString(feedback, 'action');
  final memoryName = diagnosticString(feedback, 'memoryName');
  final clearedMemoryName = diagnosticString(feedback, 'clearedMemoryName');
  final storyboardId = diagnosticInt(feedback, 'storyboardId');
  final removedRows = diagnosticInt(feedback, 'removedRows');
  final removedChars = diagnosticInt(feedback, 'removedChars');
  final removedVisualRows = diagnosticInt(feedback, 'removedVisualRows');
  final removedDuplicateRows = diagnosticInt(feedback, 'removedDuplicateRows');
  final focusTags = diagnosticStringList(feedback, 'focusTags');

  final parts = <String>[];
  switch (action) {
    case 'promoted_selected_memory':
      parts.add(
        l10n?.qualityReviewsWritebackPromotedSelected ??
            'promoted selected memory',
      );
      break;
    case 'persisted_rejected_memory':
      parts.add(
        l10n?.qualityReviewsWritebackRejectedMemory ??
            'bad-case memory writeback',
      );
      break;
    case 'replaced_summary_memory':
      parts.add(
        l10n?.qualityReviewsWritebackSummaryMemory ??
            'review summary writeback',
      );
      break;
    case 'promoted_selected_memory_missing_prompt_seed':
      parts.add(
        l10n?.qualityReviewsWritebackMissingPromptSeed ??
            'selected memory missing prompt seed',
      );
      break;
    case 'promoted_selected_memory_empty':
      parts.add(
        l10n?.qualityReviewsWritebackEmptySelectedMemory ??
            'selected memory yielded no effective fragment',
      );
      break;
    default:
      if (action != null) parts.add(action);
  }
  if (storyboardId > 0) {
    parts.add(l10n?.qualityReviewsShotId(storyboardId) ?? 'shot $storyboardId');
  }
  if (memoryName != null) {
    parts.add(
      l10n?.qualityReviewsWriteMemory(memoryName) ?? 'write=$memoryName',
    );
  }
  if (clearedMemoryName != null) {
    parts.add(
      l10n?.qualityReviewsClearMemory(clearedMemoryName) ??
          'clear=$clearedMemoryName',
    );
  }
  if (removedChars > 0 || removedRows > 0) {
    parts.add(
      l10n?.qualityReviewsSlimSummary(
            removedChars,
            removedRows,
            removedDuplicateRows,
            removedVisualRows,
          ) ??
          'slim $removedChars chars / $removedRows items (dup $removedDuplicateRows / visual-only $removedVisualRows)',
    );
  }
  final focusSummary = summarizeFeedbackFocusTags(focusTags, l10n: l10n);
  if (focusSummary != null) {
    parts.add(
      l10n?.qualityReviewsFocusWatchTag(focusSummary) ?? 'watch=$focusSummary',
    );
  }
  return parts.isEmpty ? null : parts.join(' · ');
}

String? summarizeMemoryScopePressureFromQualityReviews(
  Iterable<QualityReview> rows, {
  int maxScopes = 3,
  AppLocalizations? l10n,
}) {
  final scopes =
      <
        String,
        ({int reviews, Map<String, int> hits, Map<String, int> suppressed})
      >{};
  for (final row in rows.where((item) => item.source == 'auto')) {
    final diagnostics = qualityDiagnosticsMap(row);
    if (diagnostics == null) continue;
    final scope = formatQualityScopeLabel(row);
    final current =
        scopes[scope] ??
        (reviews: 0, hits: <String, int>{}, suppressed: <String, int>{});
    final nextReviews = current.reviews + 1;
    final nextHits = Map<String, int>.from(current.hits);
    final nextSuppressed = Map<String, int>.from(current.suppressed);

    final hitCounts = diagnosticStringIntMap(
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
    final suppressedCounts = diagnosticStringIntMap(
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
        final hitSummary = joinTopBucketCounts(
          entry.value.hits,
          maxItems: 2,
          l10n: l10n,
        );
        final suppressedSummary = joinTopBucketCounts(
          entry.value.suppressed,
          maxItems: 2,
          l10n: l10n,
        );
        final parts = <String>[
          '${entry.key} ${entry.value.reviews}${l10n?.qualityReviewsItemUnit ?? ' items'}',
        ];
        if (hitSummary.isNotEmpty) {
          parts.add(
            l10n?.qualityReviewsHitSummary(hitSummary) ?? 'hit $hitSummary',
          );
        }
        if (suppressedSummary.isNotEmpty) {
          parts.add(
            l10n?.qualityReviewsSuppressedSummary(suppressedSummary) ??
                'suppressed $suppressedSummary',
          );
        }
        return parts.join(' · ');
      })
      .join(' | ');
}

String? summarizeMemoryOptimizationSavingsFromQualityReviews(
  Iterable<QualityReview> rows, {
  int maxScopes = 3,
  AppLocalizations? l10n,
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
    final diagnostics = qualityDiagnosticsMap(row);
    if (diagnostics == null) continue;
    final removedChars = diagnosticInt(
      diagnostics,
      'memoryOptimizationRemovedChars',
    );
    final removedRows = diagnosticInt(
      diagnostics,
      'memoryOptimizationRemovedRows',
    );
    final removedVisualRows = diagnosticInt(
      diagnostics,
      'memoryOptimizationRemovedVisualRows',
    );
    final removedDuplicateRows = diagnosticInt(
      diagnostics,
      'memoryOptimizationRemovedDuplicateRows',
    );
    if (removedChars <= 0 && removedRows <= 0) continue;
    final scope = formatQualityScopeLabel(row);
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
        return l10n?.qualityReviewsMemoryOptimizationScopeLine(
              entry.key,
              value.reviews,
              value.removedChars,
              value.removedRows,
              value.removedDuplicateRows,
              value.removedVisualRows,
            ) ??
            '${entry.key} ${value.reviews} items · slim ${value.removedChars} chars / ${value.removedRows} items (dup ${value.removedDuplicateRows} / visual-only ${value.removedVisualRows})';
      })
      .join(' | ');
}

String? summarizeScopeRepairQueueFromQualityReviews(
  Iterable<QualityReview> rows, {
  int maxScopes = 3,
  int maxSuggestionsPerScope = 2,
  AppLocalizations? l10n,
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
    return (row.dialogueNaturalness != null &&
            qualityScorePercent(row.dialogueNaturalness) < 80) ||
        comments.contains('生硬') ||
        comments.contains('朗读') ||
        comments.contains('没情绪') ||
        comments.contains('无情绪');
  }

  bool hasVisualRisk(QualityReview row) {
    final comments = (row.comments ?? '').toLowerCase();
    return (row.visualQuality != null &&
            qualityScorePercent(row.visualQuality) < 80) ||
        comments.contains('穿帮') ||
        comments.contains('不自然') ||
        comments.contains('ai') ||
        comments.contains('假');
  }

  for (final row in rows) {
    final scope = formatQualityScopeLabel(row);
    final diagnostics = qualityDiagnosticsMap(row);
    final removedChars = diagnostics == null
        ? 0
        : diagnosticInt(diagnostics, 'memoryOptimizationRemovedChars');
    final suggestions = buildQualityReviewRepairSuggestions(row, l10n: l10n);
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
          '${entry.key} ${value.reviews}${l10n?.qualityReviewsItemUnit ?? ' items'}',
          if (value.badCases > 0)
            l10n?.qualityReviewsBadCaseCount(value.badCases) ??
                'bad cases ${value.badCases}',
          if (value.dialogueRiskHits > 0)
            l10n?.qualityReviewsDialogueRiskCount(value.dialogueRiskHits) ??
                'emotion/dialogue ${value.dialogueRiskHits}',
          if (value.visualRiskHits > 0)
            l10n?.qualityReviewsVisualRiskCount(value.visualRiskHits) ??
                'realism ${value.visualRiskHits}',
          if (value.removedChars > 0) 'slim ${value.removedChars} chars',
        ];
        if (nextStep.isNotEmpty) {
          parts.add(
            l10n?.qualityReviewsNextStep(nextStep) ?? 'next step $nextStep',
          );
        }
        return parts.join(' · ');
      })
      .join(' | ');
}
