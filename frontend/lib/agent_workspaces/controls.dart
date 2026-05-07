import 'package:flutter/material.dart';

enum AgentWorkspacePane { script, production, activity }

/// Agent 工作区顶部作用域输入，独立出来让 section 保持壳层职责。
class AgentWorkspaceScopeInputs extends StatelessWidget {
  const AgentWorkspaceScopeInputs({
    super.key,
    required this.projectIdController,
    required this.scriptIdController,
    required this.projectUuidController,
    required this.scriptUuidController,
  });

  final TextEditingController projectIdController;
  final TextEditingController scriptIdController;
  final TextEditingController projectUuidController;
  final TextEditingController scriptUuidController;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: TextField(
                controller: projectIdController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: '项目 ID（numeric）',
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: scriptIdController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: '剧本 ID（numeric）',
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
                decoration: const InputDecoration(
                  labelText: '项目 UUID（可选，与 WS projectUuid 对齐）',
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: scriptUuidController,
                decoration: const InputDecoration(
                  labelText: '剧本 UUID（可选，制作 attach）',
                ),
              ),
            ),
          ],
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
    final tabs = <(AgentWorkspacePane, String)>[
      (AgentWorkspacePane.script, '剧本工作区'),
      (AgentWorkspacePane.production, '制作工作区'),
      (AgentWorkspacePane.activity, '执行动态'),
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
