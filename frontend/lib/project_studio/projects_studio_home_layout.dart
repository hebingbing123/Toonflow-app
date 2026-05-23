import 'package:flutter/material.dart';

import '../design_system/layout_breakpoints.dart';

/// Responsive gates for [ProjectsStudioHome] / [ProjectsGridView].
///
/// Prefer [contentWidth] from [LayoutBuilder] (pane width after shell chrome),
/// not full viewport [MediaQuery.size], so desktop sidebars do not mis-trigger
/// wide layouts.
class ProjectsStudioHomeLayout {
  const ProjectsStudioHomeLayout({
    required this.contentWidth,
    required this.shortestSide,
  });

  final double contentWidth;
  final double shortestSide;

  bool get isPhone => shortestSide < kProjectsHomePhoneShortestSide;

  bool get stackedHeader =>
      isPhone || contentWidth < kProjectsHomeInlineHeaderMinWidth;

  /// Light stacked header on phone (no inset hero panel).
  bool get phoneStackedHeader => isPhone && stackedHeader;

  bool get useSplitOverview =>
      !isPhone &&
      contentWidth >= kProjectsHomeSplitOverviewMinWidth;

  bool get useDenseSingleCard =>
      !isPhone && contentWidth >= kProjectsHomeDenseCardMinWidth;

  /// Full-width intrinsic-height card (phone / narrow pane).
  bool get useStandaloneSingleCard => !useDenseSingleCard;

  static ProjectsStudioHomeLayout resolve({
    required BuildContext context,
    required double contentWidth,
  }) {
    final mq = MediaQuery.sizeOf(context);
    final width = contentWidth.isFinite && contentWidth > 0
        ? contentWidth
        : mq.width;
    return ProjectsStudioHomeLayout(
      contentWidth: width,
      shortestSide: mq.shortestSide,
    );
  }
}
