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

  AppLocalizations get _l10n =>
      AppLocalizations.of(context) ??
      lookupAppLocalizations(const Locale('en'));

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
          _errorMessage = _l10n.shortVideoAudioPreviewLoadFailed(
            describeUserVisibleApiErrorResolved(context, e),
          );
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
          _errorMessage = _l10n.shortVideoAudioPreviewPlaybackFailed(
            describeUserVisibleApiErrorResolved(context, e),
          );
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
          _errorMessage = _l10n.shortVideoAudioPreviewStopFailed(
            describeUserVisibleApiErrorResolved(context, e),
          );
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
          _errorMessage = _l10n.shortVideoAudioPreviewSeekFailed(
            describeUserVisibleApiErrorResolved(context, e),
          );
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
          _errorMessage = _l10n.shortVideoAudioPreviewVolumeFailed(
            describeUserVisibleApiErrorResolved(context, e),
          );
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
    final l10n = _l10n;
    return Container(
      padding: const EdgeInsets.all(StudioSpacing.sm),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(StudioSpacing.radiusComfort),
        border: Border.all(
          color: studioPanelBorderColor(context).withValues(alpha: 0.2),
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
              const SizedBox(width: StudioSpacing.xs),
              Expanded(
                child: Text(
                  l10n.shortVideoAudioPreviewTitle,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              if (widget.onClose != null)
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: widget.onClose,
                  tooltip: l10n.shortVideoAudioPreviewCloseTooltip,
                ),
            ],
          ),
          const SizedBox(height: StudioSpacing.sm),

          if (_errorMessage != null) ...[
            StudioApiErrorCallout(
              error: _errorMessage!,
              emphasis: StudioApiErrorCalloutEmphasis.subtle,
              onDismiss: () => setState(() => _errorMessage = null),
            ),
            const SizedBox(height: StudioSpacing.sm),
          ],

          // Loading indicator
          if (_isLoading) ...[
            const Center(child: StudioMediaTileSkeleton()),
            const SizedBox(height: StudioSpacing.xs),
            Center(
              child: Text(
                l10n.shortVideoAudioPreviewLoading,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ] else ...[
            // Progress bar with time display
            Row(
              children: [
                Text(
                  _formatDuration(_position),
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(fontFamily: 'monospace'),
                ),
                const SizedBox(width: StudioSpacing.xs),
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
                const SizedBox(width: StudioSpacing.xs),
                Text(
                  _formatDuration(_duration),
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(fontFamily: 'monospace'),
                ),
              ],
            ),
            const SizedBox(height: StudioSpacing.sm),

            // Playback controls
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Stop button
                IconButton(
                  icon: const Icon(Icons.stop),
                  onPressed: _playerState != PlayerState.stopped ? _stop : null,
                  tooltip: l10n.shortVideoAudioPreviewTooltipStop,
                  iconSize: 28,
                ),
                const SizedBox(width: StudioSpacing.sm),

                // Play/Pause button
                IconButton(
                  icon: Icon(
                    _playerState == PlayerState.playing
                        ? Icons.pause_circle_filled
                        : Icons.play_circle_filled,
                  ),
                  onPressed: _togglePlayPause,
                  tooltip: _playerState == PlayerState.playing
                      ? l10n.shortVideoAudioPreviewTooltipPause
                      : l10n.shortVideoAudioPreviewTooltipPlay,
                  iconSize: 48,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ],
            ),
            const SizedBox(height: StudioSpacing.sm),

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
                const SizedBox(width: StudioSpacing.xs),
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
                      label: l10n.shortVideoAudioVolumePercent(
                        (_volume * 100).toInt(),
                      ),
                      onChanged: _setVolume,
                    ),
                  ),
                ),
                const SizedBox(width: StudioSpacing.xs),
                SizedBox(
                  width: 40,
                  child: Text(
                    l10n.shortVideoAudioVolumePercent(
                      (_volume * 100).toInt(),
                    ),
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
