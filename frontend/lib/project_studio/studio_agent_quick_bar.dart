import 'package:flutter/material.dart';

import '../design_system/components/studio_surfaces.dart';
import '../l10n/app_localizations.dart';
import 'studio_step.dart';
import '../design_system/tokens.dart';

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
    this.bottomPadding = 12,
  });

  final Set<StudioAgentAction> visibleActions;
  final VoidCallback? onRewriteScript;
  final VoidCallback? onExtractEntities;
  final VoidCallback? onBreakStoryboard;
  final VoidCallback? onAssignVoices;
  final VoidCallback? onGridPrompts;
  final double bottomPadding;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final chips = <Widget>[];

    void add(StudioAgentAction action, String label, VoidCallback? fn) {
      if (!visibleActions.contains(action) || fn == null) return;
      chips.add(
        FilledButton.tonal(
          onPressed: fn,
          style: studioFormInsetTonalChipStyle(context),
          child: Text(label),
        ),
      );
    }

    add(
      StudioAgentAction.rewriteScript,
      l10n.studioAgentRewriteScript,
      onRewriteScript,
    );
    add(
      StudioAgentAction.extractEntities,
      l10n.studioAgentExtractEntities,
      onExtractEntities,
    );
    add(
      StudioAgentAction.breakStoryboard,
      l10n.studioAgentBreakStoryboard,
      onBreakStoryboard,
    );
    add(
      StudioAgentAction.assignVoices,
      l10n.studioAgentAssignVoices,
      onAssignVoices,
    );
    add(
      StudioAgentAction.gridPrompts,
      l10n.studioAgentGridPrompts,
      onGridPrompts,
    );

    if (chips.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: EdgeInsets.only(bottom: bottomPadding),
      child: Wrap(spacing: StudioSpacing.xs, runSpacing: StudioSpacing.xs, children: chips),
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
