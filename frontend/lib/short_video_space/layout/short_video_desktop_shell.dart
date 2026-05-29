import 'package:flutter/material.dart';

import '../../design_system/components/studio_loading_placeholders.dart';
import '../../design_system/ix/studio_scroll_behavior.dart';
import '../../design_system/tokens.dart';
import '../../l10n/app_localizations.dart';
import '../components/preview_player.dart';
import '../short_video_aspect_ratio.dart';
import 'short_video_responsive_shell.dart';

/// Desktop / tablet shell: master | detail [| preview when wide].
class ShortVideoDesktopShell extends StatelessWidget {
  const ShortVideoDesktopShell({
    super.key,
    required this.videoRatio,
    required this.masterPane,
    required this.detailPane,
    this.previewVideoUrl,
    this.previewBusy = false,
    this.previewPlaylist,
    this.threePane = true,
  });

  final String videoRatio;
  final Widget masterPane;
  final Widget detailPane;
  final String? previewVideoUrl;
  final bool previewBusy;
  final List<ShotPreviewPlaylistEntry>? previewPlaylist;
  final bool threePane;

  @override
  Widget build(BuildContext context) {
    final preview = _ShortVideoInlinePreviewPane(
      videoRatio: videoRatio,
      previewVideoUrl: previewVideoUrl,
      previewBusy: previewBusy,
      previewPlaylist: previewPlaylist,
    );

    if (!threePane) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: StudioScrollbar(
              child: SingleChildScrollView(
                padding: const EdgeInsets.only(right: StudioSpacing.sm),
                child: masterPane,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: StudioScrollbar(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    preview,
                    const SizedBox(height: StudioSpacing.sm),
                    detailPane,
                  ],
                ),
              ),
            ),
          ),
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 2,
          child: StudioScrollbar(
            child: SingleChildScrollView(
              padding: const EdgeInsets.only(right: StudioSpacing.sm),
              child: masterPane,
            ),
          ),
        ),
        Expanded(
          flex: 4,
          child: StudioScrollbar(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: StudioSpacing.xs),
              child: detailPane,
            ),
          ),
        ),
        Expanded(
          flex: 4,
          child: StudioScrollbar(
            child: SingleChildScrollView(
              padding: const EdgeInsets.only(left: StudioSpacing.sm),
              child: preview,
            ),
          ),
        ),
      ],
    );
  }
}

class _ShortVideoInlinePreviewPane extends StatelessWidget {
  const _ShortVideoInlinePreviewPane({
    required this.videoRatio,
    this.previewVideoUrl,
    this.previewBusy = false,
    this.previewPlaylist,
  });

  final String videoRatio;
  final String? previewVideoUrl;
  final bool previewBusy;
  final List<ShotPreviewPlaylistEntry>? previewPlaylist;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = StudioTokens.of(context);
    final l10n = AppLocalizations.of(context)!;
    final hasUrl = (previewVideoUrl ?? '').trim().isNotEmpty;
    final hasPlaylist = previewPlaylist != null && previewPlaylist!.isNotEmpty;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(StudioSpacing.sm),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l10n.studioEpisodePreviewPlaceholder,
              style: theme.textTheme.titleSmall,
            ),
            const SizedBox(height: StudioSpacing.xs),
            if (previewBusy)
              AspectRatio(
                aspectRatio: shortVideoAspectRatioFromLabel(videoRatio),
                child: const StudioMediaTileSkeleton(),
              )
            else if (hasPlaylist)
              PreviewPlayer(
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
              )
            else if (hasUrl)
              PreviewPlayer(
                videoUrl: previewVideoUrl,
                videoRatio: videoRatio,
              )
            else
              AspectRatio(
                aspectRatio: shortVideoAspectRatioFromLabel(videoRatio),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: tokens.bgSurface,
                    borderRadius: BorderRadius.circular(
                      StudioSpacing.radiusCard,
                    ),
                    border: Border.all(color: tokens.borderSubtle),
                  ),
                  child: Center(
                    child: Text(
                      l10n.shortVideoPreviewPaneEmpty,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: tokens.textMuted,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
