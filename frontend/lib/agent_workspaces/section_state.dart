part of 'section.dart';

class _AgentWorkspacesSectionState extends State<AgentWorkspacesSection> {
  late AgentWorkspacePane _pane;
  late final TextEditingController _fallbackProductionSubAgentArgsController;
  late final TextEditingController _effectiveProjectUuidController;
  late final TextEditingController _effectiveScriptUuidController;
  late final TextEditingController _effectiveWorkspaceUuidController;
  late final bool _ownsUuidScopeControllers;
  late String _lastScriptDomainToolName;
  late int _lastScriptDomainFocusRevision;
  late String _lastProductionDomainToolName;
  late String _lastProductionFlowKey;
  late int _lastProductionDomainFocusRevision;

  TextEditingController get _productionSubAgentArgsController =>
      widget.productionSubAgentArgsController ??
      _fallbackProductionSubAgentArgsController;

  @override
  void initState() {
    super.initState();
    _pane = widget.initialPane;
    _fallbackProductionSubAgentArgsController = TextEditingController(
      text: '{}',
    );
    final pu = widget.projectUuidController;
    final su = widget.scriptUuidController;
    if (pu != null && su != null) {
      final wu = widget.workspaceUuidController;
      if (wu == null) {
        throw FlutterError.fromParts(<DiagnosticsNode>[
          ErrorSummary(
            'AgentWorkspacesSection.workspaceUuidController is required when projectUuidController and scriptUuidController are provided.',
          ),
        ]);
      }
      _effectiveProjectUuidController = pu;
      _effectiveScriptUuidController = su;
      _effectiveWorkspaceUuidController = wu;
      _ownsUuidScopeControllers = false;
    } else if (pu == null && su == null) {
      _effectiveProjectUuidController = TextEditingController();
      _effectiveScriptUuidController = TextEditingController();
      _effectiveWorkspaceUuidController = TextEditingController();
      _ownsUuidScopeControllers = true;
    } else {
      throw FlutterError.fromParts(<DiagnosticsNode>[
        ErrorSummary(
          'AgentWorkspacesSection.projectUuidController and scriptUuidController must both be null or both non-null.',
        ),
      ]);
    }
    _lastScriptDomainToolName = widget.scriptDomainToolController.text.trim();
    _lastScriptDomainFocusRevision = widget.scriptDomainFocusRevision.value;
    _lastProductionDomainToolName = widget.productionDomainToolController.text
        .trim();
    _lastProductionFlowKey = widget.flowKeyController.text.trim();
    _lastProductionDomainFocusRevision =
        widget.productionDomainFocusRevision.value;
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
    if (widget.scriptDomainToolController.text.trim().isEmpty) {
      widget.scriptDomainToolController.text = _scriptDomainToolPresets.first;
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
    if (_productionSubAgentArgsController.text.trim().isEmpty) {
      _productionSubAgentArgsController.text = '{}';
    }
    _syncScriptDomainArgsWithExternalToolChange();
    _syncProductionDomainArgsWithExternalChange();
  }

  String _trimmedControllerText(TextEditingController controller) =>
      controller.text.trim();

  void _setTrimmedTextIfPresent(
    TextEditingController controller,
    String? value,
  ) {
    final normalized = value?.trim();
    if (normalized == null || normalized.isEmpty) {
      return;
    }
    controller.text = normalized;
  }

  void _setJsonTextIfPresent(
    TextEditingController controller,
    Map<String, dynamic>? value,
  ) {
    if (value == null) {
      return;
    }
    controller.text = jsonEncode(value);
  }

  void _recordScriptFocusRevision() {
    _lastScriptDomainToolName = _trimmedControllerText(
      widget.scriptDomainToolController,
    );
    widget.scriptDomainFocusRevision.value++;
    _lastScriptDomainFocusRevision = widget.scriptDomainFocusRevision.value;
  }

  void _recordProductionFocusRevision() {
    _lastProductionDomainToolName = _trimmedControllerText(
      widget.productionDomainToolController,
    );
    _lastProductionFlowKey = _trimmedControllerText(widget.flowKeyController);
    widget.productionDomainFocusRevision.value++;
    _lastProductionDomainFocusRevision =
        widget.productionDomainFocusRevision.value;
  }

  bool _shouldSkipExternalPresetSync({
    required int currentRevision,
    required int lastRevision,
    required VoidCallback updateTracking,
  }) {
    if (currentRevision == lastRevision) {
      return false;
    }
    updateTracking();
    return true;
  }

  void _recordScriptSyncState({String? toolName, int? revision}) {
    _lastScriptDomainToolName =
        toolName ?? _trimmedControllerText(widget.scriptDomainToolController);
    _lastScriptDomainFocusRevision =
        revision ?? widget.scriptDomainFocusRevision.value;
  }

  void _recordProductionSyncState({
    String? toolName,
    String? flowKey,
    int? revision,
  }) {
    _lastProductionDomainToolName =
        toolName ??
        _trimmedControllerText(widget.productionDomainToolController);
    _lastProductionFlowKey =
        flowKey ?? _trimmedControllerText(widget.flowKeyController);
    _lastProductionDomainFocusRevision =
        revision ?? widget.productionDomainFocusRevision.value;
  }

  void _syncScriptDomainArgsWithExternalToolChange() {
    final currentTool = _trimmedControllerText(
      widget.scriptDomainToolController,
    );
    final currentRevision = widget.scriptDomainFocusRevision.value;
    if (_shouldSkipExternalPresetSync(
      currentRevision: currentRevision,
      lastRevision: _lastScriptDomainFocusRevision,
      updateTracking: () => _recordScriptSyncState(
        toolName: currentTool,
        revision: currentRevision,
      ),
    )) {
      return;
    }
    if (currentTool.isEmpty || currentTool == _lastScriptDomainToolName) {
      _recordScriptSyncState(toolName: currentTool, revision: currentRevision);
      return;
    }
    final currentArgs = widget.scriptDomainArgsController.text;
    final shouldApplyPreset =
        _isDefaultJsonObject(currentArgs) ||
        _matchesScriptToolArgsPresetText(
          raw: currentArgs,
          toolName: _lastScriptDomainToolName,
          scriptIdText: widget.scriptIdController.text,
        );
    if (shouldApplyPreset) {
      widget.scriptDomainArgsController.text = _buildScriptToolArgsPresetText(
        toolName: currentTool,
        scriptIdText: widget.scriptIdController.text,
      );
    }
    _recordScriptSyncState(toolName: currentTool, revision: currentRevision);
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

  void _applyScriptFocus({
    String? domainTool,
    Map<String, dynamic>? domainArgs,
    String? subAgentTool,
    String? prompt,
  }) {
    _setTrimmedTextIfPresent(widget.scriptDomainToolController, domainTool);
    _setJsonTextIfPresent(widget.scriptDomainArgsController, domainArgs);
    _setTrimmedTextIfPresent(widget.scriptSubAgentToolController, subAgentTool);
    _setTrimmedTextIfPresent(widget.scriptPromptController, prompt);
    _recordScriptFocusRevision();
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

  void _syncProductionDomainArgsWithExternalChange() {
    final currentTool = _trimmedControllerText(
      widget.productionDomainToolController,
    );
    final currentFlowKey = _trimmedControllerText(widget.flowKeyController);
    final currentRevision = widget.productionDomainFocusRevision.value;
    if (_shouldSkipExternalPresetSync(
      currentRevision: currentRevision,
      lastRevision: _lastProductionDomainFocusRevision,
      updateTracking: () => _recordProductionSyncState(
        toolName: currentTool,
        flowKey: currentFlowKey,
        revision: currentRevision,
      ),
    )) {
      return;
    }
    final toolChanged =
        currentTool.isNotEmpty && currentTool != _lastProductionDomainToolName;
    final flowKeyChanged = currentFlowKey != _lastProductionFlowKey;
    if (!toolChanged && !flowKeyChanged) {
      _recordProductionSyncState(
        toolName: currentTool,
        flowKey: currentFlowKey,
        revision: currentRevision,
      );
      return;
    }
    final currentArgs = widget.productionDomainArgsController.text;
    final shouldApplyPreset =
        _isDefaultJsonObject(currentArgs) ||
        _matchesProductionToolArgsPresetText(
          raw: currentArgs,
          toolName: _lastProductionDomainToolName,
          scriptIdText: widget.scriptIdController.text,
          flowKeyText: _lastProductionFlowKey,
        );
    if (shouldApplyPreset) {
      widget.productionDomainArgsController.text =
          _buildProductionToolArgsPresetText(
            toolName: currentTool,
            scriptIdText: widget.scriptIdController.text,
            flowKeyText: currentFlowKey,
          );
    }
    _recordProductionSyncState(
      toolName: currentTool,
      flowKey: currentFlowKey,
      revision: currentRevision,
    );
  }

  void _maybeApplyProductionSubAgentArgsPreset(String toolName) {
    final current = _productionSubAgentArgsController.text;
    if (!_isDefaultJsonObject(current)) {
      return;
    }
    _productionSubAgentArgsController.text = jsonEncode(
      buildProductionSuggestedSubAgentArgs(
        subAgentTool: toolName,
        toolName: widget.workspaceLastToolName,
        suggestedFlowKey: widget.workspaceSuggestedFlowKey,
        result: widget.workspaceLastToolResultData,
        toolArguments: widget.workspaceLastToolArguments,
      ),
    );
  }

  void _applyProductionFocus({
    String? flowKey,
    String? domainTool,
    Map<String, dynamic>? domainArgs,
    String? subAgentTool,
    Map<String, dynamic>? subAgentArgs,
    String? prompt,
  }) {
    _setTrimmedTextIfPresent(widget.flowKeyController, flowKey);
    _setTrimmedTextIfPresent(widget.productionDomainToolController, domainTool);
    _setJsonTextIfPresent(widget.productionDomainArgsController, domainArgs);
    _setTrimmedTextIfPresent(
      widget.productionSubAgentToolController,
      subAgentTool,
    );
    _setJsonTextIfPresent(_productionSubAgentArgsController, subAgentArgs);
    _setTrimmedTextIfPresent(widget.productionPromptController, prompt);
    _recordProductionFocusRevision();
  }

  void _selectScriptPrompt(String prompt) {
    widget.scriptPromptController.text = prompt;
  }

  void _changeScriptDomainTool(String value) {
    widget.scriptDomainToolController.text = value;
    _lastScriptDomainToolName = value.trim();
    _maybeApplyScriptToolArgsPreset(value);
  }

  void _changeScriptSubAgentTool(String value) {
    widget.scriptSubAgentToolController.text = value;
  }

  void _selectProductionPrompt(String prompt) {
    widget.productionPromptController.text = prompt;
  }

  void _changeProductionDomainTool(String value) {
    widget.productionDomainToolController.text = value;
    _lastProductionDomainToolName = value.trim();
    _maybeApplyProductionToolArgsPreset(value);
  }

  void _changeProductionFlowKey(String value) {
    widget.flowKeyController.text = value;
    _lastProductionFlowKey = value.trim();
    if (_trimmedControllerText(widget.productionDomainToolController) ==
        'get_flowData') {
      _maybeApplyProductionToolArgsPreset('get_flowData');
    }
  }

  void _changeProductionSubAgentTool(String value) {
    widget.productionSubAgentToolController.text = value;
    _productionSubAgentArgsController.text = '{}';
    _maybeApplyProductionSubAgentArgsPreset(value);
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
    final l10n = resolveAppLocalizationsForErrors(context);
    switch (_pane) {
      case AgentWorkspacePane.script:
        return AgentWorkspaceScriptCard(
          showCardTitle: widget.sectionTitle == null,
          busy: _busy,
          scriptPromptController: widget.scriptPromptController,
          scriptDomainArgsController: widget.scriptDomainArgsController,
          scriptSubAgentToolController: widget.scriptSubAgentToolController,
          scriptDomainToolPresets: _scriptDomainToolPresets,
          scriptSubAgentPresets: _scriptSubAgentPresets,
          scriptPromptPresets: agentWorkspaceScriptPromptPresets(l10n),
          selectedScriptDomainTool: widget.scriptDomainToolController.text
              .trim(),
          loadingScriptWorkspaceRun: widget.loadingScriptWorkspaceRun,
          loadingScriptDomainProbe: widget.loadingScriptDomainProbe,
          loadingScriptSubAgentRun: widget.loadingScriptSubAgentRun,
          loadingScriptResultWriteback: widget.loadingScriptResultWriteback,
          loadingScriptPlanResultWriteback:
              widget.loadingScriptPlanResultWriteback,
          scopeScriptIdText: widget.scriptIdController.text,
          workspaceAssistantText: widget.workspaceAssistantText,
          workspaceScriptWritebackSource: widget.workspaceScriptWritebackSource,
          workspaceScriptWritebackCandidate:
              widget.workspaceScriptWritebackCandidate,
          workspaceScriptPlanWritebackCandidate:
              widget.workspaceScriptPlanWritebackCandidate,
          workspaceScriptPlanRowId: widget.workspaceScriptPlanRowId,
          workspaceLastToolName: widget.workspaceLastToolName,
          workspaceLastToolResultData: widget.workspaceLastToolResultData,
          workspaceWritebackLine: widget.workspaceWritebackLine,
          onSelectPrompt: (String prompt) {
            setState(() => _selectScriptPrompt(prompt));
          },
          onScriptDomainToolChanged: (String value) {
            setState(() => _changeScriptDomainTool(value));
          },
          onRunScriptWorkspace: widget.onRunScriptWorkspace,
          onProbeScriptDomainTool: () => widget.onProbeScriptDomainTool(
            widget.scriptDomainToolController.text.trim(),
            widget.scriptDomainArgsController.text,
          ),
          onScriptSubAgentChanged: (String value) {
            setState(() => _changeScriptSubAgentTool(value));
          },
          onRunScriptSubAgentTool: widget.onRunScriptSubAgentTool,
          onWriteBackScriptResult: widget.onWriteBackScriptResult,
          onWriteBackScriptPlanResult: widget.onWriteBackScriptPlanResult,
          onWriteBackScriptPlanViaUpdateData:
              widget.onWriteBackScriptPlanViaUpdateData,
          onApplyScriptFocus:
              ({
                String? domainTool,
                Map<String, dynamic>? domainArgs,
                String? subAgentTool,
                String? prompt,
              }) {
                setState(() {
                  _applyScriptFocus(
                    domainTool: domainTool,
                    domainArgs: domainArgs,
                    subAgentTool: subAgentTool,
                    prompt: prompt,
                  );
                });
              },
        );
      case AgentWorkspacePane.production:
        return AgentWorkspaceProductionCard(
          busy: _busy,
          productionPromptController: widget.productionPromptController,
          productionDomainToolController: widget.productionDomainToolController,
          productionDomainArgsController: widget.productionDomainArgsController,
          productionSubAgentArgsController: _productionSubAgentArgsController,
          productionSubAgentToolController:
              widget.productionSubAgentToolController,
          flowKeyController: widget.flowKeyController,
          productionPromptPresets: agentWorkspaceProductionPromptPresets(l10n),
          productionDomainToolPresets: _productionDomainToolPresets,
          productionSubAgentPresets: _productionSubAgentPresets,
          flowKeyPresets: _flowKeyPresets,
          loadingProductionWorkspaceRun: widget.loadingProductionWorkspaceRun,
          loadingProductionFlowProbe: widget.loadingProductionFlowProbe,
          loadingProductionSubAgentRun: widget.loadingProductionSubAgentRun,
          loadingProductionResultWriteback:
              widget.loadingProductionResultWriteback,
          workspaceLastToolResultLine: widget.workspaceLastToolResultLine,
          workspaceLastToolName: widget.workspaceLastToolName,
          workspaceLastToolResultData: widget.workspaceLastToolResultData,
          workspaceLastToolArguments: widget.workspaceLastToolArguments,
          workspaceSuggestedFlowKey: widget.workspaceSuggestedFlowKey,
          onSelectPrompt: (String prompt) {
            setState(() => _selectProductionPrompt(prompt));
          },
          onProductionDomainToolChanged: (String value) {
            setState(() => _changeProductionDomainTool(value));
          },
          onFlowKeyChanged: (String value) {
            setState(() => _changeProductionFlowKey(value));
          },
          onRunProductionWorkspace: widget.onRunProductionWorkspace,
          onProbeProductionDomainTool: widget.onProbeProductionDomainTool,
          onProductionSubAgentChanged: (String value) {
            setState(() => _changeProductionSubAgentTool(value));
          },
          onRunProductionSubAgentTool: widget.onRunProductionSubAgentTool,
          onWriteBackProductionFlowResult:
              widget.onWriteBackProductionFlowResult,
          onApplySuggestedFlowKey: widget.onApplySuggestedFlowKey,
          onApplyProductionFocus:
              ({
                String? flowKey,
                String? domainTool,
                Map<String, dynamic>? domainArgs,
                String? subAgentTool,
                Map<String, dynamic>? subAgentArgs,
                String? prompt,
              }) {
                setState(() {
                  _applyProductionFocus(
                    flowKey: flowKey,
                    domainTool: domainTool,
                    domainArgs: domainArgs,
                    subAgentTool: subAgentTool,
                    subAgentArgs: subAgentArgs,
                    prompt: prompt,
                  );
                });
              },
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
    final l10n = resolveAppLocalizationsForErrors(context);
    final title = widget.sectionTitle ?? l10n.agentWorkspaceSectionTitle;
    final description =
        widget.sectionDescription ?? l10n.agentWorkspaceSectionDescription;
    final header = <Widget>[
      const SizedBox(height: 16),
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Expanded(
            child: Text(title, style: Theme.of(context).textTheme.titleSmall),
          ),
          const RiskyOperationConfirmPrefsOverflowMenu(),
        ],
      ),
      const SizedBox(height: 4),
      Text(description, style: Theme.of(context).textTheme.bodySmall),
    ];

    final scrollableBody = <Widget>[
      AgentWorkspaceScopeInputs(
        projectIdController: widget.projectIdController,
        scriptIdController: widget.scriptIdController,
        projectUuidController: _effectiveProjectUuidController,
        scriptUuidController: _effectiveScriptUuidController,
        workspaceUuidController: _effectiveWorkspaceUuidController,
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
      const SizedBox(height: 24),
    ];

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        if (!constraints.maxHeight.isFinite) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[...header, ...scrollableBody],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            ...header,
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: scrollableBody,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return _buildAgentWorkspacesSectionView(context);
  }

  @override
  void dispose() {
    _fallbackProductionSubAgentArgsController.dispose();
    if (_ownsUuidScopeControllers) {
      _effectiveProjectUuidController.dispose();
      _effectiveScriptUuidController.dispose();
      _effectiveWorkspaceUuidController.dispose();
    }
    super.dispose();
  }
}
