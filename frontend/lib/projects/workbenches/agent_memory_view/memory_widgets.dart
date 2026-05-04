part of '../agent_memory_view.dart';

class _AgentMemoryInsights {
  const _AgentMemoryInsights({
    required this.previews,
    required this.topBuckets,
    required this.summary,
    required this.videoSummary,
    required this.efficiencySummary,
    required this.bucketPrioritySummary,
    required this.recommendation,
  });

  final List<_AgentMemoryPreview> previews;
  final List<_MemoryBucketStats> topBuckets;
  final String? summary;
  final String? videoSummary;
  final String? efficiencySummary;
  final String? bucketPrioritySummary;
  final String? recommendation;
}

class _AgentMemoryPreview {
  const _AgentMemoryPreview({
    required this.memoryId,
    required this.memoryName,
    required this.role,
    required this.shortContent,
    required this.charCount,
    required this.normalizedPrefix,
    required this.isDuplicated,
    required this.classificationLabel,
    required this.actionLabel,
    required this.scopeLabel,
    required this.subjectLabel,
    required this.signalLabel,
  });

  final String memoryId;
  final String memoryName;
  final String role;
  final String shortContent;
  final int charCount;
  final String normalizedPrefix;
  final bool isDuplicated;
  final String classificationLabel;
  final String actionLabel;
  final String scopeLabel;
  final String subjectLabel;
  final String signalLabel;
}

_AgentMemoryInsights _buildAgentMemoryInsights(
  List<AgentMemoryHistoryItem> rows,
) {
  final rawPreviews = rows
      .map(_buildAgentMemoryPreview)
      .toList(growable: false);
  if (rawPreviews.isEmpty) {
    return const _AgentMemoryInsights(
      previews: <_AgentMemoryPreview>[],
      topBuckets: <_MemoryBucketStats>[],
      summary: null,
      videoSummary: null,
      efficiencySummary: null,
      bucketPrioritySummary: null,
      recommendation: null,
    );
  }

  final prefixCounts = <String, int>{};
  final roleCounts = <String, int>{};
  final memoryNameCounts = <String, int>{};
  var totalChars = 0;
  var longestChars = 0;
  var deliveryRows = 0;
  var deliveryChars = 0;
  var visualRows = 0;
  var visualChars = 0;
  var rejectedRows = 0;
  var rejectedChars = 0;
  var keepRows = 0;
  var keepChars = 0;
  var trimRows = 0;
  var trimChars = 0;
  var mergeRows = 0;
  var mergeChars = 0;
  for (final preview in rawPreviews) {
    totalChars += preview.charCount;
    if (preview.charCount > longestChars) {
      longestChars = preview.charCount;
    }
    roleCounts.update(preview.role, (value) => value + 1, ifAbsent: () => 1);
    if (preview.memoryName.isNotEmpty) {
      memoryNameCounts.update(
        preview.memoryName,
        (value) => value + 1,
        ifAbsent: () => 1,
      );
    }
    if (preview.normalizedPrefix.isNotEmpty) {
      prefixCounts.update(
        preview.normalizedPrefix,
        (value) => value + 1,
        ifAbsent: () => 1,
      );
    }
    switch (preview.classificationLabel) {
      case '表演优先':
      case '表演+视觉':
        deliveryRows += 1;
        deliveryChars += preview.charCount;
        break;
      case '视觉偏重':
        visualRows += 1;
        visualChars += preview.charCount;
        break;
      case '坏例约束':
        rejectedRows += 1;
        rejectedChars += preview.charCount;
        break;
    }
    switch (preview.actionLabel) {
      case '优先保留':
        keepRows += 1;
        keepChars += preview.charCount;
        break;
      case '待压缩':
        trimRows += 1;
        trimChars += preview.charCount;
        break;
      case '合并坏例':
        mergeRows += 1;
        mergeChars += preview.charCount;
        break;
    }
  }

  final previews =
      rawPreviews
          .map(
            (preview) => _AgentMemoryPreview(
              memoryId: preview.memoryId,
              memoryName: preview.memoryName,
              role: preview.role,
              shortContent: preview.shortContent,
              charCount: preview.charCount,
              normalizedPrefix: preview.normalizedPrefix,
              isDuplicated:
                  preview.normalizedPrefix.isNotEmpty &&
                  (prefixCounts[preview.normalizedPrefix] ?? 0) > 1,
              classificationLabel: preview.classificationLabel,
              actionLabel: preview.actionLabel,
              scopeLabel: preview.scopeLabel,
              subjectLabel: preview.subjectLabel,
              signalLabel: preview.signalLabel,
            ),
          )
          .toList(growable: false)
        ..sort(_compareAgentMemoryPreviewPriority);
  final duplicateCount = previews
      .where((preview) => preview.isDuplicated)
      .length;
  final rolesSummary = roleCounts.entries
      .map((entry) => '${entry.key} ${entry.value}')
      .join(' / ');
  final memoryNamesSummary = memoryNameCounts.entries.toList(growable: false)
    ..sort((a, b) => b.value.compareTo(a.value));
  final bucketStats = <String, _MemoryBucketStats>{};
  final typeSummary = memoryNamesSummary.isEmpty
      ? null
      : memoryNamesSummary
            .take(3)
            .map((entry) => '${entry.key} ${entry.value}')
            .join(' / ');
  final summary =
      '角色分布：$rolesSummary${typeSummary == null ? '' : ' · 类型 $typeSummary'} · 约 $totalChars chars · 最长 $longestChars chars${duplicateCount > 0 ? ' · 重复 $duplicateCount 条' : ''}';
  final hasVideoMemorySummary =
      deliveryRows > 0 || visualRows > 0 || rejectedRows > 0;
  final videoSummary = hasVideoMemorySummary
      ? '视频记忆：delivery $deliveryRows/$deliveryChars chars · visual $visualRows/$visualChars chars · negative $rejectedRows/$rejectedChars chars'
      : null;
  final hasEfficiencySummary = keepRows > 0 || trimRows > 0 || mergeRows > 0;
  final efficiencySummary = hasEfficiencySummary
      ? '处理建议：保留 $keepRows/$keepChars chars · 压缩 $trimRows/$trimChars chars · 合并坏例 $mergeRows/$mergeChars chars'
      : null;
  for (final preview in previews) {
    if (preview.memoryName.isEmpty || preview.actionLabel.isEmpty) {
      continue;
    }
    bucketStats.update(
      preview.memoryName,
      (existing) => existing.merge(preview),
      ifAbsent: () => _MemoryBucketStats.fromPreview(preview),
    );
  }
  final bucketPrioritySummary = _buildBucketPrioritySummary(bucketStats);
  final rankedBuckets = _rankMemoryBuckets(bucketStats);
  String? recommendation;
  if (duplicateCount >= 2) {
    recommendation = '检测到重复表述，先去重旧记忆，避免同一约束反复注入。';
  } else if (visualRows >= 2 && deliveryRows == 0 && rejectedRows == 0) {
    recommendation = '当前视频记忆几乎只有镜头/光影，先补一条表演、语气或情绪锚点，再决定删哪条视觉记忆。';
  } else if (visualRows >= 2 &&
      visualChars >= deliveryChars + 40 &&
      deliveryRows > 0) {
    recommendation = '视觉偏重记忆吃掉了更多预算，先清理只保留镜头/光影的旧条目，把 chars 留给表演、语气和情绪。';
  } else if (rejectedRows >= 3 && rejectedChars >= 180) {
    recommendation = '坏例约束累计较多，先合并重复 risk/avoid 片段，避免 negative memory 自己膨胀。';
  } else if (memoryNamesSummary.isNotEmpty &&
      memoryNamesSummary.first.value >= 6) {
    recommendation =
        '${memoryNamesSummary.first.key} 已累计 ${memoryNamesSummary.first.value} 条，先压缩这个记忆桶，避免它单独吃掉预算。';
  } else if (totalChars >= 1600 || longestChars >= 420) {
    recommendation = '当前记忆偏长，优先压缩长记忆，再决定是否继续追加。';
  } else if (rows.length >= 12) {
    recommendation = '条数偏多，先读取 summary 或清理旧 message，给当前镜头约束留预算。';
  } else if ((roleCounts['assistant'] ?? 0) >= 3 &&
      (roleCounts['assistant'] ?? 0) > (roleCounts['user'] ?? 0) * 2) {
    recommendation = 'assistant 记忆偏多，先清旧总结，只保留最新执行约束。';
  }

  return _AgentMemoryInsights(
    previews: previews,
    topBuckets: rankedBuckets.take(3).toList(growable: false),
    summary: summary,
    videoSummary: videoSummary,
    efficiencySummary: efficiencySummary,
    bucketPrioritySummary: bucketPrioritySummary,
    recommendation: recommendation,
  );
}

class _MemoryTierGroup {
  const _MemoryTierGroup({
    required this.tier,
    required this.label,
    required this.rows,
    required this.lastInjectedLabel,
  });

  final String tier;
  final String label;
  final List<AgentMemoryHistoryItem> rows;
  final String lastInjectedLabel;
}

List<_MemoryTierGroup> _buildMemoryTierGroups(
  List<AgentMemoryHistoryItem> rows,
) {
  if (rows.isEmpty) {
    return const <_MemoryTierGroup>[];
  }
  final grouped = <String, List<AgentMemoryHistoryItem>>{};
  for (final row in rows) {
    grouped
        .putIfAbsent(row.memoryTier, () => <AgentMemoryHistoryItem>[])
        .add(row);
  }
  return _memoryTierOrder
      .where(grouped.containsKey)
      .map((tier) {
        final groupRows = grouped[tier]!
          ..sort((left, right) {
            final previewOrder = _compareAgentMemoryPreviewPriority(
              _buildAgentMemoryPreview(left),
              _buildAgentMemoryPreview(right),
            );
            if (previewOrder != 0) {
              return previewOrder;
            }
            return right.createTime.compareTo(left.createTime);
          });
        return _MemoryTierGroup(
          tier: tier,
          label: _memoryTierLabel(tier),
          rows: groupRows,
          lastInjectedLabel: _formatMemoryTimestamp(groupRows.first.datetime),
        );
      })
      .toList(growable: false);
}

String? _buildCostOverviewLine(AgentMemoryCostOverview? overview) {
  if (overview == null) {
    return null;
  }
  final lastInjected = overview.lastInjectedAt == null
      ? '暂无'
      : _formatMemoryTimestamp(overview.lastInjectedAt!);
  return '成本概览：风格圣经 ${overview.styleBibleCount} 条 · 阶段摘要 ${overview.stageSummaryCount} 条 · 增量记忆 ${overview.deltaMemoryCount} 条 · 普通消息 ${overview.messageCount} 条 · 近 30 次平均注入 ${overview.avgInjectedCharsLast30} 字 · 近 30 次平均命中层级 ${overview.avgHitTierCountLast30} 个 · 最近注入 $lastInjected';
}

String _memoryTierLabel(String tier) {
  switch (tier) {
    case 'all':
      return '全部';
    case 'style_bible':
      return '风格圣经';
    case 'stage_summary':
      return '阶段摘要';
    case 'delta_memory':
      return '增量记忆';
    case 'message':
    default:
      return '普通消息';
  }
}

String _formatMemoryTimestamp(String raw) {
  try {
    final parsed = DateTime.parse(raw).toLocal();
    final mm = parsed.month.toString().padLeft(2, '0');
    final dd = parsed.day.toString().padLeft(2, '0');
    final hh = parsed.hour.toString().padLeft(2, '0');
    final min = parsed.minute.toString().padLeft(2, '0');
    return '$mm-$dd $hh:$min';
  } catch (_) {
    return raw;
  }
}

const List<String> _memoryTierOrder = <String>[
  'style_bible',
  'stage_summary',
  'delta_memory',
  'message',
];

class _MemoryBucketStats {
  const _MemoryBucketStats({
    required this.memoryName,
    required this.rowCount,
    required this.charCount,
    required this.actionLabel,
  });

  factory _MemoryBucketStats.fromPreview(_AgentMemoryPreview preview) {
    return _MemoryBucketStats(
      memoryName: preview.memoryName,
      rowCount: 1,
      charCount: preview.charCount,
      actionLabel: preview.actionLabel,
    );
  }

  final String memoryName;
  final int rowCount;
  final int charCount;
  final String actionLabel;

  _MemoryBucketStats merge(_AgentMemoryPreview preview) {
    final mergedAction =
        _actionPriority(preview.actionLabel) > _actionPriority(actionLabel)
        ? preview.actionLabel
        : actionLabel;
    return _MemoryBucketStats(
      memoryName: memoryName,
      rowCount: rowCount + 1,
      charCount: charCount + preview.charCount,
      actionLabel: mergedAction,
    );
  }
}

String? _buildBucketPrioritySummary(
  Map<String, _MemoryBucketStats> bucketStats,
) {
  if (bucketStats.isEmpty) return null;
  final ranked = _rankMemoryBuckets(bucketStats);
  return '记忆桶优先级：${ranked.take(3).map((bucket) => '${bucket.actionLabel} ${bucket.memoryName} ${bucket.rowCount}条/${bucket.charCount} chars').join(' | ')}';
}

List<_MemoryBucketStats> _rankMemoryBuckets(
  Map<String, _MemoryBucketStats> bucketStats,
) {
  final ranked = bucketStats.values.toList(growable: false)
    ..sort((left, right) {
      final byAction = _actionPriority(
        right.actionLabel,
      ).compareTo(_actionPriority(left.actionLabel));
      if (byAction != 0) return byAction;
      final byChars = right.charCount.compareTo(left.charCount);
      if (byChars != 0) return byChars;
      return left.memoryName.compareTo(right.memoryName);
    });
  return ranked;
}

String? _buildScopedExecutionChecklist(
  ProjectsAgentMemoryWorkbenchDialogViewModel model,
  _AgentMemoryInsights insights,
) {
  if (insights.previews.isEmpty) return null;
  final projectId = model.projectIdCtrl.text.trim();
  final agentType = model.agentTypeCtrl.text.trim();
  final episodesId = model.episodesIdCtrl.text.trim();
  final scopeLabel = [
    if (projectId.isNotEmpty) 'P$projectId',
    if (agentType.isNotEmpty) agentType,
    if (episodesId.isNotEmpty) 'E$episodesId',
  ].join(' / ');
  final steps = <String>[
    '范围：只处理 ${scopeLabel.isEmpty ? "当前查询 scope" : scopeLabel} 的记忆，不跨用户、项目或短剧复用。',
  ];
  for (final bucket in insights.topBuckets) {
    final action = switch (bucket.actionLabel) {
      '待压缩' => '压缩 ${bucket.memoryName} 的镜头/光影/氛围套话，优先保留表演、语气、情绪和人物一致性片段。',
      '合并坏例' =>
        '合并 ${bucket.memoryName} 的重复 risk/avoid 约束，保留最能防止穿帮、口型僵硬和身份漂移的坏例。',
      '优先保留' =>
        '保留 ${bucket.memoryName} 里最具体的表演/情绪锚点，避免删掉能让人物不读稿、不木的 delivery 记忆。',
      _ => '观察 ${bucket.memoryName} 的新增条目，避免继续堆重复记忆。',
    };
    steps.add(action);
  }
  if (insights.recommendation != null) {
    steps.add('当前提醒：${insights.recommendation}');
  }
  return '记忆执行清单：${steps.join(' ')}';
}

int _compareAgentMemoryPreviewPriority(
  _AgentMemoryPreview left,
  _AgentMemoryPreview right,
) {
  final duplicateOrder = (right.isDuplicated ? 1 : 0).compareTo(
    left.isDuplicated ? 1 : 0,
  );
  if (duplicateOrder != 0) {
    return duplicateOrder;
  }
  final actionOrder = _actionPriority(
    right.actionLabel,
  ).compareTo(_actionPriority(left.actionLabel));
  if (actionOrder != 0) {
    return actionOrder;
  }
  final charOrder = right.charCount.compareTo(left.charCount);
  if (charOrder != 0) {
    return charOrder;
  }
  return left.memoryId.compareTo(right.memoryId);
}

int _actionPriority(String actionLabel) {
  switch (actionLabel) {
    case '待压缩':
      return 4;
    case '合并坏例':
      return 3;
    case '优先保留':
      return 2;
    case '待观察':
      return 1;
    default:
      return 0;
  }
}

_AgentMemoryPreview _buildAgentMemoryPreview(AgentMemoryHistoryItem row) {
  final memoryName = row.name ?? '';
  final role = row.role;
  final content = row.plainTextContent;
  final shortContent = content.length > 60
      ? '${content.substring(0, 60)}…'
      : content;
  final normalizedPrefix = _memorySemanticDedupKey(content);
  final classificationLabel = _memoryClassificationLabel(memoryName, content);
  final actionLabel = _memoryActionLabel(
    memoryName,
    content,
    classificationLabel,
  );
  final scopeLabel = _memoryScopeLabel(content);
  final subjectLabel = _extractMemoryKeyValue(content, 'subject') ?? '';
  final signalLabel = _memorySignalLabel(content, classificationLabel);
  return _AgentMemoryPreview(
    memoryId: row.id,
    memoryName: memoryName,
    role: role,
    shortContent: shortContent,
    charCount: content.characters.length,
    normalizedPrefix: normalizedPrefix.length > 18
        ? normalizedPrefix.substring(0, 18)
        : normalizedPrefix,
    isDuplicated: false,
    classificationLabel: classificationLabel,
    actionLabel: actionLabel,
    scopeLabel: scopeLabel,
    subjectLabel: subjectLabel,
    signalLabel: signalLabel,
  );
}

String _memoryClassificationLabel(String memoryName, String content) {
  if (memoryName == 'rejected_video_negative_memory') {
    return '坏例约束';
  }
  if (!_isVideoStyleMemory(memoryName)) {
    return '';
  }
  final deliverySignals = _countKeywordMatches(
    content,
    _deliveryMemoryKeywords,
  );
  final visualSignals = _countKeywordMatches(content, _visualMemoryKeywords);
  if (deliverySignals > 0 && visualSignals > 0) {
    return '表演+视觉';
  }
  if (deliverySignals > 0) {
    return '表演优先';
  }
  if (visualSignals > 0) {
    return '视觉偏重';
  }
  return '视频记忆';
}

String _memoryActionLabel(
  String memoryName,
  String content,
  String classificationLabel,
) {
  if (memoryName == 'rejected_video_negative_memory') {
    final rejectionCount = int.tryParse(
      _extractMemoryKeyValue(content, 'rejectionCount') ?? '',
    );
    final riskTags = _extractMemoryKeyValue(content, 'riskTags') ?? '';
    if ((rejectionCount ?? 0) >= 2 || riskTags.isNotEmpty) {
      return '合并坏例';
    }
    return '待观察';
  }
  if (!_isVideoStyleMemory(memoryName)) {
    return '';
  }
  final hasSubject =
      (_extractMemoryKeyValue(content, 'subject') ?? '').isNotEmpty;
  final hasDelivery =
      _extractMemoryKeyValue(content, 'delivery')?.isNotEmpty == true ||
      _countKeywordMatches(content, _deliveryMemoryKeywords) > 0;
  final riskTags = (_extractMemoryKeyValue(content, 'riskTags') ?? '')
      .toLowerCase();
  final hasHighValueRisk =
      riskTags.contains('identity') ||
      riskTags.contains('dialogue') ||
      riskTags.contains('performance');
  if (classificationLabel == '视觉偏重') {
    return '待压缩';
  }
  if (hasDelivery && (hasSubject || hasHighValueRisk)) {
    return '优先保留';
  }
  if (classificationLabel == '表演优先' || classificationLabel == '表演+视觉') {
    return '优先保留';
  }
  return '待观察';
}

bool _isVideoStyleMemory(String memoryName) {
  return memoryName == 'selected_video_memory' ||
      memoryName == 'script_role_video_style_memory' ||
      memoryName == 'script_video_style_memory' ||
      memoryName == 'project_video_style_memory' ||
      memoryName == 'project_role_video_style_memory';
}

int _countKeywordMatches(String content, List<String> keywords) {
  final normalized = content.toLowerCase();
  return keywords.where((keyword) => normalized.contains(keyword)).length;
}

String _memorySignalLabel(String content, String classificationLabel) {
  final tags = <String>{};
  final subject = _extractMemoryKeyValue(content, 'subject') ?? '';
  final delivery = _extractMemoryKeyValue(content, 'delivery') ?? '';
  final riskTags = _extractMemoryKeyValue(content, 'riskTags') ?? '';
  final rejectionCount =
      _extractMemoryKeyValue(content, 'rejectionCount') ?? '';
  if (subject.isNotEmpty) {
    tags.add('人物');
  }
  if (delivery.isNotEmpty ||
      classificationLabel == '表演优先' ||
      classificationLabel == '表演+视觉') {
    tags.add('情绪');
  }
  if (classificationLabel == '表演+视觉') {
    tags.add('镜头');
  } else if (classificationLabel == '视觉偏重') {
    tags.add('视觉');
  }
  if (riskTags.contains('identity')) {
    tags.add('身份');
  }
  if (riskTags.contains('dialogue')) {
    tags.add('台词');
  }
  if (riskTags.contains('performance')) {
    tags.add('表演');
  }
  if (rejectionCount.isNotEmpty) {
    tags.add('坏例$rejectionCount');
  }
  return tags.join('/');
}

String _memoryScopeLabel(String content) {
  final storyboardIds = _extractMemoryKeyValue(content, 'storyboardIds');
  if (storyboardIds != null && storyboardIds.isNotEmpty) {
    return 'storyboard $storyboardIds';
  }
  final sampleCount = _extractMemoryKeyValue(content, 'sampleCount');
  if (sampleCount != null && sampleCount.isNotEmpty) {
    return 'samples $sampleCount';
  }
  return '';
}

String? _extractMemoryKeyValue(String content, String key) {
  for (final part in content.split('|')) {
    final trimmed = part.trim();
    if (!trimmed.startsWith('$key=')) {
      continue;
    }
    final value = trimmed.substring(key.length + 1).trim();
    if (value.isNotEmpty) {
      return value;
    }
  }
  return null;
}

String _memorySemanticDedupKey(String content) {
  final semantic = <String>[
    _extractMemoryKeyValue(content, 'delivery') ?? '',
    _extractMemoryKeyValue(content, 'note') ?? '',
    _extractMemoryKeyValue(content, 'avoid') ?? '',
    _extractMemoryKeyValue(content, 'style') ?? '',
    content,
  ].firstWhere((value) => value.trim().isNotEmpty, orElse: () => content);
  return semantic.replaceAll(RegExp(r'\s+'), '').toLowerCase();
}

const List<String> _deliveryMemoryKeywords = <String>[
  '表演',
  '语气',
  '情绪',
  '呼吸',
  '停顿',
  '眼神',
  '口型',
  '微表情',
  'emotion',
  'expression',
  'delivery',
  'lip',
];

const List<String> _visualMemoryKeywords = <String>[
  '镜头',
  '光影',
  '光线',
  '逆光',
  '暖光',
  '冷光',
  '运镜',
  '构图',
  '机位',
  '近景',
  '中景',
  '远景',
  'camera',
  'lighting',
  'framing',
];
