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
    return showDialog<VoiceoverSettings>(
      context: context,
      builder: (dialogContext) {
        return VoiceoverSettingsDialog(initialSettings: initialSettings);
      },
    );
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

String getVoiceoverDisplayName(String voiceId) {
  const openAIVoices = <String, String>{
    'alloy': 'Alloy (中性)',
    'echo': 'Echo (男性)',
    'fable': 'Fable (英式)',
    'onyx': 'Onyx (深沉)',
    'nova': 'Nova (女性)',
    'shimmer': 'Shimmer (柔和)',
  };

  return openAIVoices[voiceId] ?? voiceId;
}

class VoiceoverSettingsDialog extends StatefulWidget {
  const VoiceoverSettingsDialog({
    super.key,
    this.initialSettings,
  });

  final VoiceoverSettings? initialSettings;

  @override
  State<VoiceoverSettingsDialog> createState() =>
      _VoiceoverSettingsDialogState();
}

class _VoiceoverSettingsDialogState extends State<VoiceoverSettingsDialog> {
  late String _selectedProvider;
  late String _selectedVoiceId;
  late String _selectedEmotion;
  late double _selectedSpeed;

  @override
  void initState() {
    super.initState();
    final settings = widget.initialSettings ?? const VoiceoverSettings();
    _selectedProvider = settings.provider;
    _selectedVoiceId = settings.voiceId;
    _selectedEmotion = settings.emotion;
    _selectedSpeed = settings.speed;
    _syncVoiceIdWithProvider();
  }

  void _syncVoiceIdWithProvider() {
    final availableVoices = getAvailableVoiceoverVoices(_selectedProvider);
    if (!availableVoices.contains(_selectedVoiceId)) {
      _selectedVoiceId = availableVoices.first;
    }
  }

  @override
  Widget build(BuildContext context) {
    final availableVoices = getAvailableVoiceoverVoices(_selectedProvider);

    return AlertDialog(
      title: const Text('配音参数设置'),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'TTS 供应商',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                initialValue: _selectedProvider,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                ),
                items: const [
                  DropdownMenuItem(
                    value: 'openai',
                    child: Text('OpenAI TTS'),
                  ),
                  DropdownMenuItem(
                    value: 'azure',
                    child: Text('Azure TTS'),
                  ),
                  DropdownMenuItem(
                    value: 'google',
                    child: Text('Google TTS'),
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
              const SizedBox(height: 16),
              const Text(
                '声线',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                key: ValueKey<String>('voiceover-voice-$_selectedProvider'),
                initialValue: _selectedVoiceId,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                ),
                items: availableVoices
                    .map(
                      (voice) => DropdownMenuItem(
                        value: voice,
                        child: Text(getVoiceoverDisplayName(voice)),
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
              const SizedBox(height: 16),
              const Text(
                '情绪',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                initialValue: _selectedEmotion,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                ),
                items: const [
                  DropdownMenuItem(
                    value: 'neutral',
                    child: Text('中性 (Neutral)'),
                  ),
                  DropdownMenuItem(
                    value: 'happy',
                    child: Text('愉悦 (Happy)'),
                  ),
                  DropdownMenuItem(
                    value: 'sad',
                    child: Text('悲伤 (Sad)'),
                  ),
                  DropdownMenuItem(
                    value: 'angry',
                    child: Text('愤怒 (Angry)'),
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
              const SizedBox(height: 16),
              const Text(
                '语速',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
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
                    width: 60,
                    child: Text(
                      '${_selectedSpeed.toStringAsFixed(1)}x',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                '调整范围：0.5x (慢速) - 2.0x (快速)',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      size: 20,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '保存后将应用到新生成的配音。已生成的配音需要重新生成才能应用新参数。',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurfaceVariant,
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
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: () {
            Navigator.of(context).pop(
              VoiceoverSettings(
                provider: _selectedProvider,
                voiceId: _selectedVoiceId,
                emotion: _selectedEmotion,
                speed: _selectedSpeed,
              ),
            );
          },
          child: const Text('保存'),
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
