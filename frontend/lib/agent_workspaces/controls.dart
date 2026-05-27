import 'package:flutter/material.dart';
import '../design_system/components/studio_chip.dart';

import '../design_system/components/studio_ellipsis_tooltip_text.dart';
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
    borderRadius: BorderRadius.circular(StudioSpacing.radiusDense),
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
  String? hintText,
}) {
  final tokens = StudioTokens.of(context);
  final theme = Theme.of(context);
  final labelStyle = theme.textTheme.bodySmall?.copyWith(
    color: tokens.textSecondary,
  );
  final helperStyle =
      theme.inputDecorationTheme.helperStyle ??
      theme.textTheme.bodySmall?.copyWith(color: tokens.textMuted);
  return InputDecoration(
    label: labelText == null
        ? null
        : StudioEllipsisTooltipText(text: labelText, style: labelStyle),
    helper: helperText == null
        ? null
        : StudioEllipsisTooltipText(
            text: helperText,
            style: helperStyle,
            maxLines: 2,
          ),
    filled: true,
    fillColor: tokens.bgInset,
    contentPadding: const EdgeInsets.symmetric(horizontal: StudioLayoutSpacing.insetDense, vertical: StudioLayoutSpacing.stackMedium),
    border: _agentFieldBorder(tokens),
    enabledBorder: _agentFieldBorder(tokens),
    focusedBorder: _agentFieldBorder(tokens, focus: tokens.primary),
    floatingLabelBehavior: labelText == null
        ? FloatingLabelBehavior.never
        : FloatingLabelBehavior.auto,
    labelStyle: labelStyle,
    hintText: hintText,
    hintStyle: theme.textTheme.bodySmall?.copyWith(color: tokens.textMuted),
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
  String? hintText,
}) {
  final tokens = StudioTokens.of(context);
  return Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    mainAxisSize: MainAxisSize.min,
    children: <Widget>[
      StudioEllipsisTooltipText(
        text: label,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: tokens.textSecondary,
          height: 1.3,
        ),
      ),
      const SizedBox(height: StudioSpacing.xs),
      _constrainedAgentField(
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          style: agentWorkspaceFieldTextStyle(context),
          decoration: agentWorkspaceFieldDecoration(context, hintText: hintText),
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
          String? leftHint,
          String? rightHint,
        }) {
          final leftField = agentWorkspaceLabeledField(
            context,
            label: leftLabel,
            controller: left,
            keyboardType: leftKeyboard,
            hintText: leftHint,
          );
          final rightField = agentWorkspaceLabeledField(
            context,
            label: rightLabel,
            controller: right,
            keyboardType: rightKeyboard,
            hintText: rightHint,
          );
          if (narrow) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                leftField,
                const SizedBox(height: StudioSpacing.sm),
                rightField,
              ],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(child: leftField),
              const SizedBox(width: StudioSpacing.sm),
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
            const SizedBox(height: StudioSpacing.sm),
            pair(
              left: projectUuidController,
              leftLabel: l10n.agentWorkspaceScopeProjectUuidLabel,
              leftHint: l10n.agentWorkspaceScopeProjectUuidHint,
              right: scriptUuidController,
              rightLabel: l10n.agentWorkspaceScopeScriptUuidLabel,
              rightHint: l10n.agentWorkspaceScopeScriptUuidHint,
            ),
            const SizedBox(height: StudioSpacing.sm),
            agentWorkspaceLabeledField(
              context,
              label: l10n.agentWorkspaceScopeWorkspaceUuidLabel,
              controller: workspaceUuidController,
              hintText: l10n.agentWorkspaceScopeWorkspaceUuidHint,
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
      spacing: StudioSpacing.xs,
      runSpacing: StudioSpacing.xs,
      children: tabs
          .map(
            (entry) => StudioChoiceChip(
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
