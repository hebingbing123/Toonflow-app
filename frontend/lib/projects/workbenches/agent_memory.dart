import 'dart:convert';

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
  static const List<String> _queryTypes = <String>['summary', 'message', 'all'];
  static const List<String> _clearTypes = <String>['summary', 'message', 'all'];
  static const List<String> _appendTypes = <String>['message', 'summary'];
  static const List<String> _memoryTierOptions = <String>[
    'all',
    'style_bible',
    'stage_summary',
    'delta_memory',
    'message',
  ];
  static const List<String> _automationModes = <String>[
    'standard',
    'lean',
    'off',
  ];

  late final TextEditingController _projectIdCtrl;
  late final TextEditingController _agentTypeCtrl;
  late final TextEditingController _episodesIdCtrl;
  late final TextEditingController _queryTypeCtrl;
  late final TextEditingController _memoryTierCtrl;
  late final TextEditingController _scopeSignatureCtrl;
  late final TextEditingController _appendContentCtrl;
  late final TextEditingController _appendRoleCtrl;
  late final TextEditingController _appendTypeCtrl;
  late final TextEditingController _appendMemoryTierCtrl;
  late final TextEditingController _appendNameCtrl;
  late final TextEditingController _clearTypeCtrl;
  late final TextEditingController _automationModeCtrl;

  List<ProjectRow> _projects = const <ProjectRow>[];
  List<AgentMemoryHistoryItem> _memoryRows = const <AgentMemoryHistoryItem>[];
  AgentMemoryCostOverview? _costOverview;
  String? _memorySummary;
  String? _statusLine;
  bool _loadingProjects = false;
  bool _loadingMemory = false;
  bool _loadingCostOverview = false;
  bool _appendingMemory = false;
  bool _clearingMemory = false;
  bool _optimizingMemory = false;

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
    _queryTypeCtrl = TextEditingController(text: 'summary');
    _memoryTierCtrl = TextEditingController(text: 'all');
    _scopeSignatureCtrl = TextEditingController();
    _appendContentCtrl = TextEditingController();
    _appendRoleCtrl = TextEditingController(text: 'user');
    _appendTypeCtrl = TextEditingController(text: 'message');
    _appendMemoryTierCtrl = TextEditingController(text: 'message');
    _appendNameCtrl = TextEditingController();
    _clearTypeCtrl = TextEditingController(text: 'summary');
    _automationModeCtrl = TextEditingController(text: 'standard');
    _projects = List<ProjectRow>.from(widget.initialProjects);
  }

  @override
  void dispose() {
    _projectIdCtrl.dispose();
    _agentTypeCtrl.dispose();
    _episodesIdCtrl.dispose();
    _queryTypeCtrl.dispose();
    _memoryTierCtrl.dispose();
    _scopeSignatureCtrl.dispose();
    _appendContentCtrl.dispose();
    _appendRoleCtrl.dispose();
    _appendTypeCtrl.dispose();
    _appendMemoryTierCtrl.dispose();
    _appendNameCtrl.dispose();
    _clearTypeCtrl.dispose();
    _automationModeCtrl.dispose();
    super.dispose();
  }

  int? get _projectId => int.tryParse(_projectIdCtrl.text.trim());
  int? get _episodesId => int.tryParse(_episodesIdCtrl.text.trim());
  bool get _canOptimizeVideoMemory =>
      _agentTypeCtrl.text.trim() == 'productionAgent' && _episodesId != null;
  String get _queryType => _normalizedSelection(
    _queryTypeCtrl.text,
    supported: _queryTypes,
    fallback: 'summary',
  );
  String get _clearType => _normalizedSelection(
    _clearTypeCtrl.text,
    supported: _clearTypes,
    fallback: 'summary',
  );
  String get _memoryTier => _normalizedSelection(
    _memoryTierCtrl.text,
    supported: _memoryTierOptions,
    fallback: 'all',
  );
  String get _appendType => _normalizedSelection(
    _appendTypeCtrl.text,
    supported: _appendTypes,
    fallback: 'message',
  );
  String get _appendMemoryTier => _normalizedSelection(
    _appendMemoryTierCtrl.text,
    supported: _memoryTierOptions.where((value) => value != 'all').toList(),
    fallback: 'message',
  );
  String get _automationMode => _normalizedSelection(
    _automationModeCtrl.text,
    supported: _automationModes,
    fallback: 'standard',
  );

  Map<String, dynamic>? _parseScopeSignature() {
    final raw = _scopeSignatureCtrl.text.trim();
    if (raw.isEmpty) return null;
    final decoded = jsonDecode(raw);
    if (decoded is! Map) {
      throw const FormatException('scopeSignature 必须是 JSON 对象');
    }
    return Map<String, dynamic>.from(decoded);
  }

  String _normalizedSelection(
    String raw, {
    required List<String> supported,
    required String fallback,
  }) {
    final value = raw.trim();
    return supported.contains(value) ? value : fallback;
  }

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
    final memoryType = _queryType;
    if (projectId == null || agentType.isEmpty) {
      setState(() => _statusLine = '请填写合法的项目 numeric ID 和 agent type。');
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
        memoryTier: _memoryTier == 'all' ? null : _memoryTier,
        scopeSignature: _parseScopeSignature(),
      );
      if (!mounted) return;
      setState(() {
        _memoryRows = rows;
        final tierSummary = _memoryTier == 'all' ? '全部层级' : _memoryTier;
        _memorySummary =
            '已读取 ${rows.length} 条 $memoryType 记忆 · 层级 $tierSummary。';
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

  Future<void> _loadCostOverview() async {
    final projectId = _projectId;
    final agentType = _agentTypeCtrl.text.trim();
    if (projectId == null || agentType.isEmpty) {
      setState(() => _statusLine = '加载成本概览前请填写合法的项目 numeric ID 和 agent type。');
      return;
    }
    setState(() {
      _loadingCostOverview = true;
      _statusLine = null;
    });
    try {
      final overview = await getMemoryCostOverview(
        widget.accessToken,
        projectId: projectId,
        agentType: agentType,
      );
      if (!mounted) return;
      setState(() {
        _costOverview = overview;
        _statusLine = '已加载记忆成本概览。';
        _loadingCostOverview = false;
      });
    } on RustApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _statusLine = e.toString();
        _loadingCostOverview = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _statusLine = e.toString();
        _loadingCostOverview = false;
      });
    }
  }

  Future<void> _appendMemory() async {
    final projectId = _projectId;
    final agentType = _agentTypeCtrl.text.trim();
    final content = _appendContentCtrl.text.trim();
    final role = _appendRoleCtrl.text.trim();
    final appendType = _appendType;
    final appendTier = _appendMemoryTier;
    final appendName = _appendNameCtrl.text.trim();
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
        memoryType: appendType,
        role: role,
        content: content,
        name: appendName.isEmpty ? null : appendName,
        memoryTier: appendTier,
        scopeSignature: _parseScopeSignature(),
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
    final clearType = _clearType;
    if (projectId == null || agentType.isEmpty) {
      setState(() => _statusLine = '清理记忆前请填写项目和 agent type。');
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

  Future<void> _optimizeVideoMemory() async {
    final projectId = _projectId;
    final agentType = _agentTypeCtrl.text.trim();
    final episodesId = _episodesId;
    if (projectId == null || agentType.isEmpty || episodesId == null) {
      setState(() => _statusLine = '自动优化前请填写项目、agent type 和 episodes id。');
      return;
    }
    setState(() {
      _optimizingMemory = true;
      _statusLine = null;
    });
    try {
      final result = await optimizeAgentMemory(
        widget.accessToken,
        projectId: projectId,
        agentType: agentType,
        episodesId: episodesId,
        automationMode: _automationMode,
      );
      await _queryMemory();
      if (!mounted) return;
      setState(() {
        _statusLine =
            '已自动优化视频记忆（${result['automationMode'] ?? _automationMode}）：删除 ${result['removedRows'] ?? 0} 条 / ${(result['removedChars'] ?? 0)} chars，其中重复 ${(result['removedDuplicateRows'] ?? 0)} 条、纯视觉 ${(result['removedVisualRows'] ?? 0)} 条。';
        _optimizingMemory = false;
      });
    } on RustApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _statusLine = e.toString();
        _optimizingMemory = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _statusLine = e.toString();
        _optimizingMemory = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return ProjectsAgentMemoryWorkbenchDialogView(
      model: ProjectsAgentMemoryWorkbenchDialogViewModel(
        projects: _projects,
        memoryRows: _memoryRows,
        costOverview: _costOverview,
        memorySummary: _memorySummary,
        statusLine: _statusLine,
        loadingProjects: _loadingProjects,
        loadingMemory: _loadingMemory,
        loadingCostOverview: _loadingCostOverview,
        appendingMemory: _appendingMemory,
        clearingMemory: _clearingMemory,
        optimizingMemory: _optimizingMemory,
        canOptimizeVideoMemory: _canOptimizeVideoMemory,
        queryType: _queryType,
        clearType: _clearType,
        memoryTier: _memoryTier,
        queryTypeOptions: _queryTypes,
        clearTypeOptions: _clearTypes,
        memoryTierOptions: _memoryTierOptions,
        appendTypeOptions: _appendTypes,
        automationModeOptions: _automationModes,
        projectIdCtrl: _projectIdCtrl,
        agentTypeCtrl: _agentTypeCtrl,
        episodesIdCtrl: _episodesIdCtrl,
        queryTypeCtrl: _queryTypeCtrl,
        memoryTierCtrl: _memoryTierCtrl,
        scopeSignatureCtrl: _scopeSignatureCtrl,
        appendContentCtrl: _appendContentCtrl,
        appendRoleCtrl: _appendRoleCtrl,
        appendTypeCtrl: _appendTypeCtrl,
        appendMemoryTierCtrl: _appendMemoryTierCtrl,
        appendNameCtrl: _appendNameCtrl,
        clearTypeCtrl: _clearTypeCtrl,
        automationModeCtrl: _automationModeCtrl,
        appendType: _appendType,
        appendMemoryTier: _appendMemoryTier,
        automationMode: _automationMode,
      ),
      callbacks: ProjectsAgentMemoryWorkbenchDialogViewCallbacks(
        onReloadProjects: _reloadProjects,
        onQueryMemory: _queryMemory,
        onLoadCostOverview: _loadCostOverview,
        onAppendMemory: _appendMemory,
        onClearMemory: _clearMemory,
        onOptimizeVideoMemory: _optimizeVideoMemory,
        onQueryTypeChanged: (value) => _queryTypeCtrl.text = value,
        onMemoryTierChanged: (value) => _memoryTierCtrl.text = value,
        onAppendTypeChanged: (value) => _appendTypeCtrl.text = value,
        onAppendMemoryTierChanged: (value) =>
            _appendMemoryTierCtrl.text = value,
        onClearTypeChanged: (value) => _clearTypeCtrl.text = value,
        onAutomationModeChanged: (value) => _automationModeCtrl.text = value,
        onClose: () => Navigator.of(context).pop(),
      ),
    );
  }
}
