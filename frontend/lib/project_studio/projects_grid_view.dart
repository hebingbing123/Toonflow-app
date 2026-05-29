import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../demo/product_demo_tour_anchors.dart';
import '../design_system/components/studio_entrance_motion.dart';
import '../design_system/ix/studio_pointer.dart';
import '../design_system/components/studio_toolbar_button.dart';
import 'projects_studio_home_layout.dart';
import '../design_system/components/studio_skeleton.dart';
import '../design_system/components/studio_surfaces.dart';
import '../design_system/components/studio_text_styles.dart';
import '../design_system/tokens.dart';
import '../l10n/app_localizations.dart';
import '../rust_api.dart';
import 'studio_step_progress_ring.dart';

class ProjectsGridView extends StatelessWidget {
  const ProjectsGridView({
    super.key,
    required this.projects,
    required this.onOpenProject,
    this.currentProjectNumericId,
    this.onSelectProject,
    this.loading = false,
    this.progressForProject,
    this.listEntranceKey,
    this.asSliver = false,
    this.contentWidth,
    this.demoTourAnchorId,
    this.boundedMaxHeight,
  });

  final List<ProjectRow> projects;
  final ValueChanged<ProjectRow> onOpenProject;
  final int? currentProjectNumericId;
  final Future<void> Function(ProjectRow project)? onSelectProject;
  final bool loading;
  final int Function(ProjectRow project)? progressForProject;
  final Object? listEntranceKey;

  /// When true, returns a [SliverGrid] (or [SliverToBoxAdapter]) for [CustomScrollView].
  final bool asSliver;

  /// Pane width for grid metrics when [asSliver] is true.
  final double? contentWidth;

  /// When set, the first grid card is wrapped for demo tour spotlight.
  final String? demoTourAnchorId;

  /// Split-pane embed: virtualized [GridView] inside a capped height (no shrinkWrap).
  final double? boundedMaxHeight;

  @override
  Widget build(BuildContext context) {
    if (loading && projects.isEmpty) {
      return asSliver
          ? SliverToBoxAdapter(child: _LoadingGrid(width: contentWidth))
          : const _LoadingGrid();
    }

    if (asSliver) {
      return _buildSliverGrid(context);
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = contentWidth ?? constraints.maxWidth;
        if (boundedMaxHeight != null && boundedMaxHeight! > 0) {
          return _buildBoundedScrollGrid(context, width, boundedMaxHeight!);
        }
        return _buildBoxGrid(context, width);
      },
    );
  }

  Widget _buildSliverGrid(BuildContext context) {
    final width = contentWidth ?? MediaQuery.sizeOf(context).width;
    if (projects.length == 1) {
      return SliverToBoxAdapter(
        child: _buildSingleProjectCard(context, width),
      );
    }
    final metrics = _ProjectsGridMetrics.resolve(
      width: width,
      projectCount: projects.length,
      context: context,
    );
    return SliverGrid(
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: metrics.crossAxisCount,
        mainAxisSpacing: StudioLayoutSpacing.stackMedium,
        crossAxisSpacing: StudioLayoutSpacing.stackMedium,
        childAspectRatio: metrics.childAspectRatio,
      ),
      delegate: SliverChildBuilderDelegate(
        (context, index) => _buildGridCard(context, index),
        childCount: projects.length,
        addAutomaticKeepAlives: false,
        addRepaintBoundaries: true,
      ),
    );
  }

  Widget _buildBoundedScrollGrid(
    BuildContext context,
    double width,
    double maxHeight,
  ) {
    if (projects.length == 1) {
      return _buildSingleProjectCard(context, width);
    }
    final metrics = _ProjectsGridMetrics.resolve(
      width: width,
      projectCount: projects.length,
      context: context,
    );
    final estimated = metrics.estimateHeight(
      width: width,
      itemCount: projects.length,
    );
    final height = math.min(estimated, maxHeight);
    return SizedBox(
      height: height,
      child: GridView.builder(
        addAutomaticKeepAlives: false,
        addRepaintBoundaries: true,
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: metrics.crossAxisCount,
          mainAxisSpacing: StudioLayoutSpacing.stackMedium,
          crossAxisSpacing: StudioLayoutSpacing.stackMedium,
          childAspectRatio: metrics.childAspectRatio,
        ),
        itemCount: projects.length,
        itemBuilder: (context, index) => _buildGridCard(context, index),
      ),
    );
  }

  Widget _buildBoxGrid(BuildContext context, double width) {
    if (projects.length == 1) {
      return _buildSingleProjectCard(context, width);
    }
    final metrics = _ProjectsGridMetrics.resolve(
      width: width,
      projectCount: projects.length,
      context: context,
    );
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      addAutomaticKeepAlives: false,
      addRepaintBoundaries: true,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: metrics.crossAxisCount,
        mainAxisSpacing: StudioLayoutSpacing.stackMedium,
        crossAxisSpacing: StudioLayoutSpacing.stackMedium,
        childAspectRatio: metrics.childAspectRatio,
      ),
      itemCount: projects.length,
      itemBuilder: (context, index) => _buildGridCard(context, index),
    );
  }

  Widget _buildSingleProjectCard(BuildContext context, double width) {
    final layout = ProjectsStudioHomeLayout.resolve(
      context: context,
      contentWidth: width,
    );
    final project = projects.first;
    final card = _wrapGridEntrance(
      context,
      index: 0,
      child: _ProjectGridCard(
        project: project,
        completedSteps: progressForProject?.call(project) ?? 0,
        selected: currentProjectNumericId == project.numericId,
        onSelect: onSelectProject == null
            ? null
            : () => onSelectProject!(project),
        onTap: () => onOpenProject(project),
        dense: layout.useDenseSingleCard,
        standalone: layout.useStandaloneSingleCard,
      ),
    );
    if (layout.useDenseSingleCard) {
      return Align(
        alignment: Alignment.topLeft,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: width >= 1280
                ? 520
                : width >= 960
                ? 480
                : math.min(width * 0.92, 440),
          ),
          child: card,
        ),
      );
    }
    return card;
  }

  Widget _buildGridCard(BuildContext context, int index) {
    final project = projects[index];
    final steps = progressForProject?.call(project) ?? 0;
    final card = _wrapGridEntrance(
      context,
      index: index,
      child: _ProjectGridCard(
        project: project,
        completedSteps: steps,
        selected: currentProjectNumericId == project.numericId,
        onSelect: onSelectProject == null
            ? null
            : () => onSelectProject!(project),
        onTap: () => onOpenProject(project),
      ),
    );
    if (index == 0 &&
        demoTourAnchorId != null &&
        demoTourAnchorId!.isNotEmpty) {
      return ProductDemoTourAnchor(
        anchorId: demoTourAnchorId!,
        child: card,
      );
    }
    return card;
  }

  Widget _wrapGridEntrance(
    BuildContext context, {
    required int index,
    required Widget child,
  }) {
    if (index > 10) {
      return child;
    }
    return StudioStaggeredEntrance(
      index: index,
      entranceKey: listEntranceKey,
      child: child,
    );
  }
}

class _ProjectsGridMetrics {
  const _ProjectsGridMetrics({
    required this.crossAxisCount,
    required this.childAspectRatio,
  });

  final int crossAxisCount;
  final double childAspectRatio;

  static _ProjectsGridMetrics resolve({
    required double width,
    required int projectCount,
    required BuildContext context,
  }) {
    final layout = ProjectsStudioHomeLayout.resolve(
      context: context,
      contentWidth: width,
    );
    final crossAxisCount = switch (projectCount) {
      2 => layout.isPhone || width < 840 ? 1 : 2,
      _ =>
        layout.isPhone
            ? 1
            : width >= 2100
            ? 5
            : width >= 1680
            ? 4
            : width >= 1260
            ? 3
            : width >= 920
            ? 2
            : 1,
    };
    final childAspectRatio = layout.isPhone
        ? 1.12
        : width >= 2100
        ? 1.18
        : width >= 1680
        ? 1.12
        : width >= 1280
        ? 1.04
        : width >= 920
        ? 1.0
        : width >= 620
        ? 0.96
        : 0.9;
    return _ProjectsGridMetrics(
      crossAxisCount: crossAxisCount,
      childAspectRatio: childAspectRatio,
    );
  }

  double estimateHeight({
    required double width,
    required int itemCount,
  }) {
    if (itemCount <= 0) {
      return 0;
    }
    final rows = (itemCount / crossAxisCount).ceil();
    final spacing = StudioLayoutSpacing.stackMedium;
    final cellWidth =
        (width - spacing * (crossAxisCount - 1)) / crossAxisCount;
    final cellHeight = cellWidth / childAspectRatio;
    return rows * cellHeight + math.max(0, rows - 1) * spacing;
  }
}

class _LoadingGrid extends StatelessWidget {
  const _LoadingGrid({this.width});

  final double? width;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final tokens = StudioTokens.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final resolvedWidth = width ?? constraints.maxWidth;
        final crossAxisCount = resolvedWidth >= 920 ? 2 : 1;
        final childAspectRatio = resolvedWidth >= 920 ? 1.05 : 0.9;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              l10n.projectsLoading,
              style: studioHintStyle(context)?.copyWith(color: tokens.textMuted),
            ),
            const SizedBox(height: StudioSpacing.sm),
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: crossAxisCount,
              mainAxisSpacing: StudioLayoutSpacing.stackMedium,
              crossAxisSpacing: StudioLayoutSpacing.stackMedium,
              childAspectRatio: childAspectRatio,
              children: List<Widget>.generate(
                crossAxisCount == 1 ? 2 : 4,
                (_) => const _ProjectCardSkeleton(),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _ProjectCardSkeleton extends StatelessWidget {
  const _ProjectCardSkeleton();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: studioInsetPanelDecoration(context),
      child: Padding(
        padding: const EdgeInsets.all(StudioLayoutSpacing.section - 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: const <Widget>[
            Row(
              children: <Widget>[
                Expanded(child: StudioSkeleton(height: 18)),
                SizedBox(width: StudioSpacing.sm),
                StudioSkeleton(width: 40, height: 40, borderRadius: 20),
              ],
            ),
            SizedBox(height: StudioSpacing.sm),
            StudioSkeleton(height: 14),
            SizedBox(height: StudioSpacing.xs),
            StudioSkeleton(height: 14, width: 180),
            SizedBox(height: StudioSpacing.sm),
            StudioSkeleton(height: 36, borderRadius: StudioSpacing.radiusButton),
          ],
        ),
      ),
    );
  }
}

class _ProjectGridCard extends StatelessWidget {
  const _ProjectGridCard({
    required this.project,
    required this.completedSteps,
    this.selected = false,
    this.onSelect,
    required this.onTap,
    this.dense = false,
    this.standalone = false,
  });

  final ProjectRow project;
  final int completedSteps;
  final bool selected;
  final VoidCallback? onSelect;
  final VoidCallback onTap;
  final bool dense;
  /// Intrinsic-height card for phone / narrow pane (no [Expanded] body).
  final bool standalone;

  @override
  Widget build(BuildContext context) {
    final tokens = StudioTokens.of(context);
    final l10n = AppLocalizations.of(context)!;
    final title =
        project.name ?? l10n.projectsUnnamedProject(project.numericId);
    final summary = (project.intro ?? '').trim();
    final focusLabel = _projectFocusLabel(l10n, completedSteps);
    final fallbackSummary = _projectFocusSummary(l10n, completedSteps);

    final scopeSelectionEnabled = onSelect != null;
    final cardRadius = BorderRadius.circular(StudioSpacing.radiusCard);
    if (dense) {
      return _buildDenseCard(
        context,
        tokens: tokens,
        l10n: l10n,
        title: title,
        summary: summary,
        focusLabel: focusLabel,
        fallbackSummary: fallbackSummary,
        scopeSelectionEnabled: scopeSelectionEnabled,
        cardRadius: cardRadius,
      );
    }

    final selectBody = _buildSelectableCardBody(
      context,
      tokens: tokens,
      l10n: l10n,
      title: title,
      summary: summary,
      focusLabel: focusLabel,
      fallbackSummary: fallbackSummary,
      scopeSelectionEnabled: scopeSelectionEnabled,
      titleMaxLines: standalone ? 2 : 2,
      summaryMaxLines: standalone ? 2 : 3,
      fillHeight: !standalone,
    );

    return StudioPointerHover(
      borderRadius: cardRadius,
      liftShadow: false,
      builder: (context, hovered) {
        return Material(
          color: StudioPrimitives.transparent,
          borderRadius: cardRadius,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 140),
            curve: Curves.easeOutCubic,
            decoration: BoxDecoration(
              color: selected
                  ? tokens.primarySoft.withValues(alpha: 0.28)
                  : hovered
                  ? tokens.bgElevated.withValues(alpha: 0.98)
                  : tokens.bgSurface.withValues(alpha: 0.96),
              borderRadius: cardRadius,
              border: Border.all(
                color: selected
                    ? tokens.primary
                    : hovered
                    ? tokens.borderDefault
                    : tokens.borderSubtle,
                width: selected ? 1.5 : 1,
              ),
            ),
            padding: EdgeInsets.all(
              standalone
                  ? StudioLayoutSpacing.insetDense + StudioSpacing.radiusHairline
                  : StudioLayoutSpacing.section - 4,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: standalone ? MainAxisSize.min : MainAxisSize.max,
              children: <Widget>[
                if (standalone)
                  selectBody
                else
                  Expanded(child: selectBody),
                SizedBox(
                  width: double.infinity,
                  child: StudioToolbarButton(
                    key: Key('project_enter_studio_${project.numericId}'),
                    label: l10n.studioEnterStudio,
                    icon: Icons.arrow_outward,
                    onPressed: onTap,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSelectableCardBody(
    BuildContext context, {
    required StudioTokens tokens,
    required AppLocalizations l10n,
    required String title,
    required String summary,
    required String focusLabel,
    required String fallbackSummary,
    required bool scopeSelectionEnabled,
    required int titleMaxLines,
    required int summaryMaxLines,
    bool fillHeight = false,
  }) {
    final content = Padding(
      padding: const EdgeInsets.only(bottom: StudioSpacing.xs),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Expanded(
                    child: StudioHero(
                      tag: studioHeroTagProjectTitle(project.numericId),
                      child: Text(
                        title,
                        maxLines: titleMaxLines,
                        overflow: TextOverflow.ellipsis,
                        style: studioCardTitleStyle(context),
                      ),
                    ),
                  ),
                  if (selected) ...<Widget>[
                    const SizedBox(width: StudioSpacing.xs),
                    StudioIconSwap(
                      icon: Icons.check_circle,
                      size: StudioIconSize.sm,
                      color: tokens.primary,
                    ),
                    const SizedBox(width: StudioSpacing.xs),
                  ],
                  StudioStepProgressRing(
                    completedSteps: completedSteps,
                    heroTag: studioHeroTagProjectProgress(project.numericId),
                  ),
                ],
              ),
              const SizedBox(height: StudioSpacing.sm),
              Text(
                summary.isNotEmpty ? summary : fallbackSummary,
                maxLines: summaryMaxLines,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: tokens.textSecondary,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: StudioSpacing.sm),
              Wrap(
                spacing: StudioSpacing.xs,
                runSpacing: StudioSpacing.xs,
                children: <Widget>[
                  _ProjectMetaChip(
                    label: '#${project.numericId}',
                    color: tokens.textSecondary,
                  ),
                  _ProjectMetaChip(
                    label: focusLabel,
                    color: selected ? tokens.textPrimary : tokens.primary,
                    backgroundColor: selected
                        ? tokens.primarySoft.withValues(alpha: 0.84)
                        : tokens.bgInset.withValues(alpha: 0.9),
                    borderColor: selected
                        ? tokens.primary.withValues(alpha: 0.4)
                        : tokens.surfaceHighlight.withValues(alpha: 0.9),
                  ),
                ],
              ),
              if (scopeSelectionEnabled && !selected) ...<Widget>[
                const SizedBox(height: StudioSpacing.xs),
                Text(
                  l10n.studioProjectCardTapToSelect,
                  style: Theme.of(
                    context,
                  ).textTheme.labelSmall?.copyWith(color: tokens.textMuted),
                ),
              ],
            ],
          ),
        );

    return GestureDetector(
      key: Key('project_select_scope_${project.numericId}'),
      behavior: HitTestBehavior.opaque,
      onTap: onSelect ?? onTap,
      child: fillHeight
          ? SizedBox(
              width: double.infinity,
              height: double.infinity,
              child: Align(
                alignment: Alignment.topLeft,
                child: content,
              ),
            )
          : content,
    );
  }

  Widget _buildDenseCard(
    BuildContext context, {
    required StudioTokens tokens,
    required AppLocalizations l10n,
    required String title,
    required String summary,
    required String focusLabel,
    required String fallbackSummary,
    required bool scopeSelectionEnabled,
    required BorderRadius cardRadius,
  }) {
    return Material(
      color: StudioPrimitives.transparent,
      borderRadius: cardRadius,
      child: Container(
        decoration: BoxDecoration(
          color: selected
              ? tokens.primarySoft.withValues(alpha: 0.28)
              : tokens.bgSurface.withValues(alpha: 0.96),
          borderRadius: cardRadius,
          border: Border.all(
            color: selected ? tokens.primary : tokens.borderSubtle,
            width: selected ? 1.5 : 1,
          ),
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: StudioLayoutSpacing.stackMedium,
          vertical: StudioLayoutSpacing.cardInner,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: <Widget>[
            Expanded(
              child: GestureDetector(
                key: Key('project_select_scope_${project.numericId}'),
                behavior: HitTestBehavior.opaque,
                onTap: onSelect ?? onTap,
                child: Padding(
                  padding: EdgeInsets.zero,
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Expanded(
                              child: StudioHero(
                                tag: studioHeroTagProjectTitle(project.numericId),
                                child: Text(
                                  title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: studioCardTitleStyle(context),
                                ),
                              ),
                            ),
                            if (selected) ...<Widget>[
                              const SizedBox(width: StudioSpacing.xs),
                              StudioIconSwap(
                                icon: Icons.check_circle,
                                size: StudioIconSize.xs,
                                color: tokens.primary,
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: StudioSpacing.xs),
                        Text(
                          summary.isNotEmpty ? summary : fallbackSummary,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: tokens.textSecondary,
                                height: 1.35,
                              ),
                        ),
                        const SizedBox(height: StudioSpacing.xs),
                        Wrap(
                          spacing: StudioSpacing.xs,
                          runSpacing: StudioSpacing.xs,
                          children: <Widget>[
                            _ProjectMetaChip(
                              label: '#${project.numericId}',
                              color: tokens.textSecondary,
                            ),
                            _ProjectMetaChip(
                              label: focusLabel,
                              color: selected
                                  ? tokens.textPrimary
                                  : tokens.primary,
                              backgroundColor: selected
                                  ? tokens.primarySoft.withValues(alpha: 0.84)
                                  : tokens.bgInset.withValues(alpha: 0.9),
                              borderColor: selected
                                  ? tokens.primary.withValues(alpha: 0.4)
                                  : tokens.surfaceHighlight.withValues(
                                      alpha: 0.9,
                                    ),
                            ),
                          ],
                        ),
                        if (scopeSelectionEnabled && !selected) ...<Widget>[
                          const SizedBox(height: StudioSpacing.xs),
                          Text(
                            l10n.studioProjectCardTapToSelect,
                            style: Theme.of(context).textTheme.labelSmall
                                ?.copyWith(color: tokens.textMuted),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            StudioStepProgressRing(
              completedSteps: completedSteps,
              heroTag: studioHeroTagProjectProgress(project.numericId),
            ),
            const SizedBox(width: StudioSpacing.sm),
            FilledButton.icon(
              key: Key('project_enter_studio_${project.numericId}'),
              onPressed: onTap,
              style: FilledButton.styleFrom(
                visualDensity: VisualDensity.standard,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
              ),
              icon: const Icon(Icons.arrow_outward, size: StudioIconSize.xs),
              label: Text(l10n.studioEnterStudio),
            ),
          ],
        ),
      ),
    );
  }

  String _projectFocusLabel(AppLocalizations l10n, int completedSteps) {
    final clamped = completedSteps.clamp(0, 5);
    return switch (clamped) {
      0 => l10n.studioStepScriptShort,
      1 => l10n.studioStepArtShort,
      2 => l10n.studioStepAssetsShort,
      3 => l10n.studioStepStoryboardShort,
      4 => l10n.studioStepVideoShort,
      _ => l10n.studioStepDeliverShort,
    };
  }

  String _projectFocusSummary(AppLocalizations l10n, int completedSteps) {
    final clamped = completedSteps.clamp(0, 5);
    return switch (clamped) {
      0 => l10n.studioStepScriptBody,
      1 => l10n.studioStepArtBody,
      2 => l10n.studioStepAssetsBody,
      3 => l10n.studioStepStoryboardBody,
      4 => l10n.studioStepVideoBody,
      _ => l10n.studioContinueCreating,
    };
  }
}

class _ProjectMetaChip extends StatelessWidget {
  const _ProjectMetaChip({
    required this.label,
    required this.color,
    this.backgroundColor,
    this.borderColor,
  });

  final String label;
  final Color color;
  final Color? backgroundColor;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    final tokens = StudioTokens.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: StudioSpacing.xs + 2,
        vertical: StudioSpacing.xs - 2,
      ),
      decoration: BoxDecoration(
        color: backgroundColor ?? tokens.bgInset.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(StudioSpacing.radiusPill),
        border: Border.all(
          color: borderColor ?? tokens.surfaceHighlight.withValues(alpha: 0.9),
        ),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(color: color),
      ),
    );
  }
}
