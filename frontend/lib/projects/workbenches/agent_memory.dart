import 'dart:convert';

import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
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

  /// Prefer UUID from loaded project list when the numeric field matches a row.
  ({String? projectUuid, int? projectId}) _agentMemoryProjectRef() {
    final n = _projectId;
    if (n == null) {
      return (projectUuid: null, projectId: null);
    }
    for (final p in _projects) {
      if (p.numericId == n) {
        return (projectUuid: p.id, projectId: n);
      }
    }
    return (projectUuid: null, projectId: n);
  }
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
      throw const FormatException('scope_not_object');
    }
    final scopeSignature = Map<String, dynamic>.from(decoded);
    if (!_scopeSignatureHasMeaningfulDimension(scopeSignature)) {
      throw const FormatException('scope_needs_dimension');
    }
    return scopeSignature;
  }

  bool _memoryTierRequiresScope(String tier) =>
      tier == 'stage_summary' || tier == 'delta_memory';

  bool _scopeSignatureHasMeaningfulDimension(Map<String, dynamic> signature) {
    bool hasValue(Object? value) {
      if (value == null) return false;
      if (value is bool || value is num) return true;
      if (value is String) return value.trim().isNotEmpty;
      if (value is List) return value.isNotEmpty;
      if (value is Map) return value.isNotEmpty;
      return true;
    }

    return signature.values.any(hasValue);
  }

  Map<String, dynamic>? _validatedScopeSignatureForTier(
    String tier, {
    required bool forAppend,
  }) {
    final scopeSignature = _parseScopeSignature();
    if (_memoryTierRequiresScope(tier) &&
        (scopeSignature == null || scopeSignature.isEmpty)) {
      throw FormatException(
        forAppend ? 'scope_tier_requires_append' : 'scope_tier_requires_query',
      );
    }
    return scopeSignature;
  }

  String _agentMemoryMessageFromError(Object e, AppLocalizations l10n) {
    if (e is FormatException) {
      switch (e.message) {
        case 'scope_not_object':
          return l10n.agentMemoryErrScopeNotObject;
        case 'scope_needs_dimension':
          return l10n.agentMemoryErrScopeNeedsDimension;
        case 'scope_tier_requires_query':
          return l10n.agentMemoryErrScopeTierRequires(
            l10n.agentMemoryActionLabelQueryScoped,
          );
        case 'scope_tier_requires_append':
          return l10n.agentMemoryErrScopeTierRequires(
            l10n.agentMemoryActionLabelAppendScoped,
          );
      }
    }
    return describeUserVisibleApiError(l10n, e);
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
    final l10n = AppLocalizations.of(context)!;
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
        _statusLine = l10n.agentMemoryStatusProjectsRefreshed(rows.length);
        _loadingProjects = false;
      });
    } on RustApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _statusLine = describeUserVisibleApiError(l10n, e);
        _loadingProjects = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _statusLine = _agentMemoryMessageFromError(e, l10n);
        _loadingProjects = false;
      });
    }
  }

  Future<void> _queryMemory() async {
    final l10n = AppLocalizations.of(context)!;
    final agentType = _agentTypeCtrl.text.trim();
    final memoryType = _queryType;
    final memoryTier = _memoryTier;
    final ref = _agentMemoryProjectRef();
    if ((ref.projectUuid == null || ref.projectUuid!.isEmpty) &&
        ref.projectId == null) {
      setState(() => _statusLine = l10n.agentMemoryErrFillProjectAndAgent);
      return;
    }
    if (agentType.isEmpty) {
      setState(() => _statusLine = l10n.agentMemoryErrFillAgentType);
      return;
    }
    setState(() {
      _loadingMemory = true;
      _statusLine = null;
    });
    try {
      final rows = await queryAgentMemory(
        widget.accessToken,
        projectId: ref.projectId,
        projectUuid: ref.projectUuid,
        agentType: agentType,
        episodesId: _episodesId,
        memoryType: memoryType,
        memoryTier: memoryTier == 'all' ? null : memoryTier,
        scopeSignature: memoryTier == 'all'
            ? _parseScopeSignature()
            : _validatedScopeSignatureForTier(memoryTier, forAppend: false),
      );
      if (!mounted) return;
      setState(() {
        _memoryRows = rows;
        _memorySummary = l10n.agentMemoryQuerySummaryLine(
          rows.length,
          memoryType,
          agentMemoryTierDisplayLabel(l10n, memoryTier),
        );
        _loadingMemory = false;
      });
    } on RustApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _statusLine = describeUserVisibleApiError(l10n, e);
        _loadingMemory = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _statusLine = _agentMemoryMessageFromError(e, l10n);
        _loadingMemory = false;
      });
    }
  }

  Future<void> _loadCostOverview() async {
    final l10n = AppLocalizations.of(context)!;
    final agentType = _agentTypeCtrl.text.trim();
    final ref = _agentMemoryProjectRef();
    if ((ref.projectUuid == null || ref.projectUuid!.isEmpty) &&
        ref.projectId == null) {
      setState(() => _statusLine = l10n.agentMemoryErrCostOverviewFields);
      return;
    }
    if (agentType.isEmpty) {
      setState(() => _statusLine = l10n.agentMemoryErrFillAgentType);
      return;
    }
    setState(() {
      _loadingCostOverview = true;
      _statusLine = null;
    });
    try {
      final overview = await getMemoryCostOverview(
        widget.accessToken,
        projectId: ref.projectId,
        projectUuid: ref.projectUuid,
        agentType: agentType,
      );
      if (!mounted) return;
      setState(() {
        _costOverview = overview;
        _statusLine = l10n.agentMemoryStatusCostOverviewLoaded;
        _loadingCostOverview = false;
      });
    } on RustApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _statusLine = describeUserVisibleApiError(l10n, e);
        _loadingCostOverview = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _statusLine = _agentMemoryMessageFromError(e, l10n);
        _loadingCostOverview = false;
      });
    }
  }

  Future<void> _appendMemory() async {
    final l10n = AppLocalizations.of(context)!;
    final agentType = _agentTypeCtrl.text.trim();
    final content = _appendContentCtrl.text.trim();
    final role = _appendRoleCtrl.text.trim();
    final appendType = _appendType;
    final appendTier = _appendMemoryTier;
    final appendName = _appendNameCtrl.text.trim();
    final scopeSignature = _validatedScopeSignatureForTier(
      appendTier,
      forAppend: true,
    );
    final ref = _agentMemoryProjectRef();
    if ((ref.projectUuid == null || ref.projectUuid!.isEmpty) &&
        ref.projectId == null) {
      setState(() => _statusLine = l10n.agentMemoryErrAppendProjectFields);
      return;
    }
    if (agentType.isEmpty || content.isEmpty || role.isEmpty) {
      setState(() => _statusLine = l10n.agentMemoryErrAppendAgentRoleContent);
      return;
    }
    setState(() {
      _appendingMemory = true;
      _statusLine = null;
    });
    try {
      final id = await appendAgentMemory(
        widget.accessToken,
        projectId: ref.projectId,
        projectUuid: ref.projectUuid,
        agentType: agentType,
        episodesId: _episodesId,
        memoryType: appendType,
        role: role,
        content: content,
        name: appendName.isEmpty ? null : appendName,
        memoryTier: appendTier,
        scopeSignature: scopeSignature,
      );
      await _queryMemory();
      if (!mounted) return;
      setState(() {
        _appendContentCtrl.clear();
        final idDisplay =
            id.length > 8 ? '${id.substring(0, 8)}…' : id;
        _statusLine = l10n.agentMemoryStatusAppended(idDisplay);
        _appendingMemory = false;
      });
    } on RustApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _statusLine = describeUserVisibleApiError(l10n, e);
        _appendingMemory = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _statusLine = _agentMemoryMessageFromError(e, l10n);
        _appendingMemory = false;
      });
    }
  }

  Future<void> _clearMemory() async {
    final l10n = AppLocalizations.of(context)!;
    final agentType = _agentTypeCtrl.text.trim();
    final clearType = _clearType;
    final ref = _agentMemoryProjectRef();
    if ((ref.projectUuid == null || ref.projectUuid!.isEmpty) &&
        ref.projectId == null) {
      setState(() => _statusLine = l10n.agentMemoryErrClearProjectFields);
      return;
    }
    if (agentType.isEmpty) {
      setState(() => _statusLine = l10n.agentMemoryErrFillAgentType);
      return;
    }
    setState(() {
      _clearingMemory = true;
      _statusLine = null;
    });
    try {
      await clearAgentMemory(
        widget.accessToken,
        projectId: ref.projectId,
        projectUuid: ref.projectUuid,
        agentType: agentType,
        episodesId: _episodesId,
        clearType: clearType,
      );
      await _queryMemory();
      if (!mounted) return;
      setState(() {
        _statusLine = l10n.agentMemoryStatusCleared(clearType);
        _clearingMemory = false;
      });
    } on RustApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _statusLine = describeUserVisibleApiError(l10n, e);
        _clearingMemory = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _statusLine = _agentMemoryMessageFromError(e, l10n);
        _clearingMemory = false;
      });
    }
  }

  Future<void> _optimizeVideoMemory() async {
    final l10n = AppLocalizations.of(context)!;
    final agentType = _agentTypeCtrl.text.trim();
    final episodesId = _episodesId;
    final ref = _agentMemoryProjectRef();
    if ((ref.projectUuid == null || ref.projectUuid!.isEmpty) &&
        ref.projectId == null) {
      setState(() => _statusLine = l10n.agentMemoryErrOptimizeProjectFields);
      return;
    }
    if (agentType.isEmpty || episodesId == null) {
      setState(() => _statusLine = l10n.agentMemoryErrOptimizeAgentEpisodes);
      return;
    }
    setState(() {
      _optimizingMemory = true;
      _statusLine = null;
    });
    try {
      final result = await optimizeAgentMemory(
        widget.accessToken,
        projectId: ref.projectId,
        projectUuid: ref.projectUuid,
        agentType: agentType,
        episodesId: episodesId,
        automationMode: _automationMode,
      );
      await _queryMemory();
      if (!mounted) return;
      setState(() {
        final mode = (result['automationMode'] ?? _automationMode).toString();
        final removedRows = (result['removedRows'] as num?)?.toInt() ?? 0;
        final removedChars = (result['removedChars'] as num?)?.toInt() ?? 0;
        final dupRows =
            (result['removedDuplicateRows'] as num?)?.toInt() ?? 0;
        final visRows = (result['removedVisualRows'] as num?)?.toInt() ?? 0;
        _statusLine = l10n.agentMemoryStatusOptimized(
          mode,
          removedRows,
          removedChars,
          dupRows,
          visRows,
        );
        _optimizingMemory = false;
      });
    } on RustApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _statusLine = describeUserVisibleApiError(l10n, e);
        _optimizingMemory = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _statusLine = _agentMemoryMessageFromError(e, l10n);
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
