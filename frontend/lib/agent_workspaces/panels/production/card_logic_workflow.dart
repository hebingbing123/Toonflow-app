part of 'card.dart';

extension _AgentWorkspaceProductionCardWorkflow
    on _AgentWorkspaceProductionCardState {
  void _applyWorkspaceRecipe(ProductionWorkspaceRecipe recipe) {
    widget.onFlowKeyChanged(recipe.flowKey);
    if (recipe.domainTool != null && recipe.domainTool!.trim().isNotEmpty) {
      widget.onProductionDomainToolChanged(recipe.domainTool!.trim());
      widget.productionDomainArgsController.text = jsonEncode(
        recipe.domainArgs ?? <String, dynamic>{'key': recipe.flowKey},
      );
    }
    if (recipe.subAgentTool != null && recipe.subAgentTool!.trim().isNotEmpty) {
      widget.onProductionSubAgentChanged(recipe.subAgentTool!.trim());
    }
    final prompt = recipe.prompt?.trim();
    if (prompt != null && prompt.isNotEmpty) {
      widget.productionPromptController.text = prompt;
    }
    _setTaskStatus('已应用任务建议：${recipe.title}');
  }

  void _applyWorkspaceStage(ProductionWorkspaceStage stage) {
    widget.onFlowKeyChanged(stage.flowKey);
    if (stage.domainTool != null && stage.domainTool!.trim().isNotEmpty) {
      widget.onProductionDomainToolChanged(stage.domainTool!.trim());
      if (stage.domainTool == 'get_flowData') {
        widget.productionDomainArgsController.text = jsonEncode(
          stage.domainArgs ?? <String, dynamic>{'key': stage.flowKey},
        );
      }
    }
    if (stage.subAgentTool != null && stage.subAgentTool!.trim().isNotEmpty) {
      widget.onProductionSubAgentChanged(stage.subAgentTool!.trim());
    }
    final prompt = stage.prompt?.trim();
    if (prompt != null && prompt.isNotEmpty) {
      widget.productionPromptController.text = prompt;
    }
    _setTaskStatus('已应用阶段动作：${stage.title}');
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
