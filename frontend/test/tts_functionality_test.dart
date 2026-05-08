import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openflow_app/short_video_space/section.dart';

void main() {
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
      expect(getVoiceoverDisplayName('alloy'), 'Alloy (中性)');
      expect(
        getVoiceoverDisplayName('zh-CN-XiaoxiaoNeural'),
        'zh-CN-XiaoxiaoNeural',
      );
    });
  });

  group('VoiceoverSettingsDialog', () {
    testWidgets('renders initial values and keeps save hint visible',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
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
        const MaterialApp(
          home: Scaffold(
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
        MaterialApp(
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
      VoiceoverSettings? result = const VoiceoverSettings();

      await tester.pumpWidget(
        MaterialApp(
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
}
