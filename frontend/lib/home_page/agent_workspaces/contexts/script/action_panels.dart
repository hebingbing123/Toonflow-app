import 'package:flutter/material.dart';

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
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: <Widget>[
        FilledButton.tonal(
          onPressed: busy ? null : onFetchPlanData,
          child: const Text('1) 拉取 planData'),
        ),
        FilledButton.tonal(
          onPressed: busy ? null : onFetchScriptContent,
          child: const Text('2) 拉取剧本正文'),
        ),
        FilledButton.tonal(
          onPressed: busy ? null : onGenerateDraft,
          child: const Text('3) 生成剧本草稿'),
        ),
        OutlinedButton(
          onPressed: busy || !canWriteBackScriptResult
              ? null
              : onWriteBackScript,
          child: const Text('4) 写回剧本'),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        TextField(
          controller: scriptPromptController,
          maxLines: 4,
          decoration: const InputDecoration(
            labelText: '工作区提示词',
            helperText: '用于剧本通道 harness.agent.run',
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: <Widget>[
            FilledButton.tonal(
              onPressed: busy ? null : onRunScriptWorkspace,
              child: Text(loadingScriptWorkspaceRun ? '…' : '运行剧本工作流'),
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
                decoration: const InputDecoration(labelText: '剧本域工具'),
              ),
            ),
            FilledButton.tonal(
              onPressed: busy ? null : onProbeScriptDomainTool,
              child: Text(loadingScriptDomainProbe ? '…' : '读取剧本上下文'),
            ),
            SizedBox(
              width: 320,
              child: TextField(
                controller: scriptDomainArgsController,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: '剧本工具参数(JSON)',
                  helperText: '可选，例如 {"novelId":1}',
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
                decoration: const InputDecoration(labelText: '剧本子代理工具'),
              ),
            ),
            FilledButton.tonal(
              onPressed: busy ? null : onRunScriptSubAgentTool,
              child: Text(loadingScriptSubAgentRun ? '…' : '运行子代理'),
            ),
            FilledButton(
              onPressed: busy || !canWriteBackScriptResult
                  ? null
                  : onWriteBackScriptResult,
              child: Text(loadingScriptResultWriteback ? '…' : '写回剧本'),
            ),
            FilledButton.tonal(
              onPressed: busy || !canWriteBackScriptPlanResult
                  ? null
                  : onWriteBackScriptPlanResult,
              child: Text(
                loadingScriptPlanResultWriteback ? '…' : '写回计划数据',
              ),
            ),
            OutlinedButton(
              onPressed: busy || !canWriteBackScriptPlanViaUpdateData
                  ? null
                  : onWriteBackScriptPlanViaUpdateData,
              child: Text(
                loadingScriptPlanResultWriteback ? '…' : 'update-data 写回',
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
              onPressed: busy ? null : () => onApplyTemplate(entry.args, entry.label),
            ),
          )
          .toList(growable: false),
    );
  }
}
