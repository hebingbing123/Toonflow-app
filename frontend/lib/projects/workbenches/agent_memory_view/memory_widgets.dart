part of '../agent_memory_view.dart';

/// Internal classification slugs (stable across locales).
const String _memClsNeg = 'mem_cls_neg';
const String _memClsDelVis = 'mem_cls_del_vis';
const String _memClsDelFirst = 'mem_cls_del_first';
const String _memClsVisHeavy = 'mem_cls_vis_heavy';
const String _memClsVideo = 'mem_cls_video';

/// Internal action slugs (stable across locales).
const String _memActMerge = 'mem_act_merge';
const String _memActObserve = 'mem_act_observe';
const String _memActCompress = 'mem_act_compress';
const String _memActKeep = 'mem_act_keep';

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

  /// Internal classification slug (see `_memCls*`).
  final String classificationLabel;

  /// Internal action slug (see `_memAct*`).
  final String actionLabel;
  final String scopeLabel;
  final String subjectLabel;
  final String signalLabel;
}

String _displayMemoryClass(AppLocalizations l10n, String slug) {
  switch (slug) {
    case _memClsNeg:
      return l10n.agentMemoryClassNegative;
    case _memClsDelVis:
      return l10n.agentMemoryClassDeliveryVisual;
    case _memClsDelFirst:
      return l10n.agentMemoryClassDeliveryFirst;
    case _memClsVisHeavy:
      return l10n.agentMemoryClassVisualHeavy;
    case _memClsVideo:
      return l10n.agentMemoryClassVideoMemory;
    case '':
      return '';
    default:
      return slug;
  }
}

String _displayMemoryAction(AppLocalizations l10n, String slug) {
  switch (slug) {
    case _memActMerge:
      return l10n.agentMemoryActionMergeNegative;
    case _memActObserve:
      return l10n.agentMemoryActionObserve;
    case _memActCompress:
      return l10n.agentMemoryActionCompress;
    case _memActKeep:
      return l10n.agentMemoryActionKeep;
    case '':
      return '';
    default:
      return slug;
  }
}

_AgentMemoryInsights _buildAgentMemoryInsights(
  List<AgentMemoryHistoryItem> rows,
  AppLocalizations l10n,
) {
  final rawPreviews = rows
      .map((row) => _buildAgentMemoryPreview(row, l10n))
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
      case _memClsDelFirst:
      case _memClsDelVis:
        deliveryRows += 1;
        deliveryChars += preview.charCount;
        break;
      case _memClsVisHeavy:
        visualRows += 1;
        visualChars += preview.charCount;
        break;
      case _memClsNeg:
        rejectedRows += 1;
        rejectedChars += preview.charCount;
        break;
    }
    switch (preview.actionLabel) {
      case _memActKeep:
        keepRows += 1;
        keepChars += preview.charCount;
        break;
      case _memActCompress:
        trimRows += 1;
        trimChars += preview.charCount;
        break;
      case _memActMerge:
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
  final typesPart = typeSummary == null
      ? ''
      : l10n.agentMemoryInsightTypesPart(typeSummary);
  final dupPart = duplicateCount > 0
      ? l10n.agentMemoryInsightDupPart(duplicateCount)
      : '';
  final summary = l10n.agentMemoryInsightCore(
    rolesSummary,
    typesPart,
    totalChars,
    longestChars,
    dupPart,
  );
  final hasVideoMemorySummary =
      deliveryRows > 0 || visualRows > 0 || rejectedRows > 0;
  final videoSummary = hasVideoMemorySummary
      ? l10n.agentMemoryVideoInsight(
          deliveryRows,
          deliveryChars,
          visualRows,
          visualChars,
          rejectedRows,
          rejectedChars,
        )
      : null;
  final hasEfficiencySummary = keepRows > 0 || trimRows > 0 || mergeRows > 0;
  final efficiencySummary = hasEfficiencySummary
      ? l10n.agentMemoryEfficiencyInsight(
          keepRows,
          keepChars,
          trimRows,
          trimChars,
          mergeRows,
          mergeChars,
        )
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
  final bucketPrioritySummary = _buildBucketPrioritySummary(bucketStats, l10n);
  final rankedBuckets = _rankMemoryBuckets(bucketStats);
  String? recommendation;
  if (duplicateCount >= 2) {
    recommendation = l10n.agentMemoryRecDup;
  } else if (visualRows >= 2 && deliveryRows == 0 && rejectedRows == 0) {
    recommendation = l10n.agentMemoryRecVisualOnly;
  } else if (visualRows >= 2 &&
      visualChars >= deliveryChars + 40 &&
      deliveryRows > 0) {
    recommendation = l10n.agentMemoryRecVisualBudget;
  } else if (rejectedRows >= 3 && rejectedChars >= 180) {
    recommendation = l10n.agentMemoryRecNegativeMerge;
  } else if (memoryNamesSummary.isNotEmpty &&
      memoryNamesSummary.first.value >= 6) {
    recommendation = l10n.agentMemoryRecBucketHot(
      memoryNamesSummary.first.key,
      memoryNamesSummary.first.value,
    );
  } else if (totalChars >= 1600 || longestChars >= 420) {
    recommendation = l10n.agentMemoryRecLong;
  } else if (rows.length >= 12) {
    recommendation = l10n.agentMemoryRecManyRows;
  } else if ((roleCounts['assistant'] ?? 0) >= 3 &&
      (roleCounts['assistant'] ?? 0) > (roleCounts['user'] ?? 0) * 2) {
    recommendation = l10n.agentMemoryRecAssistantHeavy;
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
  AppLocalizations l10n,
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
              _buildAgentMemoryPreview(left, l10n),
              _buildAgentMemoryPreview(right, l10n),
            );
            if (previewOrder != 0) {
              return previewOrder;
            }
            return right.createTime.compareTo(left.createTime);
          });
        return _MemoryTierGroup(
          tier: tier,
          label: _memoryTierLabel(l10n, tier),
          rows: groupRows,
          lastInjectedLabel: _formatMemoryTimestamp(groupRows.first.datetime),
        );
      })
      .toList(growable: false);
}

String? _buildCostOverviewLine(
  AppLocalizations l10n,
  AgentMemoryCostOverview? overview,
) {
  if (overview == null) {
    return null;
  }
  final lastInjected = overview.lastInjectedAt == null
      ? l10n.agentMemoryCostNever
      : _formatMemoryTimestamp(overview.lastInjectedAt!);
  return l10n.agentMemoryCostOverviewLine(
    overview.scope,
    overview.styleBibleCount,
    overview.stageSummaryCount,
    overview.deltaMemoryCount,
    overview.messageCount,
    overview.avgInjectedCharsLast30,
    overview.avgHitTierCountLast30,
    lastInjected,
  );
}

String _memoryTierLabel(AppLocalizations l10n, String tier) {
  switch (tier) {
    case 'all':
      return l10n.agentMemoryTierAll;
    case 'style_bible':
      return l10n.agentMemoryTierStyleBible;
    case 'stage_summary':
      return l10n.agentMemoryTierStageSummary;
    case 'delta_memory':
      return l10n.agentMemoryTierDeltaMemory;
    case 'message':
    default:
      return l10n.agentMemoryTierMessage;
  }
}

String _agentMemoryQueryTypeLabel(AppLocalizations l10n, String value) {
  switch (value) {
    case 'summary':
      return l10n.agentMemoryQueryTypeSummary;
    case 'message':
      return l10n.agentMemoryQueryTypeMessage;
    case 'all':
      return l10n.agentMemoryQueryTypeAll;
    default:
      return value;
  }
}

String _agentMemoryAutomationModeLabel(AppLocalizations l10n, String value) {
  switch (value) {
    case 'standard':
      return l10n.agentMemoryAutomationStandard;
    case 'lean':
      return l10n.agentMemoryAutomationLean;
    case 'off':
      return l10n.agentMemoryAutomationOff;
    default:
      return value;
  }
}

String _agentMemoryAppendOrClearTypeLabel(AppLocalizations l10n, String value) {
  switch (value) {
    case 'summary':
      return l10n.agentMemoryAppendTypeSummary;
    case 'message':
      return l10n.agentMemoryAppendTypeMessage;
    case 'all':
      return l10n.agentMemoryQueryTypeAll;
    default:
      return value;
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

  /// Internal action slug.
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
  AppLocalizations l10n,
) {
  if (bucketStats.isEmpty) return null;
  final ranked = _rankMemoryBuckets(bucketStats);
  final detail = ranked
      .take(3)
      .map(
        (bucket) => l10n.agentMemoryBucketPriorityItem(
          _displayMemoryAction(l10n, bucket.actionLabel),
          bucket.memoryName,
          bucket.rowCount,
          bucket.charCount,
        ),
      )
      .join(' | ');
  return l10n.agentMemoryBucketPriorityLine(detail);
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
  AppLocalizations l10n,
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
    l10n.agentMemoryChecklistScope(
      scopeLabel.isEmpty ? l10n.agentMemoryChecklistScopeFallback : scopeLabel,
    ),
  ];
  for (final bucket in insights.topBuckets) {
    final action = switch (bucket.actionLabel) {
      _memActCompress => l10n.agentMemoryChecklistCompress(bucket.memoryName),
      _memActMerge => l10n.agentMemoryChecklistMerge(bucket.memoryName),
      _memActKeep => l10n.agentMemoryChecklistKeep(bucket.memoryName),
      _ => l10n.agentMemoryChecklistObserve(bucket.memoryName),
    };
    steps.add(action);
  }
  if (insights.recommendation != null) {
    steps.add(l10n.agentMemoryChecklistReminder(insights.recommendation!));
  }
  return '${l10n.agentMemoryChecklistTitle} ${steps.join(' ')}';
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
    case _memActCompress:
      return 4;
    case _memActMerge:
      return 3;
    case _memActKeep:
      return 2;
    case _memActObserve:
      return 1;
    default:
      return 0;
  }
}

_AgentMemoryPreview _buildAgentMemoryPreview(
  AgentMemoryHistoryItem row,
  AppLocalizations l10n,
) {
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
  final scopeLabel = _memoryScopeLabel(content, l10n);
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
    return _memClsNeg;
  }
  if (!_isVideoStyleMemory(memoryName)) {
    return '';
  }
  final deliverySignals = _countKeywordMatches(
    content,
    kAgentMemoryDeliveryKeywords,
  );
  final visualSignals = _countKeywordMatches(content, kAgentMemoryVisualKeywords);
  if (deliverySignals > 0 && visualSignals > 0) {
    return _memClsDelVis;
  }
  if (deliverySignals > 0) {
    return _memClsDelFirst;
  }
  if (visualSignals > 0) {
    return _memClsVisHeavy;
  }
  return _memClsVideo;
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
      return _memActMerge;
    }
    return _memActObserve;
  }
  if (!_isVideoStyleMemory(memoryName)) {
    return '';
  }
  final hasSubject =
      (_extractMemoryKeyValue(content, 'subject') ?? '').isNotEmpty;
  final hasDelivery =
      _extractMemoryKeyValue(content, 'delivery')?.isNotEmpty == true ||
      _countKeywordMatches(content, kAgentMemoryDeliveryKeywords) > 0;
  final riskTags = (_extractMemoryKeyValue(content, 'riskTags') ?? '')
      .toLowerCase();
  final hasHighValueRisk =
      riskTags.contains('identity') ||
      riskTags.contains('dialogue') ||
      riskTags.contains('performance');
  if (classificationLabel == _memClsVisHeavy) {
    return _memActCompress;
  }
  if (hasDelivery && (hasSubject || hasHighValueRisk)) {
    return _memActKeep;
  }
  if (classificationLabel == _memClsDelFirst ||
      classificationLabel == _memClsDelVis) {
    return _memActKeep;
  }
  return _memActObserve;
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

String _memorySignalLabel(String content, String classificationSlug) {
  final tags = <String>{};
  final subject = _extractMemoryKeyValue(content, 'subject') ?? '';
  final delivery = _extractMemoryKeyValue(content, 'delivery') ?? '';
  final riskTags = _extractMemoryKeyValue(content, 'riskTags') ?? '';
  final rejectionCount =
      _extractMemoryKeyValue(content, 'rejectionCount') ?? '';
  if (subject.isNotEmpty) {
    tags.add(_signalSubjectTag);
  }
  if (delivery.isNotEmpty ||
      classificationSlug == _memClsDelFirst ||
      classificationSlug == _memClsDelVis) {
    tags.add(_signalEmotionTag);
  }
  if (classificationSlug == _memClsDelVis) {
    tags.add(_signalCameraTag);
  } else if (classificationSlug == _memClsVisHeavy) {
    tags.add(_signalVisualTag);
  }
  if (riskTags.contains('identity')) {
    tags.add(_signalIdentityTag);
  }
  if (riskTags.contains('dialogue')) {
    tags.add(_signalDialogueTag);
  }
  if (riskTags.contains('performance')) {
    tags.add(_signalPerformanceTag);
  }
  if (rejectionCount.isNotEmpty) {
    tags.add('$_signalNegativePrefix$rejectionCount');
  }
  return tags.join('/');
}

/// Tags are internal keys; localized when rendering via [_formatSignalLabelDisplay].
const String _signalSubjectTag = 'sig_subject';
const String _signalEmotionTag = 'sig_emotion';
const String _signalCameraTag = 'sig_camera';
const String _signalVisualTag = 'sig_visual';
const String _signalIdentityTag = 'sig_identity';
const String _signalDialogueTag = 'sig_dialogue';
const String _signalPerformanceTag = 'sig_performance';
const String _signalNegativePrefix = 'sig_negative:';

String _formatSignalLabelDisplay(AppLocalizations l10n, String raw) {
  if (raw.isEmpty) return '';
  final parts = raw.split('/');
  final out = <String>[];
  for (final p in parts) {
    switch (p) {
      case _signalSubjectTag:
        out.add(l10n.agentMemorySignalSubject);
        break;
      case _signalEmotionTag:
        out.add(l10n.agentMemorySignalEmotion);
        break;
      case _signalCameraTag:
        out.add(l10n.agentMemorySignalCamera);
        break;
      case _signalVisualTag:
        out.add(l10n.agentMemorySignalVisual);
        break;
      case _signalIdentityTag:
        out.add(l10n.agentMemorySignalIdentity);
        break;
      case _signalDialogueTag:
        out.add(l10n.agentMemorySignalDialogue);
        break;
      case _signalPerformanceTag:
        out.add(l10n.agentMemorySignalPerformance);
        break;
      default:
        if (p.startsWith(_signalNegativePrefix)) {
          out.add(
            l10n.agentMemorySignalNegative(
              p.substring(_signalNegativePrefix.length),
            ),
          );
        } else {
          out.add(p);
        }
    }
  }
  return out.join('/');
}

String _memoryScopeLabel(String content, AppLocalizations l10n) {
  final storyboardIds = _extractMemoryKeyValue(content, 'storyboardIds');
  if (storyboardIds != null && storyboardIds.isNotEmpty) {
    return l10n.agentMemoryScopeStoryboardIds(storyboardIds);
  }
  final sampleCount = _extractMemoryKeyValue(content, 'sampleCount');
  if (sampleCount != null && sampleCount.isNotEmpty) {
    return l10n.agentMemoryScopeSampleCount(sampleCount);
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

