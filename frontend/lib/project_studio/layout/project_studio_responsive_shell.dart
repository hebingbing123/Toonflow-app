import 'package:flutter/material.dart';

import '../../design_system/studio_responsive_layout.dart';
import '../../design_system/tokens.dart';
import '../../short_video_space/layout/short_video_mobile_shell.dart';

/// Responsive shell for the six-step project studio journey.
///
/// - Handset: immersive preview slot + scroll body + optional bottom dock.
/// - Tablet: stacked body (mirrors short-video tablet pattern).
/// - Desktop: center step body only (product shell provides sidebar + preview rail).
class ProjectStudioResponsiveShell extends StatelessWidget {
  const ProjectStudioResponsiveShell({
    super.key,
    required this.stepBody,
    this.previewSlot,
    this.previewBusy = false,
    this.mobileDock,
    this.onOpenImmersivePreview,
    this.videoRatio = '9:16',
  });

  final Widget stepBody;
  final Widget? previewSlot;
  final bool previewBusy;
  final Widget? mobileDock;
  final VoidCallback? onOpenImmersivePreview;
  final String videoRatio;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final tier = studioWidthTier(width);
        if (tier == StudioWidthTier.handset) {
          return ShortVideoMobileShell(
            videoRatio: videoRatio,
            previewBusy: previewBusy,
            body: stepBody,
            dock: mobileDock,
            onOpenImmersivePreview: onOpenImmersivePreview,
            previewVideoUrl: null,
            previewPlaylist: null,
          );
        }
        if (tier == StudioWidthTier.tablet) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              if (previewSlot != null) ...<Widget>[
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    StudioSpacing.sm,
                    StudioSpacing.sm,
                    StudioSpacing.sm,
                    0,
                  ),
                  child: previewSlot!,
                ),
                const SizedBox(height: StudioSpacing.sm),
              ],
              Expanded(child: stepBody),
            ],
          );
        }
        return stepBody;
      },
    );
  }
}
