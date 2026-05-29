import '../rust_api/project/timeline.dart';
import 'layout/short_video_responsive_shell.dart';

String? _firstNonEmptyUrl(Iterable<String?> urls) {
  for (final raw in urls) {
    final trimmed = (raw ?? '').trim();
    if (trimmed.isNotEmpty) {
      return trimmed;
    }
  }
  return null;
}

String? _formatClipDurationMs(int inMs, int outMs, String? fallback) {
  final durationMs = outMs - inMs;
  if (durationMs > 0) {
    return '${(durationMs / 1000).toStringAsFixed(1)}s';
  }
  final trimmed = (fallback ?? '').trim();
  return trimmed.isEmpty ? null : trimmed;
}

/// Builds shot-level preview entries from timeline scripts / track clips.
List<ShotPreviewPlaylistEntry> shotPreviewPlaylistFromTimeline(
  ProjectShortVideoTimelineV1? timeline,
) {
  if (timeline == null) {
    return const <ShotPreviewPlaylistEntry>[];
  }

  final entries = <ShotPreviewPlaylistEntry>[];
  var fallbackShotNumber = 1;
  for (final group in timeline.scripts) {
    for (final shot in group.shots) {
      final url = _firstNonEmptyUrl([
        shot.selectedVideoUrl,
        shot.sourceUrl,
      ]);
      if (url == null) {
        fallbackShotNumber++;
        continue;
      }
      entries.add(
        ShotPreviewPlaylistEntry(
          videoUrl: url,
          shotNumber: shot.sbIndex ?? fallbackShotNumber,
          shotTitle: shot.subtitleSnippet.trim().isEmpty
              ? null
              : shot.subtitleSnippet.trim(),
          durationText: _formatClipDurationMs(
            shot.inMs,
            shot.outMs,
            shot.duration,
          ),
        ),
      );
      fallbackShotNumber++;
    }
  }

  if (entries.isNotEmpty) {
    return entries;
  }

  var clipIndex = 1;
  for (final clip in timeline.tracks.video) {
    final url = clip.sourceUrl.trim();
    if (url.isEmpty) {
      continue;
    }
    entries.add(
      ShotPreviewPlaylistEntry(
        videoUrl: url,
        shotNumber: clipIndex,
        durationText: _formatClipDurationMs(clip.inMs, clip.outMs, null),
      ),
    );
    clipIndex++;
  }
  return entries;
}
