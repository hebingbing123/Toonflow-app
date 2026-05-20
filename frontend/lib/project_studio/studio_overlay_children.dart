import 'package:flutter/material.dart';

import 'studio_overlay_resolution.dart';

List<Widget> buildStudioOverlayChildren({
  required ResolvedStudioOverlay resolved,
  required Widget loadingChild,
  required Widget Function(int projectNumericId) storyboardBuilder,
  required Widget Function(int projectNumericId, int scriptNumericId)
  episodeConsoleBuilder,
  required Widget Function(int projectNumericId, String projectUuid)
  projectStudioBuilder,
  required Widget Function(int projectNumericId, String projectUuid)
  reviewPackBuilder,
}) {
  switch (resolved.kind) {
    case ResolvedStudioOverlayKind.none:
    case ResolvedStudioOverlayKind.loading:
      return <Widget>[loadingChild];
    case ResolvedStudioOverlayKind.storyboardStudio:
      return <Widget>[
        Expanded(child: storyboardBuilder(resolved.projectNumericId!)),
      ];
    case ResolvedStudioOverlayKind.episodeConsole:
      return <Widget>[
        Expanded(
          child: episodeConsoleBuilder(
            resolved.projectNumericId!,
            resolved.scriptNumericId!,
          ),
        ),
      ];
    case ResolvedStudioOverlayKind.projectStudio:
      return <Widget>[
        Expanded(
          child: projectStudioBuilder(
            resolved.projectNumericId!,
            resolved.projectUuid!,
          ),
        ),
      ];
    case ResolvedStudioOverlayKind.reviewPack:
      return <Widget>[
        Expanded(
          child: reviewPackBuilder(
            resolved.projectNumericId!,
            resolved.projectUuid!,
          ),
        ),
      ];
  }
}
