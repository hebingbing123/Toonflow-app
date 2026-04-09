import 'package:flutter/material.dart';

import 'agent_workspaces_section_script.dart';

class AgentWorkspaceProductionCard extends StatelessWidget {
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

  String? _resolveDropdownValue(String value, List<String> allowed) {
    if (allowed.contains(value)) return value;
    if (allowed.isEmpty) return null;
    return allowed.first;
  }

  Widget _buildPromptTemplates() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: productionPromptPresets
          .map(
            (AgentWorkspacePromptPreset preset) => ActionChip(
              label: Text(preset.label),
              onPressed: busy ? null : () => onSelectPrompt(preset.prompt),
            ),
          )
          .toList(growable: false),
    );
  }

  String? get _suggestedFlowKeyLine {
    final key = workspaceSuggestedFlowKey?.trim();
    if (key == null || key.isEmpty) return null;
    return key;
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
            _buildPromptTemplates(),
            const SizedBox(height: 8),
            TextField(
              controller: productionPromptController,
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
                  onPressed: busy ? null : onRunProductionWorkspace,
                  child: Text(
                    loadingProductionWorkspaceRun ? '…' : 'Run production',
                  ),
                ),
                SizedBox(
                  width: 260,
                  child: DropdownButtonFormField<String>(
                    isExpanded: true,
                    initialValue: _resolveDropdownValue(
                      productionDomainToolController.text.trim(),
                      productionDomainToolPresets,
                    ),
                    items: productionDomainToolPresets
                        .map(
                          (String tool) => DropdownMenuItem<String>(
                            value: tool,
                            child: Text(tool),
                          ),
                        )
                        .toList(growable: false),
                    onChanged: busy
                        ? null
                        : (String? value) {
                            if (value == null) return;
                            onProductionDomainToolChanged(value);
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
                      flowKeyController.text.trim(),
                      flowKeyPresets,
                    ),
                    items: flowKeyPresets
                        .map(
                          (String key) => DropdownMenuItem<String>(
                            value: key,
                            child: Text(key),
                          ),
                        )
                        .toList(growable: false),
                    onChanged: busy
                        ? null
                        : (String? value) {
                            if (value == null) return;
                            onFlowKeyChanged(value);
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
                    controller: productionDomainArgsController,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'production tool arguments(JSON)',
                      helperText: '非 get_flowData 时使用，例如 {"ids":[1,2]}',
                    ),
                  ),
                ),
                FilledButton.tonal(
                  onPressed: busy ? null : onProbeProductionDomainTool,
                  child: Text(
                    loadingProductionFlowProbe ? '…' : 'Probe production tool',
                  ),
                ),
                SizedBox(
                  width: 300,
                  child: DropdownButtonFormField<String>(
                    isExpanded: true,
                    initialValue: _resolveDropdownValue(
                      productionSubAgentToolController.text.trim(),
                      productionSubAgentPresets,
                    ),
                    items: productionSubAgentPresets
                        .map(
                          (String tool) => DropdownMenuItem<String>(
                            value: tool,
                            child: Text(tool),
                          ),
                        )
                        .toList(growable: false),
                    onChanged: busy
                        ? null
                        : (String? value) {
                            if (value == null) return;
                            onProductionSubAgentChanged(value);
                          },
                    decoration: const InputDecoration(
                      labelText: 'production sub-agent tool',
                    ),
                  ),
                ),
                FilledButton.tonal(
                  onPressed: busy ? null : onRunProductionSubAgentTool,
                  child: Text(
                    loadingProductionSubAgentRun ? '…' : 'Run sub-agent',
                  ),
                ),
                FilledButton(
                  onPressed: busy || workspaceLastToolResultLine == null
                      ? null
                      : onWriteBackProductionFlowResult,
                  child: Text(
                    loadingProductionResultWriteback ? '…' : 'Write tool result',
                  ),
                ),
              ],
            ),
            if (workspaceLastToolResultLine != null) ...<Widget>[
              const SizedBox(height: 8),
              Text(
                'Latest tool result: $workspaceLastToolResultLine',
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
                    onPressed: busy ? null : onApplySuggestedFlowKey,
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
