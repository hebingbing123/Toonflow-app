import 'package:flutter_test/flutter_test.dart';
import 'package:openflow_app/rust_api/project/timeline.dart';
import 'package:openflow_app/short_video_space/short_video_preview_playlist.dart';

ProjectShortVideoTimelineV1 _timelineWithShot({
  required String url,
  int storyboardNumericId = 1,
}) {
  return ProjectShortVideoTimelineV1(
    schemaVersion: 1,
    tracks: const ShortVideoTimelineTracksV1(video: []),
    scripts: [
      ShortVideoTimelineScriptGroupV1(
        scriptNumericId: 10,
        shots: [
          ShortVideoTimelineShotV1(
            storyboardId: 'sb-1',
            storyboardNumericId: storyboardNumericId,
            subtitleSnippet: 'Opening',
            inMs: 0,
            outMs: 3000,
            selectedVideoUrl: url,
          ),
        ],
      ),
    ],
  );
}

void main() {
  test('shotPreviewPlaylistFromTimeline maps script shots', () {
    final playlist = shotPreviewPlaylistFromTimeline(
      _timelineWithShot(url: 'https://cdn.example.com/shot1.mp4'),
    );
    expect(playlist, hasLength(1));
    expect(playlist.first.videoUrl, 'https://cdn.example.com/shot1.mp4');
    expect(playlist.first.shotTitle, 'Opening');
    expect(playlist.first.durationText, '3.0s');
  });

  test('shotPreviewPlaylistFromTimeline falls back to track clips', () {
    final timeline = ProjectShortVideoTimelineV1(
      schemaVersion: 1,
      tracks: ShortVideoTimelineTracksV1(
        video: [
          ShortVideoTimelineVideoClipV1(
            storyboardNumericId: 2,
            sourceUrl: 'https://cdn.example.com/clip.mp4',
            inMs: 0,
            outMs: 2000,
          ),
        ],
      ),
      scripts: const [],
    );
    final playlist = shotPreviewPlaylistFromTimeline(timeline);
    expect(playlist.single.videoUrl, 'https://cdn.example.com/clip.mp4');
  });
}
