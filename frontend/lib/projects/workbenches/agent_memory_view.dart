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
    required this.projectIdCtrl,
    required this.agentTypeCtrl,
    required this.episodesIdCtrl,
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
  final TextEditingController projectIdCtrl;
  final TextEditingController agentTypeCtrl;
  final TextEditingController episodesIdCtrl;
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
    required this.onClose,
  });

  final Future<void> Function() onReloadProjects;
  final Future<void> Function() onQueryMemory;
  final Future<void> Function() onAppendMemory;
  final Future<void> Function() onClearMemory;
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
              if (model.memorySummary != null) ...[
                const SizedBox(height: 8),
                Text(
                  model.memorySummary!,
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
                ...model.memoryRows.take(8).map((row) {
                  final map = row is Map
                      ? Map<String, dynamic>.from(row)
                      : <String, dynamic>{};
                  final role = map['role']?.toString() ?? 'unknown';
                  final content = map['content']?.toString() ?? '';
                  final shortContent = content.length > 60
                      ? '${content.substring(0, 60)}…'
                      : content;
                  final memoryId = map['id']?.toString() ?? '';
                  return ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: Text(role),
                    subtitle: Text(
                      '${memoryId.isEmpty ? '' : '$memoryId · '}$shortContent',
                    ),
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
                    child: TextField(
                      controller: model.clearTypeCtrl,
                      decoration: const InputDecoration(
                        labelText: 'clear type',
                        helperText: 'all / message / summary',
                      ),
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
