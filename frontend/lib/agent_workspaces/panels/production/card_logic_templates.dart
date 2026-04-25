part of 'card.dart';

extension _AgentWorkspaceProductionCardTemplates
    on _AgentWorkspaceProductionCardState {
  Map<String, dynamic> _flowDataArgsTemplate() {
    final flowKey = widget.flowKeyController.text.trim();
    switch (flowKey.isEmpty ? 'scriptPlan' : flowKey) {
      case 'script':
        return <String, dynamic>{'key': 'script', 'maxChars': 1800};
      case 'scriptPlan':
        return <String, dynamic>{'key': 'scriptPlan', 'maxChars': 2200};
      case 'storyboardTable':
        return <String, dynamic>{
          'key': 'storyboardTable',
          'rowStart': 1,
          'rowCount': 8,
          'fields': <String>[
            'id',
            'description',
            'scene',
            'duration',
            'camera',
            'associateAssetsIds',
          ],
        };
      case 'storyboard':
        return <String, dynamic>{
          'key': 'storyboard',
          'fields': <String>[
            'id',
            'index',
            'duration',
            'src',
            'state',
            'flowId',
            'associateAssetsIds',
            'shouldGenerateImage',
          ],
          'limit': 24,
        };
      case 'workspaceResult':
        return <String, dynamic>{'key': 'workspaceResult'};
      case 'assets':
      default:
        return <String, dynamic>{
          'key': 'assets',
          'fields': <String>['id', 'name', 'type', 'src', 'flowId', 'derive'],
          'limit': 24,
        };
    }
  }

  List<({String label, Map<String, dynamic> args})> _argumentTemplates() {
    switch (_selectedProductionTool) {
      case 'get_flowData':
        return <({String label, Map<String, dynamic> args})>[
          (label: '模板: 紧凑读取', args: _flowDataArgsTemplate()),
          (
            label: '模板: 导演计划',
            args: <String, dynamic>{'key': 'scriptPlan', 'maxChars': 2200},
          ),
          (
            label: '模板: 资产摘要',
            args: <String, dynamic>{
              'key': 'assets',
              'fields': <String>[
                'id',
                'name',
                'type',
                'src',
                'flowId',
                'derive',
              ],
              'limit': 24,
            },
          ),
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
      toolArguments: widget.workspaceLastToolArguments,
    );
  }

  List<int> _buildActionCandidateIds() {
    return extractProductionActionCandidateIds(
      selectedTool: _selectedProductionTool,
      toolName: widget.workspaceLastToolName,
      suggestedFlowKey: _suggestedFlowKeyLine,
      result: widget.workspaceLastToolResultData,
      toolArguments: widget.workspaceLastToolArguments,
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
}
