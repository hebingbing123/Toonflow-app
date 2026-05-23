import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:openflow_app/design_system/components/studio_dropdown_field.dart';

import '../../../rust_api.dart';
import '../../agent_workspace_preset_labels.dart';
import '../../controls.dart';
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

const double _kAgentFormFieldMaxWidth = 560;

Widget _constrainedAgentField(BuildContext context, Widget field) {
  return Align(
    alignment: Alignment.centerLeft,
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: _kAgentFormFieldMaxWidth),
      child: SizedBox(width: double.infinity, child: field),
    ),
  );
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
    final l10n = resolveAppLocalizationsForErrors(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _constrainedAgentField(
          context,
          TextField(
            controller: productionPromptController,
            maxLines: 4,
            decoration: agentWorkspaceFieldDecoration(
              context,
              labelText: l10n.agentWorkspaceProductionPromptLabel,
              helperText: l10n.agentWorkspaceProductionPromptHelper,
            ),
          ),
        ),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            final narrow = constraints.maxWidth < 720;
            final fieldWidth = math.min(
              constraints.maxWidth,
              _kAgentFormFieldMaxWidth,
            );

            Widget domainToolDropdown() {
              return SizedBox(
                width: narrow ? double.infinity : fieldWidth,
                child: StudioDropdownButtonFormField<String>(
                  isExpanded: true,
                  initialValue: selectedProductionDomainTool,
                  items: productionDomainToolPresets
                      .map(
                        (String tool) => DropdownMenuItem<String>(
                          value: tool,
                          child: Text(
                            agentWorkspaceProductionDomainToolLabel(l10n, tool),
                          ),
                        ),
                      )
                      .toList(growable: false),
                  onChanged: busy
                      ? null
                      : (String? value) {
                          if (value == null) return;
                          onProductionDomainToolChanged(value);
                        },
                  decoration: agentWorkspaceFieldDecoration(
                    context,
                    labelText: l10n.agentWorkspaceProductionDomainToolLabel,
                  ),
                ),
              );
            }

            Widget flowKeyDropdown() {
              return SizedBox(
                width: narrow ? double.infinity : fieldWidth,
                child: StudioDropdownButtonFormField<String>(
                  isExpanded: true,
                  initialValue: selectedFlowKey,
                  items: flowKeyPresets
                      .map(
                        (String key) => DropdownMenuItem<String>(
                          value: key,
                          child: Text(agentWorkspaceFlowKeyLabel(l10n, key)),
                        ),
                      )
                      .toList(growable: false),
                  onChanged: busy
                      ? null
                      : (String? value) {
                          if (value == null) return;
                          onFlowKeyChanged(value);
                        },
                  decoration: agentWorkspaceFieldDecoration(
                    context,
                    labelText: l10n.agentWorkspaceProductionFlowKeyLabel,
                    helperText: l10n.agentWorkspaceProductionFlowKeyHelper,
                  ),
                ),
              );
            }

            Widget domainArgsField() {
              return SizedBox(
                width: narrow ? double.infinity : fieldWidth,
                child: TextField(
                  controller: productionDomainArgsController,
                  maxLines: 2,
                  decoration: agentWorkspaceFieldDecoration(
                    context,
                    labelText: l10n.agentWorkspaceProductionArgsLabel,
                    helperText: l10n.agentWorkspaceProductionArgsHelper,
                  ),
                ),
              );
            }

            Widget subAgentDropdown() {
              return SizedBox(
                width: narrow ? double.infinity : fieldWidth,
                child: StudioDropdownButtonFormField<String>(
                  isExpanded: true,
                  initialValue: selectedProductionSubAgentTool,
                  items: productionSubAgentPresets
                      .map(
                        (String tool) => DropdownMenuItem<String>(
                          value: tool,
                          child: Text(
                            agentWorkspaceProductionSubAgentLabel(l10n, tool),
                          ),
                        ),
                      )
                      .toList(growable: false),
                  onChanged: busy
                      ? null
                      : (String? value) {
                          if (value == null) return;
                          onProductionSubAgentChanged(value);
                        },
                  decoration: agentWorkspaceFieldDecoration(
                    context,
                    labelText: l10n.agentWorkspaceProductionSubAgentToolLabel,
                  ),
                ),
              );
            }

            Widget subAgentArgsField() {
              return SizedBox(
                width: narrow ? double.infinity : fieldWidth,
                child: TextField(
                  controller: productionSubAgentArgsController,
                  maxLines: 2,
                  decoration: agentWorkspaceFieldDecoration(
                    context,
                    labelText: l10n.agentWorkspaceProductionSubAgentArgsLabel,
                    helperText:
                        l10n.agentWorkspaceProductionSubAgentArgsHelper,
                  ),
                ),
              );
            }

            final workflowButton = FilledButton.tonal(
              onPressed: busy ? null : onRunProductionWorkspace,
              child: Text(
                loadingProductionWorkspaceRun
                    ? '…'
                    : l10n.agentWorkspaceProductionRunWorkflow,
              ),
            );
            final probeButton = FilledButton.tonal(
              onPressed: busy ? null : onProbeProductionDomainTool,
              child: Text(
                loadingProductionFlowProbe
                    ? '…'
                    : l10n.agentWorkspaceProductionReadTool,
              ),
            );
            final subAgentButton = FilledButton.tonal(
              onPressed: busy ? null : onRunProductionSubAgentTool,
              child: Text(
                loadingProductionSubAgentRun
                    ? '…'
                    : l10n.agentWorkspaceProductionRunSubAgent,
              ),
            );
            final writebackButton = FilledButton(
              onPressed: busy || !hasLastToolResult
                  ? null
                  : onWriteBackProductionFlowResult,
              child: Text(
                loadingProductionResultWriteback
                    ? '…'
                    : l10n.agentWorkspaceProductionWritebackToolResult,
              ),
            );

            if (narrow) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  workflowButton,
                  const SizedBox(height: 8),
                  domainToolDropdown(),
                  const SizedBox(height: 8),
                  flowKeyDropdown(),
                  const SizedBox(height: 8),
                  domainArgsField(),
                  if (argumentTemplates != null) ...<Widget>[
                    const SizedBox(height: 8),
                    argumentTemplates!,
                  ],
                  if (actionCandidatePanel != null) ...<Widget>[
                    const SizedBox(height: 8),
                    actionCandidatePanel!,
                  ],
                  const SizedBox(height: 8),
                  probeButton,
                  const SizedBox(height: 8),
                  subAgentDropdown(),
                  const SizedBox(height: 8),
                  subAgentArgsField(),
                  const SizedBox(height: 8),
                  subAgentButton,
                  const SizedBox(height: 8),
                  writebackButton,
                ],
              );
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: <Widget>[
                    workflowButton,
                    domainToolDropdown(),
                    flowKeyDropdown(),
                    probeButton,
                    subAgentButton,
                    writebackButton,
                  ],
                ),
                const SizedBox(height: 8),
                domainArgsField(),
                if (argumentTemplates != null) ...<Widget>[
                  const SizedBox(height: 8),
                  argumentTemplates!,
                ],
                if (actionCandidatePanel != null) ...<Widget>[
                  const SizedBox(height: 8),
                  actionCandidatePanel!,
                ],
                const SizedBox(height: 8),
                subAgentDropdown(),
                const SizedBox(height: 8),
                subAgentArgsField(),
              ],
            );
          },
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
    final l10n = resolveAppLocalizationsForErrors(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          l10n.agentWorkspaceProductionArgumentTemplates,
          style: Theme.of(context).textTheme.labelMedium,
        ),
        const SizedBox(height: StudioSpacing.xs),
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
    final l10n = resolveAppLocalizationsForErrors(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          l10n.agentWorkspaceProductionCurrentCandidateArgs,
          style: Theme.of(context).textTheme.labelMedium,
        ),
        if (candidateIds.isNotEmpty) ...<Widget>[
          const SizedBox(height: StudioSpacing.xs),
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
        const SizedBox(height: StudioSpacing.xs),
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
