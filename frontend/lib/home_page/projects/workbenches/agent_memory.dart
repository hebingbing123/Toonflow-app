import 'package:flutter/material.dart';

import '../../../rust_api.dart';

class ProjectsAgentMemoryWorkbenchDialog extends StatefulWidget {
  const ProjectsAgentMemoryWorkbenchDialog({
    super.key,
    required this.accessToken,
    required this.initialProjects,
  });

  final String accessToken;
  final List<ProjectRow> initialProjects;

  @override
  State<ProjectsAgentMemoryWorkbenchDialog> createState() =>
      _ProjectsAgentMemoryWorkbenchDialogState();
}

class _ProjectsAgentMemoryWorkbenchDialogState
    extends State<ProjectsAgentMemoryWorkbenchDialog> {
  late final TextEditingController _projectIdCtrl;
  late final TextEditingController _agentTypeCtrl;
  late final TextEditingController _episodesIdCtrl;
  late final TextEditingController _appendContentCtrl;
  late final TextEditingController _appendRoleCtrl;
  late final TextEditingController _clearTypeCtrl;

  List<ProjectRow> _projects = const <ProjectRow>[];
  List<dynamic> _memoryRows = const <dynamic>[];
  String? _memorySummary;
  String? _statusLine;
  bool _loadingProjects = false;
  bool _loadingMemory = false;
  bool _appendingMemory = false;
  bool _clearingMemory = false;

  @override
  void initState() {
    super.initState();
    _projectIdCtrl = TextEditingController(
      text: widget.initialProjects.isEmpty
          ? ''
          : widget.initialProjects.first.numericId.toString(),
    );
    _agentTypeCtrl = TextEditingController(text: 'scriptAgent');
    _episodesIdCtrl = TextEditingController();
    _appendContentCtrl = TextEditingController();
    _appendRoleCtrl = TextEditingController(text: 'user');
    _clearTypeCtrl = TextEditingController(text: 'message');
    _projects = List<ProjectRow>.from(widget.initialProjects);
  }

  @override
  void dispose() {
    _projectIdCtrl.dispose();
    _agentTypeCtrl.dispose();
    _episodesIdCtrl.dispose();
    _appendContentCtrl.dispose();
    _appendRoleCtrl.dispose();
    _clearTypeCtrl.dispose();
    super.dispose();
  }

  int? get _projectId => int.tryParse(_projectIdCtrl.text.trim());
  int? get _episodesId => int.tryParse(_episodesIdCtrl.text.trim());

  Future<void> _reloadProjects() async {
    setState(() {
      _loadingProjects = true;
      _statusLine = null;
    });
    try {
      final rows = await fetchProjects(widget.accessToken);
      if (!mounted) return;
      setState(() {
        _projects = rows;
        if (_projectIdCtrl.text.trim().isEmpty && rows.isNotEmpty) {
          _projectIdCtrl.text = rows.first.numericId.toString();
        }
        _statusLine = '已刷新 ${rows.length} 个项目。';
        _loadingProjects = false;
      });
    } on RustApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _statusLine = e.toString();
        _loadingProjects = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _statusLine = e.toString();
        _loadingProjects = false;
      });
    }
  }

  Future<void> _queryMemory() async {
    final projectId = _projectId;
    final agentType = _agentTypeCtrl.text.trim();
    if (projectId == null || agentType.isEmpty) {
      setState(() => _statusLine = '请填写合法的项目 legacy id 和 agent type。');
      return;
    }
    setState(() {
      _loadingMemory = true;
      _statusLine = null;
    });
    try {
      final rows = await queryAgentMemory(
        widget.accessToken,
        projectId: projectId,
        agentType: agentType,
        episodesId: _episodesId,
      );
      if (!mounted) return;
      setState(() {
        _memoryRows = rows;
        _memorySummary = '已读取 ${rows.length} 条记忆。';
        _loadingMemory = false;
      });
    } on RustApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _statusLine = e.toString();
        _loadingMemory = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _statusLine = e.toString();
        _loadingMemory = false;
      });
    }
  }

  Future<void> _appendMemory() async {
    final projectId = _projectId;
    final agentType = _agentTypeCtrl.text.trim();
    final content = _appendContentCtrl.text.trim();
    final role = _appendRoleCtrl.text.trim();
    if (projectId == null ||
        agentType.isEmpty ||
        content.isEmpty ||
        role.isEmpty) {
      setState(() => _statusLine = '追加记忆前请填写项目、agent type、role 和内容。');
      return;
    }
    setState(() {
      _appendingMemory = true;
      _statusLine = null;
    });
    try {
      final id = await appendAgentMemory(
        widget.accessToken,
        projectId: projectId,
        agentType: agentType,
        episodesId: _episodesId,
        role: role,
        content: content,
      );
      await _queryMemory();
      if (!mounted) return;
      setState(() {
        _appendContentCtrl.clear();
        _statusLine = '已追加记忆 ${id.length > 8 ? '${id.substring(0, 8)}…' : id}。';
        _appendingMemory = false;
      });
    } on RustApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _statusLine = e.toString();
        _appendingMemory = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _statusLine = e.toString();
        _appendingMemory = false;
      });
    }
  }

  Future<void> _clearMemory() async {
    final projectId = _projectId;
    final agentType = _agentTypeCtrl.text.trim();
    final clearType = _clearTypeCtrl.text.trim();
    if (projectId == null || agentType.isEmpty || clearType.isEmpty) {
      setState(() => _statusLine = '清理记忆前请填写项目、agent type 和 clear type。');
      return;
    }
    setState(() {
      _clearingMemory = true;
      _statusLine = null;
    });
    try {
      await clearAgentMemory(
        widget.accessToken,
        projectId: projectId,
        agentType: agentType,
        episodesId: _episodesId,
        clearType: clearType,
      );
      await _queryMemory();
      if (!mounted) return;
      setState(() {
        _statusLine = '已执行记忆清理：$clearType。';
        _clearingMemory = false;
      });
    } on RustApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _statusLine = e.toString();
        _clearingMemory = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _statusLine = e.toString();
        _clearingMemory = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
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
                        labelText: '项目 legacy id',
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
