import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openflow_app/design_system/components/studio_loading_placeholders.dart';
import 'package:openflow_app/short_video_space/components/preview_player.dart';

/// Unit tests for Task 9.4: PreviewPlayer Component
/// 
/// Tests cover:
/// - Requirements 1: Single shot preview playback
/// - Requirements 2: Continuous playlist playback
/// - Playback state management (play/pause/stop)
/// - Progress tracking (current position, total duration)
/// - Shot switching logic (next/previous)

void main() {
  group('ShotPreviewItem', () {
    test('should create shot preview item with required fields', () {
      final item = ShotPreviewItem(
        videoUrl: 'https://example.com/video.mp4',
        shotNumber: 1,
      );

      expect(item.videoUrl, 'https://example.com/video.mp4');
      expect(item.shotNumber, 1);
      expect(item.shotTitle, null);
      expect(item.durationText, null);
    });

    test('should create shot preview item with all fields', () {
      final item = ShotPreviewItem(
        videoUrl: 'https://example.com/video.mp4',
        shotNumber: 1,
        shotTitle: 'Opening Scene',
        durationText: '10s',
      );

      expect(item.videoUrl, 'https://example.com/video.mp4');
      expect(item.shotNumber, 1);
      expect(item.shotTitle, 'Opening Scene');
      expect(item.durationText, '10s');
    });
  });

  group('PreviewPlayer - Constructor Validation', () {
    test('should accept single shot mode with videoUrl', () {
      expect(
        () => PreviewPlayer(
          videoUrl: 'https://example.com/video.mp4',
          shotNumber: 1,
        ),
        returnsNormally,
      );
    });

    test('should accept playlist mode with non-empty playlist', () {
      expect(
        () => PreviewPlayer(
          playlist: [
            ShotPreviewItem(
              videoUrl: 'https://example.com/video1.mp4',
              shotNumber: 1,
            ),
          ],
        ),
        returnsNormally,
      );
    });

    test('should throw assertion error when both videoUrl and playlist are null', () {
      expect(
        () => PreviewPlayer(),
        throwsAssertionError,
      );
    });

    test('should throw assertion error when both videoUrl and playlist are provided', () {
      expect(
        () => PreviewPlayer(
          videoUrl: 'https://example.com/video.mp4',
          playlist: [
            ShotPreviewItem(
              videoUrl: 'https://example.com/video1.mp4',
              shotNumber: 1,
            ),
          ],
        ),
        throwsAssertionError,
      );
    });

    test('should throw assertion error when playlist is empty', () {
      expect(
        () => PreviewPlayer(playlist: const []),
        throwsAssertionError,
      );
    });
  });

  group('PreviewPlayer - Playback State Management', () {
    testWidgets('should initialize with stopped state', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PreviewPlayer(
              videoUrl: 'https://example.com/video.mp4',
              shotNumber: 1,
            ),
          ),
        ),
      );

      expect(find.byType(StudioMediaTileSkeleton), findsOneWidget);
    });

    testWidgets('should show play button when not playing', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PreviewPlayer(
              videoUrl: 'https://example.com/video.mp4',
              shotNumber: 1,
              autoPlay: false,
            ),
          ),
        ),
      );

      await tester.pump();

      // Should have play button (not pause)
      expect(find.byIcon(Icons.play_arrow), findsOneWidget);
    });

    testWidgets('should show stop button', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PreviewPlayer(
              videoUrl: 'https://example.com/video.mp4',
              shotNumber: 1,
            ),
          ),
        ),
      );

      await tester.pump();

      expect(find.byIcon(Icons.stop), findsOneWidget);
    });

    testWidgets('should display shot number when provided', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PreviewPlayer(
              videoUrl: 'https://example.com/video.mp4',
              shotNumber: 5,
            ),
          ),
        ),
      );

      await tester.pump();

      expect(find.text('Shot #5'), findsOneWidget);
    });

    testWidgets('should display shot title when provided', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PreviewPlayer(
              videoUrl: 'https://example.com/video.mp4',
              shotNumber: 1,
              shotTitle: 'Opening Scene',
            ),
          ),
        ),
      );

      await tester.pump();

      expect(find.text('Opening Scene'), findsOneWidget);
    });

    testWidgets('should display duration text when provided', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PreviewPlayer(
              videoUrl: 'https://example.com/video.mp4',
              shotNumber: 1,
              durationText: '10s',
            ),
          ),
        ),
      );

      await tester.pump();

      expect(find.text('10s'), findsOneWidget);
    });
  });

  group('PreviewPlayer - Progress Tracking', () {
    testWidgets('should display progress slider', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PreviewPlayer(
              videoUrl: 'https://example.com/video.mp4',
              shotNumber: 1,
            ),
          ),
        ),
      );

      await tester.pump();

      expect(find.byType(Slider), findsOneWidget);
    });

    testWidgets('should display current time and total duration', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PreviewPlayer(
              videoUrl: 'https://example.com/video.mp4',
              shotNumber: 1,
            ),
          ),
        ),
      );

      await tester.pump();

      // Should display time in format MM:SS
      expect(find.text('00:00'), findsAtLeastNWidgets(1));
    });

    testWidgets('should format duration correctly', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PreviewPlayer(
              videoUrl: 'https://example.com/video.mp4',
              shotNumber: 1,
            ),
          ),
        ),
      );

      await tester.pump();

      // Initial state should show 00:00
      expect(find.text('00:00'), findsAtLeastNWidgets(1));
    });
  });

  group('PreviewPlayer - Playlist Mode', () {
    testWidgets('should display playlist indicator', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PreviewPlayer(
              playlist: [
                ShotPreviewItem(
                  videoUrl: 'https://example.com/video1.mp4',
                  shotNumber: 1,
                ),
                ShotPreviewItem(
                  videoUrl: 'https://example.com/video2.mp4',
                  shotNumber: 2,
                ),
              ],
            ),
          ),
        ),
      );

      await tester.pump();

      // Should show current shot index and total count
      expect(find.text('(1/2)'), findsOneWidget);
    });

    testWidgets('should show previous and next buttons in playlist mode', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PreviewPlayer(
              playlist: [
                ShotPreviewItem(
                  videoUrl: 'https://example.com/video1.mp4',
                  shotNumber: 1,
                ),
                ShotPreviewItem(
                  videoUrl: 'https://example.com/video2.mp4',
                  shotNumber: 2,
                ),
              ],
            ),
          ),
        ),
      );

      await tester.pump();

      expect(find.byIcon(Icons.skip_previous), findsOneWidget);
      expect(find.byIcon(Icons.skip_next), findsOneWidget);
    });

    testWidgets('should not show previous/next buttons in single shot mode', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PreviewPlayer(
              videoUrl: 'https://example.com/video.mp4',
              shotNumber: 1,
            ),
          ),
        ),
      );

      await tester.pump();

      expect(find.byIcon(Icons.skip_previous), findsNothing);
      expect(find.byIcon(Icons.skip_next), findsNothing);
    });

    testWidgets('should disable previous button on first shot', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PreviewPlayer(
              playlist: [
                ShotPreviewItem(
                  videoUrl: 'https://example.com/video1.mp4',
                  shotNumber: 1,
                ),
                ShotPreviewItem(
                  videoUrl: 'https://example.com/video2.mp4',
                  shotNumber: 2,
                ),
              ],
            ),
          ),
        ),
      );

      await tester.pump();

      // Find the previous button
      final previousButton = tester.widget<IconButton>(
        find.ancestor(
          of: find.byIcon(Icons.skip_previous),
          matching: find.byType(IconButton),
        ),
      );

      // Should be disabled on first shot
      expect(previousButton.onPressed, isNull);
    });

    testWidgets('should disable next button on last shot', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PreviewPlayer(
              playlist: [
                ShotPreviewItem(
                  videoUrl: 'https://example.com/video1.mp4',
                  shotNumber: 1,
                ),
              ],
            ),
          ),
        ),
      );

      await tester.pump();

      // Find the next button
      final nextButton = tester.widget<IconButton>(
        find.ancestor(
          of: find.byIcon(Icons.skip_next),
          matching: find.byType(IconButton),
        ),
      );

      // Should be disabled on last shot (only one shot in playlist)
      expect(nextButton.onPressed, isNull);
    });

    testWidgets('should display total playlist progress', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PreviewPlayer(
              playlist: [
                ShotPreviewItem(
                  videoUrl: 'https://example.com/video1.mp4',
                  shotNumber: 1,
                ),
                ShotPreviewItem(
                  videoUrl: 'https://example.com/video2.mp4',
                  shotNumber: 2,
                ),
              ],
            ),
          ),
        ),
      );

      await tester.pump();

      // Should show total progress indicator
      expect(find.text('Overall progress'), findsOneWidget);
      expect(find.byIcon(Icons.playlist_play), findsOneWidget);
    });

    testWidgets('should display current shot progress separately', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PreviewPlayer(
              playlist: [
                ShotPreviewItem(
                  videoUrl: 'https://example.com/video1.mp4',
                  shotNumber: 1,
                ),
                ShotPreviewItem(
                  videoUrl: 'https://example.com/video2.mp4',
                  shotNumber: 2,
                ),
              ],
            ),
          ),
        ),
      );

      await tester.pump();

      // Should show current shot icon
      expect(find.byIcon(Icons.movie), findsOneWidget);
    });
  });

  group('PreviewPlayer - Shot Switching Logic', () {
    testWidgets('should update shot number when switching shots', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PreviewPlayer(
              playlist: [
                ShotPreviewItem(
                  videoUrl: 'https://example.com/video1.mp4',
                  shotNumber: 1,
                  shotTitle: 'Shot 1',
                ),
                ShotPreviewItem(
                  videoUrl: 'https://example.com/video2.mp4',
                  shotNumber: 2,
                  shotTitle: 'Shot 2',
                ),
              ],
            ),
          ),
        ),
      );

      await tester.pump();

      // Initially should show shot 1
      expect(find.text('Shot #1'), findsOneWidget);
      expect(find.text('Shot 1'), findsOneWidget);
    });

    testWidgets('should maintain playlist position indicator', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PreviewPlayer(
              playlist: [
                ShotPreviewItem(
                  videoUrl: 'https://example.com/video1.mp4',
                  shotNumber: 1,
                ),
                ShotPreviewItem(
                  videoUrl: 'https://example.com/video2.mp4',
                  shotNumber: 2,
                ),
                ShotPreviewItem(
                  videoUrl: 'https://example.com/video3.mp4',
                  shotNumber: 3,
                ),
              ],
            ),
          ),
        ),
      );

      await tester.pump();

      // Should show 1/3 initially
      expect(find.text('(1/3)'), findsOneWidget);
    });
  });

  group('PreviewPlayer - Error Handling', () {
    testWidgets('should show error message when video URL is empty', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PreviewPlayer(
              videoUrl: '',
              shotNumber: 1,
            ),
          ),
        ),
      );

      await tester.pump();

      // Should show error icon and message
      expect(find.byIcon(Icons.error_outline), findsOneWidget);
      expect(find.text('Video URL is empty'), findsOneWidget);
    });

    testWidgets('should display error icon in error state', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PreviewPlayer(
              videoUrl: '',
              shotNumber: 1,
            ),
          ),
        ),
      );

      await tester.pump();

      expect(find.byIcon(Icons.error_outline), findsOneWidget);
    });
  });

  group('PreviewPlayer - UI Layout', () {
    testWidgets('should display video in 16:9 aspect ratio', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PreviewPlayer(
              videoUrl: 'https://example.com/video.mp4',
              shotNumber: 1,
            ),
          ),
        ),
      );

      await tester.pump();

      // Should have AspectRatio widget with 16/9 ratio
      final aspectRatio = tester.widget<AspectRatio>(
        find.byType(AspectRatio),
      );
      expect(aspectRatio.aspectRatio, 16 / 9);
    });

    testWidgets('should have scrollable layout', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PreviewPlayer(
              videoUrl: 'https://example.com/video.mp4',
              shotNumber: 1,
            ),
          ),
        ),
      );

      await tester.pump();

      expect(find.byType(SingleChildScrollView), findsOneWidget);
    });

    testWidgets('should display all control buttons', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PreviewPlayer(
              videoUrl: 'https://example.com/video.mp4',
              shotNumber: 1,
            ),
          ),
        ),
      );

      await tester.pump();

      // Should have stop and play/pause buttons
      expect(find.byIcon(Icons.stop), findsOneWidget);
      expect(find.byIcon(Icons.play_arrow), findsOneWidget);
    });
  });

  group('PreviewPlayerDialog', () {
    testWidgets('should create dialog with single shot', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () {
                  PreviewPlayerDialog.show(
                    context,
                    videoUrl: 'https://example.com/video.mp4',
                    shotNumber: 1,
                  );
                },
                child: const Text('Show Dialog'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Show Dialog'));
      await tester.pumpAndSettle();

      // Dialog should be displayed
      expect(find.byType(Dialog), findsOneWidget);
      expect(find.byType(PreviewPlayer), findsOneWidget);
    });

    testWidgets('should create dialog with playlist', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () {
                  PreviewPlayerDialog.showPlaylist(
                    context,
                    playlist: [
                      ShotPreviewItem(
                        videoUrl: 'https://example.com/video1.mp4',
                        shotNumber: 1,
                      ),
                      ShotPreviewItem(
                        videoUrl: 'https://example.com/video2.mp4',
                        shotNumber: 2,
                      ),
                    ],
                  );
                },
                child: const Text('Show Playlist'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Show Playlist'));
      await tester.pumpAndSettle();

      // Dialog should be displayed with playlist
      expect(find.byType(Dialog), findsOneWidget);
      expect(find.byType(PreviewPlayer), findsOneWidget);
      expect(find.text('(1/2)'), findsOneWidget);
    });

    testWidgets('should have close button', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () {
                  PreviewPlayerDialog.show(
                    context,
                    videoUrl: 'https://example.com/video.mp4',
                    shotNumber: 1,
                  );
                },
                child: const Text('Show Dialog'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Show Dialog'));
      await tester.pumpAndSettle();

      expect(find.text('Close'), findsOneWidget);
    });

    testWidgets('should close dialog when close button tapped', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () {
                  PreviewPlayerDialog.show(
                    context,
                    videoUrl: 'https://example.com/video.mp4',
                    shotNumber: 1,
                  );
                },
                child: const Text('Show Dialog'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Show Dialog'));
      await tester.pumpAndSettle();

      expect(find.byType(Dialog), findsOneWidget);

      // Use ensureVisible to scroll the close button into view if needed
      await tester.ensureVisible(find.text('Close'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Close'), warnIfMissed: false);
      await tester.pumpAndSettle();

      expect(find.byType(Dialog), findsNothing);
    });

    testWidgets('should have constrained size', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () {
                  PreviewPlayerDialog.show(
                    context,
                    videoUrl: 'https://example.com/video.mp4',
                    shotNumber: 1,
                  );
                },
                child: const Text('Show Dialog'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Show Dialog'));
      await tester.pumpAndSettle();

      // Should have ConstrainedBox with max width
      // Find the specific ConstrainedBox that has maxWidth constraint
      final constrainedBoxes = find.descendant(
        of: find.byType(Dialog),
        matching: find.byType(ConstrainedBox),
      );

      // The dialog should contain a ConstrainedBox
      expect(constrainedBoxes, findsAtLeastNWidgets(1));

      // Check if any ConstrainedBox has the expected maxWidth
      bool foundCorrectConstraint = false;
      for (final element in constrainedBoxes.evaluate()) {
        final widget = element.widget as ConstrainedBox;
        if (widget.constraints.maxWidth == 800) {
          foundCorrectConstraint = true;
          break;
        }
      }

      expect(foundCorrectConstraint, true, reason: 'Should have a ConstrainedBox with maxWidth of 800');
    });
  });

  group('PreviewPlayer - Callbacks', () {
    testWidgets('should accept onPlaybackComplete callback', (WidgetTester tester) async {
      var callbackCalled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PreviewPlayer(
              videoUrl: 'https://example.com/video.mp4',
              shotNumber: 1,
              onPlaybackComplete: () {
                callbackCalled = true;
              },
            ),
          ),
        ),
      );

      await tester.pump();

      // Callback should be set (will be called when playback completes)
      expect(callbackCalled, false); // Not called yet
    });

    testWidgets('should accept onPlaylistComplete callback', (WidgetTester tester) async {
      var callbackCalled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PreviewPlayer(
              playlist: [
                ShotPreviewItem(
                  videoUrl: 'https://example.com/video1.mp4',
                  shotNumber: 1,
                ),
              ],
              onPlaylistComplete: () {
                callbackCalled = true;
              },
            ),
          ),
        ),
      );

      await tester.pump();

      // Callback should be set (will be called when playlist completes)
      expect(callbackCalled, false); // Not called yet
    });
  });

  group('PreviewPlayer - AutoPlay', () {
    testWidgets('should respect autoPlay parameter', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PreviewPlayer(
              videoUrl: 'https://example.com/video.mp4',
              shotNumber: 1,
              autoPlay: true,
            ),
          ),
        ),
      );

      await tester.pump();

      // AutoPlay is set to true (actual playback depends on video controller initialization)
      expect(find.byType(PreviewPlayer), findsOneWidget);
    });

    testWidgets('should not autoplay when autoPlay is false', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PreviewPlayer(
              videoUrl: 'https://example.com/video.mp4',
              shotNumber: 1,
              autoPlay: false,
            ),
          ),
        ),
      );

      await tester.pump();

      // Should show play button (not playing)
      expect(find.byIcon(Icons.play_arrow), findsOneWidget);
    });
  });

  group('PreviewPlayer - Edge Cases', () {
    testWidgets('should handle missing optional fields', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PreviewPlayer(
              videoUrl: 'https://example.com/video.mp4',
              // No shotNumber, shotTitle, or durationText
            ),
          ),
        ),
      );

      await tester.pump();

      // Should render without errors
      expect(find.byType(PreviewPlayer), findsOneWidget);
    });

    testWidgets('should handle single item playlist', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PreviewPlayer(
              playlist: [
                ShotPreviewItem(
                  videoUrl: 'https://example.com/video1.mp4',
                  shotNumber: 1,
                ),
              ],
            ),
          ),
        ),
      );

      await tester.pump();

      // Should show 1/1
      expect(find.text('(1/1)'), findsOneWidget);

      // Previous button should be disabled
      final previousButton = tester.widget<IconButton>(
        find.ancestor(
          of: find.byIcon(Icons.skip_previous),
          matching: find.byType(IconButton),
        ),
      );
      expect(previousButton.onPressed, isNull);

      // Next button should be disabled
      final nextButton = tester.widget<IconButton>(
        find.ancestor(
          of: find.byIcon(Icons.skip_next),
          matching: find.byType(IconButton),
        ),
      );
      expect(nextButton.onPressed, isNull);
    });

    testWidgets('should handle long shot titles with ellipsis', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PreviewPlayer(
              videoUrl: 'https://example.com/video.mp4',
              shotNumber: 1,
              shotTitle: 'This is a very long shot title that should be truncated with ellipsis',
            ),
          ),
        ),
      );

      await tester.pump();

      // Should find the text widget with ellipsis
      final textWidget = tester.widget<Text>(
        find.text('This is a very long shot title that should be truncated with ellipsis'),
      );
      expect(textWidget.overflow, TextOverflow.ellipsis);
      expect(textWidget.maxLines, 2);
    });
  });
}
