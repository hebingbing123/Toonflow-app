part of 'section.dart';

class _AgentWorkspacesSectionState extends State<AgentWorkspacesSection> {
  late AgentWorkspacePane _pane;
  String _selectedScriptDomainTool = _scriptDomainToolPresets.first;

  @override
  void initState() {
    super.initState();
    _pane = widget.initialPane;
    _ensurePresetDefaults();
  }

  @override
  void didUpdateWidget(covariant AgentWorkspacesSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialPane != widget.initialPane) {
      _pane = widget.initialPane;
    }
    _ensurePresetDefaults();
  }

  void _ensurePresetDefaults() {
    if (widget.scriptSubAgentToolController.text.trim().isEmpty) {
      widget.scriptSubAgentToolController.text = _scriptSubAgentPresets.first;
    }
    if (widget.scriptDomainArgsController.text.trim().isEmpty) {
      widget.scriptDomainArgsController.text = '{}';
    }
    if (widget.productionSubAgentToolController.text.trim().isEmpty) {
      widget.productionSubAgentToolController.text =
          _productionSubAgentPresets.first;
    }
    if (widget.flowKeyController.text.trim().isEmpty) {
      widget.flowKeyController.text = _flowKeyPresets.first;
    }
    if (widget.productionDomainToolController.text.trim().isEmpty) {
      widget.productionDomainToolController.text =
          _productionDomainToolPresets.first;
    }
    if (widget.productionDomainArgsController.text.trim().isEmpty) {
      widget.productionDomainArgsController.text = '{}';
    }
  }

  void _maybeApplyScriptToolArgsPreset(String toolName) {
    final current = widget.scriptDomainArgsController.text;
    if (!_isDefaultJsonObject(current)) {
      return;
    }
    widget.scriptDomainArgsController.text = _buildScriptToolArgsPresetText(
      toolName: toolName,
      scriptIdText: widget.scriptIdController.text,
    );
  }

  void _maybeApplyProductionToolArgsPreset(String toolName) {
    final current = widget.productionDomainArgsController.text;
    if (!_isDefaultJsonObject(current)) {
      return;
    }
    widget.productionDomainArgsController.text =
        _buildProductionToolArgsPresetText(
          toolName: toolName,
          scriptIdText: widget.scriptIdController.text,
          flowKeyText: widget.flowKeyController.text,
        );
  }

  bool get _busy =>
      widget.loadingScriptWorkspaceRun ||
      widget.loadingProductionWorkspaceRun ||
      widget.loadingScriptDomainProbe ||
      widget.loadingProductionFlowProbe ||
      widget.loadingScriptSubAgentRun ||
      widget.loadingProductionSubAgentRun ||
      widget.loadingScriptResultWriteback ||
      widget.loadingScriptPlanResultWriteback ||
      widget.loadingProductionResultWriteback;

  Widget _buildPaneBody(BuildContext context) {
    switch (_pane) {
      case AgentWorkspacePane.script:
        return AgentWorkspaceScriptCard(
          busy: _busy,
          scriptPromptController: widget.scriptPromptController,
          scriptDomainArgsController: widget.scriptDomainArgsController,
          scriptSubAgentToolController: widget.scriptSubAgentToolController,
          scriptDomainToolPresets: _scriptDomainToolPresets,
          scriptSubAgentPresets: _scriptSubAgentPresets,
          scriptPromptPresets: _scriptPromptPresets,
          selectedScriptDomainTool: _selectedScriptDomainTool,
          loadingScriptWorkspaceRun: widget.loadingScriptWorkspaceRun,
          loadingScriptDomainProbe: widget.loadingScriptDomainProbe,
          loadingScriptSubAgentRun: widget.loadingScriptSubAgentRun,
          loadingScriptResultWriteback: widget.loadingScriptResultWriteback,
          loadingScriptPlanResultWriteback: widget.loadingScriptPlanResultWriteback,
          scopeScriptIdText: widget.scriptIdController.text,
          workspaceAssistantText: widget.workspaceAssistantText,
          workspaceScriptWritebackSource: widget.workspaceScriptWritebackSource,
          workspaceScriptWritebackCandidate: widget.workspaceScriptWritebackCandidate,
          workspaceScriptPlanWritebackCandidate: widget.workspaceScriptPlanWritebackCandidate,
          workspaceScriptPlanRowId: widget.workspaceScriptPlanRowId,
          workspaceLastToolName: widget.workspaceLastToolName,
          workspaceLastToolResultData: widget.workspaceLastToolResultData,
          workspaceWritebackLine: widget.workspaceWritebackLine,
          onSelectPrompt: (String prompt) {
            setState(() => widget.scriptPromptController.text = prompt);
          },
          onScriptDomainToolChanged: (String value) {
            setState(() {
              _selectedScriptDomainTool = value;
              _maybeApplyScriptToolArgsPreset(value);
            });
          },
          onRunScriptWorkspace: widget.onRunScriptWorkspace,
          onProbeScriptDomainTool: () => widget.onProbeScriptDomainTool(
            _selectedScriptDomainTool,
            widget.scriptDomainArgsController.text,
          ),
          onScriptSubAgentChanged: (String value) {
            setState(() => widget.scriptSubAgentToolController.text = value);
          },
          onRunScriptSubAgentTool: widget.onRunScriptSubAgentTool,
          onWriteBackScriptResult: widget.onWriteBackScriptResult,
          onWriteBackScriptPlanResult: widget.onWriteBackScriptPlanResult,
          onWriteBackScriptPlanViaUpdateData:
              widget.onWriteBackScriptPlanViaUpdateData,
        );
      case AgentWorkspacePane.production:
        return AgentWorkspaceProductionCard(
          busy: _busy,
          productionPromptController: widget.productionPromptController,
          productionDomainToolController: widget.productionDomainToolController,
          productionDomainArgsController: widget.productionDomainArgsController,
          productionSubAgentToolController: widget.productionSubAgentToolController,
          flowKeyController: widget.flowKeyController,
          productionPromptPresets: _productionPromptPresets,
          productionDomainToolPresets: _productionDomainToolPresets,
          productionSubAgentPresets: _productionSubAgentPresets,
          flowKeyPresets: _flowKeyPresets,
          loadingProductionWorkspaceRun: widget.loadingProductionWorkspaceRun,
          loadingProductionFlowProbe: widget.loadingProductionFlowProbe,
          loadingProductionSubAgentRun: widget.loadingProductionSubAgentRun,
          loadingProductionResultWriteback: widget.loadingProductionResultWriteback,
          workspaceLastToolResultLine: widget.workspaceLastToolResultLine,
          workspaceLastToolName: widget.workspaceLastToolName,
          workspaceLastToolResultData: widget.workspaceLastToolResultData,
          workspaceSuggestedFlowKey: widget.workspaceSuggestedFlowKey,
          onSelectPrompt: (String prompt) {
            setState(() => widget.productionPromptController.text = prompt);
          },
          onProductionDomainToolChanged: (String value) {
            setState(() {
              widget.productionDomainToolController.text = value;
              _maybeApplyProductionToolArgsPreset(value);
            });
          },
          onFlowKeyChanged: (String value) {
            setState(() {
              widget.flowKeyController.text = value;
              if (widget.productionDomainToolController.text.trim() == 'get_flowData') {
                _maybeApplyProductionToolArgsPreset('get_flowData');
              }
            });
          },
          onRunProductionWorkspace: widget.onRunProductionWorkspace,
          onProbeProductionDomainTool: widget.onProbeProductionDomainTool,
          onProductionSubAgentChanged: (String value) {
            setState(() => widget.productionSubAgentToolController.text = value);
          },
          onRunProductionSubAgentTool: widget.onRunProductionSubAgentTool,
          onWriteBackProductionFlowResult: widget.onWriteBackProductionFlowResult,
          onApplySuggestedFlowKey: widget.onApplySuggestedFlowKey,
        );
      case AgentWorkspacePane.activity:
        return AgentWorkspaceActivityPanel(
          wsLog: widget.wsLog,
          workspaceAssistantText: widget.workspaceAssistantText,
          workspaceLastToolResultLine: widget.workspaceLastToolResultLine,
          workspaceWritebackLine: widget.workspaceWritebackLine,
        );
    }
  }

  /// Agent 工作区外层视图，负责标题、范围输入与 pane 壳层布局。
  Widget _buildAgentWorkspacesSectionView(BuildContext context) {
    final title = widget.sectionTitle ?? 'Agent 工作区';
    final description = widget.sectionDescription ??
        '将 script 与 production 工作流拆分为独立面板，并把执行日志归并到单独执行动态面板。';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const SizedBox(height: 16),
        Text(title, style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 4),
        Text(description, style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 12),
        AgentWorkspaceScopeInputs(
          projectIdController: widget.projectIdController,
          scriptIdController: widget.scriptIdController,
        ),
        if (widget.showPaneSelector) ...<Widget>[
          const SizedBox(height: 12),
          AgentWorkspacePaneSelector(
            selectedPane: _pane,
            onSelected: (AgentWorkspacePane nextPane) {
              if (_pane == nextPane) {
                return;
              }
              setState(() => _pane = nextPane);
            },
          ),
        ],
        const SizedBox(height: 12),
        _buildPaneBody(context),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return _buildAgentWorkspacesSectionView(context);
  }
}

