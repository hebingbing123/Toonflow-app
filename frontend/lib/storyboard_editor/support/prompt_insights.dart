part of 'diagnosis.dart';

class StoryboardNegativePromptCompression {
  const StoryboardNegativePromptCompression({
    required this.manualPrompt,
    required this.removedFragmentCount,
  });

  final String manualPrompt;
  final int removedFragmentCount;
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
    if (diagnostics.memoryDeliveryPriorityApplied) 'Delivery-priority ✅',
    'Memory tier ${diagnostics.memoryBudgetTier}',
  ];
  return parts.join(' · ');
}

String describeStoryboardAutoNegativeSource(
  GenerateVideoPromptDiagnostics diagnostics,
) {
  switch (diagnostics.autoNegativeSource) {
    case 'review':
      return '自动负向来自最近评审坏例';
    case 'rejected_memory':
      return '自动负向来自私有坏例记忆';
    case 'review+rejected_memory':
      return '自动负向同时用了评审坏例和私有记忆';
    case 'pending_rejected_observation':
      return '自动负向来自最近一次 reject 观察兜底';
    case 'pending_observation_note':
      return '当前还没正式负向词，只回带待观察失败提示';
    default:
      return '当前没有额外自动负向来源。';
  }
}

String buildStoryboardVideoPromptSourceSummary(
  GenerateVideoPromptDiagnostics diagnostics,
) {
  final parts = <String>[describeStoryboardAutoNegativeSource(diagnostics)];
  if (diagnostics.autoNegativeReviewFragmentCount > 0) {
    parts.add('评审 ${diagnostics.autoNegativeReviewFragmentCount} 条');
  }
  if (diagnostics.autoNegativeMemoryFragmentCount > 0) {
    parts.add('记忆 ${diagnostics.autoNegativeMemoryFragmentCount} 条');
  }
  return parts.join(' · ');
}

String buildStoryboardVideoPromptAnchorSummary(
  GenerateVideoPromptDiagnostics diagnostics,
) {
  final parts = <String>[
    if (diagnostics.roleAnchorCount > 0) '角色锚点 ${diagnostics.roleAnchorCount}',
    if (diagnostics.sceneAnchorCount > 0)
      '场景锚点 ${diagnostics.sceneAnchorCount}',
    if (diagnostics.toolAnchorCount > 0) '道具锚点 ${diagnostics.toolAnchorCount}',
    if (diagnostics.styleAnchorCount > 0)
      '风格锚点 ${diagnostics.styleAnchorCount}',
    if (diagnostics.memoryStyleAnchorCount > 0)
      '私有记忆 ${diagnostics.memoryStyleAnchorCount}',
    if (diagnostics.continuityNoteCount > 0)
      '连续性记忆 ${diagnostics.continuityNoteCount}',
    if (diagnostics.usesReferenceFrame) '已引用当前画面',
  ];
  return parts.isEmpty ? '当前提示词未命中额外锚点或记忆。' : parts.join(' · ');
}

String buildStoryboardVideoPromptBudgetHint(
  GenerateVideoPromptDiagnostics diagnostics,
) {
  String? topBucket(Map<String, int> counts) {
    if (counts.isEmpty) return null;
    return (counts.entries.toList()..sort((a, b) => b.value.compareTo(a.value)))
        .first
        .key;
  }

  if (!diagnostics.usesReferenceFrame) {
    return '当前提示词未绑定当前画面，先补参考帧再继续压缩，更稳。';
  }
  if (diagnostics.memoryDeliveryPriorityApplied &&
      diagnostics.memoryDeliveryChars > 0 &&
      diagnostics.memoryBudgetTier == 'expanded') {
    return '已命中表演/语气优先记忆，先别删这段；优先压缩重复的场景/风格与连续性泛句，避免又回到“读稿腔”。';
  }
  final topSuppressedBucket = topBucket(diagnostics.memorySuppressedBucketCounts);
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
