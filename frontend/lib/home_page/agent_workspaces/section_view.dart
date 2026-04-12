part of 'section.dart';

/// Agent 工作区外层视图，负责标题、范围输入与 pane 壳层布局。
extension _AgentWorkspacesSectionView on _AgentWorkspacesSectionState {
  Widget _buildAgentWorkspacesSectionView(BuildContext context) {
    final title = widget.sectionTitle ?? 'Agent 工作区';
    final description =
        widget.sectionDescription ??
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
}
