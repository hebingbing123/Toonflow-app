import 'dart:convert';

import 'package:flutter/material.dart';

import 'agent_workspaces_section_script.dart';

class AgentWorkspaceProductionCard extends StatefulWidget {
  const AgentWorkspaceProductionCard({
    super.key,
    required this.busy,
    required this.productionPromptController,
    required this.productionDomainToolController,
    required this.productionDomainArgsController,
    required this.productionSubAgentToolController,
    required this.flowKeyController,
    required this.productionPromptPresets,
    required this.productionDomainToolPresets,
    required this.productionSubAgentPresets,
    required this.flowKeyPresets,
    required this.loadingProductionWorkspaceRun,
    required this.loadingProductionFlowProbe,
    required this.loadingProductionSubAgentRun,
    required this.loadingProductionResultWriteback,
    required this.workspaceLastToolResultLine,
    required this.workspaceSuggestedFlowKey,
    required this.onSelectPrompt,
    required this.onProductionDomainToolChanged,
    required this.onFlowKeyChanged,
    required this.onRunProductionWorkspace,
    required this.onProbeProductionDomainTool,
    required this.onProductionSubAgentChanged,
    required this.onRunProductionSubAgentTool,
    required this.onWriteBackProductionFlowResult,
    required this.onApplySuggestedFlowKey,
  });

  final bool busy;
  final TextEditingController productionPromptController;
  final TextEditingController productionDomainToolController;
  final TextEditingController productionDomainArgsController;
  final TextEditingController productionSubAgentToolController;
  final TextEditingController flowKeyController;
  final List<AgentWorkspacePromptPreset> productionPromptPresets;
  final List<String> productionDomainToolPresets;
  final List<String> productionSubAgentPresets;
  final List<String> flowKeyPresets;
  final bool loadingProductionWorkspaceRun;
  final bool loadingProductionFlowProbe;
  final bool loadingProductionSubAgentRun;
  final bool loadingProductionResultWriteback;
  final String? workspaceLastToolResultLine;
  final String? workspaceSuggestedFlowKey;
  final ValueChanged<String> onSelectPrompt;
  final ValueChanged<String> onProductionDomainToolChanged;
  final ValueChanged<String> onFlowKeyChanged;
  final VoidCallback onRunProductionWorkspace;
  final VoidCallback onProbeProductionDomainTool;
  final ValueChanged<String> onProductionSubAgentChanged;
  final VoidCallback onRunProductionSubAgentTool;
  final VoidCallback onWriteBackProductionFlowResult;
  final VoidCallback onApplySuggestedFlowKey;

  @override
  State<AgentWorkspaceProductionCard> createState() =>
      _AgentWorkspaceProductionCardState();
}

class _AgentWorkspaceProductionCardState
    extends State<AgentWorkspaceProductionCard> {
  String? _taskStatusLine;

  String? _resolveDropdownValue(String value, List<String> allowed) {
    if (allowed.contains(value)) return value;
    if (allowed.isEmpty) return null;
    return allowed.first;
  }

  Widget _buildPromptTemplates() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: widget.productionPromptPresets
          .map(
            (AgentWorkspacePromptPreset preset) => ActionChip(
              label: Text(preset.label),
              onPressed:
                  widget.busy ? null : () => widget.onSelectPrompt(preset.prompt),
            ),
          )
          .toList(growable: false),
    );
  }

  String? get _suggestedFlowKeyLine {
    final key = widget.workspaceSuggestedFlowKey?.trim();
    if (key == null || key.isEmpty) return null;
    return key;
  }

  String? get _runningTaskLine {
    if (widget.loadingProductionWorkspaceRun) return '执行中：Run production';
    if (widget.loadingProductionFlowProbe) return '执行中：Probe production tool';
    if (widget.loadingProductionSubAgentRun) return '执行中：Run sub-agent';
    if (widget.loadingProductionResultWriteback) return '执行中：Write tool result';
    return null;
  }

  void _setTaskStatus(String message) {
    if (!mounted) return;
    setState(() => _taskStatusLine = message);
  }

  bool _validateJsonArgs(String raw) {
    final normalized = raw.trim();
    if (normalized.isEmpty) return true;
    try {
      final decoded = jsonDecode(normalized);
      if (decoded is Map<String, dynamic>) return true;
      _setTaskStatus('拦截：production tool arguments 必须是 JSON object。');
      return false;
    } catch (_) {
      _setTaskStatus('拦截：production tool arguments JSON 解析失败。');
      return false;
    }
  }

  bool _validatePrompt(String action) {
    if (widget.productionPromptController.text.trim().isNotEmpty) return true;
    _setTaskStatus('拦截：$action 需要非空 workspace prompt。');
    return false;
  }

  bool _validateFlowProbe() {
    final tool = widget.productionDomainToolController.text.trim();
    if (tool.isEmpty) {
      _setTaskStatus('拦截：Probe 需要选择 production domain tool。');
      return false;
    }
    if (!_validateJsonArgs(widget.productionDomainArgsController.text)) {
      return false;
    }
    if (tool == 'get_flowData' && widget.flowKeyController.text.trim().isEmpty) {
      _setTaskStatus('拦截：get_flowData 需要有效 flow key。');
      return false;
    }
    return true;
  }

  bool _validateSubAgentTool() {
    if (widget.productionSubAgentToolController.text.trim().isEmpty) {
      _setTaskStatus('拦截：Run sub-agent 需要选择 production sub-agent tool。');
      return false;
    }
    return _validatePrompt('Run sub-agent');
  }

  void _runProductionWorkspace() {
    if (!_validatePrompt('Run production')) return;
    widget.onRunProductionWorkspace();
    _setTaskStatus('已触发：Run production');
  }

  void _probeProductionDomainTool() {
    if (!_validateFlowProbe()) return;
    widget.onProbeProductionDomainTool();
    final tool = widget.productionDomainToolController.text.trim();
    final key = widget.flowKeyController.text.trim();
    final suffix = tool == 'get_flowData' ? ' key=$key' : '';
    _setTaskStatus('已触发：Probe production tool ($tool$suffix)');
  }

  void _runProductionSubAgentTool() {
    if (!_validateSubAgentTool()) return;
    widget.onRunProductionSubAgentTool();
    final tool = widget.productionSubAgentToolController.text.trim();
    _setTaskStatus('已触发：Run sub-agent ($tool)');
  }

  void _writeBackProductionFlowResult() {
    if (widget.workspaceLastToolResultLine == null) {
      _setTaskStatus('拦截：暂无工具结果可写回。');
      return;
    }
    if (widget.flowKeyController.text.trim().isEmpty) {
      _setTaskStatus('拦截：写回前请提供有效 flow key。');
      return;
    }
    widget.onWriteBackProductionFlowResult();
    final key = widget.flowKeyController.text.trim();
    _setTaskStatus('已触发：Write tool result -> flow[$key]');
  }

  void _applyProductionPromptIfEmpty(String prompt) {
    if (widget.productionPromptController.text.trim().isNotEmpty) return;
    widget.productionPromptController.text = prompt;
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
                  widget.onFlowKeyChanged('assets');
                  widget.onProductionDomainToolChanged('get_flowData');
                  _probeProductionDomainTool();
                },
          child: const Text('1) 拉取资产 flow'),
        ),
        FilledButton.tonal(
          onPressed: widget.busy
              ? null
              : () {
                  _applyProductionPromptIfEmpty(
                    '请基于当前资产 flow 给出下一轮衍生素材生成建议，并执行最小可行推进。',
                  );
                  widget.onProductionSubAgentChanged(
                    'run_sub_agent_derive_assets',
                  );
                  _runProductionSubAgentTool();
                },
          child: const Text('2) 运行资产子代理'),
        ),
        FilledButton.tonal(
          onPressed: widget.busy
              ? null
              : () {
                  widget.onFlowKeyChanged('storyboard');
                  widget.onProductionDomainToolChanged('get_flowData');
                  _probeProductionDomainTool();
                },
          child: const Text('3) 拉取分镜 flow'),
        ),
        OutlinedButton(
          onPressed: widget.busy || widget.workspaceLastToolResultLine == null
              ? null
              : _writeBackProductionFlowResult,
          child: const Text('4) 写回 flow'),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'Production workspace',
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
              controller: widget.productionPromptController,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'workspace prompt',
                helperText: '用于 production 通道 harness.agent.run',
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                FilledButton.tonal(
                  onPressed: widget.busy ? null : _runProductionWorkspace,
                  child: Text(
                    widget.loadingProductionWorkspaceRun ? '…' : 'Run production',
                  ),
                ),
                SizedBox(
                  width: 260,
                  child: DropdownButtonFormField<String>(
                    isExpanded: true,
                    initialValue: _resolveDropdownValue(
                      widget.productionDomainToolController.text.trim(),
                      widget.productionDomainToolPresets,
                    ),
                    items: widget.productionDomainToolPresets
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
                            widget.onProductionDomainToolChanged(value);
                          },
                    decoration: const InputDecoration(
                      labelText: 'production domain tool',
                    ),
                  ),
                ),
                SizedBox(
                  width: 220,
                  child: DropdownButtonFormField<String>(
                    isExpanded: true,
                    initialValue: _resolveDropdownValue(
                      widget.flowKeyController.text.trim(),
                      widget.flowKeyPresets,
                    ),
                    items: widget.flowKeyPresets
                        .map(
                          (String key) => DropdownMenuItem<String>(
                            value: key,
                            child: Text(key),
                          ),
                        )
                        .toList(growable: false),
                    onChanged: widget.busy
                        ? null
                        : (String? value) {
                            if (value == null) return;
                            widget.onFlowKeyChanged(value);
                          },
                    decoration: const InputDecoration(
                      labelText: 'flow key',
                      helperText: '作为 get_flowData key 和写回 key',
                    ),
                  ),
                ),
                SizedBox(
                  width: 360,
                  child: TextField(
                    controller: widget.productionDomainArgsController,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'production tool arguments(JSON)',
                      helperText: '非 get_flowData 时使用，例如 {"ids":[1,2]}',
                    ),
                  ),
                ),
                FilledButton.tonal(
                  onPressed: widget.busy ? null : _probeProductionDomainTool,
                  child: Text(
                    widget.loadingProductionFlowProbe ? '…' : 'Probe production tool',
                  ),
                ),
                SizedBox(
                  width: 300,
                  child: DropdownButtonFormField<String>(
                    isExpanded: true,
                    initialValue: _resolveDropdownValue(
                      widget.productionSubAgentToolController.text.trim(),
                      widget.productionSubAgentPresets,
                    ),
                    items: widget.productionSubAgentPresets
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
                            widget.onProductionSubAgentChanged(value);
                          },
                    decoration: const InputDecoration(
                      labelText: 'production sub-agent tool',
                    ),
                  ),
                ),
                FilledButton.tonal(
                  onPressed: widget.busy ? null : _runProductionSubAgentTool,
                  child: Text(
                    widget.loadingProductionSubAgentRun ? '…' : 'Run sub-agent',
                  ),
                ),
                FilledButton(
                  onPressed: widget.busy || widget.workspaceLastToolResultLine == null
                      ? null
                      : _writeBackProductionFlowResult,
                  child: Text(
                    widget.loadingProductionResultWriteback
                        ? '…'
                        : 'Write tool result',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              _runningTaskLine ??
                  _taskStatusLine ??
                  '等待执行：可直接用 Guided tasks 或表单按钮。',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            if (widget.workspaceLastToolResultLine != null) ...<Widget>[
              const SizedBox(height: 8),
              Text(
                'Latest tool result: ${widget.workspaceLastToolResultLine}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            if (_suggestedFlowKeyLine != null) ...<Widget>[
              const SizedBox(height: 8),
              Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      'Suggested writeback key: $_suggestedFlowKeyLine',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton(
                    onPressed: widget.busy ? null : widget.onApplySuggestedFlowKey,
                    child: const Text('Use key'),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 8),
            Text(
              '核心 key 回写策略：get_flowData 直接写回；资产/分镜/导演计划相关工具会先刷新对应 flow key 再写回。',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}
