import 'package:flutter/material.dart';

import '../../../rust_api.dart';
import 'agent_memory_view.dart';

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
  late final TextEditingController _queryTypeCtrl;
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
    _queryTypeCtrl = TextEditingController(text: 'message');
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
    _queryTypeCtrl.dispose();
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
    final memoryType = _queryTypeCtrl.text.trim();
    if (projectId == null || agentType.isEmpty || memoryType.isEmpty) {
      setState(() => _statusLine = '请填写合法的项目 numeric ID、agent type 和 query type。');
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
        memoryType: memoryType,
      );
      if (!mounted) return;
      setState(() {
        _memoryRows = rows;
        _memorySummary = '已读取 ${rows.length} 条 $memoryType 记忆。';
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
    return ProjectsAgentMemoryWorkbenchDialogView(
      model: ProjectsAgentMemoryWorkbenchDialogViewModel(
        projects: _projects,
        memoryRows: _memoryRows,
        memorySummary: _memorySummary,
        statusLine: _statusLine,
        loadingProjects: _loadingProjects,
        loadingMemory: _loadingMemory,
        appendingMemory: _appendingMemory,
        clearingMemory: _clearingMemory,
        projectIdCtrl: _projectIdCtrl,
        agentTypeCtrl: _agentTypeCtrl,
        episodesIdCtrl: _episodesIdCtrl,
        queryTypeCtrl: _queryTypeCtrl,
        appendContentCtrl: _appendContentCtrl,
        appendRoleCtrl: _appendRoleCtrl,
        clearTypeCtrl: _clearTypeCtrl,
      ),
      callbacks: ProjectsAgentMemoryWorkbenchDialogViewCallbacks(
        onReloadProjects: _reloadProjects,
        onQueryMemory: _queryMemory,
        onAppendMemory: _appendMemory,
        onClearMemory: _clearMemory,
        onClose: () => Navigator.of(context).pop(),
      ),
    );
  }
}
