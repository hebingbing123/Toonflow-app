// Extracted panel widgets for AgentWorkspaceProductionCard.
// Keeps agent_workspaces/panels/production.dart ≤800 lines.

import 'package:flutter/material.dart';

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

  @override
  Widget build(BuildContext context) {
    if (stages.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const SizedBox(height: 8),
        Text('执行阶段', style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 6),
        ...stages.map(
          (ProductionWorkspaceStage stage) => Card(
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
                      Chip(label: Text('flow=${stage.flowKey}')),
                      OutlinedButton(
                        onPressed:
                            busy ? null : () => onApplyStage(stage),
                        child: const Text('应用阶段'),
                      ),
                      if (stage.domainTool != null)
                        FilledButton.tonal(
                          onPressed: busy
                              ? null
                              : () => onRunStageDomainTool(stage),
                          child: const Text('读取 flow'),
                        ),
                      if (stage.subAgentTool != null)
                        FilledButton(
                          onPressed: busy
                              ? null
                              : () => onRunStageSubAgent(stage),
                          child: const Text('推进阶段'),
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

  @override
  Widget build(BuildContext context) {
    if (recipes.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const SizedBox(height: 8),
        Text('下一步建议', style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 6),
        ...recipes.map(
          (ProductionWorkspaceRecipe recipe) => Card(
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
                      Chip(label: Text('flow=${recipe.flowKey}')),
                      if (recipe.domainTool != null)
                        Chip(label: Text('tool=${recipe.domainTool}')),
                      if (recipe.subAgentTool != null)
                        Chip(label: Text('agent=${recipe.subAgentTool}')),
                      OutlinedButton(
                        onPressed:
                            busy ? null : () => onApplyRecipe(recipe),
                        child: const Text('应用建议'),
                      ),
                      if (recipe.domainTool != null)
                        FilledButton.tonal(
                          onPressed: busy
                              ? null
                              : () => onRunRecipeDomainTool(recipe),
                          child: const Text('读取 flow'),
                        ),
                      if (recipe.subAgentTool != null)
                        FilledButton(
                          onPressed: busy
                              ? null
                              : () => onRunRecipeSubAgent(recipe),
                          child: const Text('运行子代理'),
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
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: <Widget>[
        FilledButton.tonal(
          onPressed: busy ? null : onPullAssetsFlow,
          child: const Text('1) 拉取资产 flow'),
        ),
        FilledButton.tonal(
          onPressed: busy ? null : onRunAssetsSubAgent,
          child: const Text('2) 运行资产子代理'),
        ),
        FilledButton.tonal(
          onPressed: busy ? null : onPullStoryboardFlow,
          child: const Text('3) 拉取分镜 flow'),
        ),
        OutlinedButton(
          onPressed: busy || !hasLastResult ? null : onWriteBackFlow,
          child: const Text('4) 写回 flow'),
        ),
        FilledButton.tonal(
          onPressed: busy ? null : onRunStoryboardSubAgent,
          child: const Text('5) 运行分镜子代理'),
        ),
        FilledButton.tonal(
          onPressed: busy ? null : onRunDirectorPlanSubAgent,
          child: const Text('6) 运行导演计划子代理'),
        ),
      ],
    );
  }
}
