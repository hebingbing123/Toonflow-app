import 'package:flutter/material.dart';
import '../../../design_system/components/studio_chip.dart';
import 'package:openflow_app/design_system/components/studio_dense_action_row.dart';
import 'package:openflow_app/design_system/components/studio_dropdown_field.dart';
import 'package:openflow_app/design_system/components/studio_surfaces.dart';

import '../../../rust_api.dart';
import '../../agent_workspace_preset_labels.dart';
import '../../controls.dart';
import '../../prompt_preset.dart';
import 'package:openflow_app/design_system/studio_responsive_layout.dart';
import 'package:openflow_app/design_system/tokens.dart';

class ScriptWorkspaceArgumentTemplateEntry {
  const ScriptWorkspaceArgumentTemplateEntry({
    required this.label,
    required this.args,
  });

  final String label;
  final String args;
}

/// Renders the guided step buttons for the script workspace happy path.
class ScriptWorkspaceGuidedTasksPanel extends StatelessWidget {
  const ScriptWorkspaceGuidedTasksPanel({
    super.key,
    required this.busy,
    required this.canWriteBackScriptResult,
    required this.onFetchPlanData,
    required this.onFetchScriptContent,
    required this.onGenerateDraft,
    required this.onWriteBackScript,
  });

  final bool busy;
  final bool canWriteBackScriptResult;
  final VoidCallback onFetchPlanData;
  final VoidCallback onFetchScriptContent;
  final VoidCallback onGenerateDraft;
  final VoidCallback onWriteBackScript;

  @override
  Widget build(BuildContext context) {
    final l10n = resolveAppLocalizationsForErrors(context);
    return StudioDenseActionRow(
      children: <Widget>[
        FilledButton.tonal(
          style: studioFormTonalButtonStyle(context),
          onPressed: busy ? null : onFetchPlanData,
          child: Text(l10n.agentWorkspaceScriptStepFetchPlanData),
        ),
        FilledButton.tonal(
          style: studioFormTonalButtonStyle(context),
          onPressed: busy ? null : onFetchScriptContent,
          child: Text(l10n.agentWorkspaceScriptStepFetchContent),
        ),
        FilledButton.tonal(
          style: studioFormTonalButtonStyle(context),
          onPressed: busy ? null : onGenerateDraft,
          child: Text(l10n.agentWorkspaceScriptStepGenerateDraft),
        ),
        OutlinedButton(
          style: studioFormSecondaryButtonStyle(context),
          onPressed: busy || !canWriteBackScriptResult
              ? null
              : onWriteBackScript,
          child: Text(l10n.agentWorkspaceScriptStepWriteback),
        ),
      ],
    );
  }
}

/// Displays reusable prompt presets so the card state stays focused on orchestration.
class ScriptWorkspacePromptTemplatesPanel extends StatelessWidget {
  const ScriptWorkspacePromptTemplatesPanel({
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
      spacing: StudioSpacing.xs,
      runSpacing: StudioSpacing.xs,
      children: presets
          .map(
            (AgentWorkspacePromptPreset preset) => StudioActionChip(
              label: Text(preset.label),
              onPressed: busy ? null : () => onSelectPrompt(preset.prompt),
            ),
          )
          .toList(growable: false),
    );
  }
}

/// Owns the prompt input and tool controls used to drive the script workspace.
class ScriptWorkspaceControlsPanel extends StatelessWidget {
  const ScriptWorkspaceControlsPanel({
    super.key,
    required this.busy,
    required this.loadingScriptWorkspaceRun,
    required this.loadingScriptDomainProbe,
    required this.loadingScriptSubAgentRun,
    required this.loadingScriptResultWriteback,
    required this.loadingScriptPlanResultWriteback,
    required this.canWriteBackScriptResult,
    required this.canWriteBackScriptPlanResult,
    required this.canWriteBackScriptPlanViaUpdateData,
    required this.scriptPromptController,
    required this.scriptDomainArgsController,
    required this.scriptDomainToolPresets,
    required this.scriptSubAgentPresets,
    required this.selectedScriptDomainTool,
    required this.selectedScriptSubAgentTool,
    required this.onRunScriptWorkspace,
    required this.onScriptDomainToolChanged,
    required this.onProbeScriptDomainTool,
    required this.onScriptSubAgentChanged,
    required this.onRunScriptSubAgentTool,
    required this.onWriteBackScriptResult,
    required this.onWriteBackScriptPlanResult,
    required this.onWriteBackScriptPlanViaUpdateData,
  });

  final bool busy;
  final bool loadingScriptWorkspaceRun;
  final bool loadingScriptDomainProbe;
  final bool loadingScriptSubAgentRun;
  final bool loadingScriptResultWriteback;
  final bool loadingScriptPlanResultWriteback;
  final bool canWriteBackScriptResult;
  final bool canWriteBackScriptPlanResult;
  final bool canWriteBackScriptPlanViaUpdateData;
  final TextEditingController scriptPromptController;
  final TextEditingController scriptDomainArgsController;
  final List<String> scriptDomainToolPresets;
  final List<String> scriptSubAgentPresets;
  final String? selectedScriptDomainTool;
  final String? selectedScriptSubAgentTool;
  final VoidCallback onRunScriptWorkspace;
  final ValueChanged<String> onScriptDomainToolChanged;
  final VoidCallback onProbeScriptDomainTool;
  final ValueChanged<String> onScriptSubAgentChanged;
  final VoidCallback onRunScriptSubAgentTool;
  final VoidCallback onWriteBackScriptResult;
  final VoidCallback onWriteBackScriptPlanResult;
  final VoidCallback onWriteBackScriptPlanViaUpdateData;

  @override
  Widget build(BuildContext context) {
    final l10n = resolveAppLocalizationsForErrors(context);
    final fieldStyle = agentWorkspaceFieldTextStyle(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        TextField(
          controller: scriptPromptController,
          maxLines: 4,
          style: fieldStyle,
          decoration: agentWorkspaceFieldDecoration(
            context,
            labelText: l10n.agentWorkspaceScriptPromptLabel,
            helperText: l10n.agentWorkspaceScriptPromptHelper,
          ),
        ),
        const SizedBox(height: StudioSpacing.xs),
        LayoutBuilder(
          builder: (context, constraints) {
            final toolWidth = studioWrapTileWidth(
              constraints.maxWidth,
              maxColumns: 2,
              minTileWidth: 200,
              maxTileWidth: StudioLayoutSize.fieldStandard,
            );
            final argsWidth = studioWrapTileWidth(
              constraints.maxWidth,
              maxColumns: 1,
              minTileWidth: 260,
              maxTileWidth: 420,
            );
            return StudioDenseActionRow(
          children: <Widget>[
            FilledButton.tonal(
              style: studioFormTonalButtonStyle(context),
              onPressed: busy ? null : onRunScriptWorkspace,
              child: Text(
                loadingScriptWorkspaceRun
                    ? '…'
                    : l10n.agentWorkspaceScriptRunWorkflow,
              ),
            ),
            SizedBox(
              width: toolWidth,
              child: StudioDropdownButtonFormField<String>(
                key: ValueKey<String?>(
                  'script-domain-tool-${selectedScriptDomainTool ?? ''}',
                ),
                isExpanded: true,
                initialValue: selectedScriptDomainTool,
                items: scriptDomainToolPresets
                    .map(
                      (String tool) => DropdownMenuItem<String>(
                        value: tool,
                        child: Text(
                          agentWorkspaceScriptDomainToolLabel(l10n, tool),
                          style: fieldStyle,
                        ),
                      ),
                    )
                    .toList(growable: false),
                onChanged: busy
                    ? null
                    : (String? value) {
                        if (value == null) return;
                        onScriptDomainToolChanged(value);
                      },
                decoration: agentWorkspaceFieldDecoration(
                  context,
                  labelText: l10n.agentWorkspaceScriptDomainToolLabel,
                ),
              ),
            ),
            FilledButton.tonal(
              style: studioFormTonalButtonStyle(context),
              onPressed: busy ? null : onProbeScriptDomainTool,
              child: Text(
                loadingScriptDomainProbe
                    ? '…'
                    : l10n.agentWorkspaceScriptReadContext,
              ),
            ),
            SizedBox(
              width: argsWidth,
              child: TextField(
                controller: scriptDomainArgsController,
                maxLines: 2,
                style: fieldStyle,
                decoration: agentWorkspaceFieldDecoration(
                  context,
                  labelText: l10n.agentWorkspaceScriptArgsLabel,
                  helperText: l10n.agentWorkspaceScriptArgsHelper,
                ),
              ),
            ),
            SizedBox(
              width: toolWidth,
              child: StudioDropdownButtonFormField<String>(
                isExpanded: true,
                initialValue: selectedScriptSubAgentTool,
                items: scriptSubAgentPresets
                    .map(
                      (String tool) => DropdownMenuItem<String>(
                        value: tool,
                        child: Text(
                          agentWorkspaceScriptSubAgentLabel(l10n, tool),
                          style: fieldStyle,
                        ),
                      ),
                    )
                    .toList(growable: false),
                onChanged: busy
                    ? null
                    : (String? value) {
                        if (value == null) return;
                        onScriptSubAgentChanged(value);
                      },
                decoration: agentWorkspaceFieldDecoration(
                  context,
                  labelText: l10n.agentWorkspaceScriptSubAgentToolLabel,
                ),
              ),
            ),
            FilledButton.tonal(
              style: studioFormTonalButtonStyle(context),
              onPressed: busy ? null : onRunScriptSubAgentTool,
              child: Text(
                loadingScriptSubAgentRun
                    ? '…'
                    : l10n.agentWorkspaceScriptRunSubAgent,
              ),
            ),
            FilledButton(
              style: studioFormPrimaryButtonStyle(context),
              onPressed: busy || !canWriteBackScriptResult
                  ? null
                  : onWriteBackScriptResult,
              child: Text(
                loadingScriptResultWriteback
                    ? '…'
                    : l10n.agentWorkspaceScriptStepWriteback,
              ),
            ),
            FilledButton.tonal(
              style: studioFormTonalButtonStyle(context),
              onPressed: busy || !canWriteBackScriptPlanResult
                  ? null
                  : onWriteBackScriptPlanResult,
              child: Text(
                loadingScriptPlanResultWriteback
                    ? '…'
                    : l10n.agentWorkspaceScriptWritebackPlanData,
              ),
            ),
            OutlinedButton(
              style: studioFormSecondaryButtonStyle(context),
              onPressed: busy || !canWriteBackScriptPlanViaUpdateData
                  ? null
                  : onWriteBackScriptPlanViaUpdateData,
              child: Text(
                loadingScriptPlanResultWriteback
                    ? '…'
                    : l10n.agentWorkspaceScriptWritebackUpdateData,
              ),
            ),
          ],
            );
          },
        ),
      ],
    );
  }
}

/// Displays canned and inferred JSON argument templates for the current tool.
class ScriptWorkspaceArgumentTemplatesPanel extends StatelessWidget {
  const ScriptWorkspaceArgumentTemplatesPanel({
    super.key,
    required this.busy,
    required this.templates,
    required this.onApplyTemplate,
  });

  final bool busy;
  final List<ScriptWorkspaceArgumentTemplateEntry> templates;
  final void Function(String args, String label) onApplyTemplate;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: StudioSpacing.xs,
      runSpacing: StudioSpacing.xs,
      children: templates
          .map(
            (ScriptWorkspaceArgumentTemplateEntry entry) => StudioActionChip(
              label: Text(entry.label),
              onPressed: busy
                  ? null
                  : () => onApplyTemplate(entry.args, entry.label),
            ),
          )
          .toList(growable: false),
    );
  }
}
