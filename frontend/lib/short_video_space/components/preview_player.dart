import 'dart:async';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../../l10n/app_localizations.dart';
import '../../rust_api.dart';
import 'package:openflow_app/design_system/components/studio_dialog_shell.dart';
import 'package:openflow_app/design_system/tokens.dart';

AppLocalizations _previewPlayerL10n(BuildContext context) =>
    AppLocalizations.of(context) ?? lookupAppLocalizations(const Locale('en'));

/// 播放列表项，用于连续播放
class ShotPreviewItem {
  final String videoUrl;
  final int shotNumber;
  final String? shotTitle;
  final String? durationText;

  const ShotPreviewItem({
    required this.videoUrl,
    required this.shotNumber,
    this.shotTitle,
    this.durationText,
  });
}

/// 预览播放器组件，用于播放单个镜头或连续播放成片
///
/// 支持功能：
/// - 播放/暂停/停止控制
/// - 进度条和时间显示
/// - 拖动进度条跳转
/// - 显示镜头基本信息
/// - 连续播放多个镜头（播放列表模式）
/// - 上一个/下一个镜头控制
/// - 总进度和当前镜头进度显示
class PreviewPlayer extends StatefulWidget {
  /// 视频 URL（单镜头模式）
  final String? videoUrl;

  /// 镜头序号（单镜头模式）
  final int? shotNumber;

  /// 镜头标题/字幕（单镜头模式）
  final String? shotTitle;

  /// 镜头时长文本（单镜头模式）
  final String? durationText;

  /// 播放列表（连续播放模式）
  final List<ShotPreviewItem>? playlist;

  /// 是否自动播放
  final bool autoPlay;

  /// 播放完成回调（单镜头模式）
  final VoidCallback? onPlaybackComplete;

  /// 所有镜头播放完成回调（连续播放模式）
  final VoidCallback? onPlaylistComplete;

  const PreviewPlayer({
    super.key,
    this.videoUrl,
    this.shotNumber,
    this.shotTitle,
    this.durationText,
    this.playlist,
    this.autoPlay = false,
    this.onPlaybackComplete,
    this.onPlaylistComplete,
  }) : assert(
         (videoUrl != null && playlist == null) ||
             (videoUrl == null && playlist != null && playlist.length > 0),
         'Either videoUrl or non-empty playlist must be provided',
       );

  @override
  State<PreviewPlayer> createState() => _PreviewPlayerState();
}

class _PreviewPlayerState extends State<PreviewPlayer> {
  VideoPlayerController? _controller;
  bool _isInitialized = false;
  bool _hasError = false;
  String? _errorMessage;
  bool _isPlaying = false;
  Duration _currentPosition = Duration.zero;
  Duration _totalDuration = Duration.zero;
  bool _isDragging = false;

  // 播放列表相关状态
  int _currentShotIndex = 0;
  List<Duration> _shotDurations = [];
  Duration _totalPlaylistDuration = Duration.zero;
  Duration _playlistProgress = Duration.zero;

  bool get _isPlaylistMode => widget.playlist != null;

  ShotPreviewItem? get _currentShot =>
      _isPlaylistMode ? widget.playlist![_currentShotIndex] : null;

  String get _currentVideoUrl =>
      _isPlaylistMode ? _currentShot!.videoUrl : widget.videoUrl!;

  int? get _currentShotNumber =>
      _isPlaylistMode ? _currentShot!.shotNumber : widget.shotNumber;

  String? get _currentShotTitle =>
      _isPlaylistMode ? _currentShot!.shotTitle : widget.shotTitle;

  String? get _currentDurationText =>
      _isPlaylistMode ? _currentShot!.durationText : widget.durationText;

  @override
  void initState() {
    super.initState();
    if (_isPlaylistMode) {
      _shotDurations = List.filled(widget.playlist!.length, Duration.zero);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        unawaited(_initializePlayer());
      }
    });
  }

  @override
  void didUpdateWidget(PreviewPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    final oldUrl = oldWidget.playlist != null
        ? (oldWidget.playlist!.isNotEmpty
              ? oldWidget.playlist![0].videoUrl
              : '')
        : oldWidget.videoUrl;
    final newUrl = widget.playlist != null
        ? (widget.playlist!.isNotEmpty ? widget.playlist![0].videoUrl : '')
        : widget.videoUrl;

    if (oldUrl != newUrl) {
      _currentShotIndex = 0;
      if (_isPlaylistMode) {
        _shotDurations = List.filled(widget.playlist!.length, Duration.zero);
      }
      _disposeController();
      _initializePlayer();
    }
  }

  @override
  void dispose() {
    _disposeController();
    super.dispose();
  }

  void _disposeController() {
    _controller?.removeListener(_videoListener);
    _controller?.dispose();
    _controller = null;
  }

  Future<void> _initializePlayer() async {
    setState(() {
      _isInitialized = false;
      _hasError = false;
      _errorMessage = null;
      _isPlaying = false;
      _currentPosition = Duration.zero;
      _totalDuration = Duration.zero;
    });

    if (_currentVideoUrl.isEmpty) {
      if (!mounted) return;
      final l10n = _previewPlayerL10n(context);
      setState(() {
        _hasError = true;
        _errorMessage = l10n.shortVideoPreviewPlayerVideoUrlEmpty;
      });
      return;
    }

    try {
      final controller = VideoPlayerController.networkUrl(
        Uri.parse(_currentVideoUrl),
      );

      _controller = controller;

      await controller.initialize();

      if (!mounted) return;

      setState(() {
        _isInitialized = true;
        _totalDuration = controller.value.duration;

        // 在播放列表模式下，记录当前镜头的时长
        if (_isPlaylistMode) {
          _shotDurations[_currentShotIndex] = controller.value.duration;
          _updateTotalPlaylistDuration();
        }
      });

      controller.addListener(_videoListener);

      if (widget.autoPlay) {
        await controller.play();
        setState(() {
          _isPlaying = true;
        });
      }
    } catch (e) {
      if (!mounted) return;
      final l10n = _previewPlayerL10n(context);
      setState(() {
        _hasError = true;
        _errorMessage = l10n.shortVideoPreviewPlayerLoadFailed(
          describeUserVisibleApiErrorResolved(context, e),
        );
      });
    }
  }

  /// 更新播放列表总时长
  void _updateTotalPlaylistDuration() {
    if (!_isPlaylistMode) return;

    _totalPlaylistDuration = _shotDurations.fold(
      Duration.zero,
      (sum, duration) => sum + duration,
    );
  }

  /// 更新播放列表进度
  void _updatePlaylistProgress() {
    if (!_isPlaylistMode) return;

    // 计算已播放完成的镜头的总时长
    Duration completedDuration = Duration.zero;
    for (int i = 0; i < _currentShotIndex; i++) {
      completedDuration += _shotDurations[i];
    }

    // 加上当前镜头的播放进度
    _playlistProgress = completedDuration + _currentPosition;
  }

  void _videoListener() {
    if (_controller == null || !mounted) return;

    final controller = _controller!;
    final isPlaying = controller.value.isPlaying;
    final position = controller.value.position;

    // 检查是否播放完成
    if (position >= controller.value.duration &&
        controller.value.duration.inMilliseconds > 0) {
      if (_isPlaying) {
        if (_isPlaylistMode) {
          // 播放列表模式：自动播放下一个镜头
          _playNextShot();
        } else {
          // 单镜头模式：停止播放并回调
          setState(() {
            _isPlaying = false;
          });
          widget.onPlaybackComplete?.call();
        }
      }
    }

    // 更新播放状态和进度（仅在非拖动时更新）
    if (!_isDragging) {
      setState(() {
        _isPlaying = isPlaying;
        _currentPosition = position;

        // 更新播放列表进度
        if (_isPlaylistMode) {
          _updatePlaylistProgress();
        }
      });
    }
  }

  /// 播放下一个镜头
  Future<void> _playNextShot() async {
    if (!_isPlaylistMode) return;

    // 检查是否还有下一个镜头
    if (_currentShotIndex < widget.playlist!.length - 1) {
      // 切换到下一个镜头
      setState(() {
        _currentShotIndex++;
        _isInitialized = false;
        _hasError = false;
        _errorMessage = null;
        _currentPosition = Duration.zero;
      });

      // 释放当前控制器
      _disposeController();

      // 初始化新镜头的播放器
      await _initializePlayer();

      // 自动播放
      if (_controller != null && _isInitialized) {
        await _controller!.play();
        setState(() {
          _isPlaying = true;
        });
      }
    } else {
      // 所有镜头播放完毕
      setState(() {
        _isPlaying = false;
      });
      widget.onPlaylistComplete?.call();
    }
  }

  /// 播放上一个镜头
  Future<void> _playPreviousShot() async {
    if (!_isPlaylistMode) return;

    // 检查是否还有上一个镜头
    if (_currentShotIndex > 0) {
      // 切换到上一个镜头
      setState(() {
        _currentShotIndex--;
        _isInitialized = false;
        _hasError = false;
        _errorMessage = null;
        _currentPosition = Duration.zero;
      });

      // 释放当前控制器
      _disposeController();

      // 初始化新镜头的播放器
      await _initializePlayer();

      // 自动播放
      if (_controller != null && _isInitialized) {
        await _controller!.play();
        setState(() {
          _isPlaying = true;
        });
      }
    }
  }

  /// 跳转到指定镜头
  /// TODO: 将在添加镜头选择 UI 时使用
  // ignore: unused_element
  Future<void> _jumpToShot(int index) async {
    if (!_isPlaylistMode) return;
    if (index < 0 || index >= widget.playlist!.length) return;
    if (index == _currentShotIndex) return;

    final wasPlaying = _isPlaying;

    // 切换到指定镜头
    setState(() {
      _currentShotIndex = index;
      _isInitialized = false;
      _hasError = false;
      _errorMessage = null;
      _currentPosition = Duration.zero;
    });

    // 释放当前控制器
    _disposeController();

    // 初始化新镜头的播放器
    await _initializePlayer();

    // 如果之前在播放，则自动播放新镜头
    if (wasPlaying && _controller != null && _isInitialized) {
      await _controller!.play();
      setState(() {
        _isPlaying = true;
      });
    }
  }

  Future<void> _togglePlayPause() async {
    if (_controller == null || !_isInitialized) return;

    if (_isPlaying) {
      await _controller!.pause();
      setState(() {
        _isPlaying = false;
      });
    } else {
      await _controller!.play();
      setState(() {
        _isPlaying = true;
      });
    }
  }

  Future<void> _stop() async {
    if (_controller == null || !_isInitialized) return;

    await _controller!.pause();
    await _controller!.seekTo(Duration.zero);
    setState(() {
      _isPlaying = false;
      _currentPosition = Duration.zero;
    });
  }

  Future<void> _seekTo(Duration position) async {
    if (_controller == null || !_isInitialized) return;
    await _controller!.seekTo(position);
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = _previewPlayerL10n(context);
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(minWidth: constraints.maxWidth),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 镜头信息
              if (_currentShotNumber != null || _currentShotTitle != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.surfaceContainerHighest,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(8),
                    ),
                  ),
                  child: Row(
                    children: [
                      if (_currentShotNumber != null) ...[
                        Icon(
                          Icons.movie_outlined,
                          size: 20,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          l10n.shortVideoPreviewPlayerShotLabel(
                            _currentShotNumber!,
                          ),
                          style: Theme.of(context).textTheme.titleSmall
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                      ],
                      if (_isPlaylistMode) ...[
                        const SizedBox(width: 8),
                        Text(
                          l10n.shortVideoPreviewPlayerPlaylistPosition(
                            _currentShotIndex + 1,
                            widget.playlist!.length,
                          ),
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: StudioTokens.of(context).textSecondary,
                              ),
                        ),
                      ],
                      if (_currentShotNumber != null &&
                          _currentShotTitle != null)
                        const SizedBox(width: 16),
                      if (_currentShotTitle != null)
                        Expanded(
                          child: Text(
                            _currentShotTitle!,
                            style: Theme.of(context).textTheme.bodyMedium,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      if (_currentDurationText != null) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: StudioTokens.of(context).primarySoft,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            _currentDurationText!,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onPrimaryContainer,
                                ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],

              // 视频播放器
              Container(
                color: Colors.black,
                child: AspectRatio(
                  aspectRatio: 16 / 9,
                  child: _buildVideoContent(context),
                ),
              ),

              // 播放控制
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: const BorderRadius.vertical(
                    bottom: Radius.circular(8),
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // 播放列表总进度（仅在播放列表模式下显示）
                    if (_isPlaylistMode) ...[
                      Row(
                        children: [
                          Icon(
                            Icons.playlist_play,
                            size: 16,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            l10n.shortVideoPreviewPlayerOverallProgress,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: StudioTokens.of(context).textSecondary,
                                ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: LinearProgressIndicator(
                              value: _totalPlaylistDuration.inMilliseconds > 0
                                  ? _playlistProgress.inMilliseconds /
                                        _totalPlaylistDuration.inMilliseconds
                                  : 0,
                              backgroundColor: Theme.of(
                                context,
                              ).colorScheme.surfaceContainerHighest,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '${_formatDuration(_playlistProgress)} / ${_formatDuration(_totalPlaylistDuration)}',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                      const SizedBox(height: StudioSpacing.sm),
                    ],

                    // 当前镜头进度条
                    Row(
                      children: [
                        if (_isPlaylistMode)
                          Icon(
                            Icons.movie,
                            size: 16,
                            color: StudioTokens.of(context).textSecondary,
                          ),
                        if (_isPlaylistMode) const SizedBox(width: 8),
                        Text(
                          _formatDuration(_currentPosition),
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: SliderTheme(
                            data: SliderTheme.of(context).copyWith(
                              trackHeight: 2,
                              thumbShape: const RoundSliderThumbShape(
                                enabledThumbRadius: 6,
                              ),
                              overlayShape: const RoundSliderOverlayShape(
                                overlayRadius: 12,
                              ),
                            ),
                            child: Slider(
                              value: _totalDuration.inMilliseconds > 0
                                  ? _currentPosition.inMilliseconds.toDouble()
                                  : 0,
                              min: 0,
                              max: _totalDuration.inMilliseconds.toDouble(),
                              onChanged: _isInitialized
                                  ? (value) {
                                      setState(() {
                                        _isDragging = true;
                                        _currentPosition = Duration(
                                          milliseconds: value.toInt(),
                                        );
                                      });
                                    }
                                  : null,
                              onChangeEnd: (value) {
                                setState(() {
                                  _isDragging = false;
                                });
                                _seekTo(Duration(milliseconds: value.toInt()));
                              },
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _formatDuration(_totalDuration),
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // 播放控制按钮
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // 上一个镜头按钮（仅在播放列表模式下显示）
                        if (_isPlaylistMode) ...[
                          IconButton(
                            onPressed: _currentShotIndex > 0
                                ? _playPreviousShot
                                : null,
                            icon: const Icon(Icons.skip_previous),
                            tooltip: l10n.shortVideoPreviewPlayerPreviousShot,
                          ),
                          const SizedBox(width: 8),
                        ],

                        IconButton(
                          onPressed: _isInitialized ? _stop : null,
                          icon: const Icon(Icons.stop),
                          tooltip: l10n.shortVideoPreviewPlayerStop,
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          onPressed: _isInitialized ? _togglePlayPause : null,
                          icon: Icon(
                            _isPlaying ? Icons.pause : Icons.play_arrow,
                          ),
                          iconSize: 32,
                          tooltip: _isPlaying
                              ? l10n.shortVideoPreviewPlayerPause
                              : l10n.shortVideoPreviewPlayerPlay,
                        ),

                        // 下一个镜头按钮（仅在播放列表模式下显示）
                        if (_isPlaylistMode) ...[
                          const SizedBox(width: 8),
                          IconButton(
                            onPressed:
                                _currentShotIndex < widget.playlist!.length - 1
                                ? _playNextShot
                                : null,
                            icon: const Icon(Icons.skip_next),
                            tooltip: l10n.shortVideoPreviewPlayerNextShot,
                          ),
                        ],
                      ],
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

  Widget _buildVideoContent(BuildContext context) {
    final l10n = _previewPlayerL10n(context);
    if (_hasError) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 48,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: 16),
            Text(
              _errorMessage ?? l10n.shortVideoSpacePreviewVideoLoadFailed,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    if (!_isInitialized) {
      return const Center(child: CircularProgressIndicator());
    }

    return VideoPlayer(_controller!);
  }
}

/// 预览播放器对话框，用于在对话框中显示预览播放器
class PreviewPlayerDialog extends StatelessWidget {
  final String? videoUrl;
  final int? shotNumber;
  final String? shotTitle;
  final String? durationText;
  final List<ShotPreviewItem>? playlist;

  const PreviewPlayerDialog({
    super.key,
    this.videoUrl,
    this.shotNumber,
    this.shotTitle,
    this.durationText,
    this.playlist,
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
  }) {
    return showStudioDialog<void>(
      context: context,
      builder: (context) => PreviewPlayerDialog(
        videoUrl: videoUrl,
        shotNumber: shotNumber,
        shotTitle: shotTitle,
        durationText: durationText,
      ),
    );
  }

  /// 显示成片连续播放对话框
  static Future<void> showPlaylist(
    BuildContext context, {
    required List<ShotPreviewItem> playlist,
  }) {
    return showStudioDialog<void>(
      context: context,
      builder: (context) => PreviewPlayerDialog(playlist: playlist),
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
                padding: const EdgeInsets.all(12),
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
