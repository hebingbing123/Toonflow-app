import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../design_system/tokens.dart';
import '../l10n/app_localizations.dart';
import 'studio_step.dart';

/// Maps the internal Studio routing steps onto the five-milestone creator journey.
int creatorJourneyMilestoneNavIndex(StudioStep step) {
  switch (step) {
    case StudioStep.script:
      return 1;
    case StudioStep.art:
    case StudioStep.assets:
      return 2;
    case StudioStep.storyboard:
    case StudioStep.video:
      return 3;
    case StudioStep.deliver:
    case StudioStep.quality:
      return 4;
  }
}

/// Landing route when user taps milestone `index` (0–4).
StudioStep creatorJourneyLandingStep(int milestoneIndex) {
  switch (milestoneIndex.clamp(0, 4)) {
    case 0:
    case 1:
      return StudioStep.script;
    case 2:
      return StudioStep.art;
    case 3:
      return StudioStep.storyboard;
    case 4:
      return StudioStep.deliver;
    default:
      return StudioStep.script;
  }
}

enum CreatorJourneyTileStatus { notStarted, inProgress, completed, blocked }

CreatorJourneyTileStatus creatorJourneyTileStatus({
  required int milestoneIndex,
  required StudioStep currentStep,
  required int failedJobCount,
}) {
  final nav = creatorJourneyMilestoneNavIndex(currentStep);
  final blockedHere =
      failedJobCount > 0 && milestoneIndex == nav && milestoneIndex > 0;

  if (milestoneIndex == 0) {
    return CreatorJourneyTileStatus.completed;
  }
  if (blockedHere) {
    return CreatorJourneyTileStatus.blocked;
  }
  if (milestoneIndex < nav) {
    return CreatorJourneyTileStatus.completed;
  }
  if (milestoneIndex == nav) {
    return CreatorJourneyTileStatus.inProgress;
  }
  return CreatorJourneyTileStatus.notStarted;
}

String _statusSemantics(
  AppLocalizations l10n,
  CreatorJourneyTileStatus status,
) {
  switch (status) {
    case CreatorJourneyTileStatus.completed:
      return l10n.studioCreatorJourneyStatusCompleted;
    case CreatorJourneyTileStatus.inProgress:
      return l10n.studioCreatorJourneyStatusInProgress;
    case CreatorJourneyTileStatus.notStarted:
      return l10n.studioCreatorJourneyStatusNotStarted;
    case CreatorJourneyTileStatus.blocked:
      return l10n.studioCreatorJourneyStatusBlocked;
  }
}

IconData _statusIcon(CreatorJourneyTileStatus status) {
  switch (status) {
    case CreatorJourneyTileStatus.completed:
      return Icons.check_circle_rounded;
    case CreatorJourneyTileStatus.inProgress:
      return Icons.adjust_rounded;
    case CreatorJourneyTileStatus.notStarted:
      return Icons.radio_button_unchecked_rounded;
    case CreatorJourneyTileStatus.blocked:
      return Icons.error_outline_rounded;
  }
}

Color _statusColor(
  BuildContext context,
  CreatorJourneyTileStatus status,
  StudioTokens tokens,
) {
  switch (status) {
    case CreatorJourneyTileStatus.completed:
      return tokens.primary;
    case CreatorJourneyTileStatus.inProgress:
      return tokens.accent;
    case CreatorJourneyTileStatus.notStarted:
      return tokens.textSecondary.withValues(alpha: 0.55);
    case CreatorJourneyTileStatus.blocked:
      return Theme.of(context).colorScheme.error;
  }
}

/// Five-milestone creator journey strip (project → script → art → storyboard → review pack).
class CreatorJourneyStrip extends StatelessWidget {
  const CreatorJourneyStrip({
    super.key,
    required this.currentStep,
    required this.failedJobCount,
    required this.onSelectMilestone,
    this.onOpenReviewPackMilestone,
  });

  final StudioStep currentStep;
  final int failedJobCount;
  final ValueChanged<StudioStep> onSelectMilestone;

  /// When set, tapping the last milestone opens the review-pack route instead of
  /// only selecting [StudioStep.deliver] in-place.
  final VoidCallback? onOpenReviewPackMilestone;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final tokens = StudioTokens.of(context);
    final labels = <String>[
      l10n.studioCreatorJourneyProject,
      l10n.studioCreatorJourneyScript,
      l10n.studioCreatorJourneyArtPhase,
      l10n.studioCreatorJourneyStoryboardPhase,
      l10n.studioCreatorJourneyReviewPack,
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final iconSize = width.isFinite && width < 520 ? 18.0 : 20.0;
        final labelStyle = Theme.of(context).textTheme.labelSmall?.copyWith(
          fontWeight: FontWeight.w600,
          height: 1.15,
          fontSize: width.isFinite && width < 520 ? 10.5 : 11,
        );

        Widget milestoneTile(int i) {
          final status = creatorJourneyTileStatus(
            milestoneIndex: i,
            currentStep: currentStep,
            failedJobCount: failedJobCount,
          );
          final landing = creatorJourneyLandingStep(i);
          final semanticsLabel =
              '${labels[i]}, ${_statusSemantics(l10n, status)}';
          final iconColor = _statusColor(context, status, tokens);
          final VoidCallback onTapMilestone =
              i == labels.length - 1 && onOpenReviewPackMilestone != null
              ? onOpenReviewPackMilestone!
              : () => onSelectMilestone(landing);

          final tile = InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: onTapMilestone,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Icon(_statusIcon(status), size: iconSize, color: iconColor),
                  SizedBox(height: iconSize >= 19 ? 6 : 4),
                  Text(
                    labels[i],
                    maxLines: 2,
                    textAlign: TextAlign.center,
                    overflow: TextOverflow.ellipsis,
                    style: labelStyle?.copyWith(
                      color: status == CreatorJourneyTileStatus.notStarted
                          ? tokens.textSecondary.withValues(alpha: 0.72)
                          : tokens.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
          );

          return Semantics(
            button: true,
            label: semanticsLabel,
            child: Tooltip(message: semanticsLabel, child: tile),
          );
        }

        Widget connectorAfter(int milestoneBefore) {
          final nextStatus = creatorJourneyTileStatus(
            milestoneIndex: milestoneBefore + 1,
            currentStep: currentStep,
            failedJobCount: failedJobCount,
          );
          final connectorColor =
              nextStatus == CreatorJourneyTileStatus.notStarted
              ? tokens.borderSubtle
              : tokens.primary.withValues(alpha: 0.35);
          return Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: SizedBox(
              height: 2,
              width: 8,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: connectorColor,
                  borderRadius: BorderRadius.circular(1),
                ),
              ),
            ),
          );
        }

        final rowChildren = <Widget>[
          for (var i = 0; i < labels.length; i++) ...<Widget>[
            Expanded(child: milestoneTile(i)),
            if (i < labels.length - 1) connectorAfter(i),
          ],
        ];

        final viewportWidth = width.isFinite ? width : 480.0;
        final rowWidth = math.max(viewportWidth, 460.0);

        return Scrollbar(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              width: rowWidth,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: rowChildren,
              ),
            ),
          ),
        );
      },
    );
  }
}
