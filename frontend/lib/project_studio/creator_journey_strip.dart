import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../design_system/tokens.dart';
import '../l10n/app_localizations.dart';
import 'studio_step.dart';
import 'studio_step_model_routing_bar.dart';

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

/// [←] Target in focus-mode compact bar: same-milestone SOP back, else prior milestone landing.
StudioStep? creatorJourneyCompactBarPrevStep(StudioStep step) {
  if (step == StudioStep.quality) {
    return StudioStep.deliver;
  }
  if (step == StudioStep.deliver) {
    return StudioStep.video;
  }
  final nav = creatorJourneyMilestoneNavIndex(step);
  final landing = creatorJourneyLandingStep(nav);
  final sopIndex = StudioStep.sopSteps.indexOf(step);
  if (step != landing && sopIndex > 0) {
    final prevSop = StudioStep.sopSteps[sopIndex - 1];
    if (creatorJourneyMilestoneNavIndex(prevSop) == nav) {
      return prevSop;
    }
  }
  if (nav <= 1) {
    return null;
  }
  return creatorJourneyLandingStep(nav - 1);
}

/// Whether [←] should call [onBackToProjects] (script milestone).
bool creatorJourneyCompactBarPrevIsExitToProjects(StudioStep step) {
  return creatorJourneyMilestoneNavIndex(step) == 1 &&
      creatorJourneyCompactBarPrevStep(step) == null;
}

/// Whether the compact-bar «Focus:» pill should use [projectStudioStepShortLabel]
/// instead of the milestone name (assets / video / quality off landing tab).
bool creatorJourneyCompactBarFocusUsesStepShortLabel(StudioStep step) {
  final nav = creatorJourneyMilestoneNavIndex(step);
  return step != creatorJourneyLandingStep(nav);
}

/// [→] Target in focus-mode compact bar: next milestone landing (not raw SOP chain).
///
/// Keeps «美术 → 分镜» aligned with milestone labels; [StudioStep.assets] is reached
/// via the step menu / «更多步骤», not the primary forward control from art.
StudioStep? creatorJourneyCompactBarNextStep(StudioStep step) {
  final nav = creatorJourneyMilestoneNavIndex(step);
  if (nav >= 4) {
    return null;
  }
  return creatorJourneyLandingStep(nav + 1);
}

/// Whether compact-bar [→] opens the review-pack route (only after deliver/quality).
bool creatorJourneyCompactBarNextOpensReviewPack(StudioStep step) {
  return creatorJourneyCompactBarNextStep(step) == null &&
      creatorJourneyMilestoneNavIndex(step) >= 4;
}

/// [←]/[→]/«专注» label for compact bar (nav 4 landing is deliver, not review-pack).
String creatorJourneyCompactBarChromeLabel(
  AppLocalizations l10n,
  StudioStep step,
) {
  final nav = creatorJourneyMilestoneNavIndex(step);
  final landing = creatorJourneyLandingStep(nav);
  if (step != landing) {
    return projectStudioStepShortLabel(l10n, step);
  }
  return switch (nav) {
    1 => l10n.studioCreatorJourneyScript,
    2 => l10n.studioCreatorJourneyArtPhase,
    3 => l10n.studioCreatorJourneyStoryboardPhase,
    4 => l10n.studioStepDeliverShort,
    _ => projectStudioStepShortLabel(l10n, step),
  };
}

/// Nav milestone index (1–4) → landing [StudioStep] for compact-bar [→]/[←].
///
/// Not the same as [creatorJourneyStripTargetForTile] (strip tiles 0–4 include
/// «项目» exit and review-pack route on tile 4).
StudioStep creatorJourneyLandingStep(int milestoneNavIndex) {
  switch (milestoneNavIndex.clamp(0, 4)) {
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

/// Strip UI tile kinds (project / script / art / storyboard / review-pack).
enum CreatorJourneyStripTileKind { exitProjects, studioStep, reviewPack }

/// Target when the user taps a tile on [CreatorJourneyStrip].
final class CreatorJourneyStripTileTarget {
  const CreatorJourneyStripTileTarget.exitProjects()
    : kind = CreatorJourneyStripTileKind.exitProjects,
      step = null;

  const CreatorJourneyStripTileTarget.studio(this.step)
    : kind = CreatorJourneyStripTileKind.studioStep;

  const CreatorJourneyStripTileTarget.reviewPack()
    : kind = CreatorJourneyStripTileKind.reviewPack,
      step = null;

  final CreatorJourneyStripTileKind kind;
  final StudioStep? step;
}

/// Strip tile label (tile 4 is deliver landing; review-pack is via [→] / menu).
String creatorJourneyStripLabelForTile(AppLocalizations l10n, int tileIndex) {
  return switch (tileIndex.clamp(0, 4)) {
    0 => l10n.studioCreatorJourneyProject,
    1 => l10n.studioCreatorJourneyScript,
    2 => l10n.studioCreatorJourneyArtPhase,
    3 => l10n.studioCreatorJourneyStoryboardPhase,
    4 => l10n.studioStepDeliverShort,
    _ => l10n.studioCreatorJourneyScript,
  };
}

/// Maps strip tile index 0–4 to exit / studio step (tile 4 = deliver).
CreatorJourneyStripTileTarget creatorJourneyStripTargetForTile(int tileIndex) {
  switch (tileIndex.clamp(0, 4)) {
    case 0:
      return const CreatorJourneyStripTileTarget.exitProjects();
    case 1:
      return const CreatorJourneyStripTileTarget.studio(StudioStep.script);
    case 2:
      return const CreatorJourneyStripTileTarget.studio(StudioStep.art);
    case 3:
      return const CreatorJourneyStripTileTarget.studio(StudioStep.storyboard);
    case 4:
      return const CreatorJourneyStripTileTarget.studio(StudioStep.deliver);
    default:
      return const CreatorJourneyStripTileTarget.studio(StudioStep.script);
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

/// Five-milestone creator journey strip (project → script → art → storyboard → deliver).
class CreatorJourneyStrip extends StatelessWidget {
  const CreatorJourneyStrip({
    super.key,
    required this.currentStep,
    required this.failedJobCount,
    required this.onSelectMilestone,
    this.onBackToProjects,
    this.onOpenReviewPackMilestone,
  });

  final StudioStep currentStep;
  final int failedJobCount;
  final ValueChanged<StudioStep> onSelectMilestone;

  /// Tile 0 («项目»): return to projects home.
  final VoidCallback? onBackToProjects;

  /// Tile 4: open `/review-pack` when set.
  final VoidCallback? onOpenReviewPackMilestone;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final tokens = StudioTokens.of(context);
    final labels = List<String>.generate(
      5,
      (i) => creatorJourneyStripLabelForTile(l10n, i),
    );

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
          final tileTarget = creatorJourneyStripTargetForTile(i);
          final semanticsLabel =
              '${labels[i]}, ${_statusSemantics(l10n, status)}';
          final iconColor = _statusColor(context, status, tokens);
          final VoidCallback onTapMilestone = switch (tileTarget.kind) {
            CreatorJourneyStripTileKind.exitProjects =>
              onBackToProjects ?? () => onSelectMilestone(StudioStep.script),
            CreatorJourneyStripTileKind.studioStep =>
              () => onSelectMilestone(tileTarget.step!),
            CreatorJourneyStripTileKind.reviewPack =>
              onOpenReviewPackMilestone ??
              () => onSelectMilestone(StudioStep.deliver),
          };

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
            padding: const EdgeInsets.only(bottom: StudioLayoutSpacing.stackMedium),
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
