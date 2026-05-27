import 'package:flutter/material.dart';

import '../design_system/components/studio_icon_button.dart';
import '../design_system/components/studio_text_styles.dart';
import '../design_system/layout_breakpoints.dart';
import '../design_system/tokens.dart';
import '../l10n/app_localizations.dart';
import 'creator_journey_menu.dart';
import 'creator_journey_strip.dart';
import 'studio_step.dart';
import 'package:openflow_app/design_system/ix/studio_context_menu.dart';

/// Compact journey chrome for project-studio focus mode.
class CreatorJourneyCompactBar extends StatelessWidget {
  const CreatorJourneyCompactBar({
    super.key,
    required this.currentStep,
    required this.failedJobCount,
    required this.onSelectStep,
    required this.onBackToProjects,
    required this.onWorkspaceMenuSelected,
    this.onOpenReviewPackMilestone,
    this.onOpenStepSetup,
  });

  final StudioStep currentStep;
  final int failedJobCount;
  final ValueChanged<StudioStep> onSelectStep;
  final VoidCallback onBackToProjects;
  final ValueChanged<CreatorWorkspaceMenuTarget> onWorkspaceMenuSelected;
  final VoidCallback? onOpenReviewPackMilestone;
  final VoidCallback? onOpenStepSetup;

  static ButtonStyle _compactIconStyle(Color foreground) {
    return IconButton.styleFrom(
      foregroundColor: foreground,
      visualDensity: VisualDensity.standard,
      tapTargetSize: MaterialTapTargetSize.padded,
      minimumSize: const Size(StudioSpacing.touchTarget, StudioSpacing.touchTarget),
      padding: EdgeInsets.zero,
    );
  }

  String _milestoneLabel(AppLocalizations l10n, int index) {
    return switch (index) {
      0 => l10n.studioCreatorJourneyProject,
      1 => l10n.studioCreatorJourneyScript,
      2 => l10n.studioCreatorJourneyArtPhase,
      3 => l10n.studioCreatorJourneyStoryboardPhase,
      _ => l10n.studioCreatorJourneyReviewPack,
    };
  }

  void _showFullWorkflow(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) {
        final tokens = StudioTokens.of(sheetContext);
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              StudioSpacing.sm,
              StudioSpacing.xs,
              StudioSpacing.sm,
              StudioSpacing.md,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Text(
                  l10n.studioCreatorJourneyCompactExpandTitle,
                  style: Theme.of(sheetContext).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: tokens.textPrimary,
                  ),
                ),
                const SizedBox(height: StudioLayoutSpacing.stackMedium),
                CreatorJourneyStrip(
                  currentStep: currentStep,
                  failedJobCount: failedJobCount,
                  onSelectMilestone: onSelectStep,
                  onBackToProjects: onBackToProjects,
                  onOpenReviewPackMilestone: onOpenReviewPackMilestone,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showCollapsedToolsMenu(BuildContext context, AppLocalizations l10n) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        final sheetChildren = <Widget>[
          if (onOpenStepSetup != null)
            StudioListRow(
              leading: const Icon(Icons.playlist_add_check_outlined),
              title: Text(l10n.studioScriptStepSetupOpen),
              onTap: () {
                Navigator.pop(sheetContext);
                onOpenStepSetup!();
              },
            ),
          StudioListRow(
            leading: const Icon(Icons.unfold_more_rounded),
            title: Text(l10n.studioCreatorJourneyCompactExpand),
            onTap: () {
              Navigator.pop(sheetContext);
              _showFullWorkflow(context);
            },
          ),
          const Divider(height: StudioControlSize.dividerThickness),
        ];
        for (final entry in buildCreatorWorkspaceMenuEntries(context, l10n)) {
          if (entry is PopupMenuDivider) {
            sheetChildren.add(const Divider(height: StudioControlSize.dividerThickness));
            continue;
          }
          if (entry is! PopupMenuItem<CreatorWorkspaceMenuTarget>) {
            continue;
          }
          if (!entry.enabled) {
            sheetChildren.add(
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  StudioSpacing.sm,
                  StudioSpacing.radiusComfort,
                  StudioSpacing.sm,
                  StudioSpacing.chromeActionGap,
                ),
                child: DefaultTextStyle(
                  style:
                      studioChromeTitleStyle(context) ??
                      Theme.of(context).textTheme.labelLarge!.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                  child: entry.child ?? const SizedBox.shrink(),
                ),
              ),
            );
            continue;
          }
          final target = entry.value;
          if (target == null) {
            continue;
          }
          sheetChildren.add(
            StudioListRow(
              title: entry.child ?? const SizedBox.shrink(),
              onTap: () {
                Navigator.pop(sheetContext);
                onWorkspaceMenuSelected(target);
              },
            ),
          );
        }
        sheetChildren.add(const SizedBox(height: StudioSpacing.xs));
        return SafeArea(child: Column(mainAxisSize: MainAxisSize.min, children: sheetChildren));
      },
    );
  }

  Widget? _buildPrevControl({
    required BuildContext context,
    required AppLocalizations l10n,
    required StudioTokens tokens,
    required int nav,
    required bool iconOnly,
  }) {
    if (creatorJourneyCompactBarPrevIsExitToProjects(currentStep)) {
      final projectLabel = _milestoneLabel(l10n, 0);
      if (iconOnly) {
        return StudioIconButton(
          icon: Icons.chevron_left_rounded,
          label: projectLabel,
          onPressed: onBackToProjects,
          style: _compactIconStyle(tokens.textSecondary),
        );
      }
      return TextButton.icon(
        onPressed: onBackToProjects,
        icon: const Icon(Icons.chevron_left_rounded, size: StudioIconSize.md),
        label: Text(projectLabel, overflow: TextOverflow.ellipsis, maxLines: 1),
        style: TextButton.styleFrom(
          foregroundColor: tokens.textSecondary,
          padding: const EdgeInsets.symmetric(horizontal: StudioSpacing.xs),
          visualDensity: VisualDensity.standard,
        ),
      );
    }
    final prevStep = creatorJourneyCompactBarPrevStep(currentStep);
    if (prevStep == null) {
      return null;
    }
    final prevLabel = creatorJourneyCompactBarChromeLabel(l10n, prevStep);
    void onPressed() => onSelectStep(prevStep);
    if (iconOnly) {
      return StudioIconButton(
        icon: Icons.chevron_left_rounded,
        label: prevLabel,
        onPressed: onPressed,
        style: _compactIconStyle(tokens.textSecondary),
      );
    }
    return TextButton.icon(
      onPressed: onPressed,
      icon: const Icon(Icons.chevron_left_rounded, size: StudioIconSize.md),
      label: Text(prevLabel, overflow: TextOverflow.ellipsis, maxLines: 1),
      style: TextButton.styleFrom(
        foregroundColor: tokens.textSecondary,
        padding: const EdgeInsets.symmetric(horizontal: StudioSpacing.xs),
        visualDensity: VisualDensity.standard,
      ),
    );
  }

  Widget? _buildNextControl({
    required BuildContext context,
    required AppLocalizations l10n,
    required StudioTokens tokens,
    required int nav,
    required bool iconOnly,
  }) {
    VoidCallback? onPressed;
    String? tooltip;
    String? label;
    final nextStep = creatorJourneyCompactBarNextStep(currentStep);
    if (nextStep != null) {
      final nextLabel = creatorJourneyCompactBarChromeLabel(l10n, nextStep);
      onPressed = () => onSelectStep(nextStep);
      tooltip = l10n.studioCreatorJourneyNextSop(nextLabel);
      label = tooltip;
    } else if (creatorJourneyCompactBarNextOpensReviewPack(currentStep) &&
        onOpenReviewPackMilestone != null) {
      final reviewLabel = l10n.studioCreatorJourneyReviewPack;
      onPressed = onOpenReviewPackMilestone;
      tooltip = l10n.studioCreatorJourneyNextSop(reviewLabel);
      label = tooltip;
    }
    if (onPressed == null) {
      return null;
    }
    if (iconOnly) {
      return StudioIconButton(
        icon: Icons.arrow_forward_rounded,
        label: tooltip!,
        onPressed: onPressed,
        style: _compactIconStyle(tokens.primary),
      );
    }
    return TextButton.icon(
      onPressed: onPressed,
      icon: const Icon(Icons.arrow_forward_rounded, size: StudioIconSize.sm),
      label: Text(label!, overflow: TextOverflow.ellipsis, maxLines: 1),
      style: TextButton.styleFrom(
        foregroundColor: tokens.primary,
        padding: const EdgeInsets.symmetric(horizontal: StudioSpacing.xs),
        visualDensity: VisualDensity.standard,
      ),
    );
  }

  Widget _buildCurrentPill({
    required BuildContext context,
    required AppLocalizations l10n,
    required StudioTokens tokens,
    required String currentLabel,
    required TextStyle? labelStyle,
  }) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: tokens.primarySoft.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(StudioSpacing.radiusButton),
        border: Border.all(color: tokens.primary.withValues(alpha: 0.45)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: StudioLayoutSpacing.inlineGap,
          vertical: StudioLayoutSpacing.microGap,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(Icons.menu_book_outlined, size: StudioIconSize.xs, color: tokens.primary),
            const SizedBox(width: StudioSpacing.xs),
            Flexible(
              child: Text(
                l10n.studioCreatorJourneyCompactCurrent(currentLabel),
                style:
                    (studioControlLabelStyle(context) ?? labelStyle)?.copyWith(
                      color: tokens.textPrimary,
                    ),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTrailingTools({
    required BuildContext context,
    required AppLocalizations l10n,
    required StudioTokens tokens,
    required bool iconOnly,
    required bool collapseTools,
  }) {
    if (collapseTools) {
      return StudioIconButton(
        icon: Icons.more_horiz_rounded,
        label: l10n.studioCreatorJourneyMoreStepsTooltip,
        onPressed: () => _showCollapsedToolsMenu(context, l10n),
        color: tokens.textSecondary,
        style: _compactIconStyle(tokens.textSecondary),
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        if (onOpenStepSetup != null)
          iconOnly
              ? StudioIconButton(
                  icon: Icons.playlist_add_check_outlined,
                  label: l10n.studioScriptStepSetupOpen,
                  onPressed: onOpenStepSetup,
                  style: _compactIconStyle(tokens.textSecondary),
                )
              : TextButton.icon(
                  onPressed: onOpenStepSetup,
                  icon: const Icon(Icons.playlist_add_check_outlined, size: StudioIconSize.sm),
                  label: Text(
                    l10n.studioScriptStepSetupOpen,
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                  style: TextButton.styleFrom(
                    foregroundColor: tokens.textSecondary,
                    padding: const EdgeInsets.symmetric(
                      horizontal: StudioSpacing.xs,
                    ),
                    visualDensity: VisualDensity.standard,
                  ),
                ),
        StudioIconButton(
          icon: Icons.unfold_more_rounded,
          label: l10n.studioCreatorJourneyCompactExpand,
          onPressed: () => _showFullWorkflow(context),
          color: tokens.textSecondary,
          style: _compactIconStyle(tokens.textSecondary),
        ),
        PopupMenuButton<CreatorWorkspaceMenuTarget>(
          tooltip: l10n.studioCreatorJourneyMoreStepsTooltip,
          onSelected: onWorkspaceMenuSelected,
          itemBuilder: (context) => buildCreatorWorkspaceMenuEntries(context, l10n),
          padding: EdgeInsets.zero,
          icon: Icon(
            Icons.tune_rounded,
            color: tokens.textSecondary.withValues(alpha: 0.85),
          ),
          style: _compactIconStyle(tokens.textSecondary),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final tokens = StudioTokens.of(context);
    final nav = creatorJourneyMilestoneNavIndex(currentStep);
    final labelStyle = studioControlLabelStyle(context);
    final currentLabel = creatorJourneyCompactBarChromeLabel(l10n, currentStep);

    return LayoutBuilder(
      builder: (context, constraints) {
        final iconOnly =
            constraints.maxWidth < kStudioJourneyCompactBarIconOnlyMinWidth;
        final collapseTools =
            constraints.maxWidth < kStudioJourneyCompactBarCollapseToolsMinWidth;

        final prev = _buildPrevControl(
          context: context,
          l10n: l10n,
          tokens: tokens,
          nav: nav,
          iconOnly: iconOnly,
        );
        final next = _buildNextControl(
          context: context,
          l10n: l10n,
          tokens: tokens,
          nav: nav,
          iconOnly: iconOnly,
        );
        final tools = _buildTrailingTools(
          context: context,
          l10n: l10n,
          tokens: tokens,
          iconOnly: iconOnly,
          collapseTools: collapseTools,
        );

        return Row(
          children: <Widget>[
            ?prev,
            Expanded(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 260),
                  child: _buildCurrentPill(
                    context: context,
                    l10n: l10n,
                    tokens: tokens,
                    currentLabel: currentLabel,
                    labelStyle: labelStyle,
                  ),
                ),
              ),
            ),
            ?next,
            tools,
          ],
        );
      },
    );
  }
}
