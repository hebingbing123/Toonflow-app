part of 'diagnosis.dart';

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
    'Memory tier ${diagnostics.memoryBudgetTier}',
  ];
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
  if (!diagnostics.usesReferenceFrame) {
    return '当前提示词未绑定当前画面，先补参考帧再继续压缩，更稳。';
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
  if (anchorCount == 0 && diagnostics.styleAnchorCount == 0) {
    return '当前提示词主要依赖分镜文案，缺少角色/场景锚点，画面更容易漂。';
  }
  return '当前提示词预算仍可控，可继续优先保留人物表演、关键道具和情绪信息。';
}
