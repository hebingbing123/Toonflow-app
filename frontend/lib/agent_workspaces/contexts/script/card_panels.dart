// Extracted panel widgets for AgentWorkspaceScriptCard.
// Keeps agent_workspaces/panels/script.dart ≤800 lines.

import 'package:flutter/material.dart';
import '../../../design_system/components/studio_chip.dart';

import 'package:openflow_app/design_system/components/studio_dense_action_row.dart';
import 'package:openflow_app/design_system/components/studio_surfaces.dart';
import '../../../design_system/components/studio_entrance_motion.dart';
import '../../../design_system/components/studio_workbench_section.dart';
import '../../../design_system/tokens.dart';
import '../../../rust_api.dart';
import '../../agent_workspace_preset_labels.dart';
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
    final l10n = resolveAppLocalizationsForErrors(context);
    if (stages.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const SizedBox(height: StudioSpacing.xs),
        Text(
          l10n.agentWorkspaceScriptStagesTitle,
          style: Theme.of(context).textTheme.labelLarge,
        ),
        const SizedBox(height: StudioSpacing.xs),
        ...studioStaggeredChildren(
          stages.map(
            (ScriptWorkspaceStage stage) => Card(
              margin: const EdgeInsets.only(bottom: StudioSpacing.xs),
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              child: Padding(
                padding: const EdgeInsets.all(StudioSpacing.radiusComfort),
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
                        StudioChip(label: Text(stage.statusLabel)),
                      ],
                    ),
                    Text(
                      stage.detail,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: StudioSpacing.xs),
                    StudioDenseActionRow(
                      children: <Widget>[
                        OutlinedButton(
                          style: studioFormSecondaryButtonStyle(context),
                          onPressed: busy ? null : () => onApplyStage(stage),
                          child: Text(l10n.agentWorkspaceScriptApplyStage),
                        ),
                        if (stage.domainTool != null)
                          FilledButton.tonal(
                            style: studioFormTonalButtonStyle(context),
                            onPressed: busy
                                ? null
                                : () => onRunStageDomainTool(stage),
                            child: Text(l10n.agentWorkspaceScriptReadContext),
                          ),
                        if (stage.subAgentTool != null)
                          FilledButton(
                            style: studioFormPrimaryButtonStyle(context),
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
          entranceKey: stages.length,
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
    final l10n = resolveAppLocalizationsForErrors(context);
    if (recipes.isEmpty) return const SizedBox.shrink();
    final tokens = StudioTokens.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: StudioLayoutSpacing.listItem),
      child: StudioWorkbenchSection(
        title: l10n.agentWorkspaceScriptDiagnosisTitle,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: studioStaggeredChildren(
            recipes.map(
              (ScriptWorkspaceRecipe recipe) => Card(
                margin: const EdgeInsets.only(
                  bottom: StudioLayoutSpacing.listItem,
                ),
                color: tokens.bgInset,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(
                    StudioSpacing.radiusButton,
                  ),
                  side: BorderSide(color: tokens.borderSubtle),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(
                    StudioSpacing.radiusComfort,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        recipe.title,
                        style: Theme.of(context).textTheme.labelLarge,
                      ),
                      const SizedBox(height: StudioSpacing.xs),
                      Text(
                        recipe.detail,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(height: StudioSpacing.xs),
                      StudioDenseActionRow(
                        children: <Widget>[
                          if (recipe.domainTool != null)
                            StudioChip(
                              label: Text(
                                agentWorkspaceScriptDomainToolLabel(
                                  l10n,
                                  recipe.domainTool!,
                                ),
                              ),
                            ),
                          if (recipe.subAgentTool != null)
                            StudioChip(
                              label: Text(
                                agentWorkspaceScriptSubAgentLabel(
                                  l10n,
                                  recipe.subAgentTool!,
                                ),
                              ),
                            ),
                          OutlinedButton(
                            style: studioFormSecondaryButtonStyle(context),
                            onPressed: busy
                                ? null
                                : () => onApplyRecipe(recipe),
                            child: Text(
                              l10n.agentWorkspaceScriptApplySuggestion,
                            ),
                          ),
                          if (recipe.domainTool != null)
                            FilledButton.tonal(
                              style: studioFormTonalButtonStyle(context),
                              onPressed: busy
                                  ? null
                                  : () => onRunRecipeDomainTool(recipe),
                              child: Text(
                                l10n.agentWorkspaceScriptReadContext,
                              ),
                            ),
                          if (recipe.subAgentTool != null)
                            FilledButton(
                              style: studioFormPrimaryButtonStyle(context),
                              onPressed: busy
                                  ? null
                                  : () => onRunRecipeSubAgent(recipe),
                              child: Text(
                                l10n.agentWorkspaceScriptRunSubAgent,
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
            entranceKey: recipes.length,
          ),
        ),
      ),
    );
  }
}
