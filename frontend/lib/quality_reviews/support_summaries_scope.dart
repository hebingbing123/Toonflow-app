import '../../rust_api.dart';
import '../l10n/app_localizations.dart';
import 'quality_reviews_l10n.dart';
import 'support_actions.dart';
import 'support_models.dart';

String? summarizeMemoryScopePressureFromQualityReviews(
  Iterable<QualityReview> rows, {
  int maxScopes = 3,
  AppLocalizations? l10n,
}) {
  final loc = qualityReviewsResolveL10n(l10n);
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
          l10n: loc,
        );
        final suppressedSummary = joinTopBucketCounts(
          entry.value.suppressed,
          maxItems: 2,
          l10n: loc,
        );
        final parts = <String>[
          '${entry.key} ${entry.value.reviews}${loc.qualityReviewsItemUnit}',
        ];
        if (hitSummary.isNotEmpty) {
          parts.add(loc.qualityReviewsHitSummary(hitSummary));
        }
        if (suppressedSummary.isNotEmpty) {
          parts.add(loc.qualityReviewsSuppressedSummary(suppressedSummary));
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
  final loc = qualityReviewsResolveL10n(l10n);
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
        return loc.qualityReviewsMemoryOptimizationScopeLine(
          entry.key,
          value.reviews,
          value.removedChars,
          value.removedRows,
          value.removedDuplicateRows,
          value.removedVisualRows,
        );
      })
      .join(' | ');
}

String? summarizeScopeRepairQueueFromQualityReviews(
  Iterable<QualityReview> rows, {
  int maxScopes = 3,
  int maxSuggestionsPerScope = 2,
  AppLocalizations? l10n,
}) {
  final loc = qualityReviewsResolveL10n(l10n);
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
    final suggestions = buildQualityReviewRepairSuggestions(row, l10n: loc);
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
          '${entry.key} ${value.reviews}${loc.qualityReviewsItemUnit}',
          if (value.badCases > 0)
            loc.qualityReviewsBadCaseCount(value.badCases),
          if (value.dialogueRiskHits > 0)
            loc.qualityReviewsDialogueRiskCount(value.dialogueRiskHits),
          if (value.visualRiskHits > 0)
            loc.qualityReviewsVisualRiskCount(value.visualRiskHits),
          if (value.removedChars > 0)
            loc.qualityReviewsMemorySlimming('${value.removedChars}'),
        ];
        if (nextStep.isNotEmpty) {
          parts.add(loc.qualityReviewsNextStep(nextStep));
        }
        return parts.join(' · ');
      })
      .join(' | ');
}
