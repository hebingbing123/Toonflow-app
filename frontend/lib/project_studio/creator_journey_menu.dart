import 'package:flutter/material.dart';

import '../design_system/components/studio_text_styles.dart';
import '../l10n/app_localizations.dart';
import 'studio_step.dart';
import 'studio_step_model_routing_bar.dart';

/// Primary SOP tabs aligned with the five-milestone creator journey.
const List<StudioStep> studioCreatorJourneyPrimarySopSteps = <StudioStep>[
  StudioStep.script,
  StudioStep.art,
  StudioStep.storyboard,
  StudioStep.deliver,
];

/// Secondary workspace tabs (assets, video, quality) — not on the main milestone strip.
const List<StudioStep> studioCreatorJourneyAdvancedSopSteps = <StudioStep>[
  StudioStep.assets,
  StudioStep.video,
  StudioStep.quality,
];

/// Popup menu target: a workspace step or the review-pack route.
final class CreatorWorkspaceMenuTarget {
  const CreatorWorkspaceMenuTarget.step(this.step) : isReviewPack = false;

  const CreatorWorkspaceMenuTarget.reviewPack() : step = null, isReviewPack = true;

  final StudioStep? step;
  final bool isReviewPack;

  @override
  bool operator ==(Object other) {
    return other is CreatorWorkspaceMenuTarget &&
        other.isReviewPack == isReviewPack &&
        other.step == step;
  }

  @override
  int get hashCode => Object.hash(isReviewPack, step);
}

List<PopupMenuEntry<CreatorWorkspaceMenuTarget>> buildCreatorWorkspaceMenuEntries(
  BuildContext context,
  AppLocalizations l10n,
) {
  Widget sectionHeader(String label) {
    return Text(label, style: studioMenuSectionHeaderStyle(context));
  }

  PopupMenuItem<CreatorWorkspaceMenuTarget> stepItem(StudioStep step) {
    return PopupMenuItem<CreatorWorkspaceMenuTarget>(
      value: CreatorWorkspaceMenuTarget.step(step),
      child: Text(projectStudioStepShortLabel(l10n, step)),
    );
  }

  return <PopupMenuEntry<CreatorWorkspaceMenuTarget>>[
    PopupMenuItem<CreatorWorkspaceMenuTarget>(
      enabled: false,
      child: sectionHeader(l10n.studioCreatorJourneyMenuPrimary),
    ),
    ...studioCreatorJourneyPrimarySopSteps.map(stepItem),
    const PopupMenuDivider(),
    PopupMenuItem<CreatorWorkspaceMenuTarget>(
      value: const CreatorWorkspaceMenuTarget.reviewPack(),
      child: Text(l10n.studioCreatorJourneyMenuReviewPack),
    ),
    const PopupMenuDivider(),
    PopupMenuItem<CreatorWorkspaceMenuTarget>(
      enabled: false,
      child: sectionHeader(l10n.studioCreatorJourneyMenuAdvanced),
    ),
    ...studioCreatorJourneyAdvancedSopSteps.map(stepItem),
  ];
}
