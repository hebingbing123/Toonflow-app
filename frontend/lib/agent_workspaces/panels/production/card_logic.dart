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
    if (widget.loadingProductionWorkspaceRun) return '执行中：运行制作工作流';
    if (widget.loadingProductionFlowProbe) return '执行中：读取制作工具结果';
    if (widget.loadingProductionSubAgentRun) return '执行中：运行子代理';
    if (widget.loadingProductionResultWriteback) return '执行中：写回工具结果';
    return null;
  }

  bool _validateJsonArgs(String raw) {
    final normalized = raw.trim();
    if (normalized.isEmpty) return true;
    try {
      final decoded = jsonDecode(normalized);
      if (decoded is Map<String, dynamic>) return true;
      _setTaskStatus('拦截：制作工具参数必须是 JSON object。');
      return false;
    } catch (_) {
      _setTaskStatus('拦截：制作工具参数 JSON 解析失败。');
      return false;
    }
  }

  bool _validatePrompt(String action) {
    if (widget.productionPromptController.text.trim().isNotEmpty) return true;
    _setTaskStatus('拦截：$action 需要非空工作区提示词。');
    return false;
  }

  bool _validateFlowProbe() {
    final tool = widget.productionDomainToolController.text.trim();
    if (tool.isEmpty) {
      _setTaskStatus('拦截：读取前需要选择制作域工具。');
      return false;
    }
    if (!_validateJsonArgs(widget.productionDomainArgsController.text)) {
      return false;
    }
    if (tool == 'get_flowData' &&
        widget.flowKeyController.text.trim().isEmpty) {
      _setTaskStatus('拦截：get_flowData 需要有效 flow key。');
      return false;
    }
    return true;
  }

  bool _normalizeArgsForProbe() {
    final tool = widget.productionDomainToolController.text.trim();
    final raw = widget.productionDomainArgsController.text.trim();
    if (raw.isEmpty) {
      widget.productionDomainArgsController.text = '{}';
    }
    final decoded = jsonDecode(
      widget.productionDomainArgsController.text.trim(),
    );
    if (decoded is! Map<String, dynamic>) {
      _setTaskStatus('拦截：制作工具参数必须是 JSON object。');
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
    _setTaskStatus('已同步：get_flowData arguments.key -> $key');
    return true;
  }

  bool _validateSubAgentTool() {
    if (widget.productionSubAgentToolController.text.trim().isEmpty) {
      _setTaskStatus('拦截：运行子代理前需要选择制作子代理工具。');
      return false;
    }
    if (!_validateJsonArgs(widget.productionSubAgentArgsController.text)) {
      return false;
    }
    return _validatePrompt('运行子代理');
  }

  void _runProductionWorkspace() {
    if (!_validatePrompt('运行制作工作流')) return;
    widget.onRunProductionWorkspace();
    _setTaskStatus('已触发：运行制作工作流');
  }

  void _probeProductionDomainTool() {
    if (!_validateFlowProbe()) return;
    if (!_normalizeArgsForProbe()) return;
    widget.onProbeProductionDomainTool();
    final tool = widget.productionDomainToolController.text.trim();
    final key = widget.flowKeyController.text.trim();
    final suffix = tool == 'get_flowData' ? ' key=$key' : '';
    _setTaskStatus('已触发：读取制作工具 ($tool$suffix)');
  }

  void _runProductionSubAgentTool() {
    if (!_validateSubAgentTool()) return;
    widget.onRunProductionSubAgentTool();
    final tool = widget.productionSubAgentToolController.text.trim();
    _setTaskStatus('已触发：运行子代理 ($tool)');
  }

  void _writeBackProductionFlowResult() {
    if (widget.workspaceLastToolResultLine == null) {
      _setTaskStatus('拦截：暂无工具结果可写回。');
      return;
    }
    if (widget.flowKeyController.text.trim().isEmpty) {
      _setTaskStatus('拦截：写回前请提供有效 flow key。');
      return;
    }
    widget.onWriteBackProductionFlowResult();
    final key = widget.flowKeyController.text.trim();
    _setTaskStatus('已触发：写回工具结果 -> flow[$key]');
  }

  void _applyProductionPromptIfEmpty(String prompt) {
    if (widget.productionPromptController.text.trim().isNotEmpty) return;
    widget.productionPromptController.text = prompt;
  }

  String get _selectedProductionTool =>
      widget.productionDomainToolController.text.trim();

  Widget _buildGuidedTasks() {
    return ProductionWorkspaceGuidedTasksPanel(
      busy: widget.busy,
      hasLastResult: widget.workspaceLastToolResultLine != null,
      onPullAssetsFlow: () {
        widget.onFlowKeyChanged('assets');
        widget.onProductionDomainToolChanged('get_flowData');
        _probeProductionDomainTool();
      },
      onRunAssetsSubAgent: () {
        _applyProductionPromptIfEmpty('请基于当前资产 flow 给出下一轮衍生素材生成建议，并执行最小可行推进。');
        widget.onProductionSubAgentChanged('run_sub_agent_derive_assets');
        widget.productionSubAgentArgsController.text = '{}';
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
        _applyProductionPromptIfEmpty('请基于当前分镜 flow 输出下一轮分镜生成计划，并执行最小可行生成动作。');
        widget.onProductionSubAgentChanged('run_sub_agent_storyboard_gen');
        widget.productionSubAgentArgsController.text = '{}';
        _runProductionSubAgentTool();
      },
      onRunDirectorPlanSubAgent: () {
        widget.onFlowKeyChanged('scriptPlan');
        _applyProductionPromptIfEmpty(
          '请结合 scriptPlan 与现有素材状态，产出下一轮导演计划并给出执行优先级。',
        );
        widget.onProductionSubAgentChanged('run_sub_agent_director_plan');
        widget.productionSubAgentArgsController.text = '{}';
        _runProductionSubAgentTool();
      },
    );
  }
}
