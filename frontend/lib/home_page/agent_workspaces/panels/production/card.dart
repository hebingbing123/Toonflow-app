import 'dart:convert';

import 'package:flutter/material.dart';

import '../../panel_support.dart';
import '../../prompt_preset.dart';
import '../../contexts/production/action_panels.dart';
import '../../contexts/production/card_panels.dart';
import '../../contexts/production/context_snapshot.dart';
import '../../contexts/production/flow_logic.dart';
import '../../contexts/production/status_panels.dart';
import '../../contexts/production/support.dart';

class AgentWorkspaceProductionCard extends StatefulWidget {
  const AgentWorkspaceProductionCard({
    super.key,
    required this.busy,
    required this.productionPromptController,
    required this.productionDomainToolController,
    required this.productionDomainArgsController,
    required this.productionSubAgentToolController,
    required this.flowKeyController,
    required this.productionPromptPresets,
    required this.productionDomainToolPresets,
    required this.productionSubAgentPresets,
    required this.flowKeyPresets,
    required this.loadingProductionWorkspaceRun,
    required this.loadingProductionFlowProbe,
    required this.loadingProductionSubAgentRun,
    required this.loadingProductionResultWriteback,
    required this.workspaceLastToolResultLine,
    this.workspaceLastToolName,
    this.workspaceLastToolResultData,
    required this.workspaceSuggestedFlowKey,
    required this.onSelectPrompt,
    required this.onProductionDomainToolChanged,
    required this.onFlowKeyChanged,
    required this.onRunProductionWorkspace,
    required this.onProbeProductionDomainTool,
    required this.onProductionSubAgentChanged,
    required this.onRunProductionSubAgentTool,
    required this.onWriteBackProductionFlowResult,
    required this.onApplySuggestedFlowKey,
  });

  final bool busy;
  final TextEditingController productionPromptController;
  final TextEditingController productionDomainToolController;
  final TextEditingController productionDomainArgsController;
  final TextEditingController productionSubAgentToolController;
  final TextEditingController flowKeyController;
  final List<AgentWorkspacePromptPreset> productionPromptPresets;
  final List<String> productionDomainToolPresets;
  final List<String> productionSubAgentPresets;
  final List<String> flowKeyPresets;
  final bool loadingProductionWorkspaceRun;
  final bool loadingProductionFlowProbe;
  final bool loadingProductionSubAgentRun;
  final bool loadingProductionResultWriteback;
  final String? workspaceLastToolResultLine;
  final String? workspaceLastToolName;
  final Object? workspaceLastToolResultData;
  final String? workspaceSuggestedFlowKey;
  final ValueChanged<String> onSelectPrompt;
  final ValueChanged<String> onProductionDomainToolChanged;
  final ValueChanged<String> onFlowKeyChanged;
  final VoidCallback onRunProductionWorkspace;
  final VoidCallback onProbeProductionDomainTool;
  final ValueChanged<String> onProductionSubAgentChanged;
  final VoidCallback onRunProductionSubAgentTool;
  final VoidCallback onWriteBackProductionFlowResult;
  final VoidCallback onApplySuggestedFlowKey;

  @override
  State<AgentWorkspaceProductionCard> createState() =>
      _AgentWorkspaceProductionCardState();
}

class _AgentWorkspaceProductionCardState
    extends State<AgentWorkspaceProductionCard> {
  String? _taskStatusLine;

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

  void _setTaskStatus(String message) {
    if (!mounted) return;
    setState(() => _taskStatusLine = message);
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

  Map<String, dynamic> _flowDataArgsTemplate() {
    final flowKey = widget.flowKeyController.text.trim();
    return <String, dynamic>{'key': flowKey.isEmpty ? 'assets' : flowKey};
  }

  List<({String label, Map<String, dynamic> args})> _argumentTemplates() {
    switch (_selectedProductionTool) {
      case 'get_flowData':
        return <({String label, Map<String, dynamic> args})>[
          (label: '模板: 仅 key', args: _flowDataArgsTemplate()),
          (label: '模板: 默认 assets', args: <String, dynamic>{'key': 'assets'}),
        ];
      case 'add_deriveAsset':
      case 'del_deriveAsset':
      case 'generate_deriveAsset':
        return <({String label, Map<String, dynamic> args})>[
          (
            label: '模板: ID 列表',
            args: <String, dynamic>{
              'ids': <int>[1],
            },
          ),
        ];
      case 'generate_storyboard':
        return <({String label, Map<String, dynamic> args})>[
          (
            label: '模板: 分镜 ID',
            args: <String, dynamic>{
              'ids': <int>[1],
            },
          ),
        ];
      default:
        return const <({String label, Map<String, dynamic> args})>[];
    }
  }

  void _applyToolArgsTemplate(Map<String, dynamic> args, String label) {
    widget.productionDomainArgsController.text = jsonEncode(args);
    _setTaskStatus('已填充参数模板：$label');
  }

  Widget _buildArgumentTemplates() {
    final templates = _argumentTemplates();
    if (templates.isEmpty) return const SizedBox.shrink();
    return ProductionWorkspaceArgumentTemplatesPanel(
      busy: widget.busy,
      templates: templates
          .map(
            (entry) => ProductionWorkspaceArgumentTemplateEntry(
              label: entry.label,
              payload: entry.args,
            ),
          )
          .toList(growable: false),
      onApplyTemplate: _applyToolArgsTemplate,
    );
  }

  List<ProductionWorkspaceArgumentSuggestion> _buildActionSuggestions() {
    return buildProductionActionArgumentSuggestions(
      selectedTool: _selectedProductionTool,
      toolName: widget.workspaceLastToolName,
      suggestedFlowKey: _suggestedFlowKeyLine,
      result: widget.workspaceLastToolResultData,
    );
  }

  List<int> _buildActionCandidateIds() {
    return extractProductionActionCandidateIds(
      selectedTool: _selectedProductionTool,
      toolName: widget.workspaceLastToolName,
      suggestedFlowKey: _suggestedFlowKeyLine,
      result: widget.workspaceLastToolResultData,
    );
  }

  void _applyActionSuggestion(
    ProductionWorkspaceArgumentSuggestion suggestion,
  ) {
    widget.productionDomainArgsController.text = jsonEncode(suggestion.payload);
    _setTaskStatus('已填充候选参数：${suggestion.label}');
  }

  Widget _buildActionCandidateTemplates(BuildContext context) {
    final suggestions = _buildActionSuggestions();
    if (suggestions.isEmpty) return const SizedBox.shrink();
    return ProductionWorkspaceActionCandidatesPanel(
      busy: widget.busy,
      suggestions: suggestions,
      candidateIds: _buildActionCandidateIds(),
      onApplySuggestion: _applyActionSuggestion,
    );
  }

  List<String> _buildResultSummaryLines() {
    final toolName = widget.workspaceLastToolName?.trim();
    final result = widget.workspaceLastToolResultData;
    final lines = <String>[
      if (toolName != null && toolName.isNotEmpty) 'tool=$toolName',
      if (result != null) 'resultType=${result.runtimeType}',
      ...summarizeProductionResultSnapshot(toolName, result),
    ];
    return lines.take(6).toList(growable: false);
  }

  List<Widget> _buildContextSnapshot(BuildContext context) {
    return <Widget>[
      ProductionContextSnapshotView(
        workspaceLastToolName: widget.workspaceLastToolName,
        workspaceLastToolResultData: widget.workspaceLastToolResultData,
      ),
    ];
  }

  List<ProductionWorkspaceRecipe> _buildWorkspaceRecipes() {
    return buildProductionWorkspaceRecipes(
      toolName: widget.workspaceLastToolName,
      suggestedFlowKey: _suggestedFlowKeyLine,
      result: widget.workspaceLastToolResultData,
    );
  }

  List<ProductionWorkspaceStage> _buildWorkspaceStages() {
    return buildProductionWorkspaceStages(
      toolName: widget.workspaceLastToolName,
      suggestedFlowKey: _suggestedFlowKeyLine,
      result: widget.workspaceLastToolResultData,
    );
  }

  void _applyWorkspaceRecipe(ProductionWorkspaceRecipe recipe) {
    widget.onFlowKeyChanged(recipe.flowKey);
    if (recipe.domainTool != null && recipe.domainTool!.trim().isNotEmpty) {
      widget.onProductionDomainToolChanged(recipe.domainTool!.trim());
      widget.productionDomainArgsController.text = jsonEncode(<String, dynamic>{
        'key': recipe.flowKey,
      });
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
          <String, dynamic>{'key': stage.flowKey},
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
    if (stage.subAgentTool == null || stage.subAgentTool!.trim().isEmpty) return;
    _runProductionSubAgentTool();
  }

  void _runWorkspaceRecipeDomainTool(ProductionWorkspaceRecipe recipe) {
    _applyWorkspaceRecipe(recipe);
    if (recipe.domainTool == null || recipe.domainTool!.trim().isEmpty) return;
    _probeProductionDomainTool();
  }

  void _runWorkspaceRecipeSubAgent(ProductionWorkspaceRecipe recipe) {
    _applyWorkspaceRecipe(recipe);
    if (recipe.subAgentTool == null || recipe.subAgentTool!.trim().isEmpty) return;
    _runProductionSubAgentTool();
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
        _applyProductionPromptIfEmpty(
          '请基于当前资产 flow 给出下一轮衍生素材生成建议，并执行最小可行推进。',
        );
        widget.onProductionSubAgentChanged('run_sub_agent_derive_assets');
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
          '请基于当前分镜 flow 输出下一轮分镜生成计划，并执行最小可行生成动作。',
        );
        widget.onProductionSubAgentChanged('run_sub_agent_storyboard_gen');
        _runProductionSubAgentTool();
      },
      onRunDirectorPlanSubAgent: () {
        widget.onFlowKeyChanged('scriptPlan');
        _applyProductionPromptIfEmpty(
          '请结合 scriptPlan 与现有素材状态，产出下一轮导演计划并给出执行优先级。',
        );
        widget.onProductionSubAgentChanged('run_sub_agent_director_plan');
        _runProductionSubAgentTool();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final resultSummaryLines = _buildResultSummaryLines();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text('制作工作区', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text('引导任务', style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 6),
            _buildGuidedTasks(),
            const SizedBox(height: 10),
            _buildPromptTemplates(),
            const SizedBox(height: 8),
            ProductionWorkspaceControlsPanel(
              busy: widget.busy,
              loadingProductionWorkspaceRun: widget.loadingProductionWorkspaceRun,
              loadingProductionFlowProbe: widget.loadingProductionFlowProbe,
              loadingProductionSubAgentRun: widget.loadingProductionSubAgentRun,
              loadingProductionResultWriteback:
                  widget.loadingProductionResultWriteback,
              hasLastToolResult: widget.workspaceLastToolResultLine != null,
              productionPromptController: widget.productionPromptController,
              productionDomainArgsController:
                  widget.productionDomainArgsController,
              productionDomainToolPresets: widget.productionDomainToolPresets,
              productionSubAgentPresets: widget.productionSubAgentPresets,
              flowKeyPresets: widget.flowKeyPresets,
              selectedProductionDomainTool: resolveWorkspaceDropdownValue(
                widget.productionDomainToolController.text.trim(),
                widget.productionDomainToolPresets,
              ),
              selectedProductionSubAgentTool: resolveWorkspaceDropdownValue(
                widget.productionSubAgentToolController.text.trim(),
                widget.productionSubAgentPresets,
              ),
              selectedFlowKey: resolveWorkspaceDropdownValue(
                widget.flowKeyController.text.trim(),
                widget.flowKeyPresets,
              ),
              onRunProductionWorkspace: _runProductionWorkspace,
              onProductionDomainToolChanged: widget.onProductionDomainToolChanged,
              onFlowKeyChanged: widget.onFlowKeyChanged,
              onProbeProductionDomainTool: _probeProductionDomainTool,
              onProductionSubAgentChanged: widget.onProductionSubAgentChanged,
              onRunProductionSubAgentTool: _runProductionSubAgentTool,
              onWriteBackProductionFlowResult: _writeBackProductionFlowResult,
              argumentTemplates: _argumentTemplates().isEmpty
                  ? null
                  : _buildArgumentTemplates(),
              actionCandidatePanel: _buildActionSuggestions().isEmpty
                  ? null
                  : _buildActionCandidateTemplates(context),
            ),
            ProductionWorkspaceStatusPanel(
              resultSummaryLines: resultSummaryLines,
              onApplySuggestedFlowKey: widget.onApplySuggestedFlowKey,
              busy: widget.busy,
              runningTaskLine: _runningTaskLine,
              taskStatusLine: _taskStatusLine,
              workspaceLastToolResultLine: widget.workspaceLastToolResultLine,
              suggestedFlowKeyLine: _suggestedFlowKeyLine,
            ),
            _buildWorkspaceStagesPanel(context),
            _buildWorkspaceDiagnosis(context),
            ..._buildContextSnapshot(context),
          ],
        ),
      ),
    );
  }
}
