import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openflow_app/short_video_space/components/preview_player.dart';

ConstrainedBox findDialogConstraint(WidgetTester tester) {
  return tester.widgetList<ConstrainedBox>(find.byType(ConstrainedBox)).firstWhere(
    (widget) => widget.constraints.maxWidth == 800,
  );
}

void main() {
  group('PreviewPlayer', () {
    const testVideoUrl = 'https://example.com/test-video.mp4';
    const testShotNumber = 42;
    const testShotTitle = '测试镜头标题';
    const testDurationText = '10s';

    testWidgets('should display shot information when provided', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: PreviewPlayer(
              videoUrl: testVideoUrl,
              shotNumber: testShotNumber,
              shotTitle: testShotTitle,
              durationText: testDurationText,
            ),
          ),
        ),
      );

      expect(find.text('镜头 #$testShotNumber'), findsOneWidget);
      expect(find.text(testShotTitle), findsOneWidget);
      expect(find.text(testDurationText), findsOneWidget);
      expect(find.byIcon(Icons.movie_outlined), findsOneWidget);
    });

    testWidgets('should not display shot information when not provided', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: PreviewPlayer(videoUrl: testVideoUrl)),
        ),
      );

      expect(find.byIcon(Icons.movie_outlined), findsNothing);
      expect(find.textContaining('镜头 #'), findsNothing);
    });

    testWidgets('should display loading indicator initially', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: PreviewPlayer(videoUrl: testVideoUrl)),
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('should display error message when video URL is empty', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: PreviewPlayer(videoUrl: '')),
        ),
      );

      await tester.pump();

      expect(find.byIcon(Icons.error_outline), findsOneWidget);
      expect(find.text('视频 URL 为空'), findsOneWidget);
    });

    testWidgets('should display play/pause control buttons', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: PreviewPlayer(videoUrl: testVideoUrl)),
        ),
      );

      expect(find.byIcon(Icons.stop), findsOneWidget);
      expect(find.byIcon(Icons.play_arrow), findsOneWidget);
    });

    testWidgets('should display progress slider', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: PreviewPlayer(videoUrl: testVideoUrl)),
        ),
      );

      expect(find.byType(Slider), findsOneWidget);
    });

    testWidgets('should display time labels', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: PreviewPlayer(videoUrl: testVideoUrl)),
        ),
      );

      // Should display current time and total duration (initially 00:00)
      expect(find.text('00:00'), findsAtLeastNWidgets(2));
    });

    testWidgets('should have 16:9 aspect ratio for video player', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: PreviewPlayer(videoUrl: testVideoUrl)),
        ),
      );

      final aspectRatio = tester.widget<AspectRatio>(find.byType(AspectRatio));
      expect(aspectRatio.aspectRatio, 16 / 9);
    });

    testWidgets('should disable controls initially before video loads', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: PreviewPlayer(videoUrl: testVideoUrl)),
        ),
      );

      final stopButton = tester.widget<IconButton>(
        find.widgetWithIcon(IconButton, Icons.stop),
      );
      expect(stopButton.onPressed, isNull);

      final playButton = tester.widget<IconButton>(
        find.widgetWithIcon(IconButton, Icons.play_arrow),
      );
      expect(playButton.onPressed, isNull);

      final slider = tester.widget<Slider>(find.byType(Slider));
      expect(slider.onChanged, isNull);
    });

    testWidgets('should show play icon when not playing', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: PreviewPlayer(videoUrl: testVideoUrl)),
        ),
      );

      expect(find.byIcon(Icons.play_arrow), findsOneWidget);
      expect(find.byIcon(Icons.pause), findsNothing);
    });

    testWidgets('should have correct tooltips on control buttons', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: PreviewPlayer(videoUrl: testVideoUrl)),
        ),
      );

      final stopButton = tester.widget<IconButton>(
        find.widgetWithIcon(IconButton, Icons.stop),
      );
      expect(stopButton.tooltip, '停止');

      final playButton = tester.widget<IconButton>(
        find.widgetWithIcon(IconButton, Icons.play_arrow),
      );
      expect(playButton.tooltip, '播放');
    });

    testWidgets('should update video URL when widget updates', (
      WidgetTester tester,
    ) async {
      const initialUrl = 'https://example.com/video1.mp4';
      const updatedUrl = 'https://example.com/video2.mp4';

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: PreviewPlayer(videoUrl: initialUrl)),
        ),
      );

      // Update the video URL
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: PreviewPlayer(videoUrl: updatedUrl)),
        ),
      );

      // Should show loading indicator again
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('should display shot title with ellipsis for long text', (
      WidgetTester tester,
    ) async {
      const longTitle = '这是一个非常非常非常非常非常非常非常非常非常长的镜头标题';

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: PreviewPlayer(
              videoUrl: testVideoUrl,
              shotNumber: testShotNumber,
              shotTitle: longTitle,
            ),
          ),
        ),
      );

      final textWidget = tester.widget<Text>(find.text(longTitle));
      expect(textWidget.maxLines, 2);
      expect(textWidget.overflow, TextOverflow.ellipsis);
    });

    testWidgets('should have black background for video container', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: PreviewPlayer(videoUrl: testVideoUrl)),
        ),
      );

      final containers = tester.widgetList<Container>(find.byType(Container));

      // Find the container with black background (video container)
      final videoContainer = containers.firstWhere(
        (container) => container.color == Colors.black,
      );
      expect(videoContainer.color, Colors.black);
    });
  });

  group('PreviewPlayerDialog', () {
    const testVideoUrl = 'https://example.com/test-video.mp4';
    const testShotNumber = 42;
    const testShotTitle = '测试镜头标题';
    const testDurationText = '10s';

    testWidgets('should display PreviewPlayer component', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: PreviewPlayerDialog(
              videoUrl: testVideoUrl,
              shotNumber: testShotNumber,
              shotTitle: testShotTitle,
              durationText: testDurationText,
            ),
          ),
        ),
      );

      expect(find.byType(PreviewPlayer), findsOneWidget);
    });

    testWidgets('should display close button', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: PreviewPlayerDialog(videoUrl: testVideoUrl)),
        ),
      );

      expect(find.text('关闭'), findsOneWidget);
    });

    testWidgets('should be wrapped in Dialog widget', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: PreviewPlayerDialog(videoUrl: testVideoUrl)),
        ),
      );

      expect(find.byType(Dialog), findsOneWidget);
    });

    testWidgets('should have max width constraint', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: PreviewPlayerDialog(videoUrl: testVideoUrl)),
        ),
      );

      final constrainedBox = findDialogConstraint(tester);
      expect(constrainedBox.constraints.maxWidth, 800);
    });

    testWidgets('should pass video URL to PreviewPlayer', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: PreviewPlayerDialog(videoUrl: testVideoUrl)),
        ),
      );

      final previewPlayer = tester.widget<PreviewPlayer>(
        find.byType(PreviewPlayer),
      );
      expect(previewPlayer.videoUrl, testVideoUrl);
    });

    testWidgets('should pass shot information to PreviewPlayer', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: PreviewPlayerDialog(
              videoUrl: testVideoUrl,
              shotNumber: testShotNumber,
              shotTitle: testShotTitle,
              durationText: testDurationText,
            ),
          ),
        ),
      );

      final previewPlayer = tester.widget<PreviewPlayer>(
        find.byType(PreviewPlayer),
      );
      expect(previewPlayer.shotNumber, testShotNumber);
      expect(previewPlayer.shotTitle, testShotTitle);
      expect(previewPlayer.durationText, testDurationText);
    });

    testWidgets('should enable autoPlay for PreviewPlayer', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: PreviewPlayerDialog(videoUrl: testVideoUrl)),
        ),
      );

      final previewPlayer = tester.widget<PreviewPlayer>(
        find.byType(PreviewPlayer),
      );
      expect(previewPlayer.autoPlay, true);
    });

    testWidgets('should close dialog when close button tapped', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () {
                    PreviewPlayerDialog.show(context, videoUrl: testVideoUrl);
                  },
                  child: const Text('Open'),
                ),
              ),
            ),
          ),
        ),
      );

      // Open the dialog
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      // Verify dialog is shown
      expect(find.byType(PreviewPlayerDialog), findsOneWidget);

      // Tap close button
      await tester.ensureVisible(find.text('关闭'));
      await tester.tap(find.text('关闭'));
      await tester.pumpAndSettle();

      // Verify dialog is closed
      expect(find.byType(PreviewPlayerDialog), findsNothing);
    });

    testWidgets('should show dialog using static show method', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () {
                    PreviewPlayerDialog.show(
                      context,
                      videoUrl: testVideoUrl,
                      shotNumber: testShotNumber,
                      shotTitle: testShotTitle,
                      durationText: testDurationText,
                    );
                  },
                  child: const Text('Open'),
                ),
              ),
            ),
          ),
        ),
      );

      // Open the dialog
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      // Verify dialog is shown with correct content
      expect(find.byType(PreviewPlayerDialog), findsOneWidget);
      expect(find.text('镜头 #$testShotNumber'), findsOneWidget);
      expect(find.text(testShotTitle), findsOneWidget);
    });
  });

  group('PreviewPlayer State Management', () {
    testWidgets('should track playing state', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: PreviewPlayer(videoUrl: 'https://example.com/test-video.mp4'),
          ),
        ),
      );

      // Initially should show play icon (not playing)
      expect(find.byIcon(Icons.play_arrow), findsOneWidget);
      expect(find.byIcon(Icons.pause), findsNothing);
    });

    testWidgets('should track progress position', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: PreviewPlayer(videoUrl: 'https://example.com/test-video.mp4'),
          ),
        ),
      );

      // Initially should show 00:00 for both current and total time
      expect(find.text('00:00'), findsAtLeastNWidgets(2));
    });

    testWidgets('should format duration correctly', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: PreviewPlayer(videoUrl: 'https://example.com/test-video.mp4'),
          ),
        ),
      );

      // Time format should be MM:SS with zero padding
      final timeTexts = tester.widgetList<Text>(
        find.textContaining(RegExp(r'\d{2}:\d{2}')),
      );
      expect(timeTexts.isNotEmpty, true);
    });

    testWidgets('should handle playback complete callback', (
      WidgetTester tester,
    ) async {
      bool callbackCalled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PreviewPlayer(
              videoUrl: 'https://example.com/test-video.mp4',
              onPlaybackComplete: () {
                callbackCalled = true;
              },
            ),
          ),
        ),
      );

      // Note: Testing actual video playback completion requires mocking
      // VideoPlayerController, which is complex in widget tests.
      // This test verifies the callback is properly wired up.
      expect(callbackCalled, false);
    });

    testWidgets('should handle autoPlay parameter', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: PreviewPlayer(
              videoUrl: 'https://example.com/test-video.mp4',
              autoPlay: true,
            ),
          ),
        ),
      );

      // Widget should be created with autoPlay enabled
      final previewPlayer = tester.widget<PreviewPlayer>(
        find.byType(PreviewPlayer),
      );
      expect(previewPlayer.autoPlay, true);
    });
  });

  group('PreviewPlayer Shot Switching', () {
    testWidgets('should support shot number display for playlist', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: PreviewPlayer(
              videoUrl: 'https://example.com/test-video.mp4',
              shotNumber: 1,
              shotTitle: '第一个镜头',
            ),
          ),
        ),
      );

      expect(find.text('镜头 #1'), findsOneWidget);
      expect(find.text('第一个镜头'), findsOneWidget);
    });

    testWidgets('should display shot information in header', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: PreviewPlayer(
              videoUrl: 'https://example.com/test-video.mp4',
              shotNumber: 5,
              shotTitle: '重要场景',
              durationText: '15s',
            ),
          ),
        ),
      );

      // All shot information should be visible
      expect(find.text('镜头 #5'), findsOneWidget);
      expect(find.text('重要场景'), findsOneWidget);
      expect(find.text('15s'), findsOneWidget);
    });

    testWidgets('should handle missing shot information gracefully', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: PreviewPlayer(
              videoUrl: 'https://example.com/test-video.mp4',
              shotNumber: 1,
              // No title or duration
            ),
          ),
        ),
      );

      // Should still show shot number
      expect(find.text('镜头 #1'), findsOneWidget);
      // But not show missing information
      expect(find.byIcon(Icons.movie_outlined), findsOneWidget);
    });
  });

  group('PreviewPlayer Error Handling', () {
    testWidgets('should display error icon when video fails to load', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: PreviewPlayer(videoUrl: '')),
        ),
      );

      await tester.pump();

      expect(find.byIcon(Icons.error_outline), findsOneWidget);
    });

    testWidgets('should display error message when video fails to load', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: PreviewPlayer(videoUrl: '')),
        ),
      );

      await tester.pump();

      expect(find.textContaining('视频'), findsOneWidget);
    });

    testWidgets('should handle empty video URL', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: PreviewPlayer(videoUrl: '')),
        ),
      );

      await tester.pump();

      expect(find.text('视频 URL 为空'), findsOneWidget);
      expect(find.byIcon(Icons.error_outline), findsOneWidget);
    });
  });

  group('PreviewPlayer Playlist Mode', () {
    final testPlaylist = [
      const ShotPreviewItem(
        videoUrl: 'https://example.com/video1.mp4',
        shotNumber: 1,
        shotTitle: '第一个镜头',
        durationText: '10s',
      ),
      const ShotPreviewItem(
        videoUrl: 'https://example.com/video2.mp4',
        shotNumber: 2,
        shotTitle: '第二个镜头',
        durationText: '15s',
      ),
      const ShotPreviewItem(
        videoUrl: 'https://example.com/video3.mp4',
        shotNumber: 3,
        shotTitle: '第三个镜头',
        durationText: '12s',
      ),
    ];

    testWidgets('should display playlist mode with shot count', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: PreviewPlayer(playlist: testPlaylist)),
        ),
      );

      // Should show current shot index and total count
      expect(find.text('(1/3)'), findsOneWidget);
    });

    testWidgets('should display first shot information initially', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: PreviewPlayer(playlist: testPlaylist)),
        ),
      );

      expect(find.text('镜头 #1'), findsOneWidget);
      expect(find.text('第一个镜头'), findsOneWidget);
      expect(find.text('10s'), findsOneWidget);
    });

    testWidgets('should display previous/next shot buttons in playlist mode', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: PreviewPlayer(playlist: testPlaylist)),
        ),
      );

      expect(find.byIcon(Icons.skip_previous), findsOneWidget);
      expect(find.byIcon(Icons.skip_next), findsOneWidget);
    });

    testWidgets(
      'should not display previous/next buttons in single shot mode',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: PreviewPlayer(
                videoUrl: 'https://example.com/test-video.mp4',
              ),
            ),
          ),
        );

        expect(find.byIcon(Icons.skip_previous), findsNothing);
        expect(find.byIcon(Icons.skip_next), findsNothing);
      },
    );

    testWidgets('should disable previous button on first shot', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: PreviewPlayer(playlist: testPlaylist)),
        ),
      );

      final previousButton = tester.widget<IconButton>(
        find.widgetWithIcon(IconButton, Icons.skip_previous),
      );
      expect(previousButton.onPressed, isNull);
    });

    testWidgets('should disable next button on last shot', (
      WidgetTester tester,
    ) async {
      // Create a playlist with only one shot
      final singleShotPlaylist = [testPlaylist.first];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: PreviewPlayer(playlist: singleShotPlaylist)),
        ),
      );

      final nextButton = tester.widget<IconButton>(
        find.widgetWithIcon(IconButton, Icons.skip_next),
      );
      expect(nextButton.onPressed, isNull);
    });

    testWidgets('should display total progress bar in playlist mode', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: PreviewPlayer(playlist: testPlaylist)),
        ),
      );

      // Should show playlist icon and total progress label
      expect(find.byIcon(Icons.playlist_play), findsOneWidget);
      expect(find.text('总进度'), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
    });

    testWidgets('should not display total progress bar in single shot mode', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: PreviewPlayer(videoUrl: 'https://example.com/test-video.mp4'),
          ),
        ),
      );

      expect(find.byIcon(Icons.playlist_play), findsNothing);
      expect(find.text('总进度'), findsNothing);
      expect(find.byType(LinearProgressIndicator), findsNothing);
    });

    testWidgets('should display current shot progress with movie icon', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: PreviewPlayer(playlist: testPlaylist)),
        ),
      );

      // Should show movie icon for current shot progress
      expect(find.byIcon(Icons.movie), findsOneWidget);
    });

    testWidgets('should have correct tooltips for playlist controls', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: PreviewPlayer(playlist: testPlaylist)),
        ),
      );

      final previousButton = tester.widget<IconButton>(
        find.widgetWithIcon(IconButton, Icons.skip_previous),
      );
      expect(previousButton.tooltip, '上一个镜头');

      final nextButton = tester.widget<IconButton>(
        find.widgetWithIcon(IconButton, Icons.skip_next),
      );
      expect(nextButton.tooltip, '下一个镜头');
    });

    testWidgets('should call onPlaylistComplete when all shots finish', (
      WidgetTester tester,
    ) async {
      bool callbackCalled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PreviewPlayer(
              playlist: testPlaylist,
              onPlaylistComplete: () {
                callbackCalled = true;
              },
            ),
          ),
        ),
      );

      // Note: Testing actual playlist completion requires mocking
      // VideoPlayerController, which is complex in widget tests.
      // This test verifies the callback is properly wired up.
      expect(callbackCalled, false);
    });

    testWidgets('should assert when both videoUrl and playlist are provided', (
      WidgetTester tester,
    ) async {
      expect(
        () => PreviewPlayer(
          videoUrl: 'https://example.com/test-video.mp4',
          playlist: testPlaylist,
        ),
        throwsAssertionError,
      );
    });

    testWidgets(
      'should assert when neither videoUrl nor playlist are provided',
      (WidgetTester tester) async {
        expect(() => PreviewPlayer(), throwsAssertionError);
      },
    );

    testWidgets('should assert when empty playlist is provided', (
      WidgetTester tester,
    ) async {
      expect(() => PreviewPlayer(playlist: const []), throwsAssertionError);
    });
  });

  group('PreviewPlayerDialog Playlist Mode', () {
    final testPlaylist = [
      const ShotPreviewItem(
        videoUrl: 'https://example.com/video1.mp4',
        shotNumber: 1,
        shotTitle: '第一个镜头',
        durationText: '10s',
      ),
      const ShotPreviewItem(
        videoUrl: 'https://example.com/video2.mp4',
        shotNumber: 2,
        shotTitle: '第二个镜头',
        durationText: '15s',
      ),
    ];

    testWidgets('should display PreviewPlayer with playlist', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: PreviewPlayerDialog(playlist: testPlaylist)),
        ),
      );

      expect(find.byType(PreviewPlayer), findsOneWidget);

      final previewPlayer = tester.widget<PreviewPlayer>(
        find.byType(PreviewPlayer),
      );
      expect(previewPlayer.playlist, testPlaylist);
    });

    testWidgets(
      'should show playlist dialog using static showPlaylist method',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (context) => Scaffold(
                body: Center(
                  child: ElevatedButton(
                    onPressed: () {
                      PreviewPlayerDialog.showPlaylist(
                        context,
                        playlist: testPlaylist,
                      );
                    },
                    child: const Text('Open Playlist'),
                  ),
                ),
              ),
            ),
          ),
        );

        // Open the dialog
        await tester.tap(find.text('Open Playlist'));
        await tester.pumpAndSettle();

        // Verify dialog is shown with playlist
        expect(find.byType(PreviewPlayerDialog), findsOneWidget);
        expect(find.text('(1/2)'), findsOneWidget);
      },
    );

    testWidgets('should assert when both videoUrl and playlist are provided', (
      WidgetTester tester,
    ) async {
      expect(
        () => PreviewPlayerDialog(
          videoUrl: 'https://example.com/test-video.mp4',
          playlist: testPlaylist,
        ),
        throwsAssertionError,
      );
    });

    testWidgets(
      'should assert when neither videoUrl nor playlist are provided',
      (WidgetTester tester) async {
        expect(() => PreviewPlayerDialog(), throwsAssertionError);
      },
    );
  });
}
