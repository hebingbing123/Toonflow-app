import 'package:characters/characters.dart';
import 'package:flutter/material.dart';

import '../../../rust_api.dart';

class ProjectsAgentMemoryWorkbenchDialogViewModel {
  const ProjectsAgentMemoryWorkbenchDialogViewModel({
    required this.projects,
    required this.memoryRows,
    required this.memorySummary,
    required this.statusLine,
    required this.loadingProjects,
    required this.loadingMemory,
    required this.appendingMemory,
    required this.clearingMemory,
    required this.optimizingMemory,
    required this.canOptimizeVideoMemory,
    required this.queryType,
    required this.clearType,
    required this.queryTypeOptions,
    required this.clearTypeOptions,
    required this.projectIdCtrl,
    required this.agentTypeCtrl,
    required this.episodesIdCtrl,
    required this.queryTypeCtrl,
    required this.appendContentCtrl,
    required this.appendRoleCtrl,
    required this.clearTypeCtrl,
  });

  final List<ProjectRow> projects;
  final List<dynamic> memoryRows;
  final String? memorySummary;
  final String? statusLine;
  final bool loadingProjects;
  final bool loadingMemory;
  final bool appendingMemory;
  final bool clearingMemory;
  final bool optimizingMemory;
  final bool canOptimizeVideoMemory;
  final String queryType;
  final String clearType;
  final List<String> queryTypeOptions;
  final List<String> clearTypeOptions;
  final TextEditingController projectIdCtrl;
  final TextEditingController agentTypeCtrl;
  final TextEditingController episodesIdCtrl;
  final TextEditingController queryTypeCtrl;
  final TextEditingController appendContentCtrl;
  final TextEditingController appendRoleCtrl;
  final TextEditingController clearTypeCtrl;
}

class ProjectsAgentMemoryWorkbenchDialogViewCallbacks {
  const ProjectsAgentMemoryWorkbenchDialogViewCallbacks({
    required this.onReloadProjects,
    required this.onQueryMemory,
    required this.onAppendMemory,
    required this.onClearMemory,
    required this.onOptimizeVideoMemory,
    required this.onQueryTypeChanged,
    required this.onClearTypeChanged,
    required this.onClose,
  });

  final Future<void> Function() onReloadProjects;
  final Future<void> Function() onQueryMemory;
  final Future<void> Function() onAppendMemory;
  final Future<void> Function() onClearMemory;
  final Future<void> Function() onOptimizeVideoMemory;
  final ValueChanged<String> onQueryTypeChanged;
  final ValueChanged<String> onClearTypeChanged;
  final VoidCallback onClose;
}

/// Agent 记忆工作台视图，承载查询结果、追加与清理表单布局。
class ProjectsAgentMemoryWorkbenchDialogView extends StatelessWidget {
  const ProjectsAgentMemoryWorkbenchDialogView({
    super.key,
    required this.model,
    required this.callbacks,
  });

  final ProjectsAgentMemoryWorkbenchDialogViewModel model;
  final ProjectsAgentMemoryWorkbenchDialogViewCallbacks callbacks;

  @override
  Widget build(BuildContext context) {
    final outline = Theme.of(context).colorScheme.outline;
    final viewportWidth = MediaQuery.sizeOf(context).width;
    final dialogWidth = viewportWidth.isFinite
        ? viewportWidth.clamp(320.0, 760.0)
        : 760.0;
    final optimizeEnabled =
        model.canOptimizeVideoMemory && !model.optimizingMemory;
    final memoryInsights = _buildAgentMemoryInsights(model.memoryRows);
    return AlertDialog(
      title: const Text('Agent 记忆工作台'),
      content: SizedBox(
        width: dialogWidth,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '针对项目级 script/production Agent 记忆执行查询、追加和清理，不再只依赖首页首项目 probe。',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: outline),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton.tonal(
                    onPressed: model.loadingProjects
                        ? null
                        : callbacks.onReloadProjects,
                    child: Text(model.loadingProjects ? '…' : '刷新项目列表'),
                  ),
                  FilledButton.tonal(
                    onPressed: model.loadingMemory
                        ? null
                        : callbacks.onQueryMemory,
                    child: Text(model.loadingMemory ? '…' : '查询记忆'),
                  ),
                  FilledButton.tonal(
                    onPressed: optimizeEnabled
                        ? callbacks.onOptimizeVideoMemory
                        : null,
                    child: Text(model.optimizingMemory ? '…' : '自动优化视频记忆'),
                  ),
                ],
              ),
              if (model.projects.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  '项目 ${model.projects.length} 个 · ${model.projects.take(4).map((p) => '#${p.numericId} ${p.name ?? "未命名项目"}').join(', ')}${model.projects.length > 4 ? '…' : ''}',
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: outline),
                ),
              ],
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: model.projectIdCtrl,
                      decoration: const InputDecoration(
                        labelText: '项目 numeric ID',
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: model.agentTypeCtrl,
                      decoration: const InputDecoration(
                        labelText: 'agent type',
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              TextField(
                controller: model.episodesIdCtrl,
                decoration: const InputDecoration(labelText: 'episodes id（可空）'),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                initialValue: model.queryType,
                decoration: const InputDecoration(
                  labelText: 'query type',
                  helperText: 'summary / message / all',
                ),
                items: model.queryTypeOptions
                    .map(
                      (value) => DropdownMenuItem<String>(
                        value: value,
                        child: Text(value),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value != null) {
                    callbacks.onQueryTypeChanged(value);
                  }
                },
              ),
              const SizedBox(height: 4),
              Text(
                '自动记忆按 项目 numeric ID + agent type + episodes id 独立隔离。',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: outline),
              ),
              const SizedBox(height: 4),
              Text(
                '自动优化只处理 productionAgent + episodes id 范围内的 selected video memory，不共享到别的用户、项目或短剧。',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: outline),
              ),
              if (!model.canOptimizeVideoMemory) ...[
                const SizedBox(height: 4),
                Text(
                  '要启用自动优化，请把 agent type 设为 productionAgent，并填写 episodes id。',
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: outline),
                ),
              ],
              if (model.memorySummary != null) ...[
                const SizedBox(height: 8),
                Text(
                  model.memorySummary!,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: outline),
                ),
              ],
              if (memoryInsights.summary != null) ...[
                const SizedBox(height: 4),
                Text(
                  memoryInsights.summary!,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: outline),
                ),
              ],
              if (memoryInsights.videoSummary != null) ...[
                const SizedBox(height: 4),
                Text(
                  memoryInsights.videoSummary!,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: outline),
                ),
              ],
              if (memoryInsights.efficiencySummary != null) ...[
                const SizedBox(height: 4),
                Text(
                  memoryInsights.efficiencySummary!,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: outline),
                ),
              ],
              if (memoryInsights.recommendation != null) ...[
                const SizedBox(height: 4),
                Text(
                  '建议：${memoryInsights.recommendation}',
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: outline),
                ),
              ],
              if (model.memoryRows.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  '${model.memoryRows.length} 条记忆',
                  style: Theme.of(context).textTheme.labelLarge,
                ),
                ...memoryInsights.previews.take(8).map((preview) {
                  final titleSegments = <String>[
                    if (preview.memoryName.isNotEmpty) preview.memoryName,
                    preview.role,
                    '${preview.charCount} chars',
                    if (preview.classificationLabel.isNotEmpty)
                      preview.classificationLabel,
                    if (preview.actionLabel.isNotEmpty) preview.actionLabel,
                  ];
                  final subtitleSegments = <String>[
                    if (preview.memoryId.isNotEmpty) preview.memoryId,
                    if (preview.scopeLabel.isNotEmpty) preview.scopeLabel,
                    if (preview.subjectLabel.isNotEmpty)
                      'subject ${preview.subjectLabel}',
                    if (preview.signalLabel.isNotEmpty)
                      'signals ${preview.signalLabel}',
                    preview.shortContent,
                  ];
                  return ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: Text(titleSegments.join(' · ')),
                    subtitle: Text(subtitleSegments.join(' · ')),
                    trailing: preview.isDuplicated
                        ? const Chip(
                            label: Text('重复'),
                            visualDensity: VisualDensity.compact,
                          )
                        : null,
                  );
                }),
              ],
              const SizedBox(height: 12),
              Text('追加记忆', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: model.appendRoleCtrl,
                      decoration: const InputDecoration(labelText: 'role'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton.tonal(
                      onPressed: model.appendingMemory
                          ? null
                          : callbacks.onAppendMemory,
                      child: Text(model.appendingMemory ? '…' : '追加记忆'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              TextField(
                controller: model.appendContentCtrl,
                minLines: 3,
                maxLines: 5,
                decoration: const InputDecoration(labelText: '记忆内容'),
              ),
              const SizedBox(height: 12),
              Text('清理记忆', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: model.clearType,
                      decoration: const InputDecoration(
                        labelText: 'clear type',
                        helperText: 'summary / message / all',
                      ),
                      items: model.clearTypeOptions
                          .map(
                            (value) => DropdownMenuItem<String>(
                              value: value,
                              child: Text(value),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        if (value != null) {
                          callbacks.onClearTypeChanged(value);
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton.tonal(
                      onPressed: model.clearingMemory
                          ? null
                          : callbacks.onClearMemory,
                      child: Text(model.clearingMemory ? '…' : '执行清理'),
                    ),
                  ),
                ],
              ),
              if (model.statusLine != null) ...[
                const SizedBox(height: 8),
                Text(
                  model.statusLine!,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: outline),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: callbacks.onClose, child: const Text('关闭')),
      ],
    );
  }
}

class _AgentMemoryInsights {
  const _AgentMemoryInsights({
    required this.previews,
    required this.summary,
    required this.videoSummary,
    required this.efficiencySummary,
    required this.recommendation,
  });

  final List<_AgentMemoryPreview> previews;
  final String? summary;
  final String? videoSummary;
  final String? efficiencySummary;
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

_AgentMemoryInsights _buildAgentMemoryInsights(List<dynamic> rows) {
  final rawPreviews = rows
      .map(_buildAgentMemoryPreview)
      .toList(growable: false);
  if (rawPreviews.isEmpty) {
    return const _AgentMemoryInsights(
      previews: <_AgentMemoryPreview>[],
      summary: null,
      videoSummary: null,
      efficiencySummary: null,
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
    summary: summary,
    videoSummary: videoSummary,
    efficiencySummary: efficiencySummary,
    recommendation: recommendation,
  );
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

_AgentMemoryPreview _buildAgentMemoryPreview(dynamic row) {
  final map = row is Map ? Map<String, dynamic>.from(row) : <String, dynamic>{};
  final memoryName = map['name']?.toString() ?? '';
  final role = map['role']?.toString() ?? 'unknown';
  final rawContent = map['content'];
  final blocks = rawContent is List ? rawContent : const <dynamic>[];
  final content = blocks.isNotEmpty && blocks.first is Map
      ? (blocks.first as Map)['data']?.toString() ?? ''
      : rawContent?.toString() ?? '';
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
    memoryId: map['id']?.toString() ?? '',
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
