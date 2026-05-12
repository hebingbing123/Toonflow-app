part of 'diagnosis.dart';

class StoryboardNegativePromptCompression {
  const StoryboardNegativePromptCompression({
    required this.manualPrompt,
    required this.removedFragmentCount,
  });

  final String manualPrompt;
  final int removedFragmentCount;
}

class StoryboardVideoPromptRepairResult {
  const StoryboardVideoPromptRepairResult({
    required this.prompt,
    required this.negativePrompt,
    required this.removedPromptFragmentCount,
    required this.removedNegativeFragmentCount,
  });

  final String prompt;
  final String negativePrompt;
  final int removedPromptFragmentCount;
  final int removedNegativeFragmentCount;

  bool get changed =>
      removedPromptFragmentCount > 0 || removedNegativeFragmentCount > 0;
}

StoryboardNegativePromptCompression compactStoryboardManualNegativePrompt({
  required String manualPrompt,
  String? automaticPrompt,
}) {
  final manualFragments = _splitStoryboardNegativePromptFragments(manualPrompt);
  if (manualFragments.isEmpty) {
    return const StoryboardNegativePromptCompression(
      manualPrompt: '',
      removedFragmentCount: 0,
    );
  }
  final automaticFragments = _splitStoryboardNegativePromptFragments(
    automaticPrompt ?? '',
  );
  if (automaticFragments.isEmpty) {
    return StoryboardNegativePromptCompression(
      manualPrompt: manualFragments.join(', '),
      removedFragmentCount: 0,
    );
  }

  final kept = <String>[];
  var removed = 0;
  for (final fragment in manualFragments) {
    if (_storyboardNegativeFragmentCoveredByAutomatic(
      fragment,
      automaticFragments,
    )) {
      removed += 1;
      continue;
    }
    kept.add(fragment);
  }
  return StoryboardNegativePromptCompression(
    manualPrompt: kept.join(', '),
    removedFragmentCount: removed,
  );
}

List<String> _splitStoryboardNegativePromptFragments(String prompt) {
  return prompt
      .split(RegExp(r'[，,；;。\n]+'))
      .map((fragment) => _normalizeStoryboardNegativePromptText(fragment))
      .where((fragment) => fragment.isNotEmpty)
      .toList(growable: false);
}

bool _storyboardNegativeFragmentCoveredByAutomatic(
  String manualFragment,
  List<String> automaticFragments,
) {
  final normalizedManual = _normalizeStoryboardNegativePromptText(
    manualFragment,
  ).toLowerCase();
  if (normalizedManual.isEmpty) {
    return true;
  }
  return automaticFragments.any((fragment) {
    final normalizedAutomatic = _normalizeStoryboardNegativePromptText(
      fragment,
    ).toLowerCase();
    if (normalizedAutomatic.isEmpty) {
      return false;
    }
    return normalizedAutomatic == normalizedManual ||
        normalizedAutomatic.contains(normalizedManual);
  });
}

String _normalizeStoryboardNegativePromptText(String text) {
  return text.trim().replaceAll(RegExp(r'\s+'), ' ');
}

StoryboardVideoPromptRepairResult applyStoryboardVideoPromptRepairs({
  required GenerateVideoPromptDiagnostics diagnostics,
  required String prompt,
  required String negativePrompt,
  String? automaticNegativePrompt,
}) {
  final promptCompression = _compactStoryboardPrompt(
    prompt: prompt,
    diagnostics: diagnostics,
  );
  final negativeCompression = compactStoryboardManualNegativePrompt(
    manualPrompt: negativePrompt,
    automaticPrompt: automaticNegativePrompt,
  );
  return StoryboardVideoPromptRepairResult(
    prompt: promptCompression.prompt,
    negativePrompt: negativeCompression.manualPrompt,
    removedPromptFragmentCount: promptCompression.removedFragmentCount,
    removedNegativeFragmentCount: negativeCompression.removedFragmentCount,
  );
}

class _StoryboardPromptCompression {
  const _StoryboardPromptCompression({
    required this.prompt,
    required this.removedFragmentCount,
  });

  final String prompt;
  final int removedFragmentCount;
}

_StoryboardPromptCompression _compactStoryboardPrompt({
  required String prompt,
  required GenerateVideoPromptDiagnostics diagnostics,
}) {
  final fragments = _splitStoryboardPromptFragments(prompt);
  if (fragments.isEmpty) {
    return const _StoryboardPromptCompression(
      prompt: '',
      removedFragmentCount: 0,
    );
  }

  final trimmed = <String>[];
  final seen = <String>{};
  var removed = 0;
  final canTrimGeneric =
      diagnostics.promptChars >= 520 ||
      diagnostics.memoryStyleChars >= 96 ||
      diagnostics.memorySuppressedBucketCounts['动作'] != null ||
      diagnostics.memorySuppressedBucketCounts['光影'] != null;

  for (final fragment in fragments) {
    final normalized = _normalizeStoryboardPromptText(fragment).toLowerCase();
    if (normalized.isEmpty) continue;
    if (!seen.add(normalized)) {
      removed += 1;
      continue;
    }
    if (canTrimGeneric &&
        _isLowValueStoryboardPromptFragment(fragment) &&
        fragments.length - removed > 3) {
      removed += 1;
      continue;
    }
    trimmed.add(fragment.trim());
  }

  return _StoryboardPromptCompression(
    prompt: trimmed.join('，'),
    removedFragmentCount: removed,
  );
}

List<String> _splitStoryboardPromptFragments(String prompt) {
  return prompt
      .split(RegExp(r'[，,；;。\n]+'))
      .map((fragment) => fragment.trim())
      .where((fragment) => fragment.isNotEmpty)
      .toList(growable: false);
}

String _normalizeStoryboardPromptText(String text) {
  return text.trim().replaceAll(RegExp(r'\s+'), ' ');
}

bool _isLowValueStoryboardPromptFragment(String fragment) {
  final normalized = _normalizeStoryboardPromptText(fragment).toLowerCase();
  if (normalized.isEmpty) return false;
  final hasPerformanceSignal = _storyboardPromptKeywords.any(
    (keyword) => normalized.contains(keyword),
  );
  if (hasPerformanceSignal) {
    return false;
  }
  return _storyboardGenericTrimKeywords.any(
    (keyword) => normalized.contains(keyword),
  );
}

const List<String> _storyboardPromptKeywords = <String>[
  '表情',
  '情绪',
  '眼神',
  '口型',
  '微表情',
  '呼吸',
  '停顿',
  '台词',
  '语气',
  '人物',
  '角色',
  'identity',
  'expression',
  'emotion',
  'lip',
  'face',
];

const List<String> _storyboardGenericTrimKeywords = <String>[
  '光影',
  '光线',
  '镜头',
  '运镜',
  '跟拍',
  '推拉',
  '摇镜',
  '氛围',
  '节奏',
  '动作',
  '缓慢',
  '唯美',
  'cinematic',
  'lighting',
  'camera',
  'tracking shot',
  'moody',
  'atmosphere',
];

String buildStoryboardVideoPromptDiagnosticsLine(
  GenerateVideoPromptDiagnostics diagnostics,
) {
  final parts = <String>[
    'Prompt ${diagnostics.promptChars} chars',
    if (diagnostics.negativePromptChars > 0)
      'Negative ${diagnostics.negativePromptChars} (${diagnostics.negativeBudgetTier})',
    if (diagnostics.observationNoteChars > 0)
      'Observation ${diagnostics.observationNoteChars}',
    if (diagnostics.memoryStyleChars > 0)
      'Memory ${diagnostics.memoryStyleChars}',
    if (diagnostics.negativeSavedChars > 0)
      'Negative slim -${diagnostics.negativeSavedChars}',
    if (diagnostics.memoryOptimizationApplied &&
        diagnostics.memoryOptimizationRemovedChars > 0)
      'Memory slim -${diagnostics.memoryOptimizationRemovedChars}',
    if (diagnostics.memoryDeliveryPriorityApplied) 'Delivery-priority ✅',
    'Memory tier ${diagnostics.memoryBudgetTier}',
  ];
  return parts.join(' · ');
}

String describeStoryboardSelectedMemoryFeedback(
  AppLocalizations l10n,
  WorkbenchVideoMemoryFeedback feedback,
) {
  final parts = <String>[];
  final subject = feedback.subject?.trim();
  if (subject != null && subject.isNotEmpty) {
    parts.add(subject);
  }
  final style = feedback.style?.trim();
  if (style != null && style.isNotEmpty) {
    parts.add(style);
  }
  final note = feedback.note?.trim();
  if (note != null && note.isNotEmpty) {
    parts.add(note);
  }
  final summary = parts.isEmpty
      ? l10n.storyboardMemorySelectedPerfDistilled
      : l10n.storyboardMemorySelectedPrivateParts(parts.join(' / '));
  return '$summary ${l10n.storyboardMemoryPrivateScopeFooter}';
}

String describeStoryboardRejectedMemoryFeedback(
  AppLocalizations l10n,
  WorkbenchVideoMemoryFeedback feedback,
) {
  final avoid = feedback.avoid?.trim();
  final rejectionCount = feedback.rejectionCount;
  final riskTags = feedback.riskTags;
  final head = (avoid == null || avoid.isEmpty)
      ? l10n.storyboardMemoryRejectedHeadEmpty
      : l10n.storyboardMemoryRejectedHeadAvoid(avoid);
  final tailParts = <String>[
    if (rejectionCount != null && rejectionCount > 1)
      l10n.storyboardMemoryRejectedFailures(rejectionCount),
    if (riskTags.isNotEmpty)
      l10n.storyboardMemoryRejectedRisks(riskTags.join(' / ')),
  ];
  final tail = tailParts.join(' · ');
  final footer = l10n.storyboardMemoryRejectedNegativeFooter;
  return tail.isEmpty ? '$head $footer' : '$head $tail；$footer';
}

String describeStoryboardAutoNegativeSource(
  AppLocalizations l10n,
  GenerateVideoPromptDiagnostics diagnostics,
) {
  switch (diagnostics.autoNegativeSource) {
    case 'review':
      return l10n.storyboardAutoNegativeSourceReview;
    case 'rejected_memory':
      return l10n.storyboardAutoNegativeSourceRejectedMemory;
    case 'review+rejected_memory':
      return l10n.storyboardAutoNegativeSourceBoth;
    case 'pending_rejected_observation':
      return l10n.storyboardAutoNegativeSourcePendingObservation;
    case 'pending_observation_note':
      return l10n.storyboardAutoNegativeSourcePendingNoteOnly;
    default:
      return l10n.storyboardAutoNegativeSourceNone;
  }
}

String buildStoryboardPromptGenerationFollowUp(
  AppLocalizations l10n,
  GenerateVideoPromptDiagnostics diagnostics, {
  String? observationNote,
}) {
  final parts = <String>[
    l10n.storyboardPromptGenDefaultFilledDuration,
    describeStoryboardAutoNegativeSource(l10n, diagnostics),
  ];
  final scopeSummary = _describeStoryboardMemoryScopeRowsIfAny(l10n, diagnostics);
  if (scopeSummary != null) {
    parts.add(l10n.storyboardPromptGenHitMemory(scopeSummary));
  }
  if (diagnostics.negativeSavedChars > 0 ||
      diagnostics.negativeSavedFragmentCount > 0) {
    parts.add(
      l10n.storyboardPromptGenNegativeTrimmed(
        diagnostics.negativeSavedFragmentCount,
        diagnostics.negativeSavedChars,
      ),
    );
  }
  final note = observationNote?.trim();
  if (note != null && note.isNotEmpty) {
    parts.add(note);
  }
  return '${parts.join('；')}。';
}

String buildStoryboardVideoPromptSourceSummary(
  AppLocalizations l10n,
  GenerateVideoPromptDiagnostics diagnostics,
) {
  final parts = <String>[
    describeStoryboardAutoNegativeSource(l10n, diagnostics),
  ];
  if (diagnostics.memoryOptimizationApplied &&
      diagnostics.memoryOptimizationRemovedRows > 0) {
    parts.add(
      l10n.storyboardPromptSourceMemorySlim(
        diagnostics.memoryOptimizationRemovedRows,
        diagnostics.memoryOptimizationRemovedLowValueRows,
        diagnostics.memoryOptimizationRemovedDuplicateRows,
        diagnostics.memoryOptimizationRemovedVisualRows,
      ),
    );
  }
  if (diagnostics.negativeSavedFragmentCount > 0 ||
      diagnostics.negativeSavedChars > 0) {
    parts.add(
      l10n.storyboardPromptSourceNegativeSlim(
        diagnostics.negativeSavedFragmentCount,
        diagnostics.negativeSavedChars,
      ),
    );
  }
  if (diagnostics.autoNegativeReviewFragmentCount > 0) {
    parts.add(
      l10n.storyboardPromptSourceReviewFrags(
        diagnostics.autoNegativeReviewFragmentCount,
      ),
    );
  }
  if (diagnostics.autoNegativeMemoryFragmentCount > 0) {
    parts.add(
      l10n.storyboardPromptSourceMemoryFrags(
        diagnostics.autoNegativeMemoryFragmentCount,
      ),
    );
  }
  return parts.join(' · ');
}

String buildStoryboardVideoPromptAnchorSummary(
  AppLocalizations l10n,
  GenerateVideoPromptDiagnostics diagnostics,
) {
  final scopeRows = _hasScopedMemoryRows(diagnostics)
      ? _describeStoryboardMemoryScopeRows(l10n, diagnostics)
      : null;
  final parts = <String>[
    if (diagnostics.roleAnchorCount > 0)
      l10n.storyboardPromptAnchorRole(diagnostics.roleAnchorCount),
    if (diagnostics.sceneAnchorCount > 0)
      l10n.storyboardPromptAnchorScene(diagnostics.sceneAnchorCount),
    if (diagnostics.toolAnchorCount > 0)
      l10n.storyboardPromptAnchorTool(diagnostics.toolAnchorCount),
    if (diagnostics.styleAnchorCount > 0)
      l10n.storyboardPromptAnchorStyle(diagnostics.styleAnchorCount),
    if (diagnostics.memoryStyleAnchorCount > 0)
      l10n.storyboardPromptAnchorPrivateMemory(
        diagnostics.memoryStyleAnchorCount,
      ),
    if (scopeRows != null && scopeRows.isNotEmpty)
      l10n.storyboardPromptGenHitMemory(scopeRows),
    if (diagnostics.continuityNoteCount > 0)
      l10n.storyboardPromptAnchorContinuity(diagnostics.continuityNoteCount),
    if (diagnostics.usesReferenceFrame)
      l10n.storyboardPromptAnchorReferenceFrame,
  ];
  return parts.isEmpty
      ? l10n.storyboardPromptAnchorEmpty
      : parts.join(' · ');
}

String buildStoryboardVideoPromptBudgetHint(
  GenerateVideoPromptDiagnostics diagnostics,
) {
  if (!diagnostics.usesReferenceFrame) {
    return '当前提示词未绑定当前画面，先补参考帧再继续压缩，更稳。';
  }
  if (diagnostics.memoryOptimizationApplied &&
      diagnostics.memoryOptimizationRemovedRows > 0 &&
      diagnostics.memoryDeliveryChars > 0) {
    return '本次生成前已自动清掉重复/纯视觉私有记忆，优先保住了表演和语气锚点；继续补词时先别把这些省下来的预算又填回泛风格句。';
  }
  if (_hasScopedMemoryRows(diagnostics) &&
      diagnostics.memoryProjectScopeRowCount > 0 &&
      diagnostics.memoryScriptScopeRowCount == 0 &&
      diagnostics.memoryRoleScopeRowCount == 0 &&
      diagnostics.memoryStyleChars >= 48) {
    return '这次主要命中项目级记忆，先把通用风格句收短一点，预算优先留给人物表演和当前镜头连续性。';
  }
  if (diagnostics.memoryRoleScopeRowCount > 0 &&
      diagnostics.memoryDeliveryChars > 0 &&
      diagnostics.memoryProjectScopeRowCount >
          diagnostics.memoryRoleScopeRowCount) {
    return '角色级记忆已经命中，继续压缩时先动项目级泛化描述，别把角色表演和情绪锚点一起删掉。';
  }
  if (diagnostics.memoryDeliveryPriorityApplied &&
      diagnostics.memoryDeliveryChars > 0 &&
      diagnostics.memoryBudgetTier == 'expanded') {
    return '已命中表演/语气优先记忆，先别删这段；优先压缩重复的场景/风格与连续性泛句，避免又回到“读稿腔”。';
  }
  final topSuppressedBucket = _topStoryboardBucket(
    diagnostics.memorySuppressedBucketCounts,
  );
  if (topSuppressedBucket != null &&
      diagnostics.promptChars >= 380 &&
      diagnostics.memoryStyleChars >= 48) {
    return '当前私有记忆里已压掉较多$topSuppressedBucket类重复片段，继续先收这类泛句，别先删角色表演记忆。';
  }
  final anchorCount =
      diagnostics.roleAnchorCount +
      diagnostics.sceneAnchorCount +
      diagnostics.toolAnchorCount;
  if (diagnostics.promptChars >= 520) {
    return '当前提示词偏长，优先删重复场景/风格描述，先别动角色和关键道具锚点。';
  }
  if (diagnostics.promptChars >= 380 && diagnostics.memoryStyleChars >= 48) {
    return '当前提示词里的私有记忆占比已经不低，优先合并泛化风格句，别先删角色表演记忆。';
  }
  if (diagnostics.memoryBudgetTier == 'expanded' &&
      diagnostics.memoryStyleChars <= 40 &&
      diagnostics.continuityNoteChars <= 40) {
    return '当前镜头被判定为高风险，先保留角色表演和连续性记忆，再压其他泛化描述。';
  }
  if (diagnostics.promptChars >= 380 &&
      diagnostics.styleAnchorCount + diagnostics.continuityNoteCount >= 3) {
    return '当前提示词已接近长 prompt，继续补充前先检查风格锚点和连续性记忆是否重复。';
  }
  if (diagnostics.continuityNoteChars >= 48) {
    return '连续性记忆已经偏长，先把重复的衔接描述压成更短的动作或表演锚点。';
  }
  if (diagnostics.negativeBudgetTier == 'expanded' &&
      diagnostics.negativeConstraintCount >= 3) {
    return '当前镜头的防穿帮约束已切到 expanded，先保留人物一致性和镜头连续性，再压泛化负面词。';
  }
  if (diagnostics.negativeBudgetTier == 'lean' &&
      diagnostics.negativePromptChars >= 56) {
    return '当前负向约束已经偏长，优先合并重复的情绪/光影警告，别先删身份一致性约束。';
  }
  if (diagnostics.autoNegativeSource == 'review+rejected_memory' &&
      diagnostics.autoNegativeMemoryFragmentCount >= 2) {
    return '当前负向词已经自动带入评审和私有坏例，手动补词前先检查是否只是重复表达。';
  }
  if (diagnostics.autoNegativeSource == 'pending_rejected_observation') {
    return '这次已经自动继承最近失败观察，先看重试结果，别急着再补一串同义负面词。';
  }
  if (anchorCount == 0 && diagnostics.styleAnchorCount == 0) {
    return '当前提示词主要依赖分镜文案，缺少角色/场景锚点，画面更容易漂。';
  }
  return '当前提示词预算仍可控，可继续优先保留人物表演、关键道具和情绪信息。';
}

String? _topStoryboardBucket(Map<String, int> counts) {
  if (counts.isEmpty) return null;
  return (counts.entries.toList()..sort((a, b) => b.value.compareTo(a.value)))
      .first
      .key;
}

List<String> buildStoryboardVideoPromptRepairSuggestions(
  GenerateVideoPromptDiagnostics diagnostics,
) {
  final suggestions = <String>[];
  final tags = <String>{};

  void addTagged(String tag, String suggestion) {
    if (tags.add(tag)) suggestions.add(suggestion);
  }

  final topSuppressedBucket = _topStoryboardBucket(
    diagnostics.memorySuppressedBucketCounts,
  );
  final hitBuckets = {
    ...diagnostics.memoryHitBuckets,
    ...diagnostics.memoryHitBucketCounts.keys,
  };

  if (!diagnostics.usesReferenceFrame) {
    addTagged('reference_frame', '先补当前参考帧，再压词；人物脸、服化道和站位会更稳。');
  }
  if (diagnostics.continuityNoteCount > 0 &&
      diagnostics.continuityNoteChars >= 48) {
    addTagged('continuity', '连续性约束改成 1-2 条硬规则，只留机位、服化道和角色位置。');
  }
  if (diagnostics.memoryDeliveryPriorityApplied ||
      hitBuckets.contains('表演') ||
      hitBuckets.contains('语气') ||
      diagnostics.memoryDeliveryChars >= 24) {
    addTagged('delivery', '保留表演/语气记忆，把情绪写成可演动作，别退回成读稿腔。');
  }
  if (diagnostics.promptChars >= 520 ||
      diagnostics.memoryStyleChars >= 96 ||
      topSuppressedBucket == '动作' ||
      topSuppressedBucket == '光影') {
    addTagged('trim_generic', '优先删动作/光影泛句，把预算让给口型、微表情和人物一致性。');
  }
  if (diagnostics.negativePromptChars > 0 &&
      diagnostics.autoNegativeSource != null) {
    addTagged('negative_reuse', '沿用自动坏例负向约束，手动补词前先去重，避免同义词重复烧 token。');
  }
  if (diagnostics.autoNegativeSource == 'review+rejected_memory' &&
      diagnostics.autoNegativeMemoryFragmentCount >= 2) {
    addTagged('memory_reuse', '这次已经命中项目/剧本私有坏例记忆，先复用它，别再堆一层共享长记忆。');
  }
  if (diagnostics.memoryProjectScopeRowCount > 0 &&
      diagnostics.memoryScriptScopeRowCount == 0 &&
      diagnostics.memoryRoleScopeRowCount == 0 &&
      diagnostics.memoryStyleChars >= 48) {
    addTagged('project_memory_trim', '这轮主要靠项目级通用记忆在撑，继续压词时优先缩短泛风格句。');
  }
  if (diagnostics.memoryRoleScopeRowCount > 0 &&
      diagnostics.memoryDeliveryChars > 0) {
    addTagged('role_memory_keep', '已经命中角色级私有记忆，优先保住角色情绪和口型，别被项目级描述盖掉。');
  }
  if (diagnostics.roleAnchorCount == 0 &&
      diagnostics.sceneAnchorCount == 0 &&
      diagnostics.styleAnchorCount == 0) {
    addTagged('anchors', '补角色、场景或关键道具锚点，不然画面更容易漂和穿帮。');
  }
  if (suggestions.isEmpty) {
    addTagged('healthy', '当前预算可控，继续保留人物表演、关键道具和情绪细节。');
  }
  return suggestions;
}

bool _hasScopedMemoryRows(GenerateVideoPromptDiagnostics diagnostics) {
  return diagnostics.memoryProjectScopeRowCount > 0 ||
      diagnostics.memoryScriptScopeRowCount > 0 ||
      diagnostics.memoryRoleScopeRowCount > 0;
}

String? _describeStoryboardMemoryScopeRowsIfAny(
  AppLocalizations l10n,
  GenerateVideoPromptDiagnostics diagnostics,
) {
  if (!_hasScopedMemoryRows(diagnostics)) {
    return null;
  }
  return _describeStoryboardMemoryScopeRows(l10n, diagnostics);
}

String _describeStoryboardMemoryScopeRows(
  AppLocalizations l10n,
  GenerateVideoPromptDiagnostics diagnostics,
) {
  final parts = <String>[
    if (diagnostics.memoryProjectScopeRowCount > 0)
      l10n.storyboardMemoryScopeProject(diagnostics.memoryProjectScopeRowCount),
    if (diagnostics.memoryScriptScopeRowCount > 0)
      l10n.storyboardMemoryScopeScript(diagnostics.memoryScriptScopeRowCount),
    if (diagnostics.memoryRoleScopeRowCount > 0)
      l10n.storyboardMemoryScopeRole(diagnostics.memoryRoleScopeRowCount),
  ];
  return parts.join(' / ');
}
