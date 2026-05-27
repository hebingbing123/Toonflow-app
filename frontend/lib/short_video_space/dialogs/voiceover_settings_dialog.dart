part of '../section.dart';

/// Voiceover settings dialog for configuring TTS parameters
///
/// This dialog allows users to:
/// - Select TTS provider (OpenAI/Azure/Google)
/// - Choose voice ID
/// - Adjust emotion parameters
/// - Configure speech speed
///
/// **Validates: Requirements 4**
extension _ShortVideoSpaceSectionVoiceoverSettingsDialog
    on _ShortVideoSpaceSectionState {
  /// Opens the voiceover settings dialog
  ///
  /// Returns a [VoiceoverSettings] object if user confirms, null if cancelled
  // ignore: unused_element
  Future<VoiceoverSettings?> _openVoiceoverSettingsDialog({
    required BuildContext context,
    VoiceoverSettings? initialSettings,
  }) async {
    return showStudioDialog<VoiceoverSettings>(
      context: context,
      builder: (dialogContext) {
        return VoiceoverSettingsDialog(
          initialSettings: initialSettings,
          onPreviewRequested: _previewVoiceoverSettings,
        );
      },
    );
  }

  Future<Uint8List> _previewVoiceoverSettings(VoiceoverSettings settings) async {
    final token = widget.accessToken?.trim();
    final project = _selectedProject;
    if (token == null || token.isEmpty || project == null) {
      throw StateError('Voice preview requires an active project and session.');
    }
    final l10n = resolveAppLocalizationsForErrors(context);
    final response = await previewTtsV1(
      token,
      text: l10n.shortVideoCharactersPreviewSampleText,
      projectId: project.id,
      voiceId: settings.voiceId,
      provider: settings.provider,
      emotion: settings.emotion,
      speed: settings.speed,
    );
    if (response.statusCode != 200) {
      throw RustApiException.fromHttpResponse(response);
    }
    return response.bodyBytes;
  }
}

const List<String> kSupportedVoiceoverProviders = <String>[
  'openai',
  'azure',
  'google',
];

List<String> getAvailableVoiceoverVoices(String provider) {
  switch (provider) {
    case 'openai':
      return ['alloy', 'echo', 'fable', 'onyx', 'nova', 'shimmer'];
    case 'azure':
      return [
        'zh-CN-XiaoxiaoNeural',
        'zh-CN-YunxiNeural',
        'zh-CN-YunjianNeural',
        'zh-CN-XiaoyiNeural',
        'zh-CN-YunyangNeural',
      ];
    case 'google':
      return [
        'zh-CN-Standard-A',
        'zh-CN-Standard-B',
        'zh-CN-Standard-C',
        'zh-CN-Standard-D',
        'zh-CN-Wavenet-A',
        'zh-CN-Wavenet-B',
        'zh-CN-Wavenet-C',
        'zh-CN-Wavenet-D',
      ];
    default:
      return ['alloy'];
  }
}

String getVoiceoverDisplayName(String voiceId, AppLocalizations l10n) {
  final openAIVoices = <String, String>{
    'alloy': l10n.shortVideoSpaceDialogVoiceoverSettingsVoiceAlloy,
    'echo': l10n.shortVideoSpaceDialogVoiceoverSettingsVoiceEcho,
    'fable': l10n.shortVideoSpaceDialogVoiceoverSettingsVoiceFable,
    'onyx': l10n.shortVideoSpaceDialogVoiceoverSettingsVoiceOnyx,
    'nova': l10n.shortVideoSpaceDialogVoiceoverSettingsVoiceNova,
    'shimmer': l10n.shortVideoSpaceDialogVoiceoverSettingsVoiceShimmer,
  };

  return openAIVoices[voiceId] ?? voiceId;
}

class VoiceoverSettingsDialog extends StatefulWidget {
  const VoiceoverSettingsDialog({
    super.key,
    this.initialSettings,
    this.onPreviewRequested,
    this.onPreviewAudioReady,
  });

  final VoiceoverSettings? initialSettings;
  final Future<Uint8List> Function(VoiceoverSettings settings)?
  onPreviewRequested;
  final Future<void> Function(Uint8List bytes)? onPreviewAudioReady;

  @override
  State<VoiceoverSettingsDialog> createState() =>
      _VoiceoverSettingsDialogState();
}

class _VoiceoverSettingsDialogState extends State<VoiceoverSettingsDialog> {
  late String _selectedProvider;
  late String _selectedVoiceId;
  late String _selectedEmotion;
  late double _selectedSpeed;
  late final AudioPlayer _previewPlayer;
  bool _previewBusy = false;
  bool _previewStatusIsError = false;
  String? _previewStatusLine;

  @override
  void initState() {
    super.initState();
    final settings = widget.initialSettings ?? const VoiceoverSettings();
    _selectedProvider = settings.provider;
    _selectedVoiceId = settings.voiceId;
    _selectedEmotion = settings.emotion;
    _selectedSpeed = settings.speed;
    _syncVoiceIdWithProvider();
    _previewPlayer = AudioPlayer();
  }

  @override
  void dispose() {
    unawaited(_previewPlayer.dispose());
    super.dispose();
  }

  void _syncVoiceIdWithProvider() {
    final availableVoices = getAvailableVoiceoverVoices(_selectedProvider);
    if (!availableVoices.contains(_selectedVoiceId)) {
      _selectedVoiceId = availableVoices.first;
    }
  }

  VoiceoverSettings get _currentSettings => VoiceoverSettings(
    provider: _selectedProvider,
    voiceId: _selectedVoiceId,
    emotion: _selectedEmotion,
    speed: _selectedSpeed,
  );

  Future<void> _runPreview() async {
    final loader = widget.onPreviewRequested;
    if (loader == null || _previewBusy) {
      return;
    }
    final l10n = resolveAppLocalizationsForErrors(context);
    final voiceName = getVoiceoverDisplayName(_selectedVoiceId, l10n);
    setState(() {
      _previewBusy = true;
      _previewStatusIsError = false;
      _previewStatusLine = l10n.shortVideoCharactersPreviewLoading(voiceName);
    });
    try {
      final bytes = await loader(_currentSettings);
      if (widget.onPreviewAudioReady != null) {
        await widget.onPreviewAudioReady!(bytes);
      } else {
        await _previewPlayer.stop();
        await _previewPlayer.play(BytesSource(bytes));
      }
      if (!mounted) {
        return;
      }
      setState(() {
        _previewStatusLine = l10n.shortVideoCharactersPreviewReady(voiceName);
      });
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _previewStatusIsError = true;
        _previewStatusLine = l10n.shortVideoCharactersPreviewFailed(
          voiceName,
          describeUserVisibleApiErrorResolved(context, e),
        );
      });
    } finally {
      if (mounted) {
        setState(() {
          _previewBusy = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final availableVoices = getAvailableVoiceoverVoices(_selectedProvider);
    final l10n = resolveAppLocalizationsForErrors(context);
    final tokens = StudioTokens.of(context);

    return StudioAlertDialog(
      scrollable: false,
      maxWidth: 560,
      title: Text(l10n.shortVideoSpaceDialogVoiceoverSettingsTitle),
      content: SizedBox(
        width: studioConstrainedDialogWidth(context, maxWidth: 520),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.shortVideoSpaceDialogVoiceoverSettingsProviderLabel,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: StudioSpacing.xs),
              StudioDropdownButtonFormField<String>(
                initialValue: _selectedProvider,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: StudioLayoutSpacing.insetDense,
                    vertical: StudioSpacing.xs,
                  ),
                ),
                items: [
                  DropdownMenuItem(
                    value: 'openai',
                    child: Text(l10n.shortVideoSpaceDialogVoiceoverSettingsProviderOpenAI),
                  ),
                  DropdownMenuItem(
                    value: 'azure',
                    child: Text(l10n.shortVideoSpaceDialogVoiceoverSettingsProviderAzure),
                  ),
                  DropdownMenuItem(
                    value: 'google',
                    child: Text(l10n.shortVideoSpaceDialogVoiceoverSettingsProviderGoogle),
                  ),
                ],
                onChanged: (value) {
                  if (value == null) {
                    return;
                  }
                  setState(() {
                    _selectedProvider = value;
                    _selectedVoiceId =
                        getAvailableVoiceoverVoices(value).first;
                  });
                },
              ),
              const SizedBox(height: StudioSpacing.sm),
              Text(
                l10n.shortVideoSpaceDialogVoiceoverSettingsVoiceLabel,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: StudioSpacing.xs),
              StudioDropdownButtonFormField<String>(
                key: ValueKey<String>('voiceover-voice-$_selectedProvider'),
                initialValue: _selectedVoiceId,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: StudioLayoutSpacing.insetDense,
                    vertical: StudioSpacing.xs,
                  ),
                ),
                items: availableVoices
                    .map(
                      (voice) => DropdownMenuItem(
                        value: voice,
                        child: Text(getVoiceoverDisplayName(voice, l10n)),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value == null) {
                    return;
                  }
                  setState(() {
                    _selectedVoiceId = value;
                  });
                },
              ),
              const SizedBox(height: StudioSpacing.sm),
              Text(
                l10n.shortVideoSpaceDialogVoiceoverSettingsEmotionLabel,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: StudioSpacing.xs),
              StudioDropdownButtonFormField<String>(
                initialValue: _selectedEmotion,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: StudioLayoutSpacing.insetDense,
                    vertical: StudioSpacing.xs,
                  ),
                ),
                items: [
                  DropdownMenuItem(
                    value: 'neutral',
                    child: Text(l10n.shortVideoSpaceDialogVoiceoverSettingsEmotionNeutral),
                  ),
                  DropdownMenuItem(
                    value: 'happy',
                    child: Text(l10n.shortVideoSpaceDialogVoiceoverSettingsEmotionHappy),
                  ),
                  DropdownMenuItem(
                    value: 'sad',
                    child: Text(l10n.shortVideoSpaceDialogVoiceoverSettingsEmotionSad),
                  ),
                  DropdownMenuItem(
                    value: 'angry',
                    child: Text(l10n.shortVideoSpaceDialogVoiceoverSettingsEmotionAngry),
                  ),
                ],
                onChanged: (value) {
                  if (value == null) {
                    return;
                  }
                  setState(() {
                    _selectedEmotion = value;
                  });
                },
              ),
              const SizedBox(height: StudioSpacing.sm),
              Text(
                l10n.shortVideoSpaceDialogVoiceoverSettingsSpeedLabel,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: StudioSpacing.xs),
              Row(
                children: [
                  Expanded(
                    child: Slider(
                      value: _selectedSpeed,
                      min: 0.5,
                      max: 2.0,
                      divisions: 15,
                      label: '${_selectedSpeed.toStringAsFixed(1)}x',
                      onChanged: (value) {
                        setState(() {
                          _selectedSpeed = value;
                        });
                      },
                    ),
                  ),
                  SizedBox(
                    width: StudioLayoutSize.sliderCompact,
                    child: Text(
                      resolveAppLocalizationsForErrors(context).shortVideoVoiceoverSpeedMultiplier(
                        _selectedSpeed.toStringAsFixed(1),
                      ),
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: StudioSpacing.xs),
              Text(
                l10n.shortVideoSpaceDialogVoiceoverSettingsSpeedRange,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              if (widget.onPreviewRequested != null) ...[
                const SizedBox(height: StudioSpacing.sm),
                Row(
                  children: [
                    FilledButton.tonalIcon(
                      onPressed: _previewBusy ? null : _runPreview,
                      icon: _previewBusy
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: StudioControlSize.progressStroke),
                            )
                          : const Icon(Icons.play_arrow),
                      label: Text(l10n.shortVideoCharactersPreviewVoice),
                    ),
                    if (_previewStatusLine != null) ...[
                      const SizedBox(width: StudioSpacing.sm),
                      Expanded(
                        child: Text(
                          _previewStatusLine!,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: _previewStatusIsError
                                    ? Theme.of(context).colorScheme.error
                                    : tokens.textSecondary,
                              ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
              const SizedBox(height: StudioSpacing.sm),
              Container(
                padding: const EdgeInsets.all(StudioSpacing.radiusComfort),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(StudioSpacing.radiusDense),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      size: StudioIconSize.md,
                      color: tokens.textSecondary,
                    ),
                    const SizedBox(width: StudioSpacing.xs),
                    Expanded(
                      child: Text(
                        l10n.shortVideoSpaceDialogVoiceoverSettingsInfoMessage,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: tokens.textSecondary,
                            ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.shortVideoSpaceDialogVoiceoverSettingsCancel),
        ),
        FilledButton(
          style: studioFormPrimaryButtonStyle(context),
          onPressed: () {
            Navigator.of(context).pop(
              _currentSettings,
            );
          },
          child: Text(l10n.shortVideoSpaceDialogVoiceoverSettingsSave),
        ),
      ],
    );
  }
}

/// Voiceover settings data class
///
/// Holds TTS configuration parameters
class VoiceoverSettings {
  const VoiceoverSettings({
    this.provider = 'openai',
    this.voiceId = 'alloy',
    this.emotion = 'neutral',
    this.speed = 1.0,
  });

  final String provider;
  final String voiceId;
  final String emotion;
  final double speed;

  VoiceoverSettings copyWith({
    String? provider,
    String? voiceId,
    String? emotion,
    double? speed,
  }) {
    return VoiceoverSettings(
      provider: provider ?? this.provider,
      voiceId: voiceId ?? this.voiceId,
      emotion: emotion ?? this.emotion,
      speed: speed ?? this.speed,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'provider': provider,
      'voiceId': voiceId,
      'emotion': emotion,
      'speed': speed,
    };
  }

  factory VoiceoverSettings.fromJson(Map<String, dynamic> json) {
    return VoiceoverSettings(
      provider: json['provider'] as String? ?? 'openai',
      voiceId: json['voiceId'] as String? ?? 'alloy',
      emotion: json['emotion'] as String? ?? 'neutral',
      speed: (json['speed'] as num?)?.toDouble() ?? 1.0,
    );
  }

  @override
  String toString() {
    return 'VoiceoverSettings(provider: $provider, voiceId: $voiceId, '
        'emotion: $emotion, speed: ${speed.toStringAsFixed(1)}x)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is VoiceoverSettings &&
        other.provider == provider &&
        other.voiceId == voiceId &&
        other.emotion == emotion &&
        other.speed == speed;
  }

  @override
  int get hashCode {
    return Object.hash(provider, voiceId, emotion, speed);
  }
}
