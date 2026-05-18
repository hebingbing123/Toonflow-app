import 'package:flutter/material.dart';

import '../design_system/tokens.dart';
import '../l10n/app_localizations.dart';
import 'studio_step.dart';

/// Huobao-style one-click agent actions (Wave 3b).
class StudioAgentQuickBar extends StatelessWidget {
  const StudioAgentQuickBar({
    super.key,
    required this.visibleActions,
    this.onRewriteScript,
    this.onExtractEntities,
    this.onBreakStoryboard,
    this.onAssignVoices,
    this.onGridPrompts,
  });

  final Set<StudioAgentAction> visibleActions;
  final VoidCallback? onRewriteScript;
  final VoidCallback? onExtractEntities;
  final VoidCallback? onBreakStoryboard;
  final VoidCallback? onAssignVoices;
  final VoidCallback? onGridPrompts;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final tokens = StudioTokens.of(context);
    final chips = <Widget>[];

    void add(StudioAgentAction action, String label, VoidCallback? fn) {
      if (!visibleActions.contains(action) || fn == null) return;
      chips.add(
        ActionChip(
          label: Text(label),
          onPressed: fn,
          backgroundColor: tokens.bgInset,
          side: BorderSide(color: tokens.borderSubtle),
        ),
      );
    }

    add(StudioAgentAction.rewriteScript, l10n.studioAgentRewriteScript, onRewriteScript);
    add(StudioAgentAction.extractEntities, l10n.studioAgentExtractEntities, onExtractEntities);
    add(StudioAgentAction.breakStoryboard, l10n.studioAgentBreakStoryboard, onBreakStoryboard);
    add(StudioAgentAction.assignVoices, l10n.studioAgentAssignVoices, onAssignVoices);
    add(StudioAgentAction.gridPrompts, l10n.studioAgentGridPrompts, onGridPrompts);

    if (chips.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Wrap(spacing: 8, runSpacing: 8, children: chips),
    );
  }
}

enum StudioAgentAction {
  rewriteScript,
  extractEntities,
  breakStoryboard,
  assignVoices,
  gridPrompts,
}

Set<StudioAgentAction> agentActionsForStep(StudioStep step) {
  return switch (step) {
    StudioStep.script => {
      StudioAgentAction.rewriteScript,
      StudioAgentAction.extractEntities,
    },
    StudioStep.assets => {StudioAgentAction.assignVoices},
    StudioStep.storyboard => {
      StudioAgentAction.breakStoryboard,
      StudioAgentAction.gridPrompts,
    },
    _ => <StudioAgentAction>{},
  };
}
