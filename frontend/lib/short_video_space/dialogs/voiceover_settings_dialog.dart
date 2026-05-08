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
    // Initialize with default or provided settings
    final settings = initialSettings ?? const VoiceoverSettings();

    var selectedProvider = settings.provider;
    var selectedVoiceId = settings.voiceId;
    var selectedEmotion = settings.emotion;
    var selectedSpeed = settings.speed;

    final result = await showDialog<VoiceoverSettings>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            // Get available voices for selected provider
            final availableVoices = _getAvailableVoices(selectedProvider);

            // Ensure selected voice is valid for current provider
            if (!availableVoices.contains(selectedVoiceId)) {
              selectedVoiceId = availableVoices.first;
            }

            return AlertDialog(
              title: const Text('配音参数设置'),
              content: SizedBox(
                width: 520,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // TTS Provider Selection
                      const Text(
                        'TTS 供应商',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        initialValue: selectedProvider,
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
                          if (value != null) {
                            setDialogState(() {
                              selectedProvider = value;
                              // Reset voice to first available for new provider
                              final voices = _getAvailableVoices(value);
                              selectedVoiceId = voices.first;
                            });
                          }
                        },
                      ),
                      const SizedBox(height: 16),

                      // Voice ID Selection
                      const Text(
                        '声线',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        initialValue: selectedVoiceId,
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
                                child: Text(_getVoiceDisplayName(voice)),
                              ),
                            )
                            .toList(),
                        onChanged: (value) {
                          if (value != null) {
                            setDialogState(() {
                              selectedVoiceId = value;
                            });
                          }
                        },
                      ),
                      const SizedBox(height: 16),

                      // Emotion Selection
                      const Text(
                        '情绪',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        initialValue: selectedEmotion,
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
                          if (value != null) {
                            setDialogState(() {
                              selectedEmotion = value;
                            });
                          }
                        },
                      ),
                      const SizedBox(height: 16),

                      // Speed Adjustment
                      const Text(
                        '语速',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: Slider(
                              value: selectedSpeed,
                              min: 0.5,
                              max: 2.0,
                              divisions: 15,
                              label: '${selectedSpeed.toStringAsFixed(1)}x',
                              onChanged: (value) {
                                setDialogState(() {
                                  selectedSpeed = value;
                                });
                              },
                            ),
                          ),
                          SizedBox(
                            width: 60,
                            child: Text(
                              '${selectedSpeed.toStringAsFixed(1)}x',
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
                        style: Theme.of(dialogContext).textTheme.bodySmall,
                      ),
                      const SizedBox(height: 16),

                      // Preview hint
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Theme.of(
                            dialogContext,
                          ).colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.info_outline,
                              size: 20,
                              color: Theme.of(
                                dialogContext,
                              ).colorScheme.onSurfaceVariant,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                '保存后将应用到新生成的配音。已生成的配音需要重新生成才能应用新参数。',
                                style: Theme.of(dialogContext)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(
                                      color: Theme.of(
                                        dialogContext,
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
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('取消'),
                ),
                FilledButton(
                  onPressed: () {
                    final newSettings = VoiceoverSettings(
                      provider: selectedProvider,
                      voiceId: selectedVoiceId,
                      emotion: selectedEmotion,
                      speed: selectedSpeed,
                    );
                    Navigator.of(dialogContext).pop(newSettings);
                  },
                  child: const Text('保存'),
                ),
              ],
            );
          },
        );
      },
    );

    return result;
  }

  /// Get available voices for a given provider
  List<String> _getAvailableVoices(String provider) {
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

  /// Get display name for a voice ID
  String _getVoiceDisplayName(String voiceId) {
    // OpenAI voices
    final openAIVoices = {
      'alloy': 'Alloy (中性)',
      'echo': 'Echo (男性)',
      'fable': 'Fable (英式)',
      'onyx': 'Onyx (深沉)',
      'nova': 'Nova (女性)',
      'shimmer': 'Shimmer (柔和)',
    };

    if (openAIVoices.containsKey(voiceId)) {
      return openAIVoices[voiceId]!;
    }

    // For Azure and Google, return the voice ID as-is
    // (they already have descriptive names)
    return voiceId;
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
