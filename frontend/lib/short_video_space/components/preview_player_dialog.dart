part of 'preview_player.dart';

class PreviewPlayerDialog extends StatelessWidget {
  final String? videoUrl;
  final int? shotNumber;
  final String? shotTitle;
  final String? durationText;
  final List<ShotPreviewItem>? playlist;
  final String videoRatio;

  const PreviewPlayerDialog({
    super.key,
    this.videoUrl,
    this.shotNumber,
    this.shotTitle,
    this.durationText,
    this.playlist,
    this.videoRatio = '9:16',
  }) : assert(
         (videoUrl != null && playlist == null) ||
             (videoUrl == null && playlist != null && playlist.length > 0),
         'Either videoUrl or non-empty playlist must be provided',
       );

  /// 显示单镜头预览播放器对话框
  static Future<void> show(
    BuildContext context, {
    required String videoUrl,
    int? shotNumber,
    String? shotTitle,
    String? durationText,
    String videoRatio = '9:16',
  }) {
    return showStudioDialog<void>(
      context: context,
      builder: (context) => PreviewPlayerDialog(
        videoUrl: videoUrl,
        shotNumber: shotNumber,
        shotTitle: shotTitle,
        durationText: durationText,
        videoRatio: videoRatio,
      ),
    );
  }

  /// 显示成片连续播放对话框
  static Future<void> showPlaylist(
    BuildContext context, {
    required List<ShotPreviewItem> playlist,
    String videoRatio = '9:16',
  }) {
    return showStudioDialog<void>(
      context: context,
      builder: (context) => PreviewPlayerDialog(
        playlist: playlist,
        videoRatio: videoRatio,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = _previewPlayerL10n(context);
    return StudioDialogFrame(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 800,
          maxHeight: MediaQuery.sizeOf(context).height * 0.9,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              PreviewPlayer(
                videoUrl: videoUrl,
                shotNumber: shotNumber,
                shotTitle: shotTitle,
                durationText: durationText,
                playlist: playlist,
                videoRatio: videoRatio,
                autoPlay: true,
                onPlaylistComplete: () {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(l10n.shortVideoPreviewPlaylistComplete),
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  }
                },
              ),
              Padding(
                padding: const EdgeInsets.all(StudioSpacing.radiusComfort),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: Text(l10n.shortVideoSpaceClose),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
