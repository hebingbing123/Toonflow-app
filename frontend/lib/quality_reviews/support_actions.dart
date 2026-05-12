import '../../rust_api.dart';
import '../l10n/app_localizations.dart';
import 'support_models.dart';

List<String> buildQualityReviewRepairSuggestions(
  QualityReview row, {
  AppLocalizations? l10n,
}) {
  final diagnostics = qualityDiagnosticsMap(row);
  final suggestions = <String>[];
  final tags = <String>{};

  void addTagged(String tag, String suggestion) {
    if (tags.add(tag)) suggestions.add(suggestion);
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
        l10n?.qualityReviewsSuggestionReferenceFrame ??
            'Add reference frame and previous-shot continuity first; lock face, costume/props, and blocking continuity.',
      );
    }
    if (continuityCount > 0 || badCaseCategory.contains('continuity')) {
      addTagged(
        'continuity',
        l10n?.qualityReviewsSuggestionContinuity ??
            'Compress continuity constraints to 1-2 hard rules: camera setup, costume/props, and character positions only.',
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
        l10n?.qualityReviewsSuggestionDelivery ??
            'Keep delivery/tone memory, add performable emotional actions, and do not trim delivery memory first.',
      );
    }
    if (suppressedBuckets.contains('动作') ||
        suppressedBuckets.contains('光影') ||
        promptChars >= 520 ||
        memoryStyleChars >= 96) {
      addTagged(
        'trim_generic',
        l10n?.qualityReviewsSuggestionTrimGeneric ??
            'Continue trimming generic action/lighting lines and reserve budget for expressions, lip sync, and identity continuity.',
      );
    }
    if (autoNegativeSource != null && negativePromptChars > 0) {
      addTagged(
        'negative_reuse',
        l10n?.qualityReviewsSuggestionNegativeReuse ??
            'Reuse existing bad-case negative constraints; dedupe manually added phrases first to avoid repeated token burn.',
      );
    }
    if (diagnosticBool(diagnostics, 'directorManualYieldedToMemory') ||
        directorSaved > 0) {
      addTagged(
        'director_trim',
        l10n?.qualityReviewsSuggestionDirectorTrim ??
            'Director descriptions already yielded to memory; reclaim repeated director lines first and keep key performance anchors.',
      );
    }
    if (projectScopeRows > 0 &&
        scriptScopeRows == 0 &&
        roleScopeRows == 0 &&
        memoryStyleChars >= 48) {
      addTagged(
        'project_scope_trim',
        l10n?.qualityReviewsSuggestionProjectScopeTrim ??
            'Current hits are mostly project-scoped memory; trim generic style lines first and keep character performance details.',
      );
    }
    if (roleScopeRows > 0 &&
        dialogueNaturalness < 85 &&
        comments.contains('情绪')) {
      addTagged(
        'role_scope_keep',
        l10n?.qualityReviewsSuggestionRoleScopeKeep ??
            'Role-scoped memory already hit; strengthen role performance actions first and avoid regressing to generic project copy.',
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
      l10n?.qualityReviewsSuggestionEmotion ??
          'In next round, turn emotional arc into observable actions; avoid explanatory dialogue only.',
    );
  }
  if (row.isBadCase &&
      (badCaseCategory.contains('visual') ||
          badCaseCategory.contains('consistency') ||
          comments.contains('穿帮') ||
          comments.contains('不自然'))) {
    addTagged(
      'visual',
      l10n?.qualityReviewsSuggestionVisual ??
          'Prioritize character appearance and shot realism constraints, then decide whether to add more style descriptions.',
    );
  }
  if (overallScore < 70 && suggestions.isEmpty) {
    addTagged(
      'general',
      l10n?.qualityReviewsSuggestionGeneral ??
          'Lock emotion, continuity, and bad-case constraints first, then run the next generation round.',
    );
  }
  return suggestions;
}

String? summarizeQualityRepairPlanFromReviews(
  Iterable<QualityReview> rows, {
  int maxItems = 3,
  AppLocalizations? l10n,
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
      .map(
        (entry) =>
            l10n?.qualityReviewsRepairPlanCount(entry.key, entry.value) ??
            '${entry.key} ${entry.value} times',
      )
      .join(' | ');
}

String? summarizeQualityTokenEfficiencyActionPlan(
  Iterable<QualityTokenEfficiencyRow> rows, {
  int? projectId,
  int? scriptId,
  int maxItems = 3,
  AppLocalizations? l10n,
}) {
  final items = rows
      .where((row) => row.memoryAction != 'observe')
      .toList(growable: false);
  if (items.isEmpty) return null;

  final scope = () {
    if (projectId != null && scriptId != null) return 'P$projectId/S$scriptId';
    if (projectId != null) return 'P$projectId';
    return l10n?.qualityReviewsCurrentFilterScope ?? 'current filter scope';
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
            return l10n?.qualityReviewsActionPlanKeepDelivery(
                  row.targetType,
                  focus,
                ) ??
                '${row.targetType}: keep delivery/emotion memory from $focus; continue trimming generic style lines before delivery fragments.';
          case 'reuse_negative_memory':
            return l10n?.qualityReviewsActionPlanReuseNegative(
                  row.targetType,
                  focus,
                ) ??
                '${row.targetType}: reuse $focus for bad-case isolation constraints; lock glitches/fakeness before deciding prompt additions.';
          case 'trim_generic_style_memory':
            return l10n?.qualityReviewsActionPlanTrimGeneric(
                  row.targetType,
                  focus,
                ) ??
                '${row.targetType}: prioritize trimming action/lighting/mood filler in $focus; reserve tokens for performance, lip sync, and continuity.';
          case 'promote_selected_memory':
            return l10n?.qualityReviewsActionPlanPromoteSelected(
                  row.targetType,
                  focus,
                ) ??
                '${row.targetType}: promote one high-score sample to $focus; reuse emotion and shot execution while reducing repetitive descriptions.';
          default:
            return null;
        }
      })
      .whereType<String>()
      .join(' | ');
  if (visible.isEmpty) return null;
  return l10n?.qualityReviewsScopedMemorySuggestion(scope, visible) ??
      '$scope scoped-memory suggestion: $visible';
}

String? buildQualityScopedExecutionChecklist({
  required Iterable<QualityReview> reviews,
  Iterable<QualityTokenEfficiencyRow> tokenRows =
      const <QualityTokenEfficiencyRow>[],
  int? projectId,
  int? scriptId,
  int maxItems = 4,
  AppLocalizations? l10n,
}) {
  final steps = <String>{};
  final scope = () {
    if (projectId != null && scriptId != null) return 'P$projectId/S$scriptId';
    if (projectId != null) return 'P$projectId';
    return l10n?.qualityReviewsCurrentFilterScope ?? 'current filter scope';
  }();

  for (final row in tokenRows.where((row) => row.memoryAction != 'observe')) {
    final focus = qualityTokenEfficiencyFocusLabel(row.memoryFocus, l10n: l10n);
    switch (row.memoryAction) {
      case 'keep_delivery_memory':
        steps.add(
          l10n?.qualityReviewsChecklistKeepDelivery(focus) ??
              'Keep performance/tone/lip-sync/emotion memory in $focus, only trim generic style filler.',
        );
        break;
      case 'reuse_negative_memory':
        steps.add(
          l10n?.qualityReviewsChecklistReuseNegative(focus) ??
              'Reuse bad-case constraints in $focus first; lock glitches/fakeness/coldness before deciding prompt additions.',
        );
        break;
      case 'trim_generic_style_memory':
        steps.add(
          l10n?.qualityReviewsChecklistTrimGeneric(focus) ??
              'Remove action/lighting/mood filler in $focus; keep tokens for performance and continuity.',
        );
        break;
      case 'promote_selected_memory':
        steps.add(
          l10n?.qualityReviewsChecklistPromoteSelected(focus) ??
              'Promote high-score samples to $focus; reuse emotion and shot execution while reducing repetitive director copy.',
        );
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
    l10n?.qualityReviewsChecklistTitle(scope) ?? '$scope checklist:',
    for (var i = 0; i < numbered.length; i++) '${i + 1}. ${numbered[i]}',
    l10n?.qualityReviewsChecklistScope(scope) ??
        'Scope: memory takes effect only in $scope; no reuse across users, projects, or shows.',
  ];
  return lines.join('\n');
}
