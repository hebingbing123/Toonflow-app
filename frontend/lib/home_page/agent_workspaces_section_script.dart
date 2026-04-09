import 'dart:convert';

import 'package:flutter/material.dart';

class AgentWorkspacePromptPreset {
  const AgentWorkspacePromptPreset({required this.label, required this.prompt});

  final String label;
  final String prompt;
}

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
    required this.workspaceWritebackLine,
    required this.onSelectPrompt,
    required this.onScriptDomainToolChanged,
    required this.onRunScriptWorkspace,
    required this.onProbeScriptDomainTool,
    required this.onScriptSubAgentChanged,
    required this.onRunScriptSubAgentTool,
    required this.onWriteBackScriptResult,
    required this.onWriteBackScriptPlanResult,
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
  final String? workspaceWritebackLine;
  final ValueChanged<String> onSelectPrompt;
  final ValueChanged<String> onScriptDomainToolChanged;
  final VoidCallback onRunScriptWorkspace;
  final VoidCallback onProbeScriptDomainTool;
  final ValueChanged<String> onScriptSubAgentChanged;
  final VoidCallback onRunScriptSubAgentTool;
  final VoidCallback onWriteBackScriptResult;
  final VoidCallback onWriteBackScriptPlanResult;

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
    return 'PlanData source ready: story/adaptation + script rows=$scriptCount';
  }

  String? get _runningTaskLine {
    if (widget.loadingScriptWorkspaceRun) return '执行中：Run script';
    if (widget.loadingScriptDomainProbe) return '执行中：Probe script data';
    if (widget.loadingScriptSubAgentRun) return '执行中：Run sub-agent';
    if (widget.loadingScriptResultWriteback) return '执行中：Write script';
    if (widget.loadingScriptPlanResultWriteback) return '执行中：Write planData';
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
      _setTaskStatus('拦截：script tool arguments 必须是 JSON object。');
      return false;
    } catch (_) {
      _setTaskStatus('拦截：script tool arguments JSON 解析失败。');
      return false;
    }
  }

  bool _validatePrompt(String action) {
    if (widget.scriptPromptController.text.trim().isNotEmpty) return true;
    _setTaskStatus('拦截：$action 需要非空 workspace prompt。');
    return false;
  }

  bool _validateScriptProbe() {
    if (widget.selectedScriptDomainTool.trim().isEmpty) {
      _setTaskStatus('拦截：Probe 需要选择 script domain tool。');
      return false;
    }
    if (!_validateJsonArgs(widget.scriptDomainArgsController.text)) {
      return false;
    }
    if (widget.selectedScriptDomainTool == 'get_script_content' &&
        _scopeScriptId == null) {
      _setTaskStatus('拦截：get_script_content 需要有效 script_id。');
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
        _setTaskStatus('拦截：script tool arguments 必须是 JSON object。');
        return false;
      }
      normalized = Map<String, dynamic>.from(decoded);
    }
    if (widget.selectedScriptDomainTool == 'get_script_content') {
      final scriptId = _scopeScriptId;
      if (scriptId == null) {
        _setTaskStatus('拦截：get_script_content 需要有效 script_id。');
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
      _setTaskStatus('拦截：Run sub-agent 需要选择 script sub-agent tool。');
      return false;
    }
    return _validatePrompt('Run sub-agent');
  }

  List<({String label, String args})> _argumentTemplates() {
    switch (widget.selectedScriptDomainTool) {
      case 'get_script_content':
        final scriptId = _scopeScriptId ?? 1;
        return <({String label, String args})>[
          (label: '模板: 当前 script', args: '{"scriptId":$scriptId}'),
        ];
      case 'get_novel_text':
      case 'get_novel_events':
        return <({String label, String args})>[
          (label: '模板: novelId', args: '{"novelId":1}'),
        ];
      case 'get_planData':
      default:
        return <({String label, String args})>[
          (label: '模板: empty', args: '{}'),
        ];
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
    return lines.take(6).toList(growable: false);
  }

  void _runScriptWorkspace() {
    if (!_validatePrompt('Run script')) return;
    widget.onRunScriptWorkspace();
    _setTaskStatus('已触发：Run script');
  }

  void _probeScriptDomainTool() {
    if (!_validateScriptProbe()) return;
    if (!_normalizeArgsForProbe()) return;
    widget.onProbeScriptDomainTool();
    _setTaskStatus(
      '已触发：Probe script data (${widget.selectedScriptDomainTool})',
    );
  }

  void _runScriptSubAgentTool() {
    if (!_validateSubAgentTool()) return;
    widget.onRunScriptSubAgentTool();
    final tool = widget.scriptSubAgentToolController.text.trim();
    _setTaskStatus('已触发：Run sub-agent ($tool)');
  }

  void _writeBackScriptResult() {
    if (!_canWriteBackScriptResult) {
      _setTaskStatus('拦截：暂无剧本结果可写回。');
      return;
    }
    widget.onWriteBackScriptResult();
    _setTaskStatus('已触发：Write script');
  }

  void _writeBackScriptPlanResult() {
    if (!_canWriteBackScriptPlanResult) {
      _setTaskStatus('拦截：暂无 planData 结果可写回。');
      return;
    }
    widget.onWriteBackScriptPlanResult();
    _setTaskStatus('已触发：Write planData');
  }

  Widget _buildPromptTemplates() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: widget.scriptPromptPresets
          .map(
            (AgentWorkspacePromptPreset preset) => ActionChip(
              label: Text(preset.label),
              onPressed: widget.busy
                  ? null
                  : () => widget.onSelectPrompt(preset.prompt),
            ),
          )
          .toList(growable: false),
    );
  }

  Widget _buildGuidedTasks() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: <Widget>[
        FilledButton.tonal(
          onPressed: widget.busy
              ? null
              : () {
                  widget.onScriptDomainToolChanged('get_planData');
                  _probeScriptDomainTool();
                },
          child: const Text('1) 拉取 planData'),
        ),
        FilledButton.tonal(
          onPressed: widget.busy
              ? null
              : () {
                  widget.onScriptDomainToolChanged('get_script_content');
                  _probeScriptDomainTool();
                },
          child: const Text('2) 拉取剧本正文'),
        ),
        FilledButton.tonal(
          onPressed: widget.busy
              ? null
              : () {
                  _applyScriptPromptIfEmpty(
                    '请基于当前剧情计划与上下文生成下一版剧本正文，输出可直接写回的完整内容。',
                  );
                  widget.onScriptSubAgentChanged('run_sub_agent_script');
                  _runScriptSubAgentTool();
                },
          child: const Text('3) 生成剧本草稿'),
        ),
        OutlinedButton(
          onPressed: widget.busy || !_canWriteBackScriptResult
              ? null
              : _writeBackScriptResult,
          child: const Text('4) 写回剧本'),
        ),
      ],
    );
  }

  Widget _buildArgumentTemplates() {
    final templates = _argumentTemplates();
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: templates
          .map(
            (entry) => ActionChip(
              label: Text(entry.label),
              onPressed: widget.busy
                  ? null
                  : () => _applyToolArgsTemplate(entry.args, entry.label),
            ),
          )
          .toList(growable: false),
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
            Text(
              'Script workspace',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text('Guided tasks', style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 6),
            _buildGuidedTasks(),
            const SizedBox(height: 10),
            _buildPromptTemplates(),
            const SizedBox(height: 8),
            TextField(
              controller: widget.scriptPromptController,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'workspace prompt',
                helperText: '用于 script 通道 harness.agent.run',
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                FilledButton.tonal(
                  onPressed: widget.busy ? null : _runScriptWorkspace,
                  child: Text(
                    widget.loadingScriptWorkspaceRun ? '…' : 'Run script',
                  ),
                ),
                SizedBox(
                  width: 220,
                  child: DropdownButtonFormField<String>(
                    isExpanded: true,
                    initialValue: _resolveDropdownValue(
                      widget.selectedScriptDomainTool,
                      widget.scriptDomainToolPresets,
                    ),
                    items: widget.scriptDomainToolPresets
                        .map(
                          (String tool) => DropdownMenuItem<String>(
                            value: tool,
                            child: Text(tool),
                          ),
                        )
                        .toList(growable: false),
                    onChanged: widget.busy
                        ? null
                        : (String? value) {
                            if (value == null) return;
                            widget.onScriptDomainToolChanged(value);
                          },
                    decoration: const InputDecoration(
                      labelText: 'script domain tool',
                    ),
                  ),
                ),
                FilledButton.tonal(
                  onPressed: widget.busy ? null : _probeScriptDomainTool,
                  child: Text(
                    widget.loadingScriptDomainProbe ? '…' : 'Probe script data',
                  ),
                ),
                SizedBox(
                  width: 320,
                  child: TextField(
                    controller: widget.scriptDomainArgsController,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'script tool arguments(JSON)',
                      helperText: '可选，例如 {"novelId":1}',
                    ),
                  ),
                ),
                SizedBox(
                  width: 300,
                  child: DropdownButtonFormField<String>(
                    isExpanded: true,
                    initialValue: _resolveDropdownValue(
                      widget.scriptSubAgentToolController.text.trim(),
                      widget.scriptSubAgentPresets,
                    ),
                    items: widget.scriptSubAgentPresets
                        .map(
                          (String tool) => DropdownMenuItem<String>(
                            value: tool,
                            child: Text(tool),
                          ),
                        )
                        .toList(growable: false),
                    onChanged: widget.busy
                        ? null
                        : (String? value) {
                            if (value == null) return;
                            widget.onScriptSubAgentChanged(value);
                          },
                    decoration: const InputDecoration(
                      labelText: 'script sub-agent tool',
                    ),
                  ),
                ),
                FilledButton.tonal(
                  onPressed: widget.busy ? null : _runScriptSubAgentTool,
                  child: Text(
                    widget.loadingScriptSubAgentRun ? '…' : 'Run sub-agent',
                  ),
                ),
                FilledButton(
                  onPressed: widget.busy || !_canWriteBackScriptResult
                      ? null
                      : _writeBackScriptResult,
                  child: Text(
                    widget.loadingScriptResultWriteback
                        ? '…'
                        : 'Write back to script',
                  ),
                ),
                FilledButton.tonal(
                  onPressed: widget.busy || !_canWriteBackScriptPlanResult
                      ? null
                      : _writeBackScriptPlanResult,
                  child: Text(
                    widget.loadingScriptPlanResultWriteback
                        ? '…'
                        : 'Write back planData',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            _buildArgumentTemplates(),
            if (_runningTaskLine != null ||
                _taskStatusLine != null) ...<Widget>[
              const SizedBox(height: 8),
              Text(
                _runningTaskLine ?? _taskStatusLine!,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            if (resultSummaryLines.isNotEmpty) ...<Widget>[
              const SizedBox(height: 8),
              ...resultSummaryLines.map(
                (String line) => Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: Text(
                    line,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ),
            ],
            if (widget.workspaceAssistantText.trim().isNotEmpty) ...<Widget>[
              const SizedBox(height: 8),
              Text(
                'Latest assistant result',
                style: Theme.of(context).textTheme.labelLarge,
              ),
              const SizedBox(height: 4),
              SelectableText(
                _previewText(
                  widget.workspaceAssistantText.trim(),
                  maxChars: 720,
                ),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            if (_scriptWritebackSourceLine != null) ...<Widget>[
              const SizedBox(height: 8),
              Text(
                'Writeback source: ${_scriptWritebackSourceLine!}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            if (_scriptPlanWritebackLine != null) ...<Widget>[
              const SizedBox(height: 8),
              Text(
                _scriptPlanWritebackLine!,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            if (widget.workspaceWritebackLine != null) ...<Widget>[
              const SizedBox(height: 8),
              Text(
                widget.workspaceWritebackLine!,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
