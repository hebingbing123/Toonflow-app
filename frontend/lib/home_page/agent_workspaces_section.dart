import 'dart:convert';

import 'package:flutter/material.dart';

class AgentWorkspacesSection extends StatefulWidget {
  const AgentWorkspacesSection({
    super.key,
    required this.projectIdController,
    required this.scriptIdController,
    required this.scriptPromptController,
    required this.scriptDomainArgsController,
    required this.productionPromptController,
    required this.flowKeyController,
    required this.productionDomainToolController,
    required this.productionDomainArgsController,
    required this.loadingScriptWorkspaceRun,
    required this.loadingProductionWorkspaceRun,
    required this.loadingScriptDomainProbe,
    required this.loadingProductionFlowProbe,
    required this.loadingScriptSubAgentRun,
    required this.loadingProductionSubAgentRun,
    required this.loadingScriptResultWriteback,
    required this.loadingProductionResultWriteback,
    required this.wsLog,
    required this.workspaceAssistantText,
    required this.workspaceScriptWritebackCandidate,
    required this.workspaceScriptWritebackSource,
    required this.workspaceLastToolResultLine,
    required this.workspaceWritebackLine,
    required this.onRunScriptWorkspace,
    required this.onRunProductionWorkspace,
    required this.onProbeScriptDomainTool,
    required this.onProbeProductionDomainTool,
    required this.scriptSubAgentToolController,
    required this.productionSubAgentToolController,
    required this.onRunScriptSubAgentTool,
    required this.onRunProductionSubAgentTool,
    required this.onWriteBackScriptResult,
    required this.onWriteBackProductionFlowResult,
  });

  final TextEditingController projectIdController;
  final TextEditingController scriptIdController;
  final TextEditingController scriptPromptController;
  final TextEditingController scriptDomainArgsController;
  final TextEditingController productionPromptController;
  final TextEditingController flowKeyController;
  final TextEditingController productionDomainToolController;
  final TextEditingController productionDomainArgsController;
  final bool loadingScriptWorkspaceRun;
  final bool loadingProductionWorkspaceRun;
  final bool loadingScriptDomainProbe;
  final bool loadingProductionFlowProbe;
  final bool loadingScriptSubAgentRun;
  final bool loadingProductionSubAgentRun;
  final bool loadingScriptResultWriteback;
  final bool loadingProductionResultWriteback;
  final List<String> wsLog;
  final String workspaceAssistantText;
  final String? workspaceScriptWritebackCandidate;
  final String? workspaceScriptWritebackSource;
  final String? workspaceLastToolResultLine;
  final String? workspaceWritebackLine;
  final VoidCallback onRunScriptWorkspace;
  final VoidCallback onRunProductionWorkspace;
  final void Function(String toolName, String rawArgs) onProbeScriptDomainTool;
  final VoidCallback onProbeProductionDomainTool;
  final TextEditingController scriptSubAgentToolController;
  final TextEditingController productionSubAgentToolController;
  final VoidCallback onRunScriptSubAgentTool;
  final VoidCallback onRunProductionSubAgentTool;
  final VoidCallback onWriteBackScriptResult;
  final VoidCallback onWriteBackProductionFlowResult;

  @override
  State<AgentWorkspacesSection> createState() => _AgentWorkspacesSectionState();
}

class _AgentWorkspacesSectionState extends State<AgentWorkspacesSection> {
  static const List<String> _flowKeyPresets = <String>[
    'assets',
    'script',
    'scriptPlan',
    'storyboardTable',
    'storyboard',
    'workspaceResult',
  ];

  static const List<String> _scriptSubAgentPresets = <String>[
    'run_sub_agent_storySkeleton',
    'run_sub_agent_adaptationStrategy',
    'run_sub_agent_script',
    'run_supervision_agent',
  ];

  static const List<String> _scriptDomainToolPresets = <String>[
    'get_planData',
    'get_script_content',
    'get_novel_text',
    'get_novel_events',
  ];

  static const List<String> _productionSubAgentPresets = <String>[
    'run_sub_agent_director_plan',
    'run_sub_agent_derive_assets',
    'run_sub_agent_generate_assets',
    'run_sub_agent_storyboard_gen',
    'run_sub_agent_storyboard_panel',
    'run_sub_agent_storyboard_table',
  ];

  static const List<String> _productionDomainToolPresets = <String>[
    'get_flowData',
    'add_deriveAsset',
    'del_deriveAsset',
    'generate_deriveAsset',
    'generate_storyboard',
  ];

  static const List<_PromptPreset> _scriptPromptPresets = <_PromptPreset>[
    _PromptPreset(
      label: '剧情骨架',
      prompt:
          '先读取 get_planData 与 get_novel_events，总结当前剧情骨架缺口，再给出下一轮 script 生成建议。',
    ),
    _PromptPreset(
      label: '章节改编',
      prompt:
          '基于 get_novel_text 与 get_script_content，对当前章节做改编策略建议，输出 3 条可执行脚本改写项。',
    ),
  ];

  static const List<_PromptPreset> _productionPromptPresets = <_PromptPreset>[
    _PromptPreset(
      label: '资产盘点',
      prompt: '先调用 get_flowData key=assets，盘点现有资产状态并给出下一步 production 任务建议。',
    ),
    _PromptPreset(
      label: '分镜推进',
      prompt:
          '读取 get_flowData key=storyboard，评估当前分镜完成度并给出下一次 generate_storyboard 的执行建议。',
    ),
  ];

  String _selectedScriptDomainTool = _scriptDomainToolPresets.first;

  @override
  void initState() {
    super.initState();
    _ensurePresetDefaults();
  }

  @override
  void didUpdateWidget(covariant AgentWorkspacesSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    _ensurePresetDefaults();
  }

  void _ensurePresetDefaults() {
    if (widget.scriptSubAgentToolController.text.trim().isEmpty) {
      widget.scriptSubAgentToolController.text = _scriptSubAgentPresets.first;
    }
    if (widget.scriptDomainArgsController.text.trim().isEmpty) {
      widget.scriptDomainArgsController.text = '{}';
    }
    if (widget.productionSubAgentToolController.text.trim().isEmpty) {
      widget.productionSubAgentToolController.text =
          _productionSubAgentPresets.first;
    }
    if (widget.flowKeyController.text.trim().isEmpty) {
      widget.flowKeyController.text = _flowKeyPresets.first;
    }
    if (widget.productionDomainToolController.text.trim().isEmpty) {
      widget.productionDomainToolController.text = _productionDomainToolPresets.first;
    }
    if (widget.productionDomainArgsController.text.trim().isEmpty) {
      widget.productionDomainArgsController.text = '{}';
    }
  }

  bool get _busy =>
      widget.loadingScriptWorkspaceRun ||
      widget.loadingProductionWorkspaceRun ||
      widget.loadingScriptDomainProbe ||
      widget.loadingProductionFlowProbe ||
      widget.loadingScriptSubAgentRun ||
      widget.loadingProductionSubAgentRun ||
      widget.loadingScriptResultWriteback ||
      widget.loadingProductionResultWriteback;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const SizedBox(height: 16),
        Text('Agent workspaces', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 4),
        Text(
          '把 script 与 production 通道分开执行，按任务模板快速触发 harness.agent.run 与子 Agent 工具。',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 12),
        _buildScopeInputs(),
        const SizedBox(height: 12),
        _buildWorkspaceCards(context),
        if (widget.wsLog.isNotEmpty) ...<Widget>[
          const SizedBox(height: 12),
          _buildLogSummary(context),
          const SizedBox(height: 8),
          _buildLogList(context),
        ],
      ],
    );
  }

  Widget _buildScopeInputs() {
    return Row(
      children: <Widget>[
        Expanded(
          child: TextField(
            controller: widget.projectIdController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'project_id'),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: TextField(
            controller: widget.scriptIdController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'script_id'),
          ),
        ),
      ],
    );
  }

  Widget _buildWorkspaceCards(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final twoColumns = constraints.maxWidth >= 920;
        if (!twoColumns) {
          return Column(
            children: <Widget>[
              _buildScriptWorkspaceCard(context),
              const SizedBox(height: 12),
              _buildProductionWorkspaceCard(context),
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Expanded(child: _buildScriptWorkspaceCard(context)),
            const SizedBox(width: 12),
            Expanded(child: _buildProductionWorkspaceCard(context)),
          ],
        );
      },
    );
  }

  Widget _buildScriptWorkspaceCard(BuildContext context) {
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
            _buildPromptTemplates(
              presets: _scriptPromptPresets,
              onSelected: (String prompt) {
                setState(() => widget.scriptPromptController.text = prompt);
              },
            ),
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
                  onPressed: _busy ? null : widget.onRunScriptWorkspace,
                  child: Text(
                    widget.loadingScriptWorkspaceRun ? '…' : 'Run script',
                  ),
                ),
                SizedBox(
                  width: 220,
                  child: DropdownButtonFormField<String>(
                    initialValue: _resolveDropdownValue(
                      _selectedScriptDomainTool,
                      _scriptDomainToolPresets,
                    ),
                    items: _scriptDomainToolPresets
                        .map(
                          (String tool) => DropdownMenuItem<String>(
                            value: tool,
                            child: Text(tool),
                          ),
                        )
                        .toList(growable: false),
                    onChanged: _busy
                        ? null
                        : (String? value) {
                            if (value == null) return;
                            setState(() => _selectedScriptDomainTool = value);
                          },
                    decoration: const InputDecoration(
                      labelText: 'script domain tool',
                    ),
                  ),
                ),
                FilledButton.tonal(
                  onPressed: _busy
                      ? null
                      : () =>
                            widget.onProbeScriptDomainTool(
                              _selectedScriptDomainTool,
                              widget.scriptDomainArgsController.text,
                            ),
                  child: Text(
                    widget.loadingScriptDomainProbe
                        ? '…'
                        : 'Probe script data',
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
                    initialValue: _resolveDropdownValue(
                      widget.scriptSubAgentToolController.text.trim(),
                      _scriptSubAgentPresets,
                    ),
                    items: _scriptSubAgentPresets
                        .map(
                          (String tool) => DropdownMenuItem<String>(
                            value: tool,
                            child: Text(tool),
                          ),
                        )
                        .toList(growable: false),
                    onChanged: _busy
                        ? null
                        : (String? value) {
                            if (value == null) return;
                            setState(
                              () => widget.scriptSubAgentToolController.text =
                                  value,
                            );
                          },
                    decoration: const InputDecoration(
                      labelText: 'script sub-agent tool',
                    ),
                  ),
                ),
                FilledButton.tonal(
                  onPressed: _busy ? null : widget.onRunScriptSubAgentTool,
                  child: Text(
                    widget.loadingScriptSubAgentRun ? '…' : 'Run sub-agent',
                  ),
                ),
                FilledButton(
                  onPressed: _busy || !_canWriteBackScriptResult
                      ? null
                      : widget.onWriteBackScriptResult,
                  child: Text(
                    widget.loadingScriptResultWriteback
                        ? '…'
                        : 'Write back to script',
                  ),
                ),
              ],
            ),
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

  Widget _buildProductionWorkspaceCard(BuildContext context) {
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
            _buildPromptTemplates(
              presets: _productionPromptPresets,
              onSelected: (String prompt) {
                setState(() => widget.productionPromptController.text = prompt);
              },
            ),
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
                  onPressed: _busy ? null : widget.onRunProductionWorkspace,
                  child: Text(
                    widget.loadingProductionWorkspaceRun
                        ? '…'
                        : 'Run production',
                  ),
                ),
                SizedBox(
                  width: 260,
                  child: DropdownButtonFormField<String>(
                    initialValue: _resolveDropdownValue(
                      widget.productionDomainToolController.text.trim(),
                      _productionDomainToolPresets,
                    ),
                    items: _productionDomainToolPresets
                        .map(
                          (String tool) => DropdownMenuItem<String>(
                            value: tool,
                            child: Text(tool),
                          ),
                        )
                        .toList(growable: false),
                    onChanged: _busy
                        ? null
                        : (String? value) {
                            if (value == null) return;
                            setState(
                              () => widget.productionDomainToolController.text = value,
                            );
                          },
                    decoration: const InputDecoration(
                      labelText: 'production domain tool',
                    ),
                  ),
                ),
                SizedBox(
                  width: 220,
                  child: DropdownButtonFormField<String>(
                    initialValue: _resolveDropdownValue(
                      widget.flowKeyController.text.trim(),
                      _flowKeyPresets,
                    ),
                    items: _flowKeyPresets
                        .map(
                          (String key) => DropdownMenuItem<String>(
                            value: key,
                            child: Text(key),
                          ),
                        )
                        .toList(growable: false),
                    onChanged: _busy
                        ? null
                        : (String? value) {
                            if (value == null) return;
                            setState(
                              () => widget.flowKeyController.text = value,
                            );
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
                  onPressed: _busy ? null : widget.onProbeProductionDomainTool,
                  child: Text(
                    widget.loadingProductionFlowProbe ? '…' : 'Probe production tool',
                  ),
                ),
                SizedBox(
                  width: 300,
                  child: DropdownButtonFormField<String>(
                    initialValue: _resolveDropdownValue(
                      widget.productionSubAgentToolController.text.trim(),
                      _productionSubAgentPresets,
                    ),
                    items: _productionSubAgentPresets
                        .map(
                          (String tool) => DropdownMenuItem<String>(
                            value: tool,
                            child: Text(tool),
                          ),
                        )
                        .toList(growable: false),
                    onChanged: _busy
                        ? null
                        : (String? value) {
                            if (value == null) return;
                            setState(
                              () =>
                                  widget.productionSubAgentToolController.text =
                                      value,
                            );
                          },
                    decoration: const InputDecoration(
                      labelText: 'production sub-agent tool',
                    ),
                  ),
                ),
                FilledButton.tonal(
                  onPressed: _busy ? null : widget.onRunProductionSubAgentTool,
                  child: Text(
                    widget.loadingProductionSubAgentRun ? '…' : 'Run sub-agent',
                  ),
                ),
                FilledButton(
                  onPressed: _busy || widget.workspaceLastToolResultLine == null
                      ? null
                      : widget.onWriteBackProductionFlowResult,
                  child: Text(
                    widget.loadingProductionResultWriteback
                        ? '…'
                        : 'Write tool result',
                  ),
                ),
              ],
            ),
            if (widget.workspaceLastToolResultLine != null) ...<Widget>[
              const SizedBox(height: 8),
              Text(
                'Latest tool result: ${widget.workspaceLastToolResultLine!}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPromptTemplates({
    required List<_PromptPreset> presets,
    required ValueChanged<String> onSelected,
  }) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: presets
          .map(
            (_PromptPreset preset) => ActionChip(
              label: Text(preset.label),
              onPressed: _busy ? null : () => onSelected(preset.prompt),
            ),
          )
          .toList(growable: false),
    );
  }

  Widget _buildLogSummary(BuildContext context) {
    final latest = widget.wsLog.last;
    final eventType = _extractEventType(latest);
    return Row(
      children: <Widget>[
        Text('workspace ws log', style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(width: 8),
        if (eventType != null)
          Chip(
            label: Text('latest: $eventType'),
            visualDensity: VisualDensity.compact,
          ),
      ],
    );
  }

  Widget _buildLogList(BuildContext context) {
    final lines = widget.wsLog.reversed.take(12).toList(growable: false);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: lines
          .map(
            (String line) => Padding(
              padding: const EdgeInsets.only(top: 4),
              child: SelectableText(
                line,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          )
          .toList(growable: false),
    );
  }

  String? _resolveDropdownValue(String value, List<String> allowed) {
    if (allowed.contains(value)) return value;
    if (allowed.isEmpty) return null;
    return allowed.first;
  }

  String? _extractEventType(String line) {
    final trimmed = line.trim();
    if (!trimmed.startsWith('{') || !trimmed.endsWith('}')) {
      return null;
    }

    try {
      final decoded = jsonDecode(trimmed);
      if (decoded is Map<String, dynamic>) {
        final type = decoded['type'];
        if (type is String && type.isNotEmpty) {
          return type;
        }
      }
    } catch (_) {
      return null;
    }

    return null;
  }

  String _previewText(String value, {required int maxChars}) {
    if (value.length <= maxChars) {
      return value;
    }
    return '${value.substring(0, maxChars)}...';
  }

  bool get _canWriteBackScriptResult =>
      widget.workspaceScriptWritebackCandidate?.trim().isNotEmpty == true ||
      widget.workspaceAssistantText.trim().isNotEmpty;

  String? get _scriptWritebackSourceLine {
    final source = widget.workspaceScriptWritebackSource?.trim();
    if (source != null && source.isNotEmpty) return source;
    if (widget.workspaceAssistantText.trim().isNotEmpty) {
      return 'assistant stream';
    }
    return null;
  }
}

class _PromptPreset {
  const _PromptPreset({required this.label, required this.prompt});

  final String label;
  final String prompt;
}
