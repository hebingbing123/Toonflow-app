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
  AppLocalizations l10n,
  GenerateVideoPromptDiagnostics diagnostics,
) {
  final parts = <String>[
    l10n.storyboardDiagPromptChars(diagnostics.promptChars),
    if (diagnostics.negativePromptChars > 0)
      l10n.storyboardDiagNegativeLine(
        diagnostics.negativePromptChars,
        diagnostics.negativeBudgetTier,
      ),
    if (diagnostics.observationNoteChars > 0)
      l10n.storyboardDiagObservation(diagnostics.observationNoteChars),
    if (diagnostics.memoryStyleChars > 0)
      l10n.storyboardDiagMemoryStyle(diagnostics.memoryStyleChars),
    if (diagnostics.negativeSavedChars > 0)
      l10n.storyboardDiagNegativeSlimSaved(diagnostics.negativeSavedChars),
    if (diagnostics.memoryOptimizationApplied &&
        diagnostics.memoryOptimizationRemovedChars > 0)
      l10n.storyboardDiagMemorySlimRemoved(
        diagnostics.memoryOptimizationRemovedChars,
      ),
    if (diagnostics.memoryDeliveryPriorityApplied)
      l10n.storyboardDiagDeliveryPriority,
    l10n.storyboardDiagMemoryTier(diagnostics.memoryBudgetTier),
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
  AppLocalizations l10n,
  GenerateVideoPromptDiagnostics diagnostics,
) {
  if (!diagnostics.usesReferenceFrame) {
    return l10n.storyboardBudgetHintNoReferenceFrame;
  }
  if (diagnostics.memoryOptimizationApplied &&
      diagnostics.memoryOptimizationRemovedRows > 0 &&
      diagnostics.memoryDeliveryChars > 0) {
    return l10n.storyboardBudgetHintOptimizationKeptDelivery;
  }
  if (_hasScopedMemoryRows(diagnostics) &&
      diagnostics.memoryProjectScopeRowCount > 0 &&
      diagnostics.memoryScriptScopeRowCount == 0 &&
      diagnostics.memoryRoleScopeRowCount == 0 &&
      diagnostics.memoryStyleChars >= 48) {
    return l10n.storyboardBudgetHintProjectMemoryHeavy;
  }
  if (diagnostics.memoryRoleScopeRowCount > 0 &&
      diagnostics.memoryDeliveryChars > 0 &&
      diagnostics.memoryProjectScopeRowCount >
          diagnostics.memoryRoleScopeRowCount) {
    return l10n.storyboardBudgetHintRoleVsProject;
  }
  if (diagnostics.memoryDeliveryPriorityApplied &&
      diagnostics.memoryDeliveryChars > 0 &&
      diagnostics.memoryBudgetTier == 'expanded') {
    return l10n.storyboardBudgetHintDeliveryExpanded;
  }
  final topSuppressedBucket = _topStoryboardBucket(
    diagnostics.memorySuppressedBucketCounts,
  );
  if (topSuppressedBucket != null &&
      diagnostics.promptChars >= 380 &&
      diagnostics.memoryStyleChars >= 48) {
    return l10n.storyboardBudgetHintSuppressedBucket(topSuppressedBucket);
  }
  final anchorCount =
      diagnostics.roleAnchorCount +
      diagnostics.sceneAnchorCount +
      diagnostics.toolAnchorCount;
  if (diagnostics.promptChars >= 520) {
    return l10n.storyboardBudgetHintPromptLong;
  }
  if (diagnostics.promptChars >= 380 && diagnostics.memoryStyleChars >= 48) {
    return l10n.storyboardBudgetHintPrivateMemoryHeavy;
  }
  if (diagnostics.memoryBudgetTier == 'expanded' &&
      diagnostics.memoryStyleChars <= 40 &&
      diagnostics.continuityNoteChars <= 40) {
    return l10n.storyboardBudgetHintRiskyShotExpanded;
  }
  if (diagnostics.promptChars >= 380 &&
      diagnostics.styleAnchorCount + diagnostics.continuityNoteCount >= 3) {
    return l10n.storyboardBudgetHintNearLongPrompt;
  }
  if (diagnostics.continuityNoteChars >= 48) {
    return l10n.storyboardBudgetHintContinuityLong;
  }
  if (diagnostics.negativeBudgetTier == 'expanded' &&
      diagnostics.negativeConstraintCount >= 3) {
    return l10n.storyboardBudgetHintNegativeExpanded;
  }
  if (diagnostics.negativeBudgetTier == 'lean' &&
      diagnostics.negativePromptChars >= 56) {
    return l10n.storyboardBudgetHintNegativeLeanLong;
  }
  if (diagnostics.autoNegativeSource == 'review+rejected_memory' &&
      diagnostics.autoNegativeMemoryFragmentCount >= 2) {
    return l10n.storyboardBudgetHintAutoNegativeDup;
  }
  if (diagnostics.autoNegativeSource == 'pending_rejected_observation') {
    return l10n.storyboardBudgetHintPendingObservation;
  }
  if (anchorCount == 0 && diagnostics.styleAnchorCount == 0) {
    return l10n.storyboardBudgetHintNoAnchors;
  }
  return l10n.storyboardBudgetHintHealthy;
}

String? _topStoryboardBucket(Map<String, int> counts) {
  if (counts.isEmpty) return null;
  return (counts.entries.toList()..sort((a, b) => b.value.compareTo(a.value)))
      .first
      .key;
}

List<String> buildStoryboardVideoPromptRepairSuggestions(
  AppLocalizations l10n,
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
    addTagged('reference_frame', l10n.storyboardRepairSuggestReferenceFrame);
  }
  if (diagnostics.continuityNoteCount > 0 &&
      diagnostics.continuityNoteChars >= 48) {
    addTagged('continuity', l10n.storyboardRepairSuggestContinuity);
  }
  if (diagnostics.memoryDeliveryPriorityApplied ||
      hitBuckets.contains('表演') ||
      hitBuckets.contains('语气') ||
      diagnostics.memoryDeliveryChars >= 24) {
    addTagged('delivery', l10n.storyboardRepairSuggestDelivery);
  }
  if (diagnostics.promptChars >= 520 ||
      diagnostics.memoryStyleChars >= 96 ||
      topSuppressedBucket == '动作' ||
      topSuppressedBucket == '光影') {
    addTagged('trim_generic', l10n.storyboardRepairSuggestTrimGeneric);
  }
  if (diagnostics.negativePromptChars > 0 &&
      diagnostics.autoNegativeSource != null) {
    addTagged('negative_reuse', l10n.storyboardRepairSuggestNegativeReuse);
  }
  if (diagnostics.autoNegativeSource == 'review+rejected_memory' &&
      diagnostics.autoNegativeMemoryFragmentCount >= 2) {
    addTagged('memory_reuse', l10n.storyboardRepairSuggestMemoryReuse);
  }
  if (diagnostics.memoryProjectScopeRowCount > 0 &&
      diagnostics.memoryScriptScopeRowCount == 0 &&
      diagnostics.memoryRoleScopeRowCount == 0 &&
      diagnostics.memoryStyleChars >= 48) {
    addTagged('project_memory_trim', l10n.storyboardRepairSuggestProjectMemoryTrim);
  }
  if (diagnostics.memoryRoleScopeRowCount > 0 &&
      diagnostics.memoryDeliveryChars > 0) {
    addTagged('role_memory_keep', l10n.storyboardRepairSuggestRoleMemoryKeep);
  }
  if (diagnostics.roleAnchorCount == 0 &&
      diagnostics.sceneAnchorCount == 0 &&
      diagnostics.styleAnchorCount == 0) {
    addTagged('anchors', l10n.storyboardRepairSuggestAnchors);
  }
  if (suggestions.isEmpty) {
    addTagged('healthy', l10n.storyboardRepairSuggestHealthy);
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
