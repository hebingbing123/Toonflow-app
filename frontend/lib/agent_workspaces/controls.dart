import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';

enum AgentWorkspacePane { script, production, activity }

/// Agent 工作区顶部作用域输入，独立出来让 section 保持壳层职责。
class AgentWorkspaceScopeInputs extends StatelessWidget {
  const AgentWorkspaceScopeInputs({
    super.key,
    required this.projectIdController,
    required this.scriptIdController,
    required this.projectUuidController,
    required this.scriptUuidController,
    required this.workspaceUuidController,
  });

  final TextEditingController projectIdController;
  final TextEditingController scriptIdController;
  final TextEditingController projectUuidController;
  final TextEditingController scriptUuidController;
  final TextEditingController workspaceUuidController;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: TextField(
                controller: projectIdController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: l10n.agentWorkspaceScopeProjectIdLabel,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: scriptIdController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: l10n.agentWorkspaceScopeScriptIdLabel,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: <Widget>[
            Expanded(
              child: TextField(
                controller: projectUuidController,
                decoration: InputDecoration(
                  labelText: l10n.agentWorkspaceScopeProjectUuidLabel,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: scriptUuidController,
                decoration: InputDecoration(
                  labelText: l10n.agentWorkspaceScopeScriptUuidLabel,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        TextField(
          controller: workspaceUuidController,
          decoration: InputDecoration(
            labelText: l10n.agentWorkspaceScopeWorkspaceUuidLabel,
          ),
        ),
      ],
    );
  }
}

/// Agent 工作区 Pane 选择器，集中管理 script/production/activity 入口。
class AgentWorkspacePaneSelector extends StatelessWidget {
  const AgentWorkspacePaneSelector({
    super.key,
    required this.selectedPane,
    required this.onSelected,
  });

  final AgentWorkspacePane selectedPane;
  final ValueChanged<AgentWorkspacePane> onSelected;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final tabs = <(AgentWorkspacePane, String)>[
      (AgentWorkspacePane.script, l10n.agentWorkspacePaneScript),
      (AgentWorkspacePane.production, l10n.agentWorkspacePaneProduction),
      (AgentWorkspacePane.activity, l10n.agentWorkspacePaneActivity),
    ];
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: tabs
          .map(
            (entry) => ChoiceChip(
              label: Text(entry.$2),
              selected: selectedPane == entry.$1,
              onSelected: (bool selected) {
                if (!selected || selectedPane == entry.$1) {
                  return;
                }
                onSelected(entry.$1);
              },
            ),
          )
          .toList(growable: false),
    );
  }
}
