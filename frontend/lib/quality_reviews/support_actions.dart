import '../../rust_api.dart';
import '../l10n/app_localizations.dart';
import 'enum_labels.dart';
import 'support_models.dart';

String? describeSuggestedRepairAction(
  String? action, {
  required AppLocalizations l10n,
}) {
  final hint = qualitySuggestedActionRepairHint(action ?? '', l10n);
  if (hint != null) {
    return hint;
  }
  final trimmed = action?.trim();
  if (trimmed == null || trimmed.isEmpty) {
    return null;
  }
  return qualitySuggestedActionLabel(trimmed, l10n);
}

List<String> buildQualityReviewRepairSuggestions(
  QualityReview row, {
  required AppLocalizations l10n,
}) {
  final diagnostics = qualityDiagnosticsMap(row);
  final suggestions = <String>[];
  final tags = <String>{};

  void addTagged(String tag, String suggestion) {
    if (tags.add(tag)) suggestions.add(suggestion);
  }

  final suggestedRepair = describeSuggestedRepairAction(
    row.suggestedAction,
    l10n: l10n,
  );
  if (suggestedRepair != null) {
    addTagged('suggested_action', suggestedRepair);
  }

  final badCaseCategory = (row.badCaseCategory ?? '').toLowerCase();
  final comments = (row.comments ?? '').toLowerCase();
  final overallScore = qualityScorePercent(row.overallScore);
  final dialogueNaturalness = qualityScorePercent(
    row.dialogueNaturalness,
    fallback: row.overallScore ?? 10,
  );
  final visualQuality = qualityScorePercent(
    row.visualQuality,
    fallback: row.overallScore ?? 10,
  );

  if (diagnostics != null) {
    final usesReferenceFrame = diagnosticBool(
      diagnostics,
      'usesReferenceFrame',
    );
    final continuityCount = diagnosticInt(diagnostics, 'continuityNoteCount');
    final promptChars = diagnosticInt(diagnostics, 'promptChars');
    final memoryStyleChars = diagnosticInt(diagnostics, 'memoryStyleChars');
    final negativePromptChars = diagnosticInt(
      diagnostics,
      'negativePromptChars',
    );
    final directorSaved = diagnosticInt(
      diagnostics,
      'directorAnchorSavedChars',
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
    final hitCounts = diagnosticStringIntMap(
      diagnostics,
      'memoryHitBucketCounts',
    );
    final suppressedCounts = diagnosticStringIntMap(
      diagnostics,
      'memorySuppressedBucketCounts',
    );
    final autoNegativeSource = diagnosticString(
      diagnostics,
      'autoNegativeSource',
    );

    final hitBuckets = {
      ...diagnosticStringList(diagnostics, 'memoryHitBuckets'),
      ...hitCounts.keys,
    };
    final suppressedBuckets = {
      ...diagnosticStringList(diagnostics, 'memorySuppressedBuckets'),
      ...suppressedCounts.keys,
    };

    if (!usesReferenceFrame &&
        (visualQuality < 80 ||
            continuityCount > 0 ||
            badCaseCategory.contains('continuity'))) {
      addTagged(
        'reference_frame',
        l10n.qualityReviewsSuggestionReferenceFrame,
      );
    }
    if (continuityCount > 0 || badCaseCategory.contains('continuity')) {
      addTagged(
        'continuity',
        l10n.qualityReviewsSuggestionContinuity,
      );
    }
    if (hitBuckets.contains('表演') ||
        hitBuckets.contains('语气') ||
        dialogueNaturalness < 80 ||
        comments.contains('生硬') ||
        comments.contains('朗读') ||
        comments.contains('没情绪') ||
        comments.contains('无情绪')) {
      addTagged(
        'delivery',
        l10n.qualityReviewsSuggestionDelivery,
      );
    }
    if (suppressedBuckets.contains('动作') ||
        suppressedBuckets.contains('光影') ||
        promptChars >= 520 ||
        memoryStyleChars >= 96) {
      addTagged(
        'trim_generic',
        l10n.qualityReviewsSuggestionTrimGeneric,
      );
    }
    if (autoNegativeSource != null && negativePromptChars > 0) {
      addTagged(
        'negative_reuse',
        l10n.qualityReviewsSuggestionNegativeReuse,
      );
    }
    if (diagnosticBool(diagnostics, 'directorManualYieldedToMemory') ||
        directorSaved > 0) {
      addTagged(
        'director_trim',
        l10n.qualityReviewsSuggestionDirectorTrim,
      );
    }
    if (projectScopeRows > 0 &&
        scriptScopeRows == 0 &&
        roleScopeRows == 0 &&
        memoryStyleChars >= 48) {
      addTagged(
        'project_scope_trim',
        l10n.qualityReviewsSuggestionProjectScopeTrim,
      );
    }
    if (roleScopeRows > 0 &&
        dialogueNaturalness < 85 &&
        comments.contains('情绪')) {
      addTagged(
        'role_scope_keep',
        l10n.qualityReviewsSuggestionRoleScopeKeep,
      );
    }
  }

  if (row.isBadCase &&
      (badCaseCategory.contains('emotion') ||
          badCaseCategory.contains('dialogue') ||
          badCaseCategory.contains('performance') ||
          comments.contains('情绪') ||
          comments.contains('台词'))) {
    addTagged(
      'emotion',
      l10n.qualityReviewsSuggestionEmotion,
    );
  }
  if (row.isBadCase &&
      (badCaseCategory.contains('visual') ||
          badCaseCategory.contains('consistency') ||
          comments.contains('穿帮') ||
          comments.contains('不自然'))) {
    addTagged(
      'visual',
      l10n.qualityReviewsSuggestionVisual,
    );
  }
  if (overallScore < 70 && suggestions.isEmpty) {
    addTagged(
      'general',
      l10n.qualityReviewsSuggestionGeneral,
    );
  }
  return suggestions;
}

String? summarizeQualityRepairPlanFromReviews(
  Iterable<QualityReview> rows, {
  int maxItems = 3,
  required AppLocalizations l10n,
}) {
  final counts = <String, int>{};
  for (final row in rows) {
    for (final suggestion in buildQualityReviewRepairSuggestions(
      row,
      l10n: l10n,
    )) {
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
      .map((entry) => l10n.qualityReviewsRepairPlanCount(entry.key, entry.value))
      .join(' | ');
}

String? summarizeSuggestedActionHotspotsFromReviews(
  Iterable<QualityReview> rows, {
  int maxItems = 4,
  required AppLocalizations l10n,
}) {
  final counts = <String, int>{};
  for (final row in rows) {
    final action = row.suggestedAction?.trim();
    if (action == null || action.isEmpty) continue;
    counts.update(action, (count) => count + 1, ifAbsent: () => 1);
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
      .map((entry) {
        final summary = describeSuggestedRepairAction(entry.key, l10n: l10n);
        final label = summary ?? qualitySuggestedActionLabel(entry.key, l10n);
        return l10n.qualityReviewsHotspotCount(label, entry.value);
      })
      .join(' | ');
}

String? summarizeQualityTokenEfficiencyActionPlan(
  Iterable<QualityTokenEfficiencyRow> rows, {
  int? projectId,
  int? scriptId,
  int maxItems = 3,
  required AppLocalizations l10n,
}) {
  final items = rows
      .where((row) => row.memoryAction != 'observe')
      .toList(growable: false);
  if (items.isEmpty) return null;

  final scope = () {
    if (projectId != null && scriptId != null) return 'P$projectId/S$scriptId';
    if (projectId != null) return 'P$projectId';
    return l10n.qualityReviewsCurrentFilterScope;
  }();

  final ranked = items.toList()
    ..sort((a, b) {
      final priority = qualityTokenEfficiencyActionPriority(
        b.memoryAction,
      ).compareTo(qualityTokenEfficiencyActionPriority(a.memoryAction));
      if (priority != 0) return priority;
      return b.sampleCount.compareTo(a.sampleCount);
    });

  final visible = ranked
      .take(maxItems)
      .map((row) {
        final focus = qualityTokenEfficiencyFocusLabel(
          row.memoryFocus,
          l10n: l10n,
        );
        switch (row.memoryAction) {
          case 'keep_delivery_memory':
            return l10n.qualityReviewsActionPlanKeepDelivery(
              row.targetType,
              focus,
            );
          case 'reuse_negative_memory':
            return l10n.qualityReviewsActionPlanReuseNegative(
              row.targetType,
              focus,
            );
          case 'trim_generic_style_memory':
            return l10n.qualityReviewsActionPlanTrimGeneric(
              row.targetType,
              focus,
            );
          case 'promote_selected_memory':
            return l10n.qualityReviewsActionPlanPromoteSelected(
              row.targetType,
              focus,
            );
          default:
            return null;
        }
      })
      .whereType<String>()
      .join(' | ');
  if (visible.isEmpty) return null;
  return l10n.qualityReviewsScopedMemorySuggestion(scope, visible);
}

String? buildQualityScopedExecutionChecklist({
  required Iterable<QualityReview> reviews,
  Iterable<QualityTokenEfficiencyRow> tokenRows =
      const <QualityTokenEfficiencyRow>[],
  int? projectId,
  int? scriptId,
  int maxItems = 4,
  required AppLocalizations l10n,
}) {
  final steps = <String>{};
  final scope = () {
    if (projectId != null && scriptId != null) return 'P$projectId/S$scriptId';
    if (projectId != null) return 'P$projectId';
    return l10n.qualityReviewsCurrentFilterScope;
  }();

  for (final row in tokenRows.where((row) => row.memoryAction != 'observe')) {
    final focus = qualityTokenEfficiencyFocusLabel(row.memoryFocus, l10n: l10n);
    switch (row.memoryAction) {
      case 'keep_delivery_memory':
        steps.add(l10n.qualityReviewsChecklistKeepDelivery(focus));
        break;
      case 'reuse_negative_memory':
        steps.add(l10n.qualityReviewsChecklistReuseNegative(focus));
        break;
      case 'trim_generic_style_memory':
        steps.add(l10n.qualityReviewsChecklistTrimGeneric(focus));
        break;
      case 'promote_selected_memory':
        steps.add(l10n.qualityReviewsChecklistPromoteSelected(focus));
        break;
    }
    if (steps.length >= maxItems) break;
  }

  final suggestionCounts = <String, int>{};
  for (final review in reviews) {
    for (final suggestion in buildQualityReviewRepairSuggestions(
      review,
      l10n: l10n,
    )) {
      suggestionCounts.update(
        suggestion,
        (count) => count + 1,
        ifAbsent: () => 1,
      );
    }
  }
  final rankedSuggestions = suggestionCounts.entries.toList()
    ..sort((a, b) {
      final byCount = b.value.compareTo(a.value);
      if (byCount != 0) return byCount;
      return a.key.compareTo(b.key);
    });
  for (final entry in rankedSuggestions) {
    if (steps.length >= maxItems) break;
    steps.add(entry.key);
  }

  if (steps.isEmpty) return null;

  final numbered = steps.take(maxItems).toList(growable: false);
  final lines = <String>[
    l10n.qualityReviewsChecklistTitle(scope),
    for (var i = 0; i < numbered.length; i++) '${i + 1}. ${numbered[i]}',
    l10n.qualityReviewsChecklistScope(scope),
  ];
  return lines.join('\n');
}
