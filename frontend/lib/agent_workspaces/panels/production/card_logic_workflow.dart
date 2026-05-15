part of 'card.dart';

extension _AgentWorkspaceProductionCardWorkflow
    on _AgentWorkspaceProductionCardState {
  void _applyWorkspaceRecipe(ProductionWorkspaceRecipe recipe) {
    final domainTool = recipe.domainTool?.trim();
    final subAgentTool = recipe.subAgentTool?.trim();
    final prompt = recipe.prompt?.trim();
    widget.onApplyProductionFocus(
      flowKey: recipe.flowKey,
      domainTool: domainTool != null && domainTool.isNotEmpty
          ? domainTool
          : null,
      domainArgs: domainTool == null || domainTool.isEmpty
          ? null
          : recipe.domainArgs ??
                (domainTool == 'get_flowData'
                    ? _flowDataArgsTemplate()
                    : <String, dynamic>{'key': recipe.flowKey}),
      subAgentTool: subAgentTool != null && subAgentTool.isNotEmpty
          ? subAgentTool
          : null,
      subAgentArgs: subAgentTool == null || subAgentTool.isEmpty
          ? null
          : recipe.subAgentArgs ?? const <String, dynamic>{},
      prompt: prompt != null && prompt.isNotEmpty ? prompt : null,
    );
    _setTaskStatus(
      summarizeAppliedProductionRecipeStatus(
        recipe,
        resolveAppLocalizationsForErrors(context),
      ),
    );
  }

  void _applyWorkspaceStage(ProductionWorkspaceStage stage) {
    final domainTool = stage.domainTool?.trim();
    final subAgentTool = stage.subAgentTool?.trim();
    final prompt = stage.prompt?.trim();
    widget.onApplyProductionFocus(
      flowKey: stage.flowKey,
      domainTool: domainTool != null && domainTool.isNotEmpty
          ? domainTool
          : null,
      domainArgs: domainTool == 'get_flowData'
          ? stage.domainArgs ?? _flowDataArgsTemplate()
          : null,
      subAgentTool: subAgentTool != null && subAgentTool.isNotEmpty
          ? subAgentTool
          : null,
      subAgentArgs: subAgentTool == null || subAgentTool.isEmpty
          ? null
          : stage.subAgentArgs ?? const <String, dynamic>{},
      prompt: prompt != null && prompt.isNotEmpty ? prompt : null,
    );
    _setTaskStatus(
      summarizeAppliedProductionStageStatus(
        stage,
        resolveAppLocalizationsForErrors(context),
      ),
    );
  }

  void _runWorkspaceStageDomainTool(ProductionWorkspaceStage stage) {
    _applyWorkspaceStage(stage);
    if (stage.domainTool == null || stage.domainTool!.trim().isEmpty) return;
    _probeProductionDomainTool();
  }

  void _runWorkspaceStageSubAgent(ProductionWorkspaceStage stage) {
    _applyWorkspaceStage(stage);
    if (stage.subAgentTool == null || stage.subAgentTool!.trim().isEmpty) {
      return;
    }
    _runProductionSubAgentTool();
  }

  void _runWorkspaceRecipeDomainTool(ProductionWorkspaceRecipe recipe) {
    _applyWorkspaceRecipe(recipe);
    if (recipe.domainTool == null || recipe.domainTool!.trim().isEmpty) return;
    _probeProductionDomainTool();
  }

  void _runWorkspaceRecipeSubAgent(ProductionWorkspaceRecipe recipe) {
    _applyWorkspaceRecipe(recipe);
    if (recipe.subAgentTool == null || recipe.subAgentTool!.trim().isEmpty) {
      return;
    }
    _runProductionSubAgentTool();
  }
}
