import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../design_system/components/studio_loading_placeholders.dart';
import '../../design_system/components/studio_surfaces.dart';
import '../../design_system/ix/studio_mobile_affordances.dart';
import '../../design_system/ix/studio_scroll_behavior.dart';
import '../../design_system/tokens.dart';
import '../components/preview_player.dart';
import '../short_video_aspect_ratio.dart';
import 'short_video_responsive_shell.dart';

/// Handset shell: optional inline preview, scrollable body, bottom creation dock.
class ShortVideoMobileShell extends StatelessWidget {
  const ShortVideoMobileShell({
    super.key,
    required this.videoRatio,
    required this.body,
    this.previewVideoUrl,
    this.previewBusy = false,
    this.previewPlaylist,
    this.dock,
    this.onOpenImmersivePreview,
  });

  final String videoRatio;
  final Widget body;
  final String? previewVideoUrl;
  final bool previewBusy;
  final List<ShotPreviewPlaylistEntry>? previewPlaylist;
  final Widget? dock;
  final VoidCallback? onOpenImmersivePreview;

  @override
  Widget build(BuildContext context) {
    final hasUrl = (previewVideoUrl ?? '').trim().isNotEmpty;
    final hasPlaylist = previewPlaylist != null && previewPlaylist!.isNotEmpty;
    final showPreview = previewBusy || hasUrl || hasPlaylist;

    return StudioSystemUiSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (showPreview) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(
                StudioSpacing.sm,
                StudioSpacing.sm,
                StudioSpacing.sm,
                0,
              ),
              child: _MobilePreviewHeader(
                videoRatio: videoRatio,
                previewVideoUrl: previewVideoUrl,
                previewBusy: previewBusy,
                previewPlaylist: previewPlaylist,
                onOpenImmersive: onOpenImmersivePreview,
              ),
            ),
            const SizedBox(height: StudioSpacing.sm),
          ],
          Expanded(
            child: StudioScrollbar(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: StudioSpacing.sm),
                child: body,
              ),
            ),
          ),
          if (dock != null)
            SafeArea(
              top: false,
              child: Material(
                elevation: 8,
                color: Theme.of(context).colorScheme.surfaceContainerHigh,
                child: Padding(
                  padding: const EdgeInsets.all(StudioSpacing.sm),
                  child: dock,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _MobilePreviewHeader extends StatelessWidget {
  const _MobilePreviewHeader({
    required this.videoRatio,
    this.previewVideoUrl,
    this.previewBusy = false,
    this.previewPlaylist,
    this.onOpenImmersive,
  });

  final String videoRatio;
  final String? previewVideoUrl;
  final bool previewBusy;
  final List<ShotPreviewPlaylistEntry>? previewPlaylist;
  final VoidCallback? onOpenImmersive;

  @override
  Widget build(BuildContext context) {
    final aspect = shortVideoAspectRatioFromLabel(videoRatio);
    final hasUrl = (previewVideoUrl ?? '').trim().isNotEmpty;
    final hasPlaylist = previewPlaylist != null && previewPlaylist!.isNotEmpty;

    Widget player;
    if (previewBusy) {
      player = const AspectRatio(
        aspectRatio: 9 / 16,
        child: StudioMediaTileSkeleton(),
      );
    } else if (hasPlaylist) {
      player = PreviewPlayer(
        playlist: previewPlaylist!
            .map(
              (e) => ShotPreviewItem(
                videoUrl: e.videoUrl,
                shotNumber: e.shotNumber,
                shotTitle: e.shotTitle,
                durationText: e.durationText,
              ),
            )
            .toList(growable: false),
        videoRatio: videoRatio,
      );
    } else if (hasUrl) {
      player = PreviewPlayer(
        videoUrl: previewVideoUrl,
        videoRatio: videoRatio,
      );
    } else {
      player = const SizedBox.shrink();
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(StudioSpacing.radiusCard),
      child: AspectRatio(
        aspectRatio: aspect,
        child: Stack(
          fit: StackFit.expand,
          children: [
            player,
            if (onOpenImmersive != null && (hasUrl || hasPlaylist))
                Positioned(
                right: StudioSpacing.xs,
                top: StudioSpacing.xs,
                child: Tooltip(
                  message: AppLocalizations.of(context)!
                      .shortVideoImmersiveFullscreen,
                  child: FilledButton.tonal(
                    style: studioFormTonalButtonStyle(context),
                    onPressed: onOpenImmersive,
                    child: const Icon(Icons.fullscreen, size: StudioIconSize.sm),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
