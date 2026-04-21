part of 'section.dart';

class _AgentWorkspacesSectionState extends State<AgentWorkspacesSection> {
  static const List<String> _flowKeyPresets = <String>[
    'assets',
    'script',
    'scriptPlan',
    'storyboardTable',
    'storyboard',
    'workspaceResult',
  ];

  static const List<String> _scriptSubAgentPresets = <String>[
    'run_sub_agent_storySkeleton',
    'run_sub_agent_adaptationStrategy',
    'run_sub_agent_script',
    'run_supervision_agent',
  ];

  static const List<String> _scriptDomainToolPresets = <String>[
    'get_planData',
    'get_script_content',
    'get_novel_text',
    'get_novel_events',
  ];

  static const List<String> _productionSubAgentPresets = <String>[
    'run_sub_agent_director_plan',
    'run_sub_agent_derive_assets',
    'run_sub_agent_generate_assets',
    'run_sub_agent_storyboard_gen',
    'run_sub_agent_storyboard_panel',
    'run_sub_agent_storyboard_table',
  ];

  static const List<String> _productionDomainToolPresets = <String>[
    'get_flowData',
    'add_deriveAsset',
    'del_deriveAsset',
    'generate_deriveAsset',
    'generate_storyboard',
  ];

  static const List<AgentWorkspacePromptPreset> _scriptPromptPresets =
      <AgentWorkspacePromptPreset>[
        AgentWorkspacePromptPreset(
          label: '剧情骨架',
          prompt:
              '先读取 get_planData 与 get_novel_events，总结当前剧情骨架缺口，再给出下一轮 script 生成建议。',
        ),
        AgentWorkspacePromptPreset(
          label: '章节改编',
          prompt:
              '基于 get_novel_text 与 get_script_content，对当前章节做改编策略建议，输出 3 条可执行脚本改写项。',
        ),
      ];

  static const List<AgentWorkspacePromptPreset> _productionPromptPresets =
      <AgentWorkspacePromptPreset>[
        AgentWorkspacePromptPreset(
          label: '资产盘点',
          prompt: '先调用 get_flowData key=assets，盘点现有资产状态并给出下一步 production 任务建议。',
        ),
        AgentWorkspacePromptPreset(
          label: '分镜推进',
          prompt:
              '读取 get_flowData key=storyboard，评估当前分镜完成度并给出下一次 generate_storyboard 的执行建议。',
        ),
      ];

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

  bool _isDefaultJsonObject(String raw) {
    final trimmed = raw.trim();
    return trimmed.isEmpty || trimmed == '{}';
  }

  void _maybeApplyScriptToolArgsPreset(String toolName) {
    final current = widget.scriptDomainArgsController.text;
    if (!_isDefaultJsonObject(current)) {
      return;
    }
    final scriptId = int.tryParse(widget.scriptIdController.text.trim());
    final Map<String, dynamic> preset;
    switch (toolName) {
      case 'get_script_content':
        preset = scriptId != null && scriptId > 0
            ? <String, dynamic>{'scriptId': scriptId}
            : <String, dynamic>{'scriptId': 1};
        break;
      case 'get_novel_text':
      case 'get_novel_events':
        preset = <String, dynamic>{'novelId': 1};
        break;
      case 'get_planData':
      default:
        preset = <String, dynamic>{};
        break;
    }
    widget.scriptDomainArgsController.text = jsonEncode(preset);
  }

  void _maybeApplyProductionToolArgsPreset(String toolName) {
    final current = widget.productionDomainArgsController.text;
    if (!_isDefaultJsonObject(current)) {
      return;
    }
    final scriptId = int.tryParse(widget.scriptIdController.text.trim());
    final flowKey = widget.flowKeyController.text.trim();
    final Map<String, dynamic> preset;
    switch (toolName) {
      case 'get_flowData':
        preset = <String, dynamic>{
          'key': flowKey.isEmpty ? 'assets' : flowKey,
          if (scriptId != null && scriptId > 0) 'scriptId': scriptId,
        };
        break;
      case 'add_deriveAsset':
      case 'del_deriveAsset':
      case 'generate_deriveAsset':
      case 'generate_storyboard':
        preset = <String, dynamic>{
          'ids': <int>[1],
        };
        break;
      default:
        preset = <String, dynamic>{};
        break;
    }
    widget.productionDomainArgsController.text = jsonEncode(preset);
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

