part of 'support.dart';

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
    final projectScopeRows = _diagnosticInt(
      diagnostics,
      'memoryProjectScopeRowCount',
    );
    final scriptScopeRows = _diagnosticInt(
      diagnostics,
      'memoryScriptScopeRowCount',
    );
    final roleScopeRows = _diagnosticInt(
      diagnostics,
      'memoryRoleScopeRowCount',
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
    if (projectScopeRows > 0 &&
        scriptScopeRows == 0 &&
        roleScopeRows == 0 &&
        memoryStyleChars >= 48) {
      addTagged('project_scope_trim', '当前主要命中项目级记忆，继续压词时先缩通用风格句，别动人物表演。');
    }
    if (roleScopeRows > 0 &&
        dialogueNaturalness < 85 &&
        comments.contains('情绪')) {
      addTagged('role_scope_keep', '已经命中角色级记忆，优先加强角色表演动作，不要回退成泛项目描述。');
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

String? summarizeQualityTokenEfficiencyActionPlan(
  Iterable<QualityTokenEfficiencyRow> rows, {
  int? projectId,
  int? scriptId,
  int maxItems = 3,
}) {
  final items = rows
      .where((row) => row.memoryAction != 'observe')
      .toList(growable: false);
  if (items.isEmpty) return null;

  final scope = () {
    if (projectId != null && scriptId != null) return 'P$projectId/S$scriptId';
    if (projectId != null) return 'P$projectId';
    return '当前筛选范围';
  }();

  final ranked = items.toList()
    ..sort((a, b) {
      final priority = _qualityTokenEfficiencyActionPriority(
        b.memoryAction,
      ).compareTo(_qualityTokenEfficiencyActionPriority(a.memoryAction));
      if (priority != 0) return priority;
      return b.sampleCount.compareTo(a.sampleCount);
    });

  final visible = ranked
      .take(maxItems)
      .map((row) {
        final focus = _qualityTokenEfficiencyFocusLabel(row.memoryFocus);
        switch (row.memoryAction) {
          case 'keep_delivery_memory':
            return '${row.targetType} 保留$focus的表演/情绪记忆，继续压泛风格句，别先删 delivery 片段。';
          case 'reuse_negative_memory':
            return '${row.targetType} 先复用$focus做坏例隔离约束，锁住穿帮/假感后再决定是否补 prompt。';
          case 'trim_generic_style_memory':
            return '${row.targetType} 优先压$focus里的动作/光影/氛围套话，把 token 留给人物表演、口型和连续性。';
          case 'promote_selected_memory':
            return '${row.targetType} 从高分样本晋升一条$focus，复用人物情绪和镜头执行，减少重复描述。';
          default:
            return null;
        }
      })
      .whereType<String>()
      .join(' | ');
  if (visible.isEmpty) return null;
  return '$scope 独立记忆建议：$visible';
}

String? buildQualityScopedExecutionChecklist({
  required Iterable<QualityReview> reviews,
  Iterable<QualityTokenEfficiencyRow> tokenRows =
      const <QualityTokenEfficiencyRow>[],
  int? projectId,
  int? scriptId,
  int maxItems = 4,
}) {
  final steps = LinkedHashSet<String>();
  final scope = () {
    if (projectId != null && scriptId != null) return 'P$projectId/S$scriptId';
    if (projectId != null) return 'P$projectId';
    return '当前筛选范围';
  }();

  for (final row in tokenRows.where((row) => row.memoryAction != 'observe')) {
    final focus = _qualityTokenEfficiencyFocusLabel(row.memoryFocus);
    switch (row.memoryAction) {
      case 'keep_delivery_memory':
        steps.add('保留$focus里的表演、语气、口型和情绪记忆，只压泛风格套话。');
        break;
      case 'reuse_negative_memory':
        steps.add('先复用$focus里的坏例约束，锁住穿帮、假感和冷场，再决定是否补 prompt。');
        break;
      case 'trim_generic_style_memory':
        steps.add('清掉$focus里的动作、光影、氛围套话，把 token 留给人物表演和连续性。');
        break;
      case 'promote_selected_memory':
        steps.add('把高分样本晋升为$focus，复用人物情绪和镜头执行，减少重复导演描述。');
        break;
    }
    if (steps.length >= maxItems) break;
  }

  final suggestionCounts = <String, int>{};
  for (final review in reviews) {
    for (final suggestion in buildQualityReviewRepairSuggestions(review)) {
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
    '$scope 执行清单：',
    for (var i = 0; i < numbered.length; i++) '${i + 1}. ${numbered[i]}',
    '范围：记忆只在 $scope 生效，不跨用户、项目或短剧复用。',
  ];
  return lines.join('\n');
}

