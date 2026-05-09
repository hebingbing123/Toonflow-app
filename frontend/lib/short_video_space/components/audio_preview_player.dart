part of '../section.dart';

/// Audio preview player component for TTS-generated voiceovers
///
/// This component provides:
/// - Audio playback controls (play/pause/stop)
/// - Volume adjustment slider
/// - Progress bar with time display
/// - Seek functionality
///
/// **Validates: Requirements 5**
class AudioPreviewPlayer extends StatefulWidget {
  const AudioPreviewPlayer({
    super.key,
    required this.audioUrl,
    this.autoPlay = false,
    this.onClose,
  });

  /// URL of the audio file to preview
  final String audioUrl;

  /// Whether to start playing automatically
  final bool autoPlay;

  /// Callback when close button is pressed
  final VoidCallback? onClose;

  @override
  State<AudioPreviewPlayer> createState() => _AudioPreviewPlayerState();
}

class _AudioPreviewPlayerState extends State<AudioPreviewPlayer> {
  late AudioPlayer _audioPlayer;
  PlayerState _playerState = PlayerState.stopped;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;
  double _volume = 1.0;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _audioPlayer = AudioPlayer();
    _initializePlayer();
  }

  Future<void> _initializePlayer() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Set up listeners
      _audioPlayer.onPlayerStateChanged.listen((state) {
        if (mounted) {
          setState(() {
            _playerState = state;
          });
        }
      });

      _audioPlayer.onDurationChanged.listen((duration) {
        if (mounted) {
          setState(() {
            _duration = duration;
          });
        }
      });

      _audioPlayer.onPositionChanged.listen((position) {
        if (mounted) {
          setState(() {
            _position = position;
          });
        }
      });

      _audioPlayer.onPlayerComplete.listen((_) {
        if (mounted) {
          setState(() {
            _position = Duration.zero;
            _playerState = PlayerState.stopped;
          });
        }
      });

      // Set audio source
      await _audioPlayer.setSourceUrl(widget.audioUrl);
      await _audioPlayer.setVolume(_volume);

      setState(() {
        _isLoading = false;
      });

      // Auto play if requested
      if (widget.autoPlay) {
        await _audioPlayer.resume();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = '加载音频失败: $e';
        });
      }
    }
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _togglePlayPause() async {
    try {
      if (_playerState == PlayerState.playing) {
        await _audioPlayer.pause();
      } else {
        await _audioPlayer.resume();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = '播放控制失败: $e';
        });
      }
    }
  }

  Future<void> _stop() async {
    try {
      await _audioPlayer.stop();
      setState(() {
        _position = Duration.zero;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = '停止播放失败: $e';
        });
      }
    }
  }

  Future<void> _seek(Duration position) async {
    try {
      await _audioPlayer.seek(position);
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = '跳转失败: $e';
        });
      }
    }
  }

  Future<void> _setVolume(double volume) async {
    try {
      await _audioPlayer.setVolume(volume);
      setState(() {
        _volume = volume;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = '音量调节失败: $e';
        });
      }
    }
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header with title and close button
          Row(
            children: [
              Icon(
                Icons.audiotrack,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '配音预览',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ),
              if (widget.onClose != null)
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: widget.onClose,
                  tooltip: '关闭',
                ),
            ],
          ),
          const SizedBox(height: 16),

          // Error message
          if (_errorMessage != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.errorContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.error_outline,
                    color: Theme.of(context).colorScheme.error,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _errorMessage!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onErrorContainer,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Loading indicator
          if (_isLoading) ...[
            const Center(
              child: CircularProgressIndicator(),
            ),
            const SizedBox(height: 8),
            Center(
              child: Text(
                '正在加载音频...',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ] else ...[
            // Progress bar with time display
            Row(
              children: [
                Text(
                  _formatDuration(_position),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontFamily: 'monospace',
                      ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      trackHeight: 4,
                      thumbShape: const RoundSliderThumbShape(
                        enabledThumbRadius: 6,
                      ),
                      overlayShape: const RoundSliderOverlayShape(
                        overlayRadius: 12,
                      ),
                    ),
                    child: Slider(
                      value: _duration.inMilliseconds > 0
                          ? _position.inMilliseconds.toDouble()
                          : 0,
                      min: 0,
                      max: _duration.inMilliseconds.toDouble(),
                      onChanged: (value) {
                        _seek(Duration(milliseconds: value.toInt()));
                      },
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  _formatDuration(_duration),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontFamily: 'monospace',
                      ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Playback controls
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Stop button
                IconButton(
                  icon: const Icon(Icons.stop),
                  onPressed: _playerState != PlayerState.stopped ? _stop : null,
                  tooltip: '停止',
                  iconSize: 28,
                ),
                const SizedBox(width: 16),

                // Play/Pause button
                IconButton(
                  icon: Icon(
                    _playerState == PlayerState.playing
                        ? Icons.pause_circle_filled
                        : Icons.play_circle_filled,
                  ),
                  onPressed: _togglePlayPause,
                  tooltip: _playerState == PlayerState.playing ? '暂停' : '播放',
                  iconSize: 48,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Volume control
            Row(
              children: [
                Icon(
                  _volume == 0
                      ? Icons.volume_off
                      : _volume < 0.5
                          ? Icons.volume_down
                          : Icons.volume_up,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      trackHeight: 3,
                      thumbShape: const RoundSliderThumbShape(
                        enabledThumbRadius: 5,
                      ),
                      overlayShape: const RoundSliderOverlayShape(
                        overlayRadius: 10,
                      ),
                    ),
                    child: Slider(
                      value: _volume,
                      min: 0,
                      max: 1,
                      divisions: 20,
                      label: '${(_volume * 100).toInt()}%',
                      onChanged: _setVolume,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 40,
                  child: Text(
                    '${(_volume * 100).toInt()}%',
                    textAlign: TextAlign.right,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
