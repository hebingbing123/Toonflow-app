import 'package:flutter/material.dart';

import '../../../rust_api.dart';
import '../../prompt_preset.dart';

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
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: <Widget>[
        FilledButton.tonal(
          onPressed: busy ? null : onFetchPlanData,
          child: Text(l10n.agentWorkspaceScriptStepFetchPlanData),
        ),
        FilledButton.tonal(
          onPressed: busy ? null : onFetchScriptContent,
          child: Text(l10n.agentWorkspaceScriptStepFetchContent),
        ),
        FilledButton.tonal(
          onPressed: busy ? null : onGenerateDraft,
          child: Text(l10n.agentWorkspaceScriptStepGenerateDraft),
        ),
        OutlinedButton(
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        TextField(
          controller: scriptPromptController,
          maxLines: 4,
          decoration: InputDecoration(
            labelText: l10n.agentWorkspaceScriptPromptLabel,
            helperText: l10n.agentWorkspaceScriptPromptHelper,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: <Widget>[
            FilledButton.tonal(
              onPressed: busy ? null : onRunScriptWorkspace,
              child: Text(
                loadingScriptWorkspaceRun
                    ? '…'
                    : l10n.agentWorkspaceScriptRunWorkflow,
              ),
            ),
            SizedBox(
              width: 220,
              child: DropdownButtonFormField<String>(
                isExpanded: true,
                initialValue: selectedScriptDomainTool,
                items: scriptDomainToolPresets
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
                        onScriptDomainToolChanged(value);
                      },
                decoration: InputDecoration(
                  labelText: l10n.agentWorkspaceScriptDomainToolLabel,
                ),
              ),
            ),
            FilledButton.tonal(
              onPressed: busy ? null : onProbeScriptDomainTool,
              child: Text(
                loadingScriptDomainProbe
                    ? '…'
                    : l10n.agentWorkspaceScriptReadContext,
              ),
            ),
            SizedBox(
              width: 320,
              child: TextField(
                controller: scriptDomainArgsController,
                maxLines: 2,
                decoration: InputDecoration(
                  labelText: l10n.agentWorkspaceScriptArgsLabel,
                  helperText: l10n.agentWorkspaceScriptArgsHelper,
                ),
              ),
            ),
            SizedBox(
              width: 300,
              child: DropdownButtonFormField<String>(
                isExpanded: true,
                initialValue: selectedScriptSubAgentTool,
                items: scriptSubAgentPresets
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
                        onScriptSubAgentChanged(value);
                      },
                decoration: InputDecoration(
                  labelText: l10n.agentWorkspaceScriptSubAgentToolLabel,
                ),
              ),
            ),
            FilledButton.tonal(
              onPressed: busy ? null : onRunScriptSubAgentTool,
              child: Text(
                loadingScriptSubAgentRun
                    ? '…'
                    : l10n.agentWorkspaceScriptRunSubAgent,
              ),
            ),
            FilledButton(
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
      spacing: 8,
      runSpacing: 8,
      children: templates
          .map(
            (ScriptWorkspaceArgumentTemplateEntry entry) => ActionChip(
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
