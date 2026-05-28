import 'package:flutter/material.dart';

import '../studio_responsive_layout.dart';
import '../tokens.dart';
import 'studio_entrance_motion.dart';
import 'studio_skeleton.dart';
import 'studio_surfaces.dart';

/// Layout presets for async data loading placeholders.
enum StudioLoadingPlaceholder {
  /// Compact inset panel (settings / task summary).
  pane,

  /// Vertical list of media cards (search, notifications).
  list,

  /// Grid of square thumbnails (assets, storyboard frames).
  grid,

  /// Detail workspace: sidebar list + main canvas.
  detail,

  /// Single 16:9 media tile.
  mediaTile,
}

/// Shimmer-style skeleton layouts aligned with Studio list/grid/detail surfaces.
class StudioLoadingPlaceholders {
  const StudioLoadingPlaceholders._();

  static Widget build(
    BuildContext context,
    StudioLoadingPlaceholder placeholder, {
    int itemCount = 4,
    int crossAxisCount = 3,
    bool scrollable = true,
    EdgeInsetsGeometry? padding,
  }) {
    switch (placeholder) {
      case StudioLoadingPlaceholder.pane:
        return StudioLoadingPane(scrollable: scrollable);
      case StudioLoadingPlaceholder.list:
        return StudioListSkeleton(
          itemCount: itemCount,
          scrollable: scrollable,
          padding: padding,
        );
      case StudioLoadingPlaceholder.grid:
        return StudioGridSkeleton(
          itemCount: itemCount,
          crossAxisCount: crossAxisCount,
          scrollable: scrollable,
          padding: padding,
        );
      case StudioLoadingPlaceholder.detail:
        return StudioDetailSkeleton(scrollable: scrollable);
      case StudioLoadingPlaceholder.mediaTile:
        return const StudioMediaTileSkeleton();
    }
  }
}

/// Row density for nested panels (no extra inset chrome).
enum StudioPaneLoadingDensity {
  standard,
  comfortable,
  detail,
}

/// Skeleton rows only — use inside an existing inset panel.
class StudioPaneLoadingSkeleton extends StatelessWidget {
  const StudioPaneLoadingSkeleton({
    super.key,
    this.density = StudioPaneLoadingDensity.standard,
  });

  final StudioPaneLoadingDensity density;

  @override
  Widget build(BuildContext context) {
    final (double rowA, double rowB) = switch (density) {
      StudioPaneLoadingDensity.standard => (56.0, 56.0),
      StudioPaneLoadingDensity.comfortable => (72.0, 72.0),
      StudioPaneLoadingDensity.detail => (120.0, 48.0),
    };
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        const StudioSkeleton(height: 18),
        const SizedBox(height: StudioSpacing.sm),
        StudioSkeleton(height: rowA),
        const SizedBox(height: StudioSpacing.sm),
        StudioSkeleton(height: rowB),
      ],
    );
  }
}

/// Standard inset panel skeleton (header + two rows).
class StudioLoadingPane extends StatelessWidget {
  const StudioLoadingPane({
    super.key,
    this.scrollable = false,
    this.maxWidth = 520,
  });

  final bool scrollable;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    final body = Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: DecoratedBox(
          decoration: studioInsetPanelDecoration(context),
          child: const Padding(
            padding: EdgeInsets.all(StudioLayoutSpacing.insetComfortable),
            child: StudioPaneLoadingSkeleton(),
          ),
        ),
      ),
    );
    if (!scrollable) {
      return body;
    }
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(vertical: StudioSpacing.xs),
      child: body,
    );
  }
}

/// One list row shaped like [SearchResultCard] / notification tiles.
class StudioListCardSkeleton extends StatelessWidget {
  const StudioListCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final subtitleWidth = studioClampedPaneWidth(
          constraints.maxWidth,
          fraction: 0.42,
          min: 120,
          max: 240,
        );
        return DecoratedBox(
          decoration: studioInsetPanelDecoration(context),
          child: Padding(
            padding: const EdgeInsets.all(StudioLayoutSpacing.cardInner),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const StudioSkeleton(width: 40, height: 40, borderRadius: 10),
                const SizedBox(width: StudioSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      const StudioSkeleton(height: 16),
                      const SizedBox(height: StudioSpacing.xs),
                      StudioSkeleton(height: 12, width: subtitleWidth),
                      const SizedBox(height: StudioSpacing.sm),
                      const StudioSkeleton(height: 12),
                      const SizedBox(height: StudioSpacing.xs),
                      const StudioSkeleton(height: 12),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Stacked list-card skeletons.
class StudioListSkeleton extends StatelessWidget {
  const StudioListSkeleton({
    super.key,
    this.itemCount = 4,
    this.scrollable = true,
    this.padding,
  });

  final int itemCount;
  final bool scrollable;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[
      for (var i = 0; i < itemCount; i++) ...<Widget>[
        if (i > 0) const SizedBox(height: StudioSpacing.sm),
        studioStaggeredItem(
          i,
          entranceKey: itemCount,
          child: const StudioListCardSkeleton(),
        ),
      ],
    ];
    if (!scrollable) {
      return Padding(
        padding: padding ?? EdgeInsets.zero,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: children,
        ),
      );
    }
    return ListView(
      padding:
          padding ??
          const EdgeInsets.symmetric(
            horizontal: StudioSpacing.sm,
            vertical: StudioSpacing.xs,
          ),
      children: children,
    );
  }
}

/// Square tile for asset grids / shot thumbnails.
class StudioGridTileSkeleton extends StatelessWidget {
  const StudioGridTileSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1,
      child: DecoratedBox(
        decoration: studioInsetPanelDecoration(context),
        child: const Padding(
          padding: EdgeInsets.all(StudioSpacing.xs),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Expanded(child: StudioSkeleton(borderRadius: 10)),
              SizedBox(height: StudioSpacing.xs),
              StudioSkeleton(height: 12),
            ],
          ),
        ),
      ),
    );
  }
}

/// Responsive grid of square tiles.
class StudioGridSkeleton extends StatelessWidget {
  const StudioGridSkeleton({
    super.key,
    this.itemCount = 6,
    this.crossAxisCount = 3,
    this.scrollable = true,
    this.padding,
  });

  final int itemCount;
  final int crossAxisCount;
  final bool scrollable;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final grid = GridView.builder(
      shrinkWrap: !scrollable,
      physics: scrollable ? null : const NeverScrollableScrollPhysics(),
      padding:
          padding ??
          const EdgeInsets.all(StudioLayoutSpacing.cardInner),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        mainAxisSpacing: StudioSpacing.sm,
        crossAxisSpacing: StudioSpacing.sm,
        childAspectRatio: 0.92,
      ),
      itemCount: itemCount,
      itemBuilder: (context, index) => studioStaggeredItem(
        index,
        entranceKey: itemCount,
        child: const StudioGridTileSkeleton(),
      ),
    );
    return grid;
  }
}

/// Storyboard / editor layout: narrow shot list + wide canvas.
class StudioDetailSkeleton extends StatelessWidget {
  const StudioDetailSkeleton({super.key, this.scrollable = false});

  final bool scrollable;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final listWidth = studioClampedPaneWidth(
          constraints.maxWidth,
          fraction: 0.28,
          min: 200,
          max: 320,
        );
        final bodyHeight = studioPreviewImageHeight(
          constraints.maxHeight.isFinite && constraints.maxHeight > 0
              ? constraints.maxHeight
              : MediaQuery.sizeOf(context).height,
          fraction: 0.5,
          min: 280,
          max: 520,
        );
        final row = Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        SizedBox(
          width: listWidth,
          child: DecoratedBox(
            decoration: studioInsetPanelDecoration(context),
            child: const Padding(
              padding: EdgeInsets.all(StudioLayoutSpacing.cardInner),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  StudioSkeleton(height: 18),
                  SizedBox(height: StudioSpacing.sm),
                  StudioSkeleton(height: 44),
                  SizedBox(height: StudioSpacing.xs),
                  StudioSkeleton(height: 44),
                  SizedBox(height: StudioSpacing.xs),
                  StudioSkeleton(height: 44),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: StudioSpacing.sm),
        Expanded(
          child: DecoratedBox(
            decoration: studioInsetPanelDecoration(context),
            child: Padding(
              padding: const EdgeInsets.all(StudioLayoutSpacing.insetComfortable),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  StudioSkeleton(
                    height: 22,
                    width: studioClampedPaneWidth(
                      constraints.maxWidth - listWidth - StudioSpacing.sm,
                      fraction: 0.45,
                      min: 120,
                      max: 220,
                    ),
                  ),
                  const SizedBox(height: StudioSpacing.md),
                  const Expanded(child: StudioSkeleton(borderRadius: 12)),
                ],
              ),
            ),
          ),
        ),
      ],
    );
        if (!scrollable) {
          return SizedBox(height: bodyHeight, child: row);
        }
        return SingleChildScrollView(
          padding: const EdgeInsets.all(StudioSpacing.sm),
          child: SizedBox(height: bodyHeight, child: row),
        );
      },
    );
  }
}

/// 16:9 media preview placeholder.
class StudioMediaTileSkeleton extends StatelessWidget {
  const StudioMediaTileSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return const AspectRatio(
      aspectRatio: 16 / 9,
      child: StudioSkeleton(borderRadius: StudioSpacing.radiusCard),
    );
  }
}
