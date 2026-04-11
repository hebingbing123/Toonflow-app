import 'package:flutter/material.dart';

import '../../panels/script.dart';
import 'support.dart';

class ProductionWorkspaceArgumentTemplateEntry {
  const ProductionWorkspaceArgumentTemplateEntry({
    required this.label,
    required this.payload,
  });

  final String label;
  final Map<String, dynamic> payload;
}

/// Displays reusable production prompt presets above the control surface.
class ProductionWorkspacePromptTemplatesPanel extends StatelessWidget {
  const ProductionWorkspacePromptTemplatesPanel({
    super.key,
    required this.busy,
    required this.presets,
    required this.onSelectPrompt,
  });

  final bool busy;
  final List<AgentWorkspacePromptPreset> presets;
  final ValueChanged<String> onSelectPrompt;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: presets
          .map(
            (AgentWorkspacePromptPreset preset) => ActionChip(
              label: Text(preset.label),
              onPressed: busy ? null : () => onSelectPrompt(preset.prompt),
            ),
          )
          .toList(growable: false),
    );
  }
}

/// Owns the prompt input and tool/sub-agent controls for production flow work.
class ProductionWorkspaceControlsPanel extends StatelessWidget {
  const ProductionWorkspaceControlsPanel({
    super.key,
    required this.busy,
    required this.loadingProductionWorkspaceRun,
    required this.loadingProductionFlowProbe,
    required this.loadingProductionSubAgentRun,
    required this.loadingProductionResultWriteback,
    required this.hasLastToolResult,
    required this.productionPromptController,
    required this.productionDomainArgsController,
    required this.productionDomainToolPresets,
    required this.productionSubAgentPresets,
    required this.flowKeyPresets,
    required this.selectedProductionDomainTool,
    required this.selectedProductionSubAgentTool,
    required this.selectedFlowKey,
    required this.onRunProductionWorkspace,
    required this.onProductionDomainToolChanged,
    required this.onFlowKeyChanged,
    required this.onProbeProductionDomainTool,
    required this.onProductionSubAgentChanged,
    required this.onRunProductionSubAgentTool,
    required this.onWriteBackProductionFlowResult,
    this.argumentTemplates,
    this.actionCandidatePanel,
  });

  final bool busy;
  final bool loadingProductionWorkspaceRun;
  final bool loadingProductionFlowProbe;
  final bool loadingProductionSubAgentRun;
  final bool loadingProductionResultWriteback;
  final bool hasLastToolResult;
  final TextEditingController productionPromptController;
  final TextEditingController productionDomainArgsController;
  final List<String> productionDomainToolPresets;
  final List<String> productionSubAgentPresets;
  final List<String> flowKeyPresets;
  final String? selectedProductionDomainTool;
  final String? selectedProductionSubAgentTool;
  final String? selectedFlowKey;
  final VoidCallback onRunProductionWorkspace;
  final ValueChanged<String> onProductionDomainToolChanged;
  final ValueChanged<String> onFlowKeyChanged;
  final VoidCallback onProbeProductionDomainTool;
  final ValueChanged<String> onProductionSubAgentChanged;
  final VoidCallback onRunProductionSubAgentTool;
  final VoidCallback onWriteBackProductionFlowResult;
  final Widget? argumentTemplates;
  final Widget? actionCandidatePanel;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        TextField(
          controller: productionPromptController,
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
              onPressed: busy ? null : onRunProductionWorkspace,
              child: Text(loadingProductionWorkspaceRun ? '…' : '运行制作工作流'),
            ),
            SizedBox(
              width: 260,
              child: DropdownButtonFormField<String>(
                isExpanded: true,
                initialValue: selectedProductionDomainTool,
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
                decoration: const InputDecoration(labelText: '制作域工具'),
              ),
            ),
            SizedBox(
              width: 220,
              child: DropdownButtonFormField<String>(
                isExpanded: true,
                initialValue: selectedFlowKey,
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
                  labelText: '制作工具参数(JSON)',
                  helperText: '非 get_flowData 时使用，例如 {"ids":[1,2]}',
                ),
              ),
            ),
            if (argumentTemplates != null)
              SizedBox(width: 360, child: argumentTemplates!),
            if (actionCandidatePanel != null)
              SizedBox(width: 360, child: actionCandidatePanel!),
            FilledButton.tonal(
              onPressed: busy ? null : onProbeProductionDomainTool,
              child: Text(loadingProductionFlowProbe ? '…' : '读取制作工具'),
            ),
            SizedBox(
              width: 300,
              child: DropdownButtonFormField<String>(
                isExpanded: true,
                initialValue: selectedProductionSubAgentTool,
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
                decoration: const InputDecoration(labelText: '制作子代理工具'),
              ),
            ),
            FilledButton.tonal(
              onPressed: busy ? null : onRunProductionSubAgentTool,
              child: Text(loadingProductionSubAgentRun ? '…' : '运行子代理'),
            ),
            FilledButton(
              onPressed: busy || !hasLastToolResult
                  ? null
                  : onWriteBackProductionFlowResult,
              child: Text(loadingProductionResultWriteback ? '…' : '写回工具结果'),
            ),
          ],
        ),
      ],
    );
  }
}

/// Displays canned argument templates for the current production tool.
class ProductionWorkspaceArgumentTemplatesPanel extends StatelessWidget {
  const ProductionWorkspaceArgumentTemplatesPanel({
    super.key,
    required this.busy,
    required this.templates,
    required this.onApplyTemplate,
  });

  final bool busy;
  final List<ProductionWorkspaceArgumentTemplateEntry> templates;
  final void Function(Map<String, dynamic> payload, String label) onApplyTemplate;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text('参数模板', style: Theme.of(context).textTheme.labelMedium),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: templates
              .map(
                (ProductionWorkspaceArgumentTemplateEntry entry) => ActionChip(
                  label: Text(entry.label),
                  onPressed: busy
                      ? null
                      : () => onApplyTemplate(entry.payload, entry.label),
                ),
              )
              .toList(growable: false),
        ),
      ],
    );
  }
}

/// Shows inferred flow-based candidate payloads for the selected production tool.
class ProductionWorkspaceActionCandidatesPanel extends StatelessWidget {
  const ProductionWorkspaceActionCandidatesPanel({
    super.key,
    required this.busy,
    required this.suggestions,
    required this.candidateIds,
    required this.onApplySuggestion,
  });

  final bool busy;
  final List<ProductionWorkspaceArgumentSuggestion> suggestions;
  final List<int> candidateIds;
  final ValueChanged<ProductionWorkspaceArgumentSuggestion> onApplySuggestion;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text('当前 flow 候选参数', style: Theme.of(context).textTheme.labelMedium),
        if (candidateIds.isNotEmpty) ...<Widget>[
          const SizedBox(height: 6),
          Text(
            '候选 ${candidateIds.length} 项：${candidateIds.take(8).join(", ")}${candidateIds.length > 8 ? "…" : ""}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: suggestions
              .map(
                (ProductionWorkspaceArgumentSuggestion suggestion) => ActionChip(
                  label: Text(suggestion.label),
                  onPressed: busy ? null : () => onApplySuggestion(suggestion),
                ),
              )
              .toList(growable: false),
        ),
      ],
    );
  }
}
