import 'package:flutter/material.dart';

import '../design_system/tokens.dart';
import '../rust_api.dart';

enum AgentWorkspacePane { script, production, activity }

const double _kAgentScopeFieldMaxWidth = 560;

TextStyle? agentWorkspaceFieldTextStyle(BuildContext context) {
  return Theme.of(context).textTheme.bodyLarge?.copyWith(
    color: Theme.of(context).colorScheme.onSurface,
  );
}

InputBorder _agentFieldBorder(StudioTokens tokens, {Color? focus}) {
  return OutlineInputBorder(
    borderRadius: BorderRadius.circular(8),
    borderSide: BorderSide(
      color: focus ?? tokens.borderSubtle,
      width: focus != null ? 1.5 : 1,
    ),
  );
}

/// Filled input without inline label (use with [agentWorkspaceLabeledField]).
InputDecoration agentWorkspaceFieldDecoration(
  BuildContext context, {
  String? labelText,
  String? helperText,
}) {
  final tokens = StudioTokens.of(context);
  return InputDecoration(
    labelText: labelText,
    helperText: helperText,
    filled: true,
    fillColor: tokens.bgInset,
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
    border: _agentFieldBorder(tokens),
    enabledBorder: _agentFieldBorder(tokens),
    focusedBorder: _agentFieldBorder(tokens, focus: tokens.primary),
    floatingLabelBehavior: labelText == null
        ? FloatingLabelBehavior.never
        : FloatingLabelBehavior.auto,
    labelStyle: TextStyle(color: tokens.textSecondary),
    hintStyle: TextStyle(color: tokens.textMuted),
  );
}

Widget _constrainedAgentField(Widget child) {
  return Align(
    alignment: Alignment.centerLeft,
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: _kAgentScopeFieldMaxWidth),
      child: SizedBox(width: double.infinity, child: child),
    ),
  );
}

/// Scope field with label above the box (avoids long-label overlap in grid).
Widget agentWorkspaceLabeledField(
  BuildContext context, {
  required String label,
  required TextEditingController controller,
  TextInputType? keyboardType,
}) {
  final tokens = StudioTokens.of(context);
  return Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    mainAxisSize: MainAxisSize.min,
    children: <Widget>[
      Text(
        label,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: tokens.textSecondary,
          height: 1.3,
        ),
      ),
      const SizedBox(height: 6),
      _constrainedAgentField(
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          style: agentWorkspaceFieldTextStyle(context),
          decoration: agentWorkspaceFieldDecoration(context),
        ),
      ),
    ],
  );
}

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
    final l10n = resolveAppLocalizationsForErrors(context);
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final narrow = constraints.maxWidth < 720;

        Widget pair({
          required TextEditingController left,
          required String leftLabel,
          required TextEditingController right,
          required String rightLabel,
          TextInputType? leftKeyboard,
          TextInputType? rightKeyboard,
        }) {
          final leftField = agentWorkspaceLabeledField(
            context,
            label: leftLabel,
            controller: left,
            keyboardType: leftKeyboard,
          );
          final rightField = agentWorkspaceLabeledField(
            context,
            label: rightLabel,
            controller: right,
            keyboardType: rightKeyboard,
          );
          if (narrow) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                leftField,
                const SizedBox(height: 12),
                rightField,
              ],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(child: leftField),
              const SizedBox(width: 12),
              Expanded(child: rightField),
            ],
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            pair(
              left: projectIdController,
              leftLabel: l10n.agentWorkspaceScopeProjectIdLabel,
              leftKeyboard: TextInputType.number,
              right: scriptIdController,
              rightLabel: l10n.agentWorkspaceScopeScriptIdLabel,
              rightKeyboard: TextInputType.number,
            ),
            const SizedBox(height: 16),
            pair(
              left: projectUuidController,
              leftLabel: l10n.agentWorkspaceScopeProjectUuidLabel,
              right: scriptUuidController,
              rightLabel: l10n.agentWorkspaceScopeScriptUuidLabel,
            ),
            const SizedBox(height: 16),
            agentWorkspaceLabeledField(
              context,
              label: l10n.agentWorkspaceScopeWorkspaceUuidLabel,
              controller: workspaceUuidController,
            ),
          ],
        );
      },
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
    final l10n = resolveAppLocalizationsForErrors(context);
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
