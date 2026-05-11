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
    final roleScopeRows = diagnosticInt(
      diagnostics,
      'memoryRoleScopeRowCount',
    );
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
            '先补参考帧和上一镜衔接，锁定脸、服化道和站位连续性。',
      );
    }
    if (continuityCount > 0 || badCaseCategory.contains('continuity')) {
      addTagged(
        'continuity',
        l10n?.qualityReviewsSuggestionContinuity ??
            '把连续性约束压成 1-2 条硬规则，只留机位、服化道和角色位置。',
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
            '保留表演/语气记忆，补可演的情绪动作，别先删 delivery 记忆。',
      );
    }
    if (suppressedBuckets.contains('动作') ||
        suppressedBuckets.contains('光影') ||
        promptChars >= 520 ||
        memoryStyleChars >= 96) {
      addTagged(
        'trim_generic',
        l10n?.qualityReviewsSuggestionTrimGeneric ??
            '继续压动作/光影这类泛句，把预算留给表情、口型和人物一致性。',
      );
    }
    if (autoNegativeSource != null && negativePromptChars > 0) {
      addTagged(
        'negative_reuse',
        l10n?.qualityReviewsSuggestionNegativeReuse ??
            '沿用现有坏例负向约束，手动补词前先去重，避免同义词重复烧 token。',
      );
    }
    if (diagnosticBool(diagnostics, 'directorManualYieldedToMemory') ||
        directorSaved > 0) {
      addTagged(
        'director_trim',
        l10n?.qualityReviewsSuggestionDirectorTrim ??
            '导演描述已经让位给记忆，优先回收重复导演句，不动关键表演锚点。',
      );
    }
    if (projectScopeRows > 0 &&
        scriptScopeRows == 0 &&
        roleScopeRows == 0 &&
        memoryStyleChars >= 48) {
      addTagged(
        'project_scope_trim',
        l10n?.qualityReviewsSuggestionProjectScopeTrim ??
            '当前主要命中项目级记忆，继续压词时先缩通用风格句，别动人物表演。',
      );
    }
    if (roleScopeRows > 0 &&
        dialogueNaturalness < 85 &&
        comments.contains('情绪')) {
      addTagged(
        'role_scope_keep',
        l10n?.qualityReviewsSuggestionRoleScopeKeep ??
            '已经命中角色级记忆，优先加强角色表演动作，不要回退成泛项目描述。',
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
          '下一轮把情绪弧线写成可观察动作，避免只剩解释性台词。',
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
          '优先补人物外观和镜头真实感约束，再决定是否继续加风格描述。',
    );
  }
  if (overallScore < 70 && suggestions.isEmpty) {
    addTagged(
      'general',
      l10n?.qualityReviewsSuggestionGeneral ??
          '先锁定人物情绪、连续性和坏例约束，再做下一轮生成。',
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
    for (final suggestion in buildQualityReviewRepairSuggestions(row, l10n: l10n)) {
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
            '${entry.key} ${entry.value}次',
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
    return l10n?.qualityReviewsCurrentFilterScope ?? '当前筛选范围';
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
        final focus = qualityTokenEfficiencyFocusLabel(row.memoryFocus, l10n: l10n);
        switch (row.memoryAction) {
          case 'keep_delivery_memory':
            return l10n?.qualityReviewsActionPlanKeepDelivery(row.targetType, focus) ??
                '${row.targetType} 保留$focus的表演/情绪记忆，继续压泛风格句，别先删 delivery 片段。';
          case 'reuse_negative_memory':
            return l10n?.qualityReviewsActionPlanReuseNegative(row.targetType, focus) ??
                '${row.targetType} 先复用$focus做坏例隔离约束，锁住穿帮/假感后再决定是否补 prompt。';
          case 'trim_generic_style_memory':
            return l10n?.qualityReviewsActionPlanTrimGeneric(row.targetType, focus) ??
                '${row.targetType} 优先压$focus里的动作/光影/氛围套话，把 token 留给人物表演、口型和连续性。';
          case 'promote_selected_memory':
            return l10n?.qualityReviewsActionPlanPromoteSelected(row.targetType, focus) ??
                '${row.targetType} 从高分样本晋升一条$focus，复用人物情绪和镜头执行，减少重复描述。';
          default:
            return null;
        }
      })
      .whereType<String>()
      .join(' | ');
  if (visible.isEmpty) return null;
  return l10n?.qualityReviewsScopedMemorySuggestion(scope, visible) ??
      '$scope 独立记忆建议：$visible';
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
    return l10n?.qualityReviewsCurrentFilterScope ?? '当前筛选范围';
  }();

  for (final row in tokenRows.where((row) => row.memoryAction != 'observe')) {
    final focus = qualityTokenEfficiencyFocusLabel(row.memoryFocus, l10n: l10n);
    switch (row.memoryAction) {
      case 'keep_delivery_memory':
        steps.add(
          l10n?.qualityReviewsChecklistKeepDelivery(focus) ??
              '保留$focus里的表演、语气、口型和情绪记忆，只压泛风格套话。',
        );
        break;
      case 'reuse_negative_memory':
        steps.add(
          l10n?.qualityReviewsChecklistReuseNegative(focus) ??
              '先复用$focus里的坏例约束，锁住穿帮、假感和冷场，再决定是否补 prompt。',
        );
        break;
      case 'trim_generic_style_memory':
        steps.add(
          l10n?.qualityReviewsChecklistTrimGeneric(focus) ??
              '清掉$focus里的动作、光影、氛围套话，把 token 留给人物表演和连续性。',
        );
        break;
      case 'promote_selected_memory':
        steps.add(
          l10n?.qualityReviewsChecklistPromoteSelected(focus) ??
              '把高分样本晋升为$focus，复用人物情绪和镜头执行，减少重复导演描述。',
        );
        break;
    }
    if (steps.length >= maxItems) break;
  }

  final suggestionCounts = <String, int>{};
  for (final review in reviews) {
    for (final suggestion in buildQualityReviewRepairSuggestions(review, l10n: l10n)) {
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
    l10n?.qualityReviewsChecklistTitle(scope) ?? '$scope 执行清单：',
    for (var i = 0; i < numbered.length; i++) '${i + 1}. ${numbered[i]}',
    l10n?.qualityReviewsChecklistScope(scope) ??
        '范围：记忆只在 $scope 生效，不跨用户、项目或短剧复用。',
  ];
  return lines.join('\n');
}
