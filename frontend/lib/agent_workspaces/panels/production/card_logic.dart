part of 'card.dart';

extension _AgentWorkspaceProductionCardLogic
    on _AgentWorkspaceProductionCardState {
  Widget _buildPromptTemplates() {
    return ProductionWorkspacePromptTemplatesPanel(
      busy: widget.busy,
      presets: widget.productionPromptPresets,
      onSelectPrompt: widget.onSelectPrompt,
    );
  }

  String? get _suggestedFlowKeyLine {
    final key = widget.workspaceSuggestedFlowKey?.trim();
    if (key == null || key.isEmpty) return null;
    return key;
  }

  String? get _runningTaskLine {
    final l10n = resolveAppLocalizationsForErrors(context);
    if (widget.loadingProductionWorkspaceRun) {
      return l10n.agentWorkspaceProductionRunningRunWorkflow;
    }
    if (widget.loadingProductionFlowProbe) {
      return l10n.agentWorkspaceProductionRunningProbeTool;
    }
    if (widget.loadingProductionSubAgentRun) {
      return l10n.agentWorkspaceProductionRunningSubAgent;
    }
    if (widget.loadingProductionResultWriteback) {
      return l10n.agentWorkspaceProductionRunningWriteback;
    }
    return null;
  }

  bool _validateJsonArgs(String raw) {
    final l10n = resolveAppLocalizationsForErrors(context);
    final normalized = raw.trim();
    if (normalized.isEmpty) return true;
    try {
      final decoded = jsonDecode(normalized);
      if (decoded is Map<String, dynamic>) return true;
      _setTaskStatus(
        l10n.agentWorkspaceProductionInterceptArgsMustBeJsonObject,
      );
      return false;
    } catch (_) {
      _setTaskStatus(l10n.agentWorkspaceProductionInterceptArgsJsonParseFailed);
      return false;
    }
  }

  bool _validatePrompt(String action) {
    final l10n = resolveAppLocalizationsForErrors(context);
    if (widget.productionPromptController.text.trim().isNotEmpty) return true;
    _setTaskStatus(
      l10n.agentWorkspaceProductionInterceptPromptRequired(action),
    );
    return false;
  }

  bool _validateFlowProbe() {
    final l10n = resolveAppLocalizationsForErrors(context);
    final tool = widget.productionDomainToolController.text.trim();
    if (tool.isEmpty) {
      _setTaskStatus(
        l10n.agentWorkspaceProductionInterceptSelectDomainToolFirst,
      );
      return false;
    }
    if (!_validateJsonArgs(widget.productionDomainArgsController.text)) {
      return false;
    }
    if (tool == 'get_flowData' &&
        widget.flowKeyController.text.trim().isEmpty) {
      _setTaskStatus(l10n.agentWorkspaceProductionInterceptGetFlowDataNeedsKey);
      return false;
    }
    return true;
  }

  bool _normalizeArgsForProbe() {
    final l10n = resolveAppLocalizationsForErrors(context);
    final tool = widget.productionDomainToolController.text.trim();
    final raw = widget.productionDomainArgsController.text.trim();
    if (raw.isEmpty) {
      widget.productionDomainArgsController.text = '{}';
    }
    final decoded = jsonDecode(
      widget.productionDomainArgsController.text.trim(),
    );
    if (decoded is! Map<String, dynamic>) {
      _setTaskStatus(
        l10n.agentWorkspaceProductionInterceptArgsMustBeJsonObject,
      );
      return false;
    }
    if (tool != 'get_flowData') {
      return true;
    }
    final key = widget.flowKeyController.text.trim();
    final normalized = Map<String, dynamic>.from(decoded);
    if (normalized['key'] == key) {
      return true;
    }
    normalized['key'] = key;
    widget.productionDomainArgsController.text = jsonEncode(normalized);
    _setTaskStatus(l10n.agentWorkspaceProductionSyncedFlowDataKey(key));
    return true;
  }

  bool _validateSubAgentTool() {
    final l10n = resolveAppLocalizationsForErrors(context);
    if (widget.productionSubAgentToolController.text.trim().isEmpty) {
      _setTaskStatus(
        l10n.agentWorkspaceProductionInterceptSelectSubAgentToolFirst,
      );
      return false;
    }
    if (!_validateJsonArgs(widget.productionSubAgentArgsController.text)) {
      return false;
    }
    return _validatePrompt(l10n.agentWorkspaceProductionActionRunSubAgent);
  }

  void _runProductionWorkspace() {
    final l10n = resolveAppLocalizationsForErrors(context);
    if (!_validatePrompt(l10n.agentWorkspaceProductionActionRunWorkflow)) {
      return;
    }
    widget.onRunProductionWorkspace();
    _setTaskStatus(l10n.agentWorkspaceProductionTriggeredRunWorkflow);
  }

  void _probeProductionDomainTool() {
    if (!_validateFlowProbe()) return;
    if (!_normalizeArgsForProbe()) return;
    widget.onProbeProductionDomainTool();
    final l10n = resolveAppLocalizationsForErrors(context);
    final tool = widget.productionDomainToolController.text.trim();
    final key = widget.flowKeyController.text.trim();
    final suffix = tool == 'get_flowData' ? ' key=$key' : '';
    _setTaskStatus(
      l10n.agentWorkspaceProductionTriggeredProbeContext('$tool$suffix'),
    );
  }

  void _runProductionSubAgentTool() {
    if (!_validateSubAgentTool()) return;
    widget.onRunProductionSubAgentTool();
    final l10n = resolveAppLocalizationsForErrors(context);
    final tool = widget.productionSubAgentToolController.text.trim();
    _setTaskStatus(l10n.agentWorkspaceProductionTriggeredRunSubAgentTool(tool));
  }

  void _writeBackProductionFlowResult() {
    final l10n = resolveAppLocalizationsForErrors(context);
    if (widget.workspaceLastToolResultLine == null) {
      _setTaskStatus(l10n.agentWorkspaceProductionInterceptNoToolWriteback);
      return;
    }
    if (widget.flowKeyController.text.trim().isEmpty) {
      _setTaskStatus(
        l10n.agentWorkspaceProductionInterceptWritebackNeedsFlowKey,
      );
      return;
    }
    widget.onWriteBackProductionFlowResult();
    final key = widget.flowKeyController.text.trim();
    _setTaskStatus(l10n.agentWorkspaceProductionTriggeredWritebackFlow(key));
  }

  void _applyProductionPromptIfEmpty(String prompt) {
    if (widget.productionPromptController.text.trim().isNotEmpty) return;
    widget.productionPromptController.text = prompt;
  }

  void _applySuggestedSubAgentArgs(String toolName) {
    widget.productionSubAgentArgsController.text = jsonEncode(
      buildProductionSuggestedSubAgentArgs(
        subAgentTool: toolName,
        toolName: widget.workspaceLastToolName,
        suggestedFlowKey: widget.workspaceSuggestedFlowKey,
        result: widget.workspaceLastToolResultData,
        toolArguments: widget.workspaceLastToolArguments,
      ),
    );
  }

  String get _selectedProductionTool =>
      widget.productionDomainToolController.text.trim();

  Widget _buildGuidedTasks() {
    final l10n = resolveAppLocalizationsForErrors(context);
    return ProductionWorkspaceGuidedTasksPanel(
      busy: widget.busy,
      hasLastResult: widget.workspaceLastToolResultLine != null,
      onPullAssetsFlow: () {
        widget.onFlowKeyChanged('assets');
        widget.onProductionDomainToolChanged('get_flowData');
        _probeProductionDomainTool();
      },
      onRunAssetsSubAgent: () {
        _applyProductionPromptIfEmpty(
          l10n.agentWorkspaceProductionGuidedDeriveAssetsPrompt,
        );
        widget.onProductionSubAgentChanged('run_sub_agent_derive_assets');
        _applySuggestedSubAgentArgs('run_sub_agent_derive_assets');
        _runProductionSubAgentTool();
      },
      onPullStoryboardFlow: () {
        widget.onFlowKeyChanged('storyboard');
        widget.onProductionDomainToolChanged('get_flowData');
        _probeProductionDomainTool();
      },
      onWriteBackFlow: _writeBackProductionFlowResult,
      onRunStoryboardSubAgent: () {
        widget.onFlowKeyChanged('storyboard');
        _applyProductionPromptIfEmpty(
          l10n.agentWorkspaceProductionGuidedStoryboardGenPrompt,
        );
        widget.onProductionSubAgentChanged('run_sub_agent_storyboard_gen');
        _applySuggestedSubAgentArgs('run_sub_agent_storyboard_gen');
        _runProductionSubAgentTool();
      },
      onRunDirectorPlanSubAgent: () {
        widget.onFlowKeyChanged('scriptPlan');
        _applyProductionPromptIfEmpty(
          l10n.agentWorkspaceProductionGuidedDirectorPlanPrompt,
        );
        widget.onProductionSubAgentChanged('run_sub_agent_director_plan');
        _applySuggestedSubAgentArgs('run_sub_agent_director_plan');
        _runProductionSubAgentTool();
      },
    );
  }
}
