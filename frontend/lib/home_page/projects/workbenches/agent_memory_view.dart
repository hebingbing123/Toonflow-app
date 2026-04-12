part of 'agent_memory.dart';

/// Agent 记忆工作台视图，承载查询结果、追加与清理表单布局。
extension _ProjectsAgentMemoryWorkbenchDialogView
    on _ProjectsAgentMemoryWorkbenchDialogState {
  Widget _buildProjectsAgentMemoryWorkbenchDialogView(BuildContext context) {
    final outline = Theme.of(context).colorScheme.outline;
    return AlertDialog(
      title: const Text('Agent 记忆工作台'),
      content: SizedBox(
        width: 760,
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
                    onPressed: _loadingProjects ? null : _reloadProjects,
                    child: Text(_loadingProjects ? '…' : '刷新项目列表'),
                  ),
                  FilledButton.tonal(
                    onPressed: _loadingMemory ? null : _queryMemory,
                    child: Text(_loadingMemory ? '…' : '查询记忆'),
                  ),
                ],
              ),
              if (_projects.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  '项目 ${_projects.length} 个 · ${_projects.take(4).map((p) => '#${p.numericId} ${p.name ?? "未命名项目"}').join(', ')}${_projects.length > 4 ? '…' : ''}',
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
                      controller: _projectIdCtrl,
                      decoration: const InputDecoration(
                        labelText: '项目 numeric ID',
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _agentTypeCtrl,
                      decoration: const InputDecoration(
                        labelText: 'agent type',
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _episodesIdCtrl,
                decoration: const InputDecoration(labelText: 'episodes id（可空）'),
              ),
              if (_memorySummary != null) ...[
                const SizedBox(height: 8),
                Text(
                  _memorySummary!,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: outline),
                ),
              ],
              if (_memoryRows.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  '${_memoryRows.length} 条记忆',
                  style: Theme.of(context).textTheme.labelLarge,
                ),
                ..._memoryRows.take(8).map((row) {
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
                      controller: _appendRoleCtrl,
                      decoration: const InputDecoration(labelText: 'role'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton.tonal(
                      onPressed: _appendingMemory ? null : _appendMemory,
                      child: Text(_appendingMemory ? '…' : '追加记忆'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _appendContentCtrl,
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
                      controller: _clearTypeCtrl,
                      decoration: const InputDecoration(
                        labelText: 'clear type',
                        helperText: 'all / message / summary',
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton.tonal(
                      onPressed: _clearingMemory ? null : _clearMemory,
                      child: Text(_clearingMemory ? '…' : '执行清理'),
                    ),
                  ),
                ],
              ),
              if (_statusLine != null) ...[
                const SizedBox(height: 8),
                Text(
                  _statusLine!,
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
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('关闭'),
        ),
      ],
    );
  }
}
