import 'dart:convert';

import 'package:flutter/material.dart';

import '../../prompt_preset.dart';
import '../../contexts/script/action_panels.dart';
import '../../contexts/script/card_panels.dart';
import '../../contexts/script/context_snapshot.dart';
import '../../contexts/script/status_panels.dart';
import '../../contexts/script/support.dart';

class AgentWorkspaceScriptCard extends StatefulWidget {
  const AgentWorkspaceScriptCard({
    super.key,
    required this.busy,
    required this.scriptPromptController,
    required this.scriptDomainArgsController,
    required this.scriptSubAgentToolController,
    required this.scriptDomainToolPresets,
    required this.scriptSubAgentPresets,
    required this.scriptPromptPresets,
    required this.selectedScriptDomainTool,
    required this.loadingScriptWorkspaceRun,
    required this.loadingScriptDomainProbe,
    required this.loadingScriptSubAgentRun,
    required this.loadingScriptResultWriteback,
    required this.loadingScriptPlanResultWriteback,
    required this.scopeScriptIdText,
    required this.workspaceAssistantText,
    required this.workspaceScriptWritebackSource,
    required this.workspaceScriptWritebackCandidate,
    required this.workspaceScriptPlanWritebackCandidate,
    this.workspaceScriptPlanRowId,
    this.workspaceLastToolName,
    this.workspaceLastToolResultData,
    required this.workspaceWritebackLine,
    required this.onSelectPrompt,
    required this.onScriptDomainToolChanged,
    required this.onRunScriptWorkspace,
    required this.onProbeScriptDomainTool,
    required this.onScriptSubAgentChanged,
    required this.onRunScriptSubAgentTool,
    required this.onWriteBackScriptResult,
    required this.onWriteBackScriptPlanResult,
    required this.onWriteBackScriptPlanViaUpdateData,
  });

  final bool busy;
  final TextEditingController scriptPromptController;
  final TextEditingController scriptDomainArgsController;
  final TextEditingController scriptSubAgentToolController;
  final List<String> scriptDomainToolPresets;
  final List<String> scriptSubAgentPresets;
  final List<AgentWorkspacePromptPreset> scriptPromptPresets;
  final String selectedScriptDomainTool;
  final bool loadingScriptWorkspaceRun;
  final bool loadingScriptDomainProbe;
  final bool loadingScriptSubAgentRun;
  final bool loadingScriptResultWriteback;
  final bool loadingScriptPlanResultWriteback;
  final String scopeScriptIdText;
  final String workspaceAssistantText;
  final String? workspaceScriptWritebackSource;
  final String? workspaceScriptWritebackCandidate;
  final Map<String, dynamic>? workspaceScriptPlanWritebackCandidate;
  final int? workspaceScriptPlanRowId;
  final String? workspaceLastToolName;
  final Object? workspaceLastToolResultData;
  final String? workspaceWritebackLine;
  final ValueChanged<String> onSelectPrompt;
  final ValueChanged<String> onScriptDomainToolChanged;
  final VoidCallback onRunScriptWorkspace;
  final VoidCallback onProbeScriptDomainTool;
  final ValueChanged<String> onScriptSubAgentChanged;
  final VoidCallback onRunScriptSubAgentTool;
  final VoidCallback onWriteBackScriptResult;
  final VoidCallback onWriteBackScriptPlanResult;
  final VoidCallback onWriteBackScriptPlanViaUpdateData;

  @override
  State<AgentWorkspaceScriptCard> createState() =>
      _AgentWorkspaceScriptCardState();
}

class _AgentWorkspaceScriptCardState extends State<AgentWorkspaceScriptCard> {
  String? _taskStatusLine;

  bool get _canWriteBackScriptResult =>
      widget.workspaceScriptWritebackCandidate?.trim().isNotEmpty == true ||
      widget.workspaceAssistantText.trim().isNotEmpty;

  bool get _canWriteBackScriptPlanResult =>
      widget.workspaceScriptPlanWritebackCandidate != null;

  bool get _canWriteBackScriptPlanViaUpdateData =>
      widget.workspaceScriptPlanWritebackCandidate != null &&
      widget.workspaceScriptPlanRowId != null;

  String? get _scriptWritebackSourceLine {
    final source = widget.workspaceScriptWritebackSource?.trim();
    if (source != null && source.isNotEmpty) return source;
    if (widget.workspaceAssistantText.trim().isNotEmpty) {
      return 'assistant stream';
    }
    return null;
  }

  String? get _scriptPlanWritebackLine {
    final candidate = widget.workspaceScriptPlanWritebackCandidate;
    if (candidate == null) return null;
    final data = candidate['data'];
    if (data is! Map<String, dynamic>) return null;
    final scriptRaw = data['script'];
    final scriptCount = scriptRaw is List
        ? scriptRaw.whereType<Map<String, dynamic>>().length
        : 0;
    final pid = widget.workspaceScriptPlanRowId;
    final planHint = pid != null ? ' plan_row_id=$pid' : '';
    return 'PlanData source ready:$planHint story/adaptation + script rows=$scriptCount';
  }

  String? get _runningTaskLine {
    if (widget.loadingScriptWorkspaceRun) return '执行中：运行剧本工作流';
    if (widget.loadingScriptDomainProbe) return '执行中：读取剧本上下文';
    if (widget.loadingScriptSubAgentRun) return '执行中：运行子代理';
    if (widget.loadingScriptResultWriteback) return '执行中：写回剧本';
    if (widget.loadingScriptPlanResultWriteback) return '执行中：写回计划数据';
    return null;
  }

  int? get _scopeScriptId {
    final parsed = int.tryParse(widget.scopeScriptIdText.trim());
    if (parsed == null || parsed <= 0) return null;
    return parsed;
  }

  void _setTaskStatus(String message) {
    if (!mounted) return;
    setState(() => _taskStatusLine = message);
  }

  void _applyScriptPromptIfEmpty(String prompt) {
    if (widget.scriptPromptController.text.trim().isNotEmpty) return;
    widget.scriptPromptController.text = prompt;
  }

  String _previewText(String value, {required int maxChars}) {
    if (value.length <= maxChars) {
      return value;
    }
    return '${value.substring(0, maxChars)}...';
  }

  String? _resolveDropdownValue(String value, List<String> allowed) {
    if (allowed.contains(value)) return value;
    if (allowed.isEmpty) return null;
    return allowed.first;
  }

  bool _validateJsonArgs(String raw) {
    final normalized = raw.trim();
    if (normalized.isEmpty) return true;
    try {
      final decoded = jsonDecode(normalized);
      if (decoded is Map<String, dynamic>) return true;
      _setTaskStatus('拦截：剧本工具参数必须是 JSON object。');
      return false;
    } catch (_) {
      _setTaskStatus('拦截：剧本工具参数 JSON 解析失败。');
      return false;
    }
  }

  bool _validatePrompt(String action) {
    if (widget.scriptPromptController.text.trim().isNotEmpty) return true;
    _setTaskStatus('拦截：$action 需要非空工作区提示词。');
    return false;
  }

  bool _validateScriptProbe() {
    if (widget.selectedScriptDomainTool.trim().isEmpty) {
      _setTaskStatus('拦截：读取前需要选择剧本域工具。');
      return false;
    }
    if (!_validateJsonArgs(widget.scriptDomainArgsController.text)) {
      return false;
    }
    if (widget.selectedScriptDomainTool == 'get_script_content' &&
        _scopeScriptId == null) {
      _setTaskStatus('拦截：get_script_content 需要有效剧本 ID。');
      return false;
    }
    return true;
  }

  bool _normalizeArgsForProbe() {
    final raw = widget.scriptDomainArgsController.text.trim();
    final Map<String, dynamic> normalized;
    if (raw.isEmpty) {
      normalized = <String, dynamic>{};
    } else {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) {
        _setTaskStatus('拦截：剧本工具参数必须是 JSON object。');
        return false;
      }
      normalized = Map<String, dynamic>.from(decoded);
    }
    if (widget.selectedScriptDomainTool == 'get_script_content') {
      final scriptId = _scopeScriptId;
      if (scriptId == null) {
        _setTaskStatus('拦截：get_script_content 需要有效剧本 ID。');
        return false;
      }
      if (normalized['scriptId'] != scriptId) {
        normalized['scriptId'] = scriptId;
        widget.scriptDomainArgsController.text = jsonEncode(normalized);
        _setTaskStatus(
          '已同步：get_script_content arguments.scriptId -> $scriptId',
        );
      }
      return true;
    }
    widget.scriptDomainArgsController.text = jsonEncode(normalized);
    return true;
  }

  bool _validateSubAgentTool() {
    if (widget.scriptSubAgentToolController.text.trim().isEmpty) {
      _setTaskStatus('拦截：运行子代理前需要选择剧本子代理工具。');
      return false;
    }
    return _validatePrompt('运行子代理');
  }

  List<({String label, String args})> _argumentTemplates() {
    switch (widget.selectedScriptDomainTool) {
      case 'get_script_content':
        final scriptId = _scopeScriptId ?? 1;
        return <({String label, String args})>[
          (label: '模板: 当前剧本', args: '{"scriptId":$scriptId}'),
        ];
      case 'get_novel_text':
      case 'get_novel_events':
        return <({String label, String args})>[
          (label: '模板: 小说 ID', args: '{"novelId":1}'),
        ];
      case 'get_planData':
      default:
        return <({String label, String args})>[(label: '模板: 空参数', args: '{}')];
    }
  }

  void _applyToolArgsTemplate(String args, String label) {
    widget.scriptDomainArgsController.text = args;
    _setTaskStatus('已填充参数模板：$label');
  }

  List<String> _buildResultSummaryLines() {
    final lines = <String>[
      'tool=${widget.selectedScriptDomainTool}',
      if (_scriptWritebackSourceLine != null)
        'writebackSource=${_scriptWritebackSourceLine!}',
      if (widget.workspaceScriptWritebackCandidate?.trim().isNotEmpty == true)
        'scriptCandidate.chars=${widget.workspaceScriptWritebackCandidate!.trim().length}',
      if (widget.workspaceAssistantText.trim().isNotEmpty)
        'assistant.chars=${widget.workspaceAssistantText.trim().length}',
    ];
    final planCandidate = widget.workspaceScriptPlanWritebackCandidate;
    if (planCandidate != null) {
      final pid = widget.workspaceScriptPlanRowId;
      if (pid != null) {
        lines.add('planRowId=$pid');
      }
      final data = planCandidate['data'];
      if (data is Map<String, dynamic>) {
        final scriptRows = data['script'];
        if (scriptRows is List) {
          lines.add('plan.scriptRows=${scriptRows.length}');
        }
        if ((data['storySkeleton'] as String?)?.trim().isNotEmpty == true) {
          lines.add('plan.storySkeleton=ready');
        }
        if ((data['adaptationStrategy'] as String?)?.trim().isNotEmpty ==
            true) {
          lines.add('plan.adaptationStrategy=ready');
        }
      }
    }
    lines.addAll(
      summarizeScriptResultSnapshot(
        widget.workspaceLastToolName,
        widget.workspaceLastToolResultData,
      ),
    );
    return lines.take(6).toList(growable: false);
  }

  List<Widget> _buildContextSnapshot(BuildContext context) {
    final snapshot = ScriptContextSnapshotView(
      workspaceScriptPlanWritebackCandidate:
          widget.workspaceScriptPlanWritebackCandidate,
      workspaceLastToolName: widget.workspaceLastToolName,
      workspaceLastToolResultData: widget.workspaceLastToolResultData,
    );
    return <Widget>[snapshot];
  }

  void _runScriptWorkspace() {
    if (!_validatePrompt('运行剧本工作流')) return;
    widget.onRunScriptWorkspace();
    _setTaskStatus('已触发：运行剧本工作流');
  }

  void _probeScriptDomainTool() {
    if (!_validateScriptProbe()) return;
    if (!_normalizeArgsForProbe()) return;
    widget.onProbeScriptDomainTool();
    _setTaskStatus('已触发：读取剧本上下文 (${widget.selectedScriptDomainTool})');
  }

  void _runScriptSubAgentTool() {
    if (!_validateSubAgentTool()) return;
    widget.onRunScriptSubAgentTool();
    final tool = widget.scriptSubAgentToolController.text.trim();
    _setTaskStatus('已触发：运行子代理 ($tool)');
  }

  void _writeBackScriptResult() {
    if (!_canWriteBackScriptResult) {
      _setTaskStatus('拦截：暂无剧本结果可写回。');
      return;
    }
    widget.onWriteBackScriptResult();
    _setTaskStatus('已触发：写回剧本');
  }

  void _writeBackScriptPlanResult() {
    if (!_canWriteBackScriptPlanResult) {
      _setTaskStatus('拦截：暂无 planData 结果可写回。');
      return;
    }
    widget.onWriteBackScriptPlanResult();
    _setTaskStatus('已触发：写回计划数据');
  }

  void _writeBackScriptPlanViaUpdateData() {
    if (!_canWriteBackScriptPlanViaUpdateData) {
      _setTaskStatus('拦截：需要 planId（拉取 get_planData）与 planData。');
      return;
    }
    widget.onWriteBackScriptPlanViaUpdateData();
    _setTaskStatus('已触发：update-data 写回计划行');
  }

  Widget _buildPromptTemplates() {
    return ScriptWorkspacePromptTemplatesPanel(
      busy: widget.busy,
      presets: widget.scriptPromptPresets,
      onSelectPrompt: widget.onSelectPrompt,
    );
  }

  Widget _buildGuidedTasks() {
    return ScriptWorkspaceGuidedTasksPanel(
      busy: widget.busy,
      canWriteBackScriptResult: _canWriteBackScriptResult,
      onFetchPlanData: () {
        widget.onScriptDomainToolChanged('get_planData');
        _probeScriptDomainTool();
      },
      onFetchScriptContent: () {
        widget.onScriptDomainToolChanged('get_script_content');
        _probeScriptDomainTool();
      },
      onGenerateDraft: () {
        _applyScriptPromptIfEmpty(
          '请基于当前剧情计划与上下文生成下一版剧本正文，输出可直接写回的完整内容。',
        );
        widget.onScriptSubAgentChanged('run_sub_agent_script');
        _runScriptSubAgentTool();
      },
      onWriteBackScript: _writeBackScriptResult,
    );
  }

  Widget _buildArgumentTemplates() {
    final templates = _argumentTemplates();
    final suggestions = buildScriptWorkspaceArgumentSuggestions(
      selectedTool: widget.selectedScriptDomainTool,
      toolName: widget.workspaceLastToolName,
      result: widget.workspaceLastToolResultData,
    );
    return ScriptWorkspaceArgumentTemplatesPanel(
      busy: widget.busy,
      templates: <ScriptWorkspaceArgumentTemplateEntry>[
        ...templates.map(
          (entry) => ScriptWorkspaceArgumentTemplateEntry(
            label: entry.label,
            args: entry.args,
          ),
        ),
        ...suggestions.map(
          (suggestion) => ScriptWorkspaceArgumentTemplateEntry(
            label: suggestion.label,
            args: jsonEncode(suggestion.payload),
          ),
        ),
      ],
      onApplyTemplate: _applyToolArgsTemplate,
    );
  }

  List<ScriptWorkspaceRecipe> _buildWorkspaceRecipes() {
    return buildScriptWorkspaceRecipes(
      toolName: widget.workspaceLastToolName,
      result: widget.workspaceLastToolResultData,
      scopeScriptId: _scopeScriptId,
    );
  }

  List<ScriptWorkspaceStage> _buildWorkspaceStages() {
    return buildScriptWorkspaceStages(
      toolName: widget.workspaceLastToolName,
      result: widget.workspaceLastToolResultData,
      scopeScriptId: _scopeScriptId,
    );
  }

  void _applyWorkspaceRecipe(ScriptWorkspaceRecipe recipe) {
    if (recipe.domainTool != null && recipe.domainTool!.trim().isNotEmpty) {
      widget.onScriptDomainToolChanged(recipe.domainTool!.trim());
      widget.scriptDomainArgsController.text = jsonEncode(
        recipe.args ?? <String, dynamic>{},
      );
    }
    if (recipe.subAgentTool != null && recipe.subAgentTool!.trim().isNotEmpty) {
      widget.onScriptSubAgentChanged(recipe.subAgentTool!.trim());
    }
    final prompt = recipe.prompt?.trim();
    if (prompt != null && prompt.isNotEmpty) {
      widget.scriptPromptController.text = prompt;
    }
    _setTaskStatus('已应用任务建议：${recipe.title}');
  }

  void _runWorkspaceRecipeDomainTool(ScriptWorkspaceRecipe recipe) {
    _applyWorkspaceRecipe(recipe);
    if (recipe.domainTool == null || recipe.domainTool!.trim().isEmpty) return;
    _probeScriptDomainTool();
  }

  void _runWorkspaceRecipeSubAgent(ScriptWorkspaceRecipe recipe) {
    _applyWorkspaceRecipe(recipe);
    if (recipe.subAgentTool == null || recipe.subAgentTool!.trim().isEmpty) return;
    _runScriptSubAgentTool();
  }

  void _applyWorkspaceStage(ScriptWorkspaceStage stage) {
    if (stage.domainTool != null && stage.domainTool!.trim().isNotEmpty) {
      widget.onScriptDomainToolChanged(stage.domainTool!.trim());
      widget.scriptDomainArgsController.text = jsonEncode(
        stage.args ?? <String, dynamic>{},
      );
    }
    if (stage.subAgentTool != null && stage.subAgentTool!.trim().isNotEmpty) {
      widget.onScriptSubAgentChanged(stage.subAgentTool!.trim());
    }
    final prompt = stage.prompt?.trim();
    if (prompt != null && prompt.isNotEmpty) {
      widget.scriptPromptController.text = prompt;
    }
    _setTaskStatus('已应用阶段动作：${stage.title}');
  }

  void _runWorkspaceStageDomainTool(ScriptWorkspaceStage stage) {
    _applyWorkspaceStage(stage);
    if (stage.domainTool == null || stage.domainTool!.trim().isEmpty) return;
    _probeScriptDomainTool();
  }

  void _runWorkspaceStageSubAgent(ScriptWorkspaceStage stage) {
    _applyWorkspaceStage(stage);
    if (stage.subAgentTool == null || stage.subAgentTool!.trim().isEmpty) return;
    _runScriptSubAgentTool();
  }

  Widget _buildWorkspaceStagesPanel(BuildContext context) {
    return ScriptWorkspaceStagesPanel(
      stages: _buildWorkspaceStages(),
      busy: widget.busy,
      onApplyStage: _applyWorkspaceStage,
      onRunStageDomainTool: _runWorkspaceStageDomainTool,
      onRunStageSubAgent: _runWorkspaceStageSubAgent,
    );
  }

  Widget _buildWorkspaceDiagnosis(BuildContext context) {
    return ScriptWorkspaceDiagnosisPanel(
      recipes: _buildWorkspaceRecipes(),
      busy: widget.busy,
      onApplyRecipe: _applyWorkspaceRecipe,
      onRunRecipeDomainTool: _runWorkspaceRecipeDomainTool,
      onRunRecipeSubAgent: _runWorkspaceRecipeSubAgent,
    );
  }

  @override
  Widget build(BuildContext context) {
    final resultSummaryLines = _buildResultSummaryLines();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text('剧本工作区', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text('引导任务', style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 6),
            _buildGuidedTasks(),
            const SizedBox(height: 10),
            _buildPromptTemplates(),
            const SizedBox(height: 8),
            ScriptWorkspaceControlsPanel(
              busy: widget.busy,
              loadingScriptWorkspaceRun: widget.loadingScriptWorkspaceRun,
              loadingScriptDomainProbe: widget.loadingScriptDomainProbe,
              loadingScriptSubAgentRun: widget.loadingScriptSubAgentRun,
              loadingScriptResultWriteback: widget.loadingScriptResultWriteback,
              loadingScriptPlanResultWriteback:
                  widget.loadingScriptPlanResultWriteback,
              canWriteBackScriptResult: _canWriteBackScriptResult,
              canWriteBackScriptPlanResult: _canWriteBackScriptPlanResult,
              canWriteBackScriptPlanViaUpdateData:
                  _canWriteBackScriptPlanViaUpdateData,
              scriptPromptController: widget.scriptPromptController,
              scriptDomainArgsController: widget.scriptDomainArgsController,
              scriptDomainToolPresets: widget.scriptDomainToolPresets,
              scriptSubAgentPresets: widget.scriptSubAgentPresets,
              selectedScriptDomainTool: _resolveDropdownValue(
                widget.selectedScriptDomainTool,
                widget.scriptDomainToolPresets,
              ),
              selectedScriptSubAgentTool: _resolveDropdownValue(
                widget.scriptSubAgentToolController.text.trim(),
                widget.scriptSubAgentPresets,
              ),
              onRunScriptWorkspace: _runScriptWorkspace,
              onScriptDomainToolChanged: widget.onScriptDomainToolChanged,
              onProbeScriptDomainTool: _probeScriptDomainTool,
              onScriptSubAgentChanged: widget.onScriptSubAgentChanged,
              onRunScriptSubAgentTool: _runScriptSubAgentTool,
              onWriteBackScriptResult: _writeBackScriptResult,
              onWriteBackScriptPlanResult: _writeBackScriptPlanResult,
              onWriteBackScriptPlanViaUpdateData:
                  _writeBackScriptPlanViaUpdateData,
            ),
            const SizedBox(height: 8),
            _buildArgumentTemplates(),
            ScriptWorkspaceStatusPanel(
              resultSummaryLines: resultSummaryLines,
              workspaceAssistantText: widget.workspaceAssistantText,
              previewAssistantText: _previewText,
              runningTaskLine: _runningTaskLine,
              taskStatusLine: _taskStatusLine,
              scriptWritebackSourceLine: _scriptWritebackSourceLine,
              scriptPlanWritebackLine: _scriptPlanWritebackLine,
              workspaceWritebackLine: widget.workspaceWritebackLine,
            ),
            _buildWorkspaceStagesPanel(context),
            _buildWorkspaceDiagnosis(context),
            ..._buildContextSnapshot(context),
          ],
        ),
      ),
    );
  }
}
