import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../prompt_preset.dart';
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
    required this.productionSubAgentArgsController,
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
  final TextEditingController productionSubAgentArgsController;
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
    final l10n = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        TextField(
          controller: productionPromptController,
          maxLines: 4,
          decoration: InputDecoration(
            labelText: l10n.agentWorkspaceProductionPromptLabel,
            helperText: l10n.agentWorkspaceProductionPromptHelper,
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
                loadingProductionWorkspaceRun
                    ? '…'
                    : l10n.agentWorkspaceProductionRunWorkflow,
              ),
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
                decoration: InputDecoration(
                  labelText: l10n.agentWorkspaceProductionDomainToolLabel,
                ),
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
                decoration: InputDecoration(
                  labelText: l10n.agentWorkspaceProductionFlowKeyLabel,
                  helperText: l10n.agentWorkspaceProductionFlowKeyHelper,
                ),
              ),
            ),
            SizedBox(
              width: 360,
              child: TextField(
                controller: productionDomainArgsController,
                maxLines: 2,
                decoration: InputDecoration(
                  labelText: l10n.agentWorkspaceProductionArgsLabel,
                  helperText: l10n.agentWorkspaceProductionArgsHelper,
                ),
              ),
            ),
            if (argumentTemplates != null)
              SizedBox(width: 360, child: argumentTemplates!),
            if (actionCandidatePanel != null)
              SizedBox(width: 360, child: actionCandidatePanel!),
            FilledButton.tonal(
              onPressed: busy ? null : onProbeProductionDomainTool,
              child: Text(
                loadingProductionFlowProbe
                    ? '…'
                    : l10n.agentWorkspaceProductionReadTool,
              ),
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
                decoration: InputDecoration(
                  labelText: l10n.agentWorkspaceProductionSubAgentToolLabel,
                ),
              ),
            ),
            SizedBox(
              width: 360,
              child: TextField(
                controller: productionSubAgentArgsController,
                maxLines: 2,
                decoration: InputDecoration(
                  labelText: l10n.agentWorkspaceProductionSubAgentArgsLabel,
                  helperText: l10n.agentWorkspaceProductionSubAgentArgsHelper,
                ),
              ),
            ),
            FilledButton.tonal(
              onPressed: busy ? null : onRunProductionSubAgentTool,
              child: Text(
                loadingProductionSubAgentRun
                    ? '…'
                    : l10n.agentWorkspaceProductionRunSubAgent,
              ),
            ),
            FilledButton(
              onPressed: busy || !hasLastToolResult
                  ? null
                  : onWriteBackProductionFlowResult,
              child: Text(
                loadingProductionResultWriteback
                    ? '…'
                    : l10n.agentWorkspaceProductionWritebackToolResult,
              ),
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
  final void Function(Map<String, dynamic> payload, String label)
  onApplyTemplate;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          l10n.agentWorkspaceProductionArgumentTemplates,
          style: Theme.of(context).textTheme.labelMedium,
        ),
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

/// Shows inferred candidate payloads for the selected production tool.
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
    final l10n = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          l10n.agentWorkspaceProductionCurrentCandidateArgs,
          style: Theme.of(context).textTheme.labelMedium,
        ),
        if (candidateIds.isNotEmpty) ...<Widget>[
          const SizedBox(height: 6),
          Text(
            l10n.agentWorkspaceProductionCandidateIds(
              candidateIds.length,
              [
                candidateIds.take(8).join(', '),
                if (candidateIds.length > 8) '…',
              ].join(),
            ),
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: suggestions
              .map(
                (ProductionWorkspaceArgumentSuggestion suggestion) =>
                    ActionChip(
                      label: Text(suggestion.label),
                      onPressed: busy
                          ? null
                          : () => onApplySuggestion(suggestion),
                    ),
              )
              .toList(growable: false),
        ),
      ],
    );
  }
}
