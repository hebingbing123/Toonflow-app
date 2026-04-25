part of 'card.dart';

extension _AgentWorkspaceProductionCardSupport
    on _AgentWorkspaceProductionCardState {
  List<String> _buildResultSummaryLines() {
    final toolName = widget.workspaceLastToolName?.trim();
    final result = widget.workspaceLastToolResultData;
    final lines = <String>[
      if (toolName != null && toolName.isNotEmpty) 'tool=$toolName',
      if (result != null) 'resultType=${result.runtimeType}',
      ...summarizeProductionResultSnapshot(
        toolName,
        result,
        _suggestedFlowKeyLine,
      ),
    ];
    return lines.take(6).toList(growable: false);
  }

  List<Widget> _buildContextSnapshot(BuildContext context) {
    return <Widget>[
      ProductionContextSnapshotView(
        workspaceLastToolName: widget.workspaceLastToolName,
        workspaceLastToolResultData: widget.workspaceLastToolResultData,
        workspaceSuggestedFlowKey: widget.workspaceSuggestedFlowKey,
      ),
    ];
  }

  List<ProductionWorkspaceRecipe> _buildWorkspaceRecipes() {
    return buildProductionWorkspaceRecipes(
      toolName: widget.workspaceLastToolName,
      suggestedFlowKey: _suggestedFlowKeyLine,
      result: widget.workspaceLastToolResultData,
      toolArguments: widget.workspaceLastToolArguments,
    );
  }

  List<ProductionWorkspaceStage> _buildWorkspaceStages() {
    return buildProductionWorkspaceStages(
      toolName: widget.workspaceLastToolName,
      suggestedFlowKey: _suggestedFlowKeyLine,
      result: widget.workspaceLastToolResultData,
      toolArguments: widget.workspaceLastToolArguments,
    );
  }

  Widget _buildWorkspaceStagesPanel(BuildContext context) {
    return ProductionWorkspaceStagesPanel(
      stages: _buildWorkspaceStages(),
      busy: widget.busy,
      onApplyStage: _applyWorkspaceStage,
      onRunStageDomainTool: _runWorkspaceStageDomainTool,
      onRunStageSubAgent: _runWorkspaceStageSubAgent,
    );
  }

  Widget _buildWorkspaceDiagnosis(BuildContext context) {
    return ProductionWorkspaceDiagnosisPanel(
      recipes: _buildWorkspaceRecipes(),
      busy: widget.busy,
      onApplyRecipe: _applyWorkspaceRecipe,
      onRunRecipeDomainTool: _runWorkspaceRecipeDomainTool,
      onRunRecipeSubAgent: _runWorkspaceRecipeSubAgent,
    );
  }
}
