// Extracted panel widgets for AgentWorkspaceProductionCard.
// Keeps agent_workspaces/panels/production.dart ≤800 lines.

import 'package:flutter/material.dart';
import '../../../design_system/components/studio_chip.dart';
import '../../../design_system/components/studio_dense_action_row.dart';
import '../../../design_system/components/studio_surfaces.dart';
import '../../../design_system/components/studio_entrance_motion.dart';
import '../../../design_system/components/studio_workbench_section.dart';
import '../../../design_system/tokens.dart';
import '../../../rust_api.dart';
import '../../agent_workspace_preset_labels.dart';
import 'support.dart';

/// Renders the "执行阶段" stage board.
class ProductionWorkspaceStagesPanel extends StatelessWidget {
  const ProductionWorkspaceStagesPanel({
    super.key,
    required this.stages,
    required this.busy,
    required this.onApplyStage,
    required this.onRunStageDomainTool,
    required this.onRunStageSubAgent,
  });

  final List<ProductionWorkspaceStage> stages;
  final bool busy;
  final ValueChanged<ProductionWorkspaceStage> onApplyStage;
  final ValueChanged<ProductionWorkspaceStage> onRunStageDomainTool;
  final ValueChanged<ProductionWorkspaceStage> onRunStageSubAgent;

  Widget _buildPromptPreview(BuildContext context, String prompt) {
    final l10n = resolveAppLocalizationsForErrors(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(StudioLayoutSpacing.inlineGap),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(StudioSpacing.radiusDense),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            l10n.agentWorkspaceProductionPromptPreviewTitle,
            style: Theme.of(context).textTheme.labelSmall,
          ),
          const SizedBox(height: StudioSpacing.xs),
          Text(prompt, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = resolveAppLocalizationsForErrors(context);
    if (stages.isEmpty) return const SizedBox.shrink();
    final blockerSummary = summarizeProductionPrimaryBlocker(stages, l10n);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const SizedBox(height: StudioSpacing.xs),
        Text(
          l10n.agentWorkspaceProductionStagesTitle,
          style: Theme.of(context).textTheme.labelLarge,
        ),
        if (blockerSummary.isNotEmpty) ...<Widget>[
          const SizedBox(height: StudioSpacing.xs),
          Text(blockerSummary, style: Theme.of(context).textTheme.bodySmall),
        ],
        const SizedBox(height: StudioSpacing.xs),
        ...studioStaggeredChildren(
          stages.map(
            (ProductionWorkspaceStage stage) => Card(
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
                        StudioChip(label: Text(stage.status.localizedLabel(l10n))),
                      ],
                    ),
                    Text(
                      stage.detail,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    if (stage.prompt?.trim().isNotEmpty ?? false) ...<Widget>[
                      const SizedBox(height: StudioSpacing.xs),
                      _buildPromptPreview(context, stage.prompt!.trim()),
                    ],
                    const SizedBox(height: StudioSpacing.xs),
                    StudioDenseActionRow(
                      children: <Widget>[
                        StudioChip(
                          label: Text(
                            agentWorkspaceFlowKeyLabel(l10n, stage.flowKey),
                          ),
                        ),
                        OutlinedButton(
                          style: studioFormSecondaryButtonStyle(context),
                          onPressed: busy ? null : () => onApplyStage(stage),
                          child: Text(l10n.agentWorkspaceProductionApplyStage),
                        ),
                        if (stage.domainTool != null)
                          FilledButton.tonal(
                            style: studioFormTonalButtonStyle(context),
                            onPressed: busy
                                ? null
                                : () => onRunStageDomainTool(stage),
                            child: Text(
                              productionStageDomainButtonLabel(stage, l10n),
                            ),
                          ),
                        if (stage.subAgentTool != null)
                          FilledButton(
                            style: studioFormPrimaryButtonStyle(context),
                            onPressed: busy
                                ? null
                                : () => onRunStageSubAgent(stage),
                            child: Text(
                              productionStageSubAgentButtonLabel(stage, l10n),
                            ),
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

/// Renders the "下一步建议" recipe diagnosis panel.
class ProductionWorkspaceDiagnosisPanel extends StatelessWidget {
  const ProductionWorkspaceDiagnosisPanel({
    super.key,
    required this.recipes,
    required this.busy,
    required this.onApplyRecipe,
    required this.onRunRecipeDomainTool,
    required this.onRunRecipeSubAgent,
  });

  final List<ProductionWorkspaceRecipe> recipes;
  final bool busy;
  final ValueChanged<ProductionWorkspaceRecipe> onApplyRecipe;
  final ValueChanged<ProductionWorkspaceRecipe> onRunRecipeDomainTool;
  final ValueChanged<ProductionWorkspaceRecipe> onRunRecipeSubAgent;

  Widget _buildPromptPreview(BuildContext context, String prompt) {
    final l10n = resolveAppLocalizationsForErrors(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(StudioLayoutSpacing.inlineGap),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(StudioSpacing.radiusDense),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            l10n.agentWorkspaceProductionPromptPreviewTitle,
            style: Theme.of(context).textTheme.labelSmall,
          ),
          const SizedBox(height: StudioSpacing.xs),
          Text(prompt, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = resolveAppLocalizationsForErrors(context);
    if (recipes.isEmpty) return const SizedBox.shrink();
    final diagnosisHeadline = summarizeProductionDiagnosisHeadline(
      recipes,
      l10n,
    );
    final tokens = StudioTokens.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: StudioLayoutSpacing.listItem),
      child: StudioWorkbenchSection(
        title: l10n.agentWorkspaceProductionDiagnosisTitle,
        subtitle: diagnosisHeadline.isEmpty ? null : diagnosisHeadline,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: studioStaggeredChildren(
            recipes.map(
              (ProductionWorkspaceRecipe recipe) => Card(
                margin: const EdgeInsets.only(bottom: StudioLayoutSpacing.listItem),
                color: tokens.bgInset,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(StudioSpacing.radiusButton),
                  side: BorderSide(color: tokens.borderSubtle),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(StudioSpacing.radiusComfort),
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
                      if (recipe.prompt?.trim().isNotEmpty ?? false) ...<Widget>[
                        const SizedBox(height: StudioSpacing.xs),
                        _buildPromptPreview(context, recipe.prompt!.trim()),
                      ],
                      const SizedBox(height: StudioSpacing.xs),
                      StudioDenseActionRow(
                        children: <Widget>[
                          StudioChip(
                            label: Text(
                              agentWorkspaceFlowKeyLabel(l10n, recipe.flowKey),
                            ),
                          ),
                          if (recipe.domainTool != null)
                            StudioChip(
                              label: Text(
                                agentWorkspaceProductionDomainToolLabel(
                                  l10n,
                                  recipe.domainTool!,
                                ),
                              ),
                            ),
                          if (recipe.subAgentTool != null)
                            StudioChip(
                              label: Text(
                                agentWorkspaceProductionSubAgentLabel(
                                  l10n,
                                  recipe.subAgentTool!,
                                ),
                              ),
                            ),
                          OutlinedButton(
                            style: studioFormSecondaryButtonStyle(context),
                            onPressed: busy ? null : () => onApplyRecipe(recipe),
                            child: Text(
                              l10n.agentWorkspaceProductionApplySuggestion,
                            ),
                          ),
                          if (recipe.domainTool != null)
                            FilledButton.tonal(
                              style: studioFormTonalButtonStyle(context),
                              onPressed: busy
                                  ? null
                                  : () => onRunRecipeDomainTool(recipe),
                              child: Text(
                                productionRecipeDomainButtonLabel(recipe, l10n),
                              ),
                            ),
                          if (recipe.subAgentTool != null)
                            FilledButton(
                              style: studioFormPrimaryButtonStyle(context),
                              onPressed: busy
                                  ? null
                                  : () => onRunRecipeSubAgent(recipe),
                              child: Text(
                                productionRecipeSubAgentButtonLabel(recipe, l10n),
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

/// Renders the "引导任务" quick-action buttons.
class ProductionWorkspaceGuidedTasksPanel extends StatelessWidget {
  const ProductionWorkspaceGuidedTasksPanel({
    super.key,
    required this.busy,
    required this.hasLastResult,
    required this.onPullAssetsFlow,
    required this.onRunAssetsSubAgent,
    required this.onPullStoryboardFlow,
    required this.onWriteBackFlow,
    required this.onRunStoryboardSubAgent,
    required this.onRunDirectorPlanSubAgent,
  });

  final bool busy;
  final bool hasLastResult;
  final VoidCallback onPullAssetsFlow;
  final VoidCallback onRunAssetsSubAgent;
  final VoidCallback onPullStoryboardFlow;
  final VoidCallback onWriteBackFlow;
  final VoidCallback onRunStoryboardSubAgent;
  final VoidCallback onRunDirectorPlanSubAgent;

  @override
  Widget build(BuildContext context) {
    final l10n = resolveAppLocalizationsForErrors(context);
    return StudioDenseActionRow(
      children: <Widget>[
        FilledButton.tonal(
          style: studioFormTonalButtonStyle(context),
          onPressed: busy ? null : onPullAssetsFlow,
          child: Text(l10n.agentWorkspaceProductionStepPullAssetsFlow),
        ),
        FilledButton.tonal(
          style: studioFormTonalButtonStyle(context),
          onPressed: busy ? null : onRunAssetsSubAgent,
          child: Text(l10n.agentWorkspaceProductionStepRunAssetsSubAgent),
        ),
        FilledButton.tonal(
          style: studioFormTonalButtonStyle(context),
          onPressed: busy ? null : onPullStoryboardFlow,
          child: Text(l10n.agentWorkspaceProductionStepPullStoryboardFlow),
        ),
        OutlinedButton(
          style: studioFormSecondaryButtonStyle(context),
          onPressed: busy || !hasLastResult ? null : onWriteBackFlow,
          child: Text(l10n.agentWorkspaceProductionStepWritebackFlow),
        ),
        FilledButton.tonal(
          style: studioFormTonalButtonStyle(context),
          onPressed: busy ? null : onRunStoryboardSubAgent,
          child: Text(l10n.agentWorkspaceProductionStepRunStoryboardSubAgent),
        ),
        FilledButton.tonal(
          style: studioFormTonalButtonStyle(context),
          onPressed: busy ? null : onRunDirectorPlanSubAgent,
          child: Text(l10n.agentWorkspaceProductionStepRunDirectorPlanSubAgent),
        ),
      ],
    );
  }
}
