import '../../config.dart';
import '../core.dart';
import 'api.dart';

/// Job kind for short-video assembly export (`POST …/short-video-export`).
const kVideoExportJobKind = 'video.export';

/// Job kind for timeline rough-cut preview (`POST …/short-video-timeline/preview`).
const kTimelinePreviewJobKind = 'short_video.timeline_preview';

/// Reads playable URL from a succeeded job result payload.
String? outputUrlFromJobResult(Map<String, dynamic>? result) {
  return playableUrlFromJobResult(result);
}

/// Resolves relative job file URLs against [kApiBaseUrl].
String? playableUrlFromJobResult(Map<String, dynamic>? result) {
  if (result == null) {
    return null;
  }
  for (final key in [
    'preview_url',
    'export_url',
    'output_url',
    'file_url',
    'url',
  ]) {
    final raw = result[key];
    if (raw is String && raw.trim().isNotEmpty) {
      final trimmed = raw.trim();
      if (trimmed.startsWith('http')) {
        return trimmed;
      }
      return '$kApiBaseUrl$trimmed';
    }
  }
  return null;
}

DateTime _jobSortTime(JobRow job) {
  return DateTime.tryParse(job.updatedAt) ??
      DateTime.tryParse(job.createdAt) ??
      DateTime.fromMillisecondsSinceEpoch(0);
}

Future<String?> _latestProjectJobPlayableUrl(
  String accessToken,
  String projectUuid, {
  required String kind,
  int limit = 50,
}) async {
  final trimmedProject = projectUuid.trim();
  if (trimmedProject.isEmpty) {
    return null;
  }
  final jobs = await fetchJobs(
    accessToken,
    kind: kind,
    status: 'succeeded',
    limit: limit,
  );
  final matching = jobs
      .where(
        (job) => job.payload['project_uuid']?.toString() == trimmedProject,
      )
      .toList(growable: false);
  matching.sort((a, b) => _jobSortTime(b).compareTo(_jobSortTime(a)));
  for (final job in matching) {
    final url = playableUrlFromJobResult(job.result);
    if (url != null) {
      return url;
    }
  }
  return null;
}

/// Latest succeeded **`video.export`** output URL for [projectUuid], if any.
Future<String?> fetchLatestProjectVideoExportOutputUrl(
  String accessToken,
  String projectUuid, {
  int limit = 50,
}) {
  return _latestProjectJobPlayableUrl(
    accessToken,
    projectUuid,
    kind: kVideoExportJobKind,
    limit: limit,
  );
}

/// Latest succeeded **`short_video.timeline_preview`** URL for [projectUuid].
Future<String?> fetchLatestProjectTimelinePreviewOutputUrl(
  String accessToken,
  String projectUuid, {
  int limit = 50,
}) {
  return _latestProjectJobPlayableUrl(
    accessToken,
    projectUuid,
    kind: kTimelinePreviewJobKind,
    limit: limit,
  );
}

/// Newest playable preview among timeline preview and assembly export jobs.
Future<String?> fetchLatestProjectVideoPreviewOutputUrl(
  String accessToken,
  String projectUuid, {
  int limit = 50,
}) async {
  final trimmedProject = projectUuid.trim();
  if (trimmedProject.isEmpty) {
    return null;
  }
  final jobs = await fetchJobs(
    accessToken,
    status: 'succeeded',
    limit: limit,
  );
  final matching = jobs
      .where((job) {
        if (job.payload['project_uuid']?.toString() != trimmedProject) {
          return false;
        }
        return job.kind == kVideoExportJobKind ||
            job.kind == kTimelinePreviewJobKind;
      })
      .toList(growable: false);
  matching.sort((a, b) => _jobSortTime(b).compareTo(_jobSortTime(a)));
  for (final job in matching) {
    final url = playableUrlFromJobResult(job.result);
    if (url != null) {
      return url;
    }
  }
  return null;
}
