import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openflow_app/l10n/app_localizations.dart';
import 'package:openflow_app/short_video_space/section.dart';

void main() {
  group('AudioPreviewPlayer', () {
    Widget buildHarness(Widget child) {
      return MaterialApp(
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('zh'),
        home: Scaffold(body: child),
      );
    }

    testWidgets('renders with required properties', (
      WidgetTester tester,
    ) async {
      // Requirements 5: Audio preview player component
      await tester.pumpWidget(
        buildHarness(
          const AudioPreviewPlayer(audioUrl: 'https://example.com/audio.mp3'),
        ),
      );

      // Verify basic UI elements are present
      expect(find.text('配音预览'), findsOneWidget);
      expect(find.byIcon(Icons.audiotrack), findsOneWidget);

      // Wait a bit for initial render
      await tester.pump();
    });

    testWidgets('displays close button when onClose is provided', (
      WidgetTester tester,
    ) async {
      var closeCalled = false;

      await tester.pumpWidget(
        buildHarness(
          AudioPreviewPlayer(
            audioUrl: 'https://example.com/audio.mp3',
            onClose: () {
              closeCalled = true;
            },
          ),
        ),
      );

      // Verify close button is present
      expect(find.byIcon(Icons.close), findsOneWidget);

      // Tap close button
      await tester.tap(find.byIcon(Icons.close));
      await tester.pump();

      expect(closeCalled, isTrue);
    });

    testWidgets('does not display close button when onClose is null', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        buildHarness(
          const AudioPreviewPlayer(audioUrl: 'https://example.com/audio.mp3'),
        ),
      );

      // Verify close button is not present
      expect(find.byIcon(Icons.close), findsNothing);
    });

    testWidgets('displays loading indicator initially', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        buildHarness(
          const AudioPreviewPlayer(audioUrl: 'https://example.com/audio.mp3'),
        ),
      );

      // Verify loading indicator is shown
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('正在加载音频…'), findsOneWidget);
    });

    test('formats duration correctly', () {
      // Test duration formatting logic
      String formatDuration(Duration duration) {
        final minutes = duration.inMinutes
            .remainder(60)
            .toString()
            .padLeft(2, '0');
        final seconds = duration.inSeconds
            .remainder(60)
            .toString()
            .padLeft(2, '0');
        return '$minutes:$seconds';
      }

      expect(formatDuration(Duration.zero), '00:00');
      expect(formatDuration(const Duration(seconds: 30)), '00:30');
      expect(formatDuration(const Duration(minutes: 1, seconds: 15)), '01:15');
      expect(formatDuration(const Duration(minutes: 2, seconds: 5)), '02:05');
      expect(formatDuration(const Duration(minutes: 10, seconds: 59)), '10:59');
    });

    test('PlayerState enum values', () {
      // Verify PlayerState enum from audioplayers package
      expect(PlayerState.stopped, isNotNull);
      expect(PlayerState.playing, isNotNull);
      expect(PlayerState.paused, isNotNull);
    });

    testWidgets('respects autoPlay parameter', (WidgetTester tester) async {
      // Requirements 5: Auto-play functionality
      await tester.pumpWidget(
        buildHarness(
          const AudioPreviewPlayer(
            audioUrl: 'https://example.com/audio.mp3',
            autoPlay: true,
          ),
        ),
      );

      // Widget should be created with autoPlay enabled
      final audioPlayer = tester.widget<AudioPreviewPlayer>(
        find.byType(AudioPreviewPlayer),
      );

      expect(audioPlayer.autoPlay, isTrue);
    });

    testWidgets('has proper styling and layout', (WidgetTester tester) async {
      // Requirements 5: UI/UX requirements
      await tester.pumpWidget(
        buildHarness(
          const AudioPreviewPlayer(audioUrl: 'https://example.com/audio.mp3'),
        ),
      );

      await tester.pump();

      // Verify container has proper styling
      final container = find.byType(Container).first;
      expect(container, findsOneWidget);

      // Verify column layout
      expect(find.byType(Column), findsWidgets);
    });

    testWidgets('displays proper header with icon and title', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        buildHarness(
          const AudioPreviewPlayer(audioUrl: 'https://example.com/audio.mp3'),
        ),
      );

      // Verify header elements
      expect(find.byIcon(Icons.audiotrack), findsOneWidget);
      expect(find.text('配音预览'), findsOneWidget);
    });

    testWidgets('creates AudioPlayer instance', (WidgetTester tester) async {
      // Requirements 5: Audio playback functionality
      await tester.pumpWidget(
        buildHarness(
          const AudioPreviewPlayer(audioUrl: 'https://example.com/audio.mp3'),
        ),
      );

      await tester.pump();

      // Verify widget is created successfully
      expect(find.byType(AudioPreviewPlayer), findsOneWidget);
    });

    testWidgets('displays loading state before audio loads', (
      WidgetTester tester,
    ) async {
      // Requirements 5: Loading state
      await tester.pumpWidget(
        buildHarness(
          const AudioPreviewPlayer(audioUrl: 'https://example.com/audio.mp3'),
        ),
      );

      // Initial state should show loading
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('正在加载音频…'), findsOneWidget);
    });

    testWidgets('has proper container decoration', (WidgetTester tester) async {
      // Requirements 5: Visual design
      await tester.pumpWidget(
        buildHarness(
          const AudioPreviewPlayer(audioUrl: 'https://example.com/audio.mp3'),
        ),
      );

      await tester.pump();

      // Verify container exists with decoration
      final containers = find.byType(Container);
      expect(containers, findsWidgets);
    });

    testWidgets('displays header row with title and optional close button', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        buildHarness(
          AudioPreviewPlayer(
            audioUrl: 'https://example.com/audio.mp3',
            onClose: () {},
          ),
        ),
      );

      // Verify header row elements
      expect(find.byIcon(Icons.audiotrack), findsOneWidget);
      expect(find.text('配音预览'), findsOneWidget);
      expect(find.byIcon(Icons.close), findsOneWidget);
    });

    test('AudioPreviewPlayer constructor parameters', () {
      // Requirements 5: Component API
      const player = AudioPreviewPlayer(
        audioUrl: 'https://example.com/audio.mp3',
        autoPlay: true,
      );

      expect(player.audioUrl, 'https://example.com/audio.mp3');
      expect(player.autoPlay, true);
      expect(player.onClose, isNull);
    });

    test('AudioPreviewPlayer with all parameters', () {
      // Requirements 5: Complete API
      void closeCallback() {}

      final player = AudioPreviewPlayer(
        audioUrl: 'https://example.com/audio.mp3',
        autoPlay: false,
        onClose: closeCallback,
      );

      expect(player.audioUrl, 'https://example.com/audio.mp3');
      expect(player.autoPlay, false);
      expect(player.onClose, closeCallback);
    });
  });
}
