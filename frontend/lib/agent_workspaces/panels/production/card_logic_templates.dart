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

  List<({String label, Map<String, dynamic> args})> _argumentTemplates(
    AppLocalizations l10n,
  ) {
    switch (_selectedProductionTool) {
      case 'get_flowData':
        return <({String label, Map<String, dynamic> args})>[
          (
            label: l10n.agentWorkspaceProductionArgTemplateCompactRead,
            args: _flowDataArgsTemplate(),
          ),
          (
            label: l10n.agentWorkspaceProductionArgTemplateDirectorPlan,
            args: <String, dynamic>{'key': 'scriptPlan', 'maxChars': 2200},
          ),
          (
            label: l10n.agentWorkspaceProductionArgTemplateAssetSummary,
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
            label: l10n.agentWorkspaceProductionArgTemplateIdList,
            args: <String, dynamic>{
              'ids': <int>[1],
            },
          ),
        ];
      case 'generate_storyboard':
        return <({String label, Map<String, dynamic> args})>[
          (
            label: l10n.agentWorkspaceProductionArgTemplateStoryboardIds,
            args: <String, dynamic>{
              'ids': <int>[1],
            },
          ),
        ];
      default:
        return const <({String label, Map<String, dynamic> args})>[];
    }
  }

  void _applyToolArgsTemplate(
    AppLocalizations l10n,
    Map<String, dynamic> args,
    String label,
  ) {
    widget.productionDomainArgsController.text = jsonEncode(args);
    _setTaskStatus(l10n.agentWorkspaceFilledArgTemplate(label));
  }

  Widget _buildArgumentTemplates(AppLocalizations l10n) {
    final templates = _argumentTemplates(l10n);
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
      onApplyTemplate: (payload, label) =>
          _applyToolArgsTemplate(l10n, payload, label),
    );
  }

  List<ProductionWorkspaceArgumentSuggestion> _buildActionSuggestions(
    AppLocalizations l10n,
  ) {
    return buildProductionActionArgumentSuggestions(
      l10n: l10n,
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
    AppLocalizations l10n,
    ProductionWorkspaceArgumentSuggestion suggestion,
  ) {
    widget.productionDomainArgsController.text = jsonEncode(suggestion.payload);
    _setTaskStatus(l10n.agentWorkspaceFilledCandidateArgs(suggestion.label));
  }

  Widget _buildActionCandidateTemplates(
    BuildContext context,
    AppLocalizations l10n,
  ) {
    final suggestions = _buildActionSuggestions(l10n);
    if (suggestions.isEmpty) return const SizedBox.shrink();
    return ProductionWorkspaceActionCandidatesPanel(
      busy: widget.busy,
      suggestions: suggestions,
      candidateIds: _buildActionCandidateIds(),
      onApplySuggestion: (suggestion) =>
          _applyActionSuggestion(l10n, suggestion),
    );
  }
}
