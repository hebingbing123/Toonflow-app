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
    this.workspaceLastToolName,
    this.workspaceLastToolResultData,
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
  final String? workspaceLastToolName;
  final Object? workspaceLastToolResultData;
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
              onPressed: widget.busy
                  ? null
                  : () => widget.onSelectPrompt(preset.prompt),
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
    if (widget.loadingProductionWorkspaceRun) return '执行中：运行制作工作流';
    if (widget.loadingProductionFlowProbe) return '执行中：读取制作工具结果';
    if (widget.loadingProductionSubAgentRun) return '执行中：运行子代理';
    if (widget.loadingProductionResultWriteback) return '执行中：写回工具结果';
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
      _setTaskStatus('拦截：制作工具参数必须是 JSON object。');
      return false;
    } catch (_) {
      _setTaskStatus('拦截：制作工具参数 JSON 解析失败。');
      return false;
    }
  }

  bool _validatePrompt(String action) {
    if (widget.productionPromptController.text.trim().isNotEmpty) return true;
    _setTaskStatus('拦截：$action 需要非空工作区提示词。');
    return false;
  }

  bool _validateFlowProbe() {
    final tool = widget.productionDomainToolController.text.trim();
    if (tool.isEmpty) {
      _setTaskStatus('拦截：读取前需要选择制作域工具。');
      return false;
    }
    if (!_validateJsonArgs(widget.productionDomainArgsController.text)) {
      return false;
    }
    if (tool == 'get_flowData' &&
        widget.flowKeyController.text.trim().isEmpty) {
      _setTaskStatus('拦截：get_flowData 需要有效 flow key。');
      return false;
    }
    return true;
  }

  bool _normalizeArgsForProbe() {
    final tool = widget.productionDomainToolController.text.trim();
    final raw = widget.productionDomainArgsController.text.trim();
    if (raw.isEmpty) {
      widget.productionDomainArgsController.text = '{}';
    }
    final decoded = jsonDecode(
      widget.productionDomainArgsController.text.trim(),
    );
    if (decoded is! Map<String, dynamic>) {
      _setTaskStatus('拦截：制作工具参数必须是 JSON object。');
      return false;
    }
    if (tool != 'get_flowData') {
      return true;
    }
    final key = widget.flowKeyController.text.trim();
    final normalized = Map<String, dynamic>.from(decoded);
    if (normalized['key'] == key) {
      return true;
    }
    normalized['key'] = key;
    widget.productionDomainArgsController.text = jsonEncode(normalized);
    _setTaskStatus('已同步：get_flowData arguments.key -> $key');
    return true;
  }

  bool _validateSubAgentTool() {
    if (widget.productionSubAgentToolController.text.trim().isEmpty) {
      _setTaskStatus('拦截：运行子代理前需要选择制作子代理工具。');
      return false;
    }
    return _validatePrompt('运行子代理');
  }

  void _runProductionWorkspace() {
    if (!_validatePrompt('运行制作工作流')) return;
    widget.onRunProductionWorkspace();
    _setTaskStatus('已触发：运行制作工作流');
  }

  void _probeProductionDomainTool() {
    if (!_validateFlowProbe()) return;
    if (!_normalizeArgsForProbe()) return;
    widget.onProbeProductionDomainTool();
    final tool = widget.productionDomainToolController.text.trim();
    final key = widget.flowKeyController.text.trim();
    final suffix = tool == 'get_flowData' ? ' key=$key' : '';
    _setTaskStatus('已触发：读取制作工具 ($tool$suffix)');
  }

  void _runProductionSubAgentTool() {
    if (!_validateSubAgentTool()) return;
    widget.onRunProductionSubAgentTool();
    final tool = widget.productionSubAgentToolController.text.trim();
    _setTaskStatus('已触发：运行子代理 ($tool)');
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
    _setTaskStatus('已触发：写回工具结果 -> flow[$key]');
  }

  void _applyProductionPromptIfEmpty(String prompt) {
    if (widget.productionPromptController.text.trim().isNotEmpty) return;
    widget.productionPromptController.text = prompt;
  }

  String get _selectedProductionTool =>
      widget.productionDomainToolController.text.trim();

  Map<String, dynamic> _flowDataArgsTemplate() {
    final flowKey = widget.flowKeyController.text.trim();
    return <String, dynamic>{'key': flowKey.isEmpty ? 'assets' : flowKey};
  }

  List<({String label, Map<String, dynamic> args})> _argumentTemplates() {
    switch (_selectedProductionTool) {
      case 'get_flowData':
        return <({String label, Map<String, dynamic> args})>[
          (label: '模板: 仅 key', args: _flowDataArgsTemplate()),
          (label: '模板: 默认 assets', args: <String, dynamic>{'key': 'assets'}),
        ];
      case 'add_deriveAsset':
      case 'del_deriveAsset':
      case 'generate_deriveAsset':
        return <({String label, Map<String, dynamic> args})>[
          (
            label: '模板: ID 列表',
            args: <String, dynamic>{
              'ids': <int>[1],
            },
          ),
        ];
      case 'generate_storyboard':
        return <({String label, Map<String, dynamic> args})>[
          (
            label: '模板: 分镜 ID',
            args: <String, dynamic>{
              'ids': <int>[1],
            },
          ),
        ];
      default:
        return const <({String label, Map<String, dynamic> args})>[];
    }
  }

  void _applyToolArgsTemplate(Map<String, dynamic> args, String label) {
    widget.productionDomainArgsController.text = jsonEncode(args);
    _setTaskStatus('已填充参数模板：$label');
  }

  Widget _buildArgumentTemplates() {
    final templates = _argumentTemplates();
    if (templates.isEmpty) return const SizedBox.shrink();
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

  List<String> _buildResultSummaryLines() {
    final result = widget.workspaceLastToolResultData;
    final toolName = widget.workspaceLastToolName?.trim();
    if (result == null) {
      if (toolName == null || toolName.isEmpty) return const <String>[];
      return <String>['tool=$toolName', 'result=空'];
    }
    final lines = <String>[
      if (toolName != null && toolName.isNotEmpty) 'tool=$toolName',
      'resultType=${result.runtimeType}',
    ];
    if (result is Map<String, dynamic>) {
      lines.add('keys=${result.keys.join(',')}');
      final data = result['data'];
      if (data is Map<String, dynamic>) {
        lines.add('dataKeys=${data.keys.join(',')}');
        final storyboard = data['storyboard'];
        if (storyboard is List) {
          lines.add('storyboard.count=${storyboard.length}');
        }
        final assets = data['assets'];
        if (assets is List) {
          lines.add('assets.count=${assets.length}');
        }
      }
      final items = result['items'];
      if (items is List) {
        lines.add('items.count=${items.length}');
      }
      final text = result['result'];
      if (text is String) {
        lines.add('result.chars=${text.length}');
      }
    } else if (result is List) {
      lines.add('items=${result.length}');
    } else if (result is String) {
      lines.add('text.chars=${result.length}');
    }
    return lines.take(6).toList(growable: false);
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
        FilledButton.tonal(
          onPressed: widget.busy
              ? null
              : () {
                  widget.onFlowKeyChanged('storyboard');
                  _applyProductionPromptIfEmpty(
                    '请基于当前分镜 flow 输出下一轮分镜生成计划，并执行最小可行生成动作。',
                  );
                  widget.onProductionSubAgentChanged(
                    'run_sub_agent_storyboard_gen',
                  );
                  _runProductionSubAgentTool();
                },
          child: const Text('5) 运行分镜子代理'),
        ),
        FilledButton.tonal(
          onPressed: widget.busy
              ? null
              : () {
                  widget.onFlowKeyChanged('scriptPlan');
                  _applyProductionPromptIfEmpty(
                    '请结合 scriptPlan 与现有素材状态，产出下一轮导演计划并给出执行优先级。',
                  );
                  widget.onProductionSubAgentChanged(
                    'run_sub_agent_director_plan',
                  );
                  _runProductionSubAgentTool();
                },
          child: const Text('6) 运行导演计划子代理'),
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
            Text('制作工作区', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text('引导任务', style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 6),
            _buildGuidedTasks(),
            const SizedBox(height: 10),
            _buildPromptTemplates(),
            const SizedBox(height: 8),
            TextField(
              controller: widget.productionPromptController,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: '工作区提示词',
                helperText: '用于制作通道 harness.agent.run',
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
                    widget.loadingProductionWorkspaceRun ? '…' : '运行制作工作流',
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
                    decoration: const InputDecoration(labelText: '制作域工具'),
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
                      labelText: '制作工具参数(JSON)',
                      helperText: '非 get_flowData 时使用，例如 {"ids":[1,2]}',
                    ),
                  ),
                ),
                if (_argumentTemplates().isNotEmpty)
                  SizedBox(
                    width: 360,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          '参数模板',
                          style: Theme.of(context).textTheme.labelMedium,
                        ),
                        const SizedBox(height: 6),
                        _buildArgumentTemplates(),
                      ],
                    ),
                  ),
                FilledButton.tonal(
                  onPressed: widget.busy ? null : _probeProductionDomainTool,
                  child: Text(
                    widget.loadingProductionFlowProbe ? '…' : '读取制作工具',
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
                    decoration: const InputDecoration(labelText: '制作子代理工具'),
                  ),
                ),
                FilledButton.tonal(
                  onPressed: widget.busy ? null : _runProductionSubAgentTool,
                  child: Text(
                    widget.loadingProductionSubAgentRun ? '…' : '运行子代理',
                  ),
                ),
                FilledButton(
                  onPressed:
                      widget.busy || widget.workspaceLastToolResultLine == null
                      ? null
                      : _writeBackProductionFlowResult,
                  child: Text(
                    widget.loadingProductionResultWriteback ? '…' : '写回工具结果',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              _runningTaskLine ?? _taskStatusLine ?? '等待执行：可直接用引导任务或表单按钮。',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            if (widget.workspaceLastToolResultLine != null) ...<Widget>[
              const SizedBox(height: 8),
              Text(
                '最新工具结果：${widget.workspaceLastToolResultLine}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            if (_buildResultSummaryLines().isNotEmpty) ...<Widget>[
              const SizedBox(height: 8),
              Text('结果摘要', style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: 4),
              ..._buildResultSummaryLines().map(
                (String line) =>
                    Text(line, style: Theme.of(context).textTheme.bodySmall),
              ),
            ],
            if (_suggestedFlowKeyLine != null) ...<Widget>[
              const SizedBox(height: 8),
              Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      '建议写回 key：$_suggestedFlowKeyLine',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton(
                    onPressed: widget.busy
                        ? null
                        : widget.onApplySuggestedFlowKey,
                    child: const Text('使用该 key'),
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
