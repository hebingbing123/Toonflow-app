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
    required this.onQueryTypeChanged,
    required this.onClearTypeChanged,
    required this.onClose,
  });

  final Future<void> Function() onReloadProjects;
  final Future<void> Function() onQueryMemory;
  final Future<void> Function() onAppendMemory;
  final Future<void> Function() onClearMemory;
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
                  final title = preview.memoryName.isEmpty
                      ? '${preview.role} · ${preview.charCount} chars'
                      : '${preview.memoryName} · ${preview.role} · ${preview.charCount} chars';
                  return ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: Text(title),
                    subtitle: Text(
                      '${preview.memoryId.isEmpty ? '' : '${preview.memoryId} · '}${preview.shortContent}',
                    ),
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
    required this.recommendation,
  });

  final List<_AgentMemoryPreview> previews;
  final String? summary;
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
  });

  final String memoryId;
  final String memoryName;
  final String role;
  final String shortContent;
  final int charCount;
  final String normalizedPrefix;
  final bool isDuplicated;
}

_AgentMemoryInsights _buildAgentMemoryInsights(List<dynamic> rows) {
  final rawPreviews = rows
      .map(_buildAgentMemoryPreview)
      .toList(growable: false);
  if (rawPreviews.isEmpty) {
    return const _AgentMemoryInsights(
      previews: <_AgentMemoryPreview>[],
      summary: null,
      recommendation: null,
    );
  }

  final prefixCounts = <String, int>{};
  final roleCounts = <String, int>{};
  final memoryNameCounts = <String, int>{};
  var totalChars = 0;
  var longestChars = 0;
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
  }

  final previews = rawPreviews
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
        ),
      )
      .toList(growable: false);
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
  String? recommendation;
  if (duplicateCount >= 2) {
    recommendation = '检测到重复表述，先去重旧记忆，避免同一约束反复注入。';
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
    recommendation: recommendation,
  );
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
  final normalizedPrefix = content.replaceAll(RegExp(r'\s+'), '').toLowerCase();
  return _AgentMemoryPreview(
    memoryId: map['id']?.toString() ?? '',
    memoryName: memoryName,
    role: role,
    shortContent: shortContent,
    charCount: content.characters.length,
    normalizedPrefix: normalizedPrefix.length > 16
        ? normalizedPrefix.substring(0, 16)
        : normalizedPrefix,
    isDuplicated: false,
  );
}
