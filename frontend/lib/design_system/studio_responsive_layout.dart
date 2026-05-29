import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'components/studio_entrance_motion.dart';
import 'layout_breakpoints.dart';
import 'tokens.dart';

/// Width tier for adaptive panes and grids (phone / tablet / desktop).
enum StudioWidthTier {
  handset,
  tablet,
  desktop,
}

/// Classifies [contentWidth] using shared studio gates (600 / 960 dp).
StudioWidthTier studioWidthTier(double contentWidth) {
  if (contentWidth < kStudioHandsetMaxWidth) {
    return StudioWidthTier.handset;
  }
  if (contentWidth < kStudioGridDesktopMinWidth) {
    return StudioWidthTier.tablet;
  }
  return StudioWidthTier.desktop;
}

/// True when a master–detail or side-by-side layout is appropriate.
bool studioUseSplitPaneLayout(double contentWidth) {
  return contentWidth >= kStudioHandsetMaxWidth;
}

/// True when a third properties / inspector column fits comfortably.
bool studioUseThreePaneLayout(double contentWidth) {
  return contentWidth >= kStudioGridDesktopMinWidth;
}

/// Clamps a side pane to a fraction of [contentWidth] with [min] / [max].
double studioClampedPaneWidth(
  double contentWidth, {
  double fraction = 0.28,
  double min = 240,
  double max = 360,
}) {
  if (!contentWidth.isFinite || contentWidth <= 0) {
    return min;
  }
  return (contentWidth * fraction).clamp(min, max).toDouble();
}

/// Grid column count from content width and per-tier targets.
int studioGridCrossAxisCount(
  double contentWidth, {
  int handset = 1,
  int tablet = 2,
  int desktop = 3,
  int desktopWide = 4,
  double desktopWideMin = 1680,
}) {
  final tier = studioWidthTier(contentWidth);
  return switch (tier) {
    StudioWidthTier.handset => handset,
    StudioWidthTier.tablet => tablet,
    StudioWidthTier.desktop =>
      contentWidth >= desktopWideMin ? desktopWide : desktop,
  };
}

/// Preview / hero image height from vertical space (avoids phone-only constants).
double studioPreviewImageHeight(
  double maxHeight, {
  double fraction = 0.42,
  double min = 200,
  double max = 520,
}) {
  if (!maxHeight.isFinite || maxHeight <= 0) {
    return min;
  }
  return math.min(maxHeight * fraction, max).clamp(min, max).toDouble();
}

/// Media tile height from content width and aspect ratio (e.g. 16:9 previews).
double studioAspectHeightFromWidth(
  double width, {
  double aspectRatio = 16 / 9,
  double min = 120,
  double max = 320,
}) {
  if (!width.isFinite || width <= 0) {
    return min;
  }
  return (width / aspectRatio).clamp(min, max).toDouble();
}

/// Width for one child inside a [Wrap] given [maxWidth] and column targets.
double studioWrapTileWidth(
  double maxWidth, {
  int maxColumns = 4,
  double minTileWidth = 220,
  double maxTileWidth = 360,
  double gap = 8,
}) {
  if (!maxWidth.isFinite || maxWidth <= 0) {
    return minTileWidth;
  }
  for (var cols = maxColumns; cols >= 1; cols--) {
    final w = (maxWidth - gap * (cols - 1)) / cols;
    if (w >= minTileWidth || cols == 1) {
      return w.clamp(minTileWidth, maxTileWidth).toDouble();
    }
  }
  return minTileWidth;
}

/// Inline form field width from viewport (full width on handset).
double studioAdaptiveFieldWidth(
  BuildContext context, {
  double fraction = 0.34,
  double min = 200,
  double max = 320,
  double handsetHorizontalMargin = 0,
}) {
  final viewport = MediaQuery.sizeOf(context).width;
  if (viewport < kStudioHandsetMaxWidth) {
    return math.max(160, viewport - handsetHorizontalMargin);
  }
  return studioClampedPaneWidth(
    viewport,
    fraction: fraction,
    min: min,
    max: max,
  );
}

/// Dialog content height from available viewport.
double studioAdaptiveDialogHeight(
  BuildContext context, {
  double fraction = 0.55,
  double min = 280,
  double max = 560,
}) {
  return studioPreviewImageHeight(
    MediaQuery.sizeOf(context).height,
    fraction: fraction,
    min: min,
    max: max,
  );
}

/// Sidebar / filter rail width for desktop layouts.
double studioAdaptiveSidebarWidth(
  BuildContext context, {
  double fraction = 0.28,
  double min = 240,
  double max = 360,
}) {
  return studioClampedPaneWidth(
    MediaQuery.sizeOf(context).width,
    fraction: fraction,
    min: min,
    max: max,
  );
}

/// Node width for horizontal flow lanes (readiness / stage strips).
double studioFlowNodeWidth(
  double laneWidth,
  int nodeCount, {
  double arrowSlotWidth = 36,
  double minNodeWidth = 96,
  double maxNodeWidth = 200,
}) {
  if (nodeCount <= 0 || !laneWidth.isFinite || laneWidth <= 0) {
    return minNodeWidth;
  }
  final arrowTotal = math.max(0, nodeCount - 1) * arrowSlotWidth;
  final available = math.max(minNodeWidth, laneWidth - arrowTotal);
  return (available / nodeCount).clamp(minNodeWidth, maxNodeWidth).toDouble();
}

/// LayoutBuilder-based responsive shell (mobile → tablet → desktop → wide).
class StudioResponsiveLayout extends StatelessWidget {
  const StudioResponsiveLayout({
    super.key,
    required this.mobile,
    this.tablet,
    this.desktop,
    this.wide,
  });

  final WidgetBuilder mobile;
  final WidgetBuilder? tablet;
  final WidgetBuilder? desktop;
  final WidgetBuilder? wide;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final breakpoint = StudioBreakpoint.fromWidth(constraints.maxWidth);
        switch (breakpoint) {
          case StudioBreakpoint.wide:
            return (wide ?? desktop ?? tablet ?? mobile)(context);
          case StudioBreakpoint.desktop:
            return (desktop ?? tablet ?? mobile)(context);
          case StudioBreakpoint.tablet:
            return (tablet ?? mobile)(context);
          case StudioBreakpoint.mobile:
            return mobile(context);
        }
      },
    );
  }
}

/// Metrics/chips: [Wrap] on handset, [GridView] on wider panes.
class StudioResponsiveChipGrid extends StatelessWidget {
  const StudioResponsiveChipGrid({
    super.key,
    required this.children,
    this.handset = 1,
    this.tablet = 2,
    this.desktop = 3,
    this.desktopWide = 4,
    this.desktopWideMin = 1680,
    this.childAspectRatio = 3.2,
    this.spacing = StudioSpacing.xs,
    this.entranceKey,
  });

  final List<Widget> children;
  final Object? entranceKey;
  final int handset;
  final int tablet;
  final int desktop;
  final int desktopWide;
  final double desktopWideMin;
  final double childAspectRatio;
  final double spacing;

  @override
  Widget build(BuildContext context) {
    if (children.isEmpty) {
      return const SizedBox.shrink();
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = studioGridCrossAxisCount(
          constraints.maxWidth,
          handset: handset,
          tablet: tablet,
          desktop: desktop,
          desktopWide: desktopWide,
          desktopWideMin: desktopWideMin,
        );
        if (crossAxisCount <= 1) {
          return Wrap(
            spacing: spacing,
            runSpacing: spacing,
            children: <Widget>[
              for (var i = 0; i < children.length; i++)
                i > 12
                    ? children[i]
                    : studioStaggeredItem(
                        i,
                        entranceKey: entranceKey ?? children.length,
                        child: children[i],
                      ),
            ],
          );
        }
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            mainAxisSpacing: spacing,
            crossAxisSpacing: spacing,
            childAspectRatio: childAspectRatio,
          ),
          itemCount: children.length,
          itemBuilder: (context, index) {
            final child = children[index];
            if (index > 12) {
              return child;
            }
            return studioStaggeredItem(
              index,
              entranceKey: entranceKey ?? children.length,
              child: child,
            );
          },
        );
      },
    );
  }
}
