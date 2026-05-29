import 'package:flutter/material.dart';

import '../../design_system/ix/studio_mobile_affordances.dart';
import '../../design_system/tokens.dart';
import '../components/preview_player.dart';
import '../layout/short_video_responsive_shell.dart';
import '../short_video_aspect_ratio.dart';

/// Full-screen 9:16 (or project ratio) immersive preview with creation dock.
class ShortVideoImmersivePreviewPage extends StatefulWidget {
  const ShortVideoImmersivePreviewPage({
    super.key,
    required this.videoRatio,
    this.videoUrl,
    this.playlist,
    this.initialIndex = 0,
    this.blockPop = false,
    this.dockActions,
  });

  final String videoRatio;
  final String? videoUrl;
  final List<ShotPreviewPlaylistEntry>? playlist;
  final int initialIndex;
  final bool blockPop;
  final Widget? dockActions;

  static Future<void> push(
    BuildContext context, {
    required String videoRatio,
    String? videoUrl,
    List<ShotPreviewPlaylistEntry>? playlist,
    int initialIndex = 0,
    bool blockPop = false,
    Widget? dockActions,
  }) {
    return Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (context) => ShortVideoImmersivePreviewPage(
          videoRatio: videoRatio,
          videoUrl: videoUrl,
          playlist: playlist,
          initialIndex: initialIndex,
          blockPop: blockPop,
          dockActions: dockActions,
        ),
      ),
    );
  }

  @override
  State<ShortVideoImmersivePreviewPage> createState() =>
      _ShortVideoImmersivePreviewPageState();
}

class _ShortVideoImmersivePreviewPageState
    extends State<ShortVideoImmersivePreviewPage> {
  late final PageController _pageController;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  List<ShotPreviewPlaylistEntry> get _entries {
    if (widget.playlist != null && widget.playlist!.isNotEmpty) {
      return widget.playlist!;
    }
    final url = (widget.videoUrl ?? '').trim();
    if (url.isEmpty) {
      return const [];
    }
    return [
      ShotPreviewPlaylistEntry(videoUrl: url, shotNumber: 1),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final entries = _entries;
    final tokens = StudioTokens.of(context);
    final aspect = shortVideoAspectRatioFromLabel(widget.videoRatio);

    return PopScope(
      canPop: !widget.blockPop,
      child: StudioSystemUiSurface(
        surfaceColor: tokens.bgBase,
        child: Scaffold(
          backgroundColor: tokens.bgBase,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.close),
              onPressed: widget.blockPop
                  ? null
                  : () => Navigator.of(context).pop(),
            ),
          ),
          body: Column(
            children: [
              Expanded(
                child: entries.length <= 1
                    ? Center(
                        child: AspectRatio(
                          aspectRatio: aspect,
                          child: PreviewPlayer(
                            videoUrl: entries.isEmpty
                                ? widget.videoUrl
                                : entries.first.videoUrl,
                            shotNumber: entries.isEmpty
                                ? null
                                : entries.first.shotNumber,
                            shotTitle: entries.isEmpty
                                ? null
                                : entries.first.shotTitle,
                            videoRatio: widget.videoRatio,
                            autoPlay: true,
                          ),
                        ),
                      )
                    : PageView.builder(
                        controller: _pageController,
                        scrollDirection: Axis.vertical,
                        itemCount: entries.length,
                        onPageChanged: (index) {
                          setState(() => _currentIndex = index);
                        },
                        itemBuilder: (context, index) {
                          final entry = entries[index];
                          return Center(
                            child: AspectRatio(
                              aspectRatio: aspect,
                              child: PreviewPlayer(
                                key: ValueKey(entry.videoUrl),
                                videoUrl: entry.videoUrl,
                                shotNumber: entry.shotNumber,
                                shotTitle: entry.shotTitle,
                                durationText: entry.durationText,
                                videoRatio: widget.videoRatio,
                                autoPlay: index == _currentIndex,
                              ),
                            ),
                          );
                        },
                      ),
              ),
              if (widget.dockActions != null)
                SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.all(StudioSpacing.sm),
                    child: widget.dockActions,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
