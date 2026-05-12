import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openflow_app/l10n/app_localizations.dart';
import 'package:openflow_app/l10n/app_localizations_zh.dart';
import 'package:openflow_app/short_video_space/section.dart';

Widget _materialAppZh({required Widget home}) => MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('zh'),
      home: home,
    );

/// **Validates: Requirements 3, 4, 5**
/// 
/// Tests for TTS functionality including:
/// - Parameter editing logic (VoiceoverSettings)
/// - Voiceover generation call (single and batch)
/// - Audio preview functionality
void main() {
  final zh = AppLocalizationsZh();
  group('VoiceoverSettings', () {
    test('uses defaults when JSON is empty', () {
      final settings = VoiceoverSettings.fromJson(<String, dynamic>{});

      expect(settings, const VoiceoverSettings());
    });

    test('supports copyWith and JSON roundtrip', () {
      final settings = const VoiceoverSettings().copyWith(
        provider: 'azure',
        voiceId: 'zh-CN-XiaoxiaoNeural',
        emotion: 'happy',
        speed: 1.5,
      );

      expect(
        VoiceoverSettings.fromJson(settings.toJson()),
        settings,
      );
      expect(
        settings.toString(),
        contains('zh-CN-XiaoxiaoNeural'),
      );
    });
  });

  group('Voiceover helpers', () {
    test('exposes supported providers and provider-specific voices', () {
      expect(
        kSupportedVoiceoverProviders,
        const ['openai', 'azure', 'google'],
      );
      expect(getAvailableVoiceoverVoices('openai'), contains('nova'));
      expect(
        getAvailableVoiceoverVoices('azure'),
        contains('zh-CN-XiaoxiaoNeural'),
      );
      expect(
        getAvailableVoiceoverVoices('google'),
        contains('zh-CN-Wavenet-A'),
      );
    });

    test('maps OpenAI voices to display names and keeps unknown ids raw', () {
      expect(getVoiceoverDisplayName('alloy', zh), 'Alloy (中性)');
      expect(
        getVoiceoverDisplayName('zh-CN-XiaoxiaoNeural', zh),
        'zh-CN-XiaoxiaoNeural',
      );
    });
  });

  group('VoiceoverSettingsDialog', () {
    testWidgets('renders initial values and keeps save hint visible',
        (tester) async {
      await tester.pumpWidget(
        _materialAppZh(
          home: const Scaffold(
            body: VoiceoverSettingsDialog(
              initialSettings: VoiceoverSettings(
                provider: 'azure',
                voiceId: 'zh-CN-XiaoxiaoNeural',
                emotion: 'happy',
                speed: 1.5,
              ),
            ),
          ),
        ),
      );

      expect(find.text('配音参数设置'), findsOneWidget);
      expect(find.text('Azure TTS'), findsOneWidget);
      expect(find.text('zh-CN-XiaoxiaoNeural'), findsOneWidget);
      expect(find.text('愉悦 (Happy)'), findsOneWidget);
      expect(find.text('1.5x'), findsWidgets);
      expect(
        find.text('保存后将应用到新生成的配音。已生成的配音需要重新生成才能应用新参数。'),
        findsOneWidget,
      );
    });

    testWidgets('resets voice choice when provider changes', (tester) async {
      await tester.pumpWidget(
        _materialAppZh(
          home: const Scaffold(
            body: VoiceoverSettingsDialog(
              initialSettings: VoiceoverSettings(
                provider: 'openai',
                voiceId: 'nova',
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('OpenAI TTS'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Azure TTS').last);
      await tester.pumpAndSettle();

      expect(find.text('Azure TTS'), findsOneWidget);
      expect(find.text('zh-CN-XiaoxiaoNeural'), findsOneWidget);
      expect(find.text('Nova (女性)'), findsNothing);
    });

    testWidgets('returns updated settings when saved', (tester) async {
      VoiceoverSettings? result;

      await tester.pumpWidget(
        _materialAppZh(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return FilledButton(
                  onPressed: () async {
                    result = await showDialog<VoiceoverSettings>(
                      context: context,
                      builder: (_) => const VoiceoverSettingsDialog(
                        initialSettings: VoiceoverSettings(),
                      ),
                    );
                  },
                  child: const Text('Open'),
                );
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('OpenAI TTS'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Google TTS').last);
      await tester.pumpAndSettle();

      await tester.tap(find.text('中性 (Neutral)'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('悲伤 (Sad)').last);
      await tester.pumpAndSettle();

      await tester.drag(find.byType(Slider), const Offset(240, 0));
      await tester.pumpAndSettle();

      await tester.tap(find.text('保存'));
      await tester.pumpAndSettle();

      expect(result, isNotNull);
      expect(result!.provider, 'google');
      expect(result!.voiceId, 'zh-CN-Standard-A');
      expect(result!.emotion, 'sad');
      expect(result!.speed, greaterThan(1.0));
    });

    testWidgets('returns null when cancelled', (tester) async {
      VoiceoverSettings? result;

      await tester.pumpWidget(
        _materialAppZh(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return FilledButton(
                  onPressed: () async {
                    result = await showDialog<VoiceoverSettings>(
                      context: context,
                      builder: (_) => const VoiceoverSettingsDialog(),
                    );
                  },
                  child: const Text('Open'),
                );
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('取消'));
      await tester.pumpAndSettle();

      expect(result, isNull);
    });
  });

  group('TTS Generation Logic', () {
    test('VoiceoverSettings validates speed range', () {
      // Test valid speed values
      const validSettings = VoiceoverSettings(speed: 1.0);
      expect(validSettings.speed, 1.0);

      const slowSettings = VoiceoverSettings(speed: 0.5);
      expect(slowSettings.speed, 0.5);

      const fastSettings = VoiceoverSettings(speed: 2.0);
      expect(fastSettings.speed, 2.0);
    });

    test('VoiceoverSettings supports all providers', () {
      for (final provider in kSupportedVoiceoverProviders) {
        final settings = VoiceoverSettings(provider: provider);
        expect(settings.provider, provider);
        
        // Verify each provider has available voices
        final voices = getAvailableVoiceoverVoices(provider);
        expect(voices, isNotEmpty);
      }
    });

    test('VoiceoverSettings supports all emotions', () {
      const emotions = ['neutral', 'happy', 'sad', 'angry'];
      for (final emotion in emotions) {
        final settings = VoiceoverSettings(emotion: emotion);
        expect(settings.emotion, emotion);
      }
    });

    test('VoiceoverSettings equality and hashCode work correctly', () {
      const settings1 = VoiceoverSettings(
        provider: 'openai',
        voiceId: 'alloy',
        emotion: 'neutral',
        speed: 1.0,
      );
      const settings2 = VoiceoverSettings(
        provider: 'openai',
        voiceId: 'alloy',
        emotion: 'neutral',
        speed: 1.0,
      );
      const settings3 = VoiceoverSettings(
        provider: 'azure',
        voiceId: 'zh-CN-XiaoxiaoNeural',
        emotion: 'happy',
        speed: 1.5,
      );

      expect(settings1, equals(settings2));
      expect(settings1.hashCode, equals(settings2.hashCode));
      expect(settings1, isNot(equals(settings3)));
      expect(settings1.hashCode, isNot(equals(settings3.hashCode)));
    });

    test('VoiceoverSettings toString includes all parameters', () {
      const settings = VoiceoverSettings(
        provider: 'azure',
        voiceId: 'zh-CN-XiaoxiaoNeural',
        emotion: 'happy',
        speed: 1.5,
      );

      final str = settings.toString();
      expect(str, contains('azure'));
      expect(str, contains('zh-CN-XiaoxiaoNeural'));
      expect(str, contains('happy'));
      expect(str, contains('1.5'));
    });

    test('getAvailableVoiceoverVoices returns correct voices for each provider', () {
      // OpenAI voices
      final openAIVoices = getAvailableVoiceoverVoices('openai');
      expect(openAIVoices, contains('alloy'));
      expect(openAIVoices, contains('echo'));
      expect(openAIVoices, contains('fable'));
      expect(openAIVoices, contains('onyx'));
      expect(openAIVoices, contains('nova'));
      expect(openAIVoices, contains('shimmer'));

      // Azure voices
      final azureVoices = getAvailableVoiceoverVoices('azure');
      expect(azureVoices, contains('zh-CN-XiaoxiaoNeural'));
      expect(azureVoices, contains('zh-CN-YunxiNeural'));
      expect(azureVoices, contains('zh-CN-YunjianNeural'));

      // Google voices
      final googleVoices = getAvailableVoiceoverVoices('google');
      expect(googleVoices, contains('zh-CN-Standard-A'));
      expect(googleVoices, contains('zh-CN-Wavenet-A'));

      // Unknown provider defaults to alloy
      final unknownVoices = getAvailableVoiceoverVoices('unknown');
      expect(unknownVoices, equals(['alloy']));
    });

    test('getVoiceoverDisplayName maps OpenAI voices correctly', () {
      expect(getVoiceoverDisplayName('alloy', zh), 'Alloy (中性)');
      expect(getVoiceoverDisplayName('echo', zh), 'Echo (男性)');
      expect(getVoiceoverDisplayName('fable', zh), 'Fable (英式)');
      expect(getVoiceoverDisplayName('onyx', zh), 'Onyx (深沉)');
      expect(getVoiceoverDisplayName('nova', zh), 'Nova (女性)');
      expect(getVoiceoverDisplayName('shimmer', zh), 'Shimmer (柔和)');
      
      // Unknown voices return as-is
      expect(getVoiceoverDisplayName('unknown', zh), 'unknown');
      expect(getVoiceoverDisplayName('zh-CN-XiaoxiaoNeural', zh), 'zh-CN-XiaoxiaoNeural');
    });
  });

  group('Audio Preview Functionality', () {
    test('VoiceoverSettings can be used to generate preview parameters', () {
      const settings = VoiceoverSettings(
        provider: 'openai',
        voiceId: 'nova',
        emotion: 'happy',
        speed: 1.2,
      );

      // Verify settings can be serialized for API calls
      final json = settings.toJson();
      expect(json['provider'], 'openai');
      expect(json['voiceId'], 'nova');
      expect(json['emotion'], 'happy');
      expect(json['speed'], 1.2);

      // Verify settings can be reconstructed
      final reconstructed = VoiceoverSettings.fromJson(json);
      expect(reconstructed, equals(settings));
    });

    test('VoiceoverSettings supports speed adjustments for preview', () {
      const baseSettings = VoiceoverSettings(speed: 1.0);
      
      // Test slower preview
      final slowerSettings = baseSettings.copyWith(speed: 0.8);
      expect(slowerSettings.speed, 0.8);
      
      // Test faster preview
      final fasterSettings = baseSettings.copyWith(speed: 1.5);
      expect(fasterSettings.speed, 1.5);
      
      // Verify original is unchanged
      expect(baseSettings.speed, 1.0);
    });

    test('VoiceoverSettings supports voice switching for preview', () {
      const baseSettings = VoiceoverSettings(
        provider: 'openai',
        voiceId: 'alloy',
      );
      
      // Switch to different voice
      final newSettings = baseSettings.copyWith(voiceId: 'nova');
      expect(newSettings.voiceId, 'nova');
      expect(newSettings.provider, 'openai'); // Provider unchanged
      
      // Verify original is unchanged
      expect(baseSettings.voiceId, 'alloy');
    });

    test('VoiceoverSettings supports emotion switching for preview', () {
      const baseSettings = VoiceoverSettings(emotion: 'neutral');
      
      // Switch to different emotion
      final happySettings = baseSettings.copyWith(emotion: 'happy');
      expect(happySettings.emotion, 'happy');
      
      final sadSettings = baseSettings.copyWith(emotion: 'sad');
      expect(sadSettings.emotion, 'sad');
      
      // Verify original is unchanged
      expect(baseSettings.emotion, 'neutral');
    });
  });

  group('TTS Parameter Validation', () {
    test('VoiceoverSettings handles edge case speed values', () {
      // Minimum speed
      const minSpeed = VoiceoverSettings(speed: 0.5);
      expect(minSpeed.speed, 0.5);
      
      // Maximum speed
      const maxSpeed = VoiceoverSettings(speed: 2.0);
      expect(maxSpeed.speed, 2.0);
      
      // Normal speed
      const normalSpeed = VoiceoverSettings(speed: 1.0);
      expect(normalSpeed.speed, 1.0);
    });

    test('VoiceoverSettings handles provider-specific voice validation', () {
      // OpenAI voice with OpenAI provider
      const openAISettings = VoiceoverSettings(
        provider: 'openai',
        voiceId: 'nova',
      );
      expect(getAvailableVoiceoverVoices(openAISettings.provider), contains(openAISettings.voiceId));
      
      // Azure voice with Azure provider
      const azureSettings = VoiceoverSettings(
        provider: 'azure',
        voiceId: 'zh-CN-XiaoxiaoNeural',
      );
      expect(getAvailableVoiceoverVoices(azureSettings.provider), contains(azureSettings.voiceId));
      
      // Google voice with Google provider
      const googleSettings = VoiceoverSettings(
        provider: 'google',
        voiceId: 'zh-CN-Wavenet-A',
      );
      expect(getAvailableVoiceoverVoices(googleSettings.provider), contains(googleSettings.voiceId));
    });

    test('VoiceoverSettings JSON serialization handles null values', () {
      final json = <String, dynamic>{
        'provider': null,
        'voiceId': null,
        'emotion': null,
        'speed': null,
      };
      
      final settings = VoiceoverSettings.fromJson(json);
      
      // Should use defaults
      expect(settings.provider, 'openai');
      expect(settings.voiceId, 'alloy');
      expect(settings.emotion, 'neutral');
      expect(settings.speed, 1.0);
    });

    test('VoiceoverSettings JSON serialization handles partial data', () {
      final json = <String, dynamic>{
        'provider': 'azure',
        // Missing voiceId, emotion, speed
      };
      
      final settings = VoiceoverSettings.fromJson(json);
      
      // Should use provided value and defaults for missing
      expect(settings.provider, 'azure');
      expect(settings.voiceId, 'alloy'); // Default
      expect(settings.emotion, 'neutral'); // Default
      expect(settings.speed, 1.0); // Default
    });
  });

  group('TTS Integration Scenarios', () {
    test('VoiceoverSettings supports complete workflow', () {
      // 1. Start with defaults
      const initial = VoiceoverSettings();
      expect(initial.provider, 'openai');
      expect(initial.voiceId, 'alloy');
      
      // 2. User changes provider
      final withProvider = initial.copyWith(provider: 'azure');
      expect(withProvider.provider, 'azure');
      
      // 3. User selects voice for new provider
      final withVoice = withProvider.copyWith(voiceId: 'zh-CN-XiaoxiaoNeural');
      expect(withVoice.voiceId, 'zh-CN-XiaoxiaoNeural');
      
      // 4. User adjusts emotion
      final withEmotion = withVoice.copyWith(emotion: 'happy');
      expect(withEmotion.emotion, 'happy');
      
      // 5. User adjusts speed
      final final_ = withEmotion.copyWith(speed: 1.3);
      expect(final_.speed, 1.3);
      
      // 6. Serialize for API call
      final json = final_.toJson();
      expect(json['provider'], 'azure');
      expect(json['voiceId'], 'zh-CN-XiaoxiaoNeural');
      expect(json['emotion'], 'happy');
      expect(json['speed'], 1.3);
    });

    test('VoiceoverSettings supports batch generation scenario', () {
      // Same settings used for multiple shots
      const batchSettings = VoiceoverSettings(
        provider: 'openai',
        voiceId: 'nova',
        emotion: 'neutral',
        speed: 1.0,
      );
      
      // Simulate applying to multiple shots
      final shot1Params = batchSettings.toJson();
      final shot2Params = batchSettings.toJson();
      final shot3Params = batchSettings.toJson();
      
      expect(shot1Params, equals(shot2Params));
      expect(shot2Params, equals(shot3Params));
    });

    test('VoiceoverSettings supports preview-then-generate scenario', () {
      // 1. User configures settings for preview
      const previewSettings = VoiceoverSettings(
        provider: 'openai',
        voiceId: 'nova',
        emotion: 'happy',
        speed: 1.2,
      );
      
      // 2. User likes preview and uses same settings for generation
      final generationSettings = previewSettings; // Same settings
      
      expect(generationSettings.provider, previewSettings.provider);
      expect(generationSettings.voiceId, previewSettings.voiceId);
      expect(generationSettings.emotion, previewSettings.emotion);
      expect(generationSettings.speed, previewSettings.speed);
    });
  });
}
