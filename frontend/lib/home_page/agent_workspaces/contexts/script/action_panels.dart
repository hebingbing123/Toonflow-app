import 'package:flutter/material.dart';

import '../../panels/script.dart';

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
