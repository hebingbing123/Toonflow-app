// Extracted panel widgets for AgentWorkspaceScriptCard.
// Keeps agent_workspaces/panels/script.dart ≤800 lines.

import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import 'support.dart';

/// Renders the "执行阶段" stage board for the script workspace.
class ScriptWorkspaceStagesPanel extends StatelessWidget {
  const ScriptWorkspaceStagesPanel({
    super.key,
    required this.stages,
    required this.busy,
    required this.onApplyStage,
    required this.onRunStageDomainTool,
    required this.onRunStageSubAgent,
  });

  final List<ScriptWorkspaceStage> stages;
  final bool busy;
  final ValueChanged<ScriptWorkspaceStage> onApplyStage;
  final ValueChanged<ScriptWorkspaceStage> onRunStageDomainTool;
  final ValueChanged<ScriptWorkspaceStage> onRunStageSubAgent;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    if (stages.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const SizedBox(height: 8),
        Text(
          l10n.agentWorkspaceScriptStagesTitle,
          style: Theme.of(context).textTheme.labelLarge,
        ),
        const SizedBox(height: 6),
        ...stages.map(
          (ScriptWorkspaceStage stage) => Card(
            margin: const EdgeInsets.only(bottom: 8),
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          stage.title,
                          style: Theme.of(context).textTheme.labelLarge,
                        ),
                      ),
                      Chip(label: Text(stage.statusLabel)),
                    ],
                  ),
                  Text(
                    stage.detail,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: <Widget>[
                      OutlinedButton(
                        onPressed: busy ? null : () => onApplyStage(stage),
                        child: Text(l10n.agentWorkspaceScriptApplyStage),
                      ),
                      if (stage.domainTool != null)
                        FilledButton.tonal(
                          onPressed: busy
                              ? null
                              : () => onRunStageDomainTool(stage),
                          child: Text(l10n.agentWorkspaceScriptReadContext),
                        ),
                      if (stage.subAgentTool != null)
                        FilledButton(
                          onPressed: busy
                              ? null
                              : () => onRunStageSubAgent(stage),
                          child: Text(l10n.agentWorkspaceScriptAdvanceStage),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Renders the "下一步建议" recipe diagnosis panel for the script workspace.
class ScriptWorkspaceDiagnosisPanel extends StatelessWidget {
  const ScriptWorkspaceDiagnosisPanel({
    super.key,
    required this.recipes,
    required this.busy,
    required this.onApplyRecipe,
    required this.onRunRecipeDomainTool,
    required this.onRunRecipeSubAgent,
  });

  final List<ScriptWorkspaceRecipe> recipes;
  final bool busy;
  final ValueChanged<ScriptWorkspaceRecipe> onApplyRecipe;
  final ValueChanged<ScriptWorkspaceRecipe> onRunRecipeDomainTool;
  final ValueChanged<ScriptWorkspaceRecipe> onRunRecipeSubAgent;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    if (recipes.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const SizedBox(height: 8),
        Text(
          l10n.agentWorkspaceScriptDiagnosisTitle,
          style: Theme.of(context).textTheme.labelLarge,
        ),
        const SizedBox(height: 6),
        ...recipes.map(
          (ScriptWorkspaceRecipe recipe) => Card(
            margin: const EdgeInsets.only(bottom: 8),
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    recipe.title,
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    recipe.detail,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: <Widget>[
                      if (recipe.domainTool != null)
                        Chip(
                          label: Text(
                            l10n.agentWorkspaceScriptToolChip(
                              recipe.domainTool!,
                            ),
                          ),
                        ),
                      if (recipe.subAgentTool != null)
                        Chip(
                          label: Text(
                            l10n.agentWorkspaceScriptAgentChip(
                              recipe.subAgentTool!,
                            ),
                          ),
                        ),
                      OutlinedButton(
                        onPressed: busy ? null : () => onApplyRecipe(recipe),
                        child: Text(l10n.agentWorkspaceScriptApplySuggestion),
                      ),
                      if (recipe.domainTool != null)
                        FilledButton.tonal(
                          onPressed: busy
                              ? null
                              : () => onRunRecipeDomainTool(recipe),
                          child: Text(l10n.agentWorkspaceScriptReadContext),
                        ),
                      if (recipe.subAgentTool != null)
                        FilledButton(
                          onPressed: busy
                              ? null
                              : () => onRunRecipeSubAgent(recipe),
                          child: Text(l10n.agentWorkspaceScriptRunSubAgent),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
