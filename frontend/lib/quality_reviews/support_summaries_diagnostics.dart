import '../../rust_api.dart';
import '../l10n/app_localizations.dart';
import 'support_models.dart';

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
