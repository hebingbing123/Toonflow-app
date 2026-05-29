import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Shared width gates for studio / product-shell responsive layout.
///
/// Use [LayoutBuilder] `constraints.maxWidth`, not [MediaQuery] full viewport,
/// so sidebars and pane padding do not trigger overly aggressive side-by-side rows.
const double kStudioTwoColumnMinWidth = 1100;

/// Title badge + pipeline chips on one row (aligned with desktop min width 960).
const double kStudioPipelineInlineMinWidth = 760;

/// Inline secondary header rows (intro + chip, etc.).
const double kStudioCompactHeaderMinWidth = 720;

/// Project-studio [CreatorJourneyCompactBar]: icon-only prev/next/setup.
const double kStudioJourneyCompactBarIconOnlyMinWidth = 960;

/// Collapse expand + more-steps into one overflow menu beside next/setup icons.
const double kStudioJourneyCompactBarCollapseToolsMinWidth = 860;

/// Product shell: stacked / multi-row top chrome below this width (non-integrated bar).
const double kStudioShellCompactTopChromeMaxWidth = 860;

/// Product shell: stacked chrome between compact and full single-row chrome.
const double kStudioShellStackedTopChromeMaxWidth = 1240;

/// macOS integrated title bar: extra-tight workspace context below this width.
const double kStudioShellMacOSUltraNarrowMaxWidth = 1080;

/// Login: marketing hero + auth panel side-by-side.
const double kStudioLoginWideMinWidth = 1120;

/// Login: single-column simplified hero.
const double kStudioLoginUltraCompactMaxWidth = 480;

/// Login: shorten hero when viewport height is tight.
const double kStudioLoginShortViewportMaxHeight = 560;

/// Login: auth panel width clamp (min, max).
const double kStudioLoginAuthPanelMinWidth = 392;
const double kStudioLoginAuthPanelMaxWidth = 456;

/// Handset / narrow Web width gate (aligns with [kProjectsHomePhoneShortestSide]).
const double kStudioHandsetMaxWidth = 600;

/// Tablet → desktop grid / split-pane gate (multi-column lists, inspector column).
const double kStudioGridDesktopMinWidth = 960;

/// Projects home: inline title + compact create (desktop / tablet landscape).
const double kProjectsHomeInlineHeaderMinWidth = kStudioPipelineInlineMinWidth;

/// Projects home: horizontal single-project card (not used on phone).
const double kProjectsHomeDenseCardMinWidth = kStudioCompactHeaderMinWidth;

/// Projects home: recent rail beside grid (wide content pane only).
const double kProjectsHomeSplitOverviewMinWidth = 1360;

/// Projects home: empty state + getting-started side-by-side.
const double kProjectsHomeEmptySplitMinWidth = 1080;

/// Projects home: recent card width tiers (content pane).
const double kProjectsHomeRecentCardWidth1080 = 272;
const double kProjectsHomeRecentCardWidth1440 = 288;
const double kProjectsHomeRecentCardWidth1800 = 320;
const double kProjectsHomeRecentCardWidthPhone = 220;

/// Projects home: max content width tiers (content pane).
const double kProjectsHomeContentMaxWidth1280 = 1320;
const double kProjectsHomeContentMaxWidth1440 = 1480;
const double kProjectsHomeContentMaxWidth1800 = 1720;
const double kProjectsHomeContentMaxWidth2200 = 1980;

/// Shortest-side gate for phone / handset layout (iOS, Android, narrow Web).
const double kProjectsHomePhoneShortestSide = kStudioHandsetMaxWidth;

/// «更多» menu: bottom sheet at handset / compact shell widths.
bool productShellMoreMenuUsesBottomSheet(double viewportWidth) {
  return viewportWidth <= kStudioShellCompactTopChromeMaxWidth;
}

/// Cap width for product shell «更多» menu (dialog, overlay, or sheet).
double productShellMoreMenuPanelWidth(
  double viewportWidth, {
  double horizontalMargin = 16,
}) {
  if (productShellMoreMenuUsesBottomSheet(viewportWidth)) {
    return math.max(280, viewportWidth - (horizontalMargin * 2));
  }
  if (viewportWidth >= 1440) {
    return 360;
  }
  if (viewportWidth >= 1100) {
    return 340;
  }
  if (viewportWidth >= 720) {
    return 320;
  }
  return math.max(280, viewportWidth - (horizontalMargin * 2));
}

/// Dialog / sheet content width capped to viewport minus [horizontalMargin].
double studioConstrainedDialogWidth(
  BuildContext context, {
  double maxWidth = 520,
  double horizontalMargin = 48,
}) {
  final viewport = MediaQuery.sizeOf(context).width;
  return math.min(maxWidth, math.max(280, viewport - horizontalMargin));
}

/// Resolves projects-home content max width from pane [contentWidth].
double projectsHomeContentMaxWidth(double contentWidth, {required bool isPhone}) {
  if (isPhone) {
    return double.infinity;
  }
  if (contentWidth >= 2200) {
    return kProjectsHomeContentMaxWidth2200;
  }
  if (contentWidth >= 1800) {
    return kProjectsHomeContentMaxWidth1800;
  }
  if (contentWidth >= 1440) {
    return kProjectsHomeContentMaxWidth1440;
  }
  if (contentWidth >= 1280) {
    return kProjectsHomeContentMaxWidth1280;
  }
  return double.infinity;
}

/// Kiro-style responsive breakpoint (maps to product constants; see
/// `docs/plans/flutter-ui-ux-breakpoint-mapping.md`).
enum StudioBreakpoint {
  mobile(maxWidth: kStudioHandsetMaxWidth),
  tablet(maxWidth: kStudioGridDesktopMinWidth),
  desktop(maxWidth: 1280),
  wide(maxWidth: double.infinity);

  const StudioBreakpoint({required this.maxWidth});
  final double maxWidth;

  static StudioBreakpoint fromWidth(double width) {
    if (width < mobile.maxWidth) return mobile;
    if (width < tablet.maxWidth) return tablet;
    if (width < desktop.maxWidth) return desktop;
    return wide;
  }

  bool get isMobile => this == mobile;
  bool get isTablet => this == tablet;
  bool get isDesktop => this == desktop;
  bool get isWide => this == wide;
}

/// Resolves recent-project chip width from pane [contentWidth].
double projectsHomeRecentCardWidth(double contentWidth, {required bool isPhone}) {
  if (isPhone) {
    return kProjectsHomeRecentCardWidthPhone;
  }
  if (contentWidth >= 1800) {
    return kProjectsHomeRecentCardWidth1800;
  }
  if (contentWidth >= 1440) {
    return kProjectsHomeRecentCardWidth1440;
  }
  if (contentWidth >= 1080) {
    return kProjectsHomeRecentCardWidth1080;
  }
  return 260;
}
