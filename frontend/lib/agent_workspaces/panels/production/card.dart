import 'dart:convert';

import 'package:flutter/material.dart';

import '../../../design_system/tokens.dart';
import '../../../l10n/app_localizations.dart';
import '../../../rust_api.dart';
import '../../panel_support.dart';
import '../../prompt_preset.dart';
import '../../contexts/production/action_panels.dart';
import '../../contexts/production/card_panels.dart';
import '../../contexts/production/context_snapshot.dart';
import '../../contexts/production/flow_logic.dart';
import '../../contexts/production/status_panels.dart';
import '../../contexts/production/support.dart';

part 'card_support.dart';
part 'card_logic.dart';
part 'card_logic_templates.dart';
part 'card_logic_workflow.dart';

typedef ApplyProductionWorkspaceFocus =
    void Function({
      String? flowKey,
      String? domainTool,
      Map<String, dynamic>? domainArgs,
      String? subAgentTool,
      Map<String, dynamic>? subAgentArgs,
      String? prompt,
    });

class AgentWorkspaceProductionCard extends StatefulWidget {
  const AgentWorkspaceProductionCard({
    super.key,
    required this.busy,
    required this.productionPromptController,
    required this.productionDomainToolController,
    required this.productionDomainArgsController,
    required this.productionSubAgentArgsController,
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
    this.workspaceLastToolArguments,
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
    required this.onApplyProductionFocus,
  });

  final bool busy;
  final TextEditingController productionPromptController;
  final TextEditingController productionDomainToolController;
  final TextEditingController productionDomainArgsController;
  final TextEditingController productionSubAgentArgsController;
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
  final Map<String, dynamic>? workspaceLastToolArguments;
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
  final ApplyProductionWorkspaceFocus onApplyProductionFocus;

  @override
  State<AgentWorkspaceProductionCard> createState() =>
      _AgentWorkspaceProductionCardState();
}

class _AgentWorkspaceProductionCardState
    extends State<AgentWorkspaceProductionCard> {
  String? _taskStatusLine;

  void _setTaskStatus(String message) {
    if (!mounted) return;
    setState(() => _taskStatusLine = message);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = resolveAppLocalizationsForErrors(context);
    final resultSummaryLines = _buildResultSummaryLines();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(StudioLayoutSpacing.cardInner - 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              l10n.agentWorkspaceProductionCardTitle,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              l10n.agentWorkspaceGuidedTasksTitle,
              style: Theme.of(context).textTheme.labelLarge,
            ),
            const SizedBox(height: 6),
            _buildGuidedTasks(),
            const SizedBox(height: StudioLayoutSpacing.inlineGap),
            _buildPromptTemplates(),
            const SizedBox(height: 8),
            ProductionWorkspaceControlsPanel(
              busy: widget.busy,
              loadingProductionWorkspaceRun:
                  widget.loadingProductionWorkspaceRun,
              loadingProductionFlowProbe: widget.loadingProductionFlowProbe,
              loadingProductionSubAgentRun: widget.loadingProductionSubAgentRun,
              loadingProductionResultWriteback:
                  widget.loadingProductionResultWriteback,
              hasLastToolResult: widget.workspaceLastToolResultLine != null,
              productionPromptController: widget.productionPromptController,
              productionDomainArgsController:
                  widget.productionDomainArgsController,
              productionSubAgentArgsController:
                  widget.productionSubAgentArgsController,
              productionDomainToolPresets: widget.productionDomainToolPresets,
              productionSubAgentPresets: widget.productionSubAgentPresets,
              flowKeyPresets: widget.flowKeyPresets,
              selectedProductionDomainTool: resolveWorkspaceDropdownValue(
                widget.productionDomainToolController.text.trim(),
                widget.productionDomainToolPresets,
              ),
              selectedProductionSubAgentTool: resolveWorkspaceDropdownValue(
                widget.productionSubAgentToolController.text.trim(),
                widget.productionSubAgentPresets,
              ),
              selectedFlowKey: resolveWorkspaceDropdownValue(
                widget.flowKeyController.text.trim(),
                widget.flowKeyPresets,
              ),
              onRunProductionWorkspace: _runProductionWorkspace,
              onProductionDomainToolChanged:
                  widget.onProductionDomainToolChanged,
              onFlowKeyChanged: widget.onFlowKeyChanged,
              onProbeProductionDomainTool: _probeProductionDomainTool,
              onProductionSubAgentChanged: widget.onProductionSubAgentChanged,
              onRunProductionSubAgentTool: _runProductionSubAgentTool,
              onWriteBackProductionFlowResult: _writeBackProductionFlowResult,
              argumentTemplates: _argumentTemplates(l10n).isEmpty
                  ? null
                  : _buildArgumentTemplates(l10n),
              actionCandidatePanel: _buildActionSuggestions(l10n).isEmpty
                  ? null
                  : _buildActionCandidateTemplates(context, l10n),
            ),
            ProductionWorkspaceStatusPanel(
              resultSummaryLines: resultSummaryLines,
              onApplySuggestedFlowKey: widget.onApplySuggestedFlowKey,
              busy: widget.busy,
              runningTaskLine: _runningTaskLine,
              taskStatusLine: _taskStatusLine,
              workspaceLastToolResultLine: widget.workspaceLastToolResultLine,
              suggestedFlowKeyLine: _suggestedFlowKeyLine,
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
