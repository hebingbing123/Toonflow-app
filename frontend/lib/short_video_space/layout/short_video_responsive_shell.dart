import 'package:flutter/material.dart';

import '../../design_system/studio_responsive_layout.dart';
import 'short_video_desktop_shell.dart';
import 'short_video_mobile_shell.dart';

/// Cross-platform layout shell for Short Video Space (stage 4).
///
/// - Handset: immersive preview slot + scroll body + bottom creation dock.
/// - Tablet: two-column master | detail+preview stack.
/// - Desktop: three-column master | detail | preview.
class ShortVideoResponsiveShell extends StatelessWidget {
  const ShortVideoResponsiveShell({
    super.key,
    required this.videoRatio,
    required this.masterPane,
    required this.detailPane,
    this.previewVideoUrl,
    this.previewBusy = false,
    this.previewPlaylist,
    this.mobileDock,
    this.onOpenImmersivePreview,
  });

  final String videoRatio;
  final Widget masterPane;
  final Widget detailPane;
  final String? previewVideoUrl;
  final bool previewBusy;
  final List<ShotPreviewPlaylistEntry>? previewPlaylist;
  final Widget? mobileDock;
  final VoidCallback? onOpenImmersivePreview;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final tier = studioWidthTier(width);
        if (tier == StudioWidthTier.handset) {
          return ShortVideoMobileShell(
            videoRatio: videoRatio,
            previewVideoUrl: previewVideoUrl,
            previewBusy: previewBusy,
            previewPlaylist: previewPlaylist,
            body: detailPane,
            dock: mobileDock,
            onOpenImmersivePreview: onOpenImmersivePreview,
          );
        }
        return ShortVideoDesktopShell(
          videoRatio: videoRatio,
          masterPane: masterPane,
          detailPane: detailPane,
          previewVideoUrl: previewVideoUrl,
          previewBusy: previewBusy,
          previewPlaylist: previewPlaylist,
          threePane: studioUseThreePaneLayout(width),
        );
      },
    );
  }
}

/// Lightweight playlist entry for responsive preview panes.
class ShotPreviewPlaylistEntry {
  const ShotPreviewPlaylistEntry({
    required this.videoUrl,
    required this.shotNumber,
    this.shotTitle,
    this.durationText,
  });

  final String videoUrl;
  final int shotNumber;
  final String? shotTitle;
  final String? durationText;
}
