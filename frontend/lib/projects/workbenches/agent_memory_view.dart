import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../rust_api.dart';

part 'agent_memory_view/memory_widgets.dart';

class ProjectsAgentMemoryWorkbenchDialogViewModel {
  const ProjectsAgentMemoryWorkbenchDialogViewModel({
    required this.projects,
    required this.memoryRows,
    required this.costOverview,
    required this.memorySummary,
    required this.statusLine,
    required this.loadingProjects,
    required this.loadingMemory,
    required this.loadingCostOverview,
    required this.appendingMemory,
    required this.clearingMemory,
    required this.optimizingMemory,
    required this.canOptimizeVideoMemory,
    required this.queryType,
    required this.clearType,
    required this.memoryTier,
    required this.queryTypeOptions,
    required this.clearTypeOptions,
    required this.memoryTierOptions,
    required this.appendTypeOptions,
    required this.automationModeOptions,
    required this.projectIdCtrl,
    required this.agentTypeCtrl,
    required this.episodesIdCtrl,
    required this.queryTypeCtrl,
    required this.memoryTierCtrl,
    required this.scopeSignatureCtrl,
    required this.appendContentCtrl,
    required this.appendRoleCtrl,
    required this.appendTypeCtrl,
    required this.appendMemoryTierCtrl,
    required this.appendNameCtrl,
    required this.clearTypeCtrl,
    required this.automationModeCtrl,
    required this.appendType,
    required this.appendMemoryTier,
    required this.automationMode,
  });

  final List<ProjectRow> projects;
  final List<AgentMemoryHistoryItem> memoryRows;
  final AgentMemoryCostOverview? costOverview;
  final String? memorySummary;
  final String? statusLine;
  final bool loadingProjects;
  final bool loadingMemory;
  final bool loadingCostOverview;
  final bool appendingMemory;
  final bool clearingMemory;
  final bool optimizingMemory;
  final bool canOptimizeVideoMemory;
  final String queryType;
  final String clearType;
  final String memoryTier;
  final List<String> queryTypeOptions;
  final List<String> clearTypeOptions;
  final List<String> memoryTierOptions;
  final List<String> appendTypeOptions;
  final List<String> automationModeOptions;
  final TextEditingController projectIdCtrl;
  final TextEditingController agentTypeCtrl;
  final TextEditingController episodesIdCtrl;
  final TextEditingController queryTypeCtrl;
  final TextEditingController memoryTierCtrl;
  final TextEditingController scopeSignatureCtrl;
  final TextEditingController appendContentCtrl;
  final TextEditingController appendRoleCtrl;
  final TextEditingController appendTypeCtrl;
  final TextEditingController appendMemoryTierCtrl;
  final TextEditingController appendNameCtrl;
  final TextEditingController clearTypeCtrl;
  final TextEditingController automationModeCtrl;
  final String appendType;
  final String appendMemoryTier;
  final String automationMode;
}

class ProjectsAgentMemoryWorkbenchDialogViewCallbacks {
  const ProjectsAgentMemoryWorkbenchDialogViewCallbacks({
    required this.onReloadProjects,
    required this.onQueryMemory,
    required this.onLoadCostOverview,
    required this.onAppendMemory,
    required this.onClearMemory,
    required this.onOptimizeVideoMemory,
    required this.onQueryTypeChanged,
    required this.onMemoryTierChanged,
    required this.onAppendTypeChanged,
    required this.onAppendMemoryTierChanged,
    required this.onClearTypeChanged,
    required this.onAutomationModeChanged,
    required this.onClose,
  });

  final Future<void> Function() onReloadProjects;
  final Future<void> Function() onQueryMemory;
  final Future<void> Function() onLoadCostOverview;
  final Future<void> Function() onAppendMemory;
  final Future<void> Function() onClearMemory;
  final Future<void> Function() onOptimizeVideoMemory;
  final ValueChanged<String> onQueryTypeChanged;
  final ValueChanged<String> onMemoryTierChanged;
  final ValueChanged<String> onAppendTypeChanged;
  final ValueChanged<String> onAppendMemoryTierChanged;
  final ValueChanged<String> onClearTypeChanged;
  final ValueChanged<String> onAutomationModeChanged;
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
    final memoryPreviewById = <String, _AgentMemoryPreview>{
      for (final preview in memoryInsights.previews) preview.memoryId: preview,
    };
    final memoryTierGroups = _buildMemoryTierGroups(model.memoryRows);
    final costOverviewLine = _buildCostOverviewLine(model.costOverview);
    final executionChecklist = _buildScopedExecutionChecklist(
      model,
      memoryInsights,
    );
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
                    onPressed: model.loadingCostOverview
                        ? null
                        : callbacks.onLoadCostOverview,
                    child: Text(model.loadingCostOverview ? '…' : '加载成本概览'),
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
              TextField(
                controller: model.scopeSignatureCtrl,
                minLines: 2,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'scopeSignature JSON（可空）',
                  helperText:
                      '例如 {"episodeId":3,"storyboardIds":[12],"focusSections":["ep3-sc2"]}',
                ),
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
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                initialValue: model.memoryTier,
                decoration: const InputDecoration(
                  labelText: 'memory tier',
                  helperText:
                      'all / style_bible / stage_summary / delta_memory / message',
                ),
                items: model.memoryTierOptions
                    .map(
                      (value) => DropdownMenuItem<String>(
                        value: value,
                        child: Text(_memoryTierLabel(value)),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value != null) {
                    callbacks.onMemoryTierChanged(value);
                  }
                },
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                initialValue: model.automationMode,
                decoration: const InputDecoration(
                  labelText: 'automation mode',
                  helperText: 'standard / lean / off',
                ),
                items: model.automationModeOptions
                    .map(
                      (value) => DropdownMenuItem<String>(
                        value: value,
                        child: Text(value),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value != null) {
                    callbacks.onAutomationModeChanged(value);
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
              if (costOverviewLine != null) ...[
                const SizedBox(height: 4),
                Text(
                  costOverviewLine,
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
              if (memoryInsights.bucketPrioritySummary != null) ...[
                const SizedBox(height: 4),
                Text(
                  memoryInsights.bucketPrioritySummary!,
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
              if (executionChecklist != null) ...[
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: SelectableText(
                        executionChecklist,
                        style: Theme.of(
                          context,
                        ).textTheme.bodySmall?.copyWith(color: outline),
                      ),
                    ),
                    IconButton(
                      tooltip: '复制记忆执行清单',
                      onPressed: () async {
                        await Clipboard.setData(
                          ClipboardData(text: executionChecklist),
                        );
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('已复制记忆执行清单')),
                        );
                      },
                      icon: const Icon(Icons.copy_all_rounded),
                    ),
                  ],
                ),
              ],
              if (model.memoryRows.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  '${model.memoryRows.length} 条记忆',
                  style: Theme.of(context).textTheme.labelLarge,
                ),
                ...memoryTierGroups.map((group) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 8),
                      Text(
                        '${group.label} · ${group.rows.length} 条 · 最近注入 ${group.lastInjectedLabel}',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      ...group.rows.take(6).map((item) {
                        final preview =
                            memoryPreviewById[item.id] ??
                            _buildAgentMemoryPreview(item);
                        final titleSegments = <String>[
                          if (preview.memoryName.isNotEmpty) preview.memoryName,
                          preview.role,
                          '${preview.charCount} chars',
                          if (preview.classificationLabel.isNotEmpty)
                            preview.classificationLabel,
                          if (preview.actionLabel.isNotEmpty)
                            preview.actionLabel,
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
                  );
                }),
              ],
              const SizedBox(height: 12),
              Text('追加记忆', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: model.appendType,
                      decoration: const InputDecoration(
                        labelText: 'append type',
                        helperText: 'message / summary',
                      ),
                      items: model.appendTypeOptions
                          .map(
                            (value) => DropdownMenuItem<String>(
                              value: value,
                              child: Text(value),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        if (value != null) {
                          callbacks.onAppendTypeChanged(value);
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: model.appendMemoryTier,
                      decoration: const InputDecoration(
                        labelText: 'append memory tier',
                        helperText:
                            'style_bible / stage_summary / delta_memory / message',
                      ),
                      items: model.memoryTierOptions
                          .where((value) => value != 'all')
                          .map(
                            (value) => DropdownMenuItem<String>(
                              value: value,
                              child: Text(_memoryTierLabel(value)),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        if (value != null) {
                          callbacks.onAppendMemoryTierChanged(value);
                        }
                      },
                    ),
                  ),
                ],
              ),
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
                    child: TextField(
                      controller: model.appendNameCtrl,
                      decoration: const InputDecoration(labelText: 'name（可空）'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.tonal(
                      onPressed: model.appendingMemory
                          ? null
                          : callbacks.onAppendMemory,
                      child: Text(
                        model.appendingMemory ? '…' : '按当前 scope 追加记忆',
                      ),
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
