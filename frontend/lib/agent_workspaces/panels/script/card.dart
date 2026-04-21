import 'dart:convert';

import 'package:flutter/material.dart';

import '../../panel_support.dart';
import '../../prompt_preset.dart';
import '../../contexts/script/action_panels.dart';
import '../../contexts/script/card_panels.dart';
import '../../contexts/script/context_snapshot.dart';
import '../../contexts/script/status_panels.dart';
import '../../contexts/script/support.dart';

part 'card_support.dart';
part 'card_logic.dart';

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
              selectedScriptDomainTool: resolveWorkspaceDropdownValue(
                widget.selectedScriptDomainTool,
                widget.scriptDomainToolPresets,
              ),
              selectedScriptSubAgentTool: resolveWorkspaceDropdownValue(
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
