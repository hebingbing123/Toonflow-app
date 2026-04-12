part of 'card.dart';

extension _AgentWorkspaceScriptCardSupport on _AgentWorkspaceScriptCardState {
  List<String> _buildResultSummaryLines() {
    final lines = <String>[
      'tool=${widget.selectedScriptDomainTool}',
      if (_scriptWritebackSourceLine != null)
        'writebackSource=${_scriptWritebackSourceLine!}',
      if (widget.workspaceScriptWritebackCandidate?.trim().isNotEmpty == true)
        'scriptCandidate.chars=${widget.workspaceScriptWritebackCandidate!.trim().length}',
      if (widget.workspaceAssistantText.trim().isNotEmpty)
        'assistant.chars=${widget.workspaceAssistantText.trim().length}',
    ];
    final planCandidate = widget.workspaceScriptPlanWritebackCandidate;
    if (planCandidate != null) {
      final pid = widget.workspaceScriptPlanRowId;
      if (pid != null) {
        lines.add('planRowId=$pid');
      }
      final data = planCandidate['data'];
      if (data is Map<String, dynamic>) {
        final scriptRows = data['script'];
        if (scriptRows is List) {
          lines.add('plan.scriptRows=${scriptRows.length}');
        }
        if ((data['storySkeleton'] as String?)?.trim().isNotEmpty == true) {
          lines.add('plan.storySkeleton=ready');
        }
        if ((data['adaptationStrategy'] as String?)?.trim().isNotEmpty ==
            true) {
          lines.add('plan.adaptationStrategy=ready');
        }
      }
    }
    lines.addAll(
      summarizeScriptResultSnapshot(
        widget.workspaceLastToolName,
        widget.workspaceLastToolResultData,
      ),
    );
    return lines.take(6).toList(growable: false);
  }

  List<Widget> _buildContextSnapshot(BuildContext context) {
    final snapshot = ScriptContextSnapshotView(
      workspaceScriptPlanWritebackCandidate:
          widget.workspaceScriptPlanWritebackCandidate,
      workspaceLastToolName: widget.workspaceLastToolName,
      workspaceLastToolResultData: widget.workspaceLastToolResultData,
    );
    return <Widget>[snapshot];
  }

  List<ScriptWorkspaceRecipe> _buildWorkspaceRecipes() {
    return buildScriptWorkspaceRecipes(
      toolName: widget.workspaceLastToolName,
      result: widget.workspaceLastToolResultData,
      scopeScriptId: _scopeScriptId,
    );
  }

  List<ScriptWorkspaceStage> _buildWorkspaceStages() {
    return buildScriptWorkspaceStages(
      toolName: widget.workspaceLastToolName,
      result: widget.workspaceLastToolResultData,
      scopeScriptId: _scopeScriptId,
    );
  }

  Widget _buildWorkspaceStagesPanel(BuildContext context) {
    return ScriptWorkspaceStagesPanel(
      stages: _buildWorkspaceStages(),
      busy: widget.busy,
      onApplyStage: _applyWorkspaceStage,
      onRunStageDomainTool: _runWorkspaceStageDomainTool,
      onRunStageSubAgent: _runWorkspaceStageSubAgent,
    );
  }

  Widget _buildWorkspaceDiagnosis(BuildContext context) {
    return ScriptWorkspaceDiagnosisPanel(
      recipes: _buildWorkspaceRecipes(),
      busy: widget.busy,
      onApplyRecipe: _applyWorkspaceRecipe,
      onRunRecipeDomainTool: _runWorkspaceRecipeDomainTool,
      onRunRecipeSubAgent: _runWorkspaceRecipeSubAgent,
    );
  }
}
