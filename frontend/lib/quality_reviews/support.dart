import '../../rust_api.dart';

class QualityMemoryDraft {
  const QualityMemoryDraft({
    required this.projectId,
    required this.episodesId,
    required this.agentType,
    required this.memoryType,
    required this.role,
    required this.name,
    required this.summary,
    required this.content,
    required this.canAppend,
    this.blockingReason,
  });

  final int? projectId;
  final int? episodesId;
  final String agentType;
  final String memoryType;
  final String role;
  final String name;
  final String summary;
  final String content;
  final bool canAppend;
  final String? blockingReason;
}

QualityMemoryDraft buildQualityMemoryDraft(
  QualityTokenEfficiencySampleRow row,
) {
  final targetLabel = row.targetId == null || row.targetId!.isEmpty
      ? row.targetType
      : '${row.targetType}:${row.targetId}';
  if (row.projectId == null || row.scriptId == null) {
    return QualityMemoryDraft(
      projectId: row.projectId,
      episodesId: row.scriptId,
      agentType: row.targetType == 'script' || row.targetType == 'storyboard'
          ? 'scriptAgent'
          : 'productionAgent',
      memoryType: 'summary',
      role: 'assistant',
      name: 'quality_feedback_memory',
      summary: '缺少 project/script 归属，不能写入隔离记忆',
      content: '',
      canAppend: false,
      blockingReason: '样本没有 projectId 或 scriptId，不能安全写入独立记忆。',
    );
  }

  final agentType = row.targetType == 'script' || row.targetType == 'storyboard'
      ? 'scriptAgent'
      : 'productionAgent';
  final details = <String>[
    'sample=${row.reviewId}',
    'target=$targetLabel',
    'action=${row.recommendedAction}',
  ];
  final baseSummary =
      '$agentType · summary · project#${row.projectId} / script#${row.scriptId}';

  switch (row.recommendedAction) {
    case 'shift_to_delivery_memory':
      return QualityMemoryDraft(
        projectId: row.projectId,
        episodesId: row.scriptId,
        agentType: agentType,
        memoryType: 'summary',
        role: 'assistant',
        name: 'quality_feedback_memory',
        summary: '$baseSummary · 优先把预算给情绪、动作、语气',
        content:
            '${details.join(" | ")} | keep=停顿、气口、表情反应、口型同步、动作反馈 | trim=泛设定、长环境描写、重复风格词 | reason=${row.recommendedActionReason}',
        canAppend: true,
      );
    case 'trim_project_memory':
      return QualityMemoryDraft(
        projectId: row.projectId,
        episodesId: row.scriptId,
        agentType: agentType,
        memoryType: 'summary',
        role: 'assistant',
        name: 'quality_feedback_memory',
        summary: '$baseSummary · 先压缩 project 级泛记忆',
        content:
            '${details.join(" | ")} | keep=角色身份、世界观主设定 | trim=重复风格词、长环境模板、无关镜头铺陈 | dominantScope=${row.dominantMemoryScope}',
        canAppend: true,
      );
    case 'split_mixed_memory':
      return QualityMemoryDraft(
        projectId: row.projectId,
        episodesId: row.scriptId,
        agentType: agentType,
        memoryType: 'summary',
        role: 'assistant',
        name: 'quality_feedback_memory',
        summary: '$baseSummary · 拆开 project/script 混合记忆',
        content:
            '${details.join(" | ")} | projectMemory=长期风格和角色身份 | scriptMemory=当前镜头动作、情绪、台词节奏 | avoid=同条记忆混写跨层信息',
        canAppend: true,
      );
    case 'trim_script_memory_keep_delivery':
      return QualityMemoryDraft(
        projectId: row.projectId,
        episodesId: row.scriptId,
        agentType: agentType,
        memoryType: 'summary',
        role: 'assistant',
        name: 'quality_feedback_memory',
        summary: '$baseSummary · 保留表演约束，删剧情复述',
        content:
            '${details.join(" | ")} | keep=情绪起伏、动作反馈、语气和口型同步 | trim=剧情复述、重复人物外观、解释性镜头语言',
        canAppend: true,
      );
    case 'trim_script_memory':
      return QualityMemoryDraft(
        projectId: row.projectId,
        episodesId: row.scriptId,
        agentType: agentType,
        memoryType: 'summary',
        role: 'assistant',
        name: 'quality_feedback_memory',
        summary: '$baseSummary · 缩短 script 级记忆',
        content:
            '${details.join(" | ")} | keep=当前镜头最关键的人物状态和动作 | trim=重复设定、过长氛围词、非当前镜头信息',
        canAppend: true,
      );
    default:
      return QualityMemoryDraft(
        projectId: row.projectId,
        episodesId: row.scriptId,
        agentType: agentType,
        memoryType: 'summary',
        role: 'assistant',
        name: 'quality_feedback_memory',
        summary: '$baseSummary · 当前更适合先收紧核心 prompt',
        content: '',
        canAppend: false,
        blockingReason: '这个样本的首要动作是收紧核心 prompt，不建议先追加记忆。',
      );
  }
}

String summarizeQualityReviews(
  Iterable<QualityReview> rows, {
  int maxItems = 4,
}) {
  final items = rows.toList(growable: false);
  if (items.isEmpty) {
    return '当前没有质量评审';
  }
  final visible = items
      .take(maxItems)
      .map((row) {
        final score = row.overallScore?.toString() ?? 'n/a';
        return '${row.targetType}:${row.source}:$score';
      })
      .join(', ');
  final suffix = items.length > maxItems ? '…' : '';
  return '评审 ${items.length} 条 · $visible$suffix';
}

String summarizeQualityStatsRows(
  Iterable<QualityStatsRow> rows, {
  int maxItems = 3,
}) {
  final items = rows.toList(growable: false);
  if (items.isEmpty) {
    return '当前没有质量统计';
  }
  final visible = items
      .take(maxItems)
      .map((row) {
        final delivery = row.deliveryPriorityTotalReviews == 0
            ? 'delivery=n/a'
            : 'delivery=${row.deliveryPriorityPassRatePercent.toStringAsFixed(1)}%';
        final nonDelivery = row.nonDeliveryPriorityTotalReviews == 0
            ? 'non=n/a'
            : 'non=${row.nonDeliveryPriorityPassRatePercent.toStringAsFixed(1)}%';
        return '${row.targetType}: total=${row.totalReviews}, pass=${row.passRatePercent.toStringAsFixed(1)}% ($delivery, $nonDelivery)';
      })
      .join(' | ');
  final suffix = items.length > maxItems ? ' | …' : '';
  return '$visible$suffix';
}

String summarizeStagePassRateRows(
  Iterable<StagePassRateRow> rows, {
  int maxItems = 4,
}) {
  final items = rows.toList(growable: false);
  if (items.isEmpty) {
    return '当前没有阶段通过率';
  }
  final visible = items
      .take(maxItems)
      .map((row) {
        final date = row.reviewDate.length >= 10
            ? row.reviewDate.substring(0, 10)
            : row.reviewDate;
        final passRate = row.passRatePercent?.toStringAsFixed(1) ?? 'n/a';
        final delivery = row.deliveryPriorityTotalReviews == 0
            ? 'delivery=n/a'
            : 'delivery=${row.deliveryPriorityPassRatePercent.toStringAsFixed(1)}%';
        final nonDelivery = row.nonDeliveryPriorityTotalReviews == 0
            ? 'non=n/a'
            : 'non=${row.nonDeliveryPriorityPassRatePercent.toStringAsFixed(1)}%';
        return '$date ${row.targetType}:$passRate% ($delivery, $nonDelivery)';
      })
      .join(' | ');
  final suffix = items.length > maxItems ? ' | …' : '';
  return '$visible$suffix';
}

String summarizeQualityTokenEfficiencyRows(
  Iterable<QualityTokenEfficiencyRow> rows, {
  int maxItems = 3,
}) {
  final items = rows.toList(growable: false);
  if (items.isEmpty) {
    return '当前没有 token 效率统计';
  }
  final visible = items
      .take(maxItems)
      .map((row) {
        final linked = '${row.linkedLlmReviewCount}/${row.totalReviews}';
        final avgScore = row.avgOverallScore.toStringAsFixed(1);
        final deliveryMemory = row.avgMemoryDeliveryChars.toStringAsFixed(0);
        final visualMemory = row.avgMemoryVisualChars.toStringAsFixed(0);
        final scriptScope = row.avgMemoryScriptScopeChars.toStringAsFixed(0);
        final projectScope = row.avgMemoryProjectScopeChars.toStringAsFixed(0);
        final mixedScope = row.avgMemoryMixedScopeChars.toStringAsFixed(0);
        final promptPerScore = row.avgPromptCharsPerScorePoint.toStringAsFixed(
          1,
        );
        final tokenPerScore = row.avgLinkedTokensPerScorePoint.toStringAsFixed(
          1,
        );
        final deliveryTokenPerScore = row
            .deliveryPriorityAvgLinkedTokensPerScorePoint
            .toStringAsFixed(1);
        final nonDeliveryTokenPerScore = row
            .nonDeliveryPriorityAvgLinkedTokensPerScorePoint
            .toStringAsFixed(1);
        return '${row.targetType}: linked=$linked, avgScore=$avgScore, mem=d$deliveryMemory/v$visualMemory scope=s$scriptScope/p$projectScope/m$mixedScope, prompt/score=$promptPerScore, token/score=$tokenPerScore (delivery=$deliveryTokenPerScore, non=$nonDeliveryTokenPerScore)';
      })
      .join(' | ');
  final suffix = items.length > maxItems ? ' | …' : '';
  return '$visible$suffix';
}

String summarizeQualityTokenEfficiencySampleRows(
  Iterable<QualityTokenEfficiencySampleRow> rows, {
  int maxItems = 3,
}) {
  final items = rows.toList(growable: false);
  if (items.isEmpty) {
    return '当前没有低效样本';
  }
  final visible = items
      .take(maxItems)
      .map((row) {
        final score = row.overallScore?.toString() ?? 'n/a';
        final promptPerScore = row.promptCharsPerScorePoint.toStringAsFixed(1);
        final tokenPerScore = row.linkedTokensPerScorePoint.toStringAsFixed(1);
        final flags = <String>[
          if (row.isBadCase) 'bad',
          if (row.memoryDeliveryPriorityApplied == true) 'delivery',
          row.dominantMemoryScope,
        ].join('/');
        final action = row.recommendedAction.replaceAll('_', '-');
        return '${row.targetType}:score=$score,p=$promptPerScore,t=$tokenPerScore,$flags->$action';
      })
      .join(' | ');
  final suffix = items.length > maxItems ? ' | …' : '';
  return '$visible$suffix';
}

String formatQualityTokenEfficiencySampleDetails(
  QualityTokenEfficiencySampleRow row,
) {
  return [
    row.reviewId,
    row.targetType,
    'scope=${row.dominantMemoryScope}',
    'action=${row.recommendedAction}',
    'reason=${row.recommendedActionReason}',
    if (row.overallScore != null) 'score=${row.overallScore}',
    'prompt/score=${row.promptCharsPerScorePoint.toStringAsFixed(1)}',
    'token/score=${row.linkedTokensPerScorePoint.toStringAsFixed(1)}',
  ].join(' · ');
}

String formatQualityReviewDetails(QualityReview row) {
  return [
    row.id,
    row.targetType,
    row.source,
    if (row.memoryDeliveryPriorityApplied != null)
      'delivery_priority=${row.memoryDeliveryPriorityApplied}',
    if (row.targetId != null && row.targetId!.isNotEmpty)
      'target=${row.targetId}',
    if (row.overallScore != null) 'score=${row.overallScore}',
    if (row.passed != null) 'passed=${row.passed}',
    if (row.isBadCase) 'bad_case',
    if (row.badCaseCategory != null) 'category=${row.badCaseCategory}',
  ].join(' · ');
}
