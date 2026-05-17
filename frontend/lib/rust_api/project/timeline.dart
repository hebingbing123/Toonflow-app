import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../config.dart';
import '../core.dart';
import '../jobs/api.dart';

class ShortVideoTimelineVideoClipV1 {
  const ShortVideoTimelineVideoClipV1({
    required this.storyboardNumericId,
    required this.sourceUrl,
    required this.inMs,
    required this.outMs,
    this.effectPresetId,
  });

  final int storyboardNumericId;
  final String sourceUrl;
  final int inMs;
  final int outMs;
  final String? effectPresetId;

  factory ShortVideoTimelineVideoClipV1.fromJson(Map<String, dynamic> json) {
    return ShortVideoTimelineVideoClipV1(
      storyboardNumericId: (json['storyboardNumericId'] as num).toInt(),
      sourceUrl: json['sourceUrl'] as String? ?? '',
      inMs: (json['inMs'] as num?)?.toInt() ?? 0,
      outMs: (json['outMs'] as num?)?.toInt() ?? 5000,
      effectPresetId: json['effectPresetId'] as String?,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'storyboardNumericId': storyboardNumericId,
    'sourceUrl': sourceUrl,
    'inMs': inMs,
    'outMs': outMs,
    if (effectPresetId != null && effectPresetId!.trim().isNotEmpty)
      'effectPresetId': effectPresetId,
  };

  ShortVideoTimelineVideoClipV1 copyWith({
    int? inMs,
    int? outMs,
    String? effectPresetId,
  }) {
    return ShortVideoTimelineVideoClipV1(
      storyboardNumericId: storyboardNumericId,
      sourceUrl: sourceUrl,
      inMs: inMs ?? this.inMs,
      outMs: outMs ?? this.outMs,
      effectPresetId: effectPresetId ?? this.effectPresetId,
    );
  }
}

class ShortVideoTimelineBgmTrackV1 {
  const ShortVideoTimelineBgmTrackV1({
    required this.enabled,
    this.assetUrl,
    this.bgmStrategy,
    required this.volume,
  });

  final bool enabled;
  final String? assetUrl;
  final String? bgmStrategy;
  final double volume;

  factory ShortVideoTimelineBgmTrackV1.fromJson(Map<String, dynamic> json) {
    return ShortVideoTimelineBgmTrackV1(
      enabled: json['enabled'] as bool? ?? false,
      assetUrl: json['assetUrl'] as String?,
      bgmStrategy: json['bgmStrategy'] as String?,
      volume: (json['volume'] as num?)?.toDouble() ?? 0.35,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'enabled': enabled,
    if (assetUrl != null && assetUrl!.trim().isNotEmpty) 'assetUrl': assetUrl,
    if (bgmStrategy != null && bgmStrategy!.trim().isNotEmpty)
      'bgmStrategy': bgmStrategy,
    'volume': volume,
  };

  ShortVideoTimelineBgmTrackV1 copyWith({
    bool? enabled,
    String? assetUrl,
    double? volume,
  }) {
    return ShortVideoTimelineBgmTrackV1(
      enabled: enabled ?? this.enabled,
      assetUrl: assetUrl ?? this.assetUrl,
      bgmStrategy: bgmStrategy,
      volume: volume ?? this.volume,
    );
  }
}

class ShortVideoTimelineSubtitleCueV1 {
  const ShortVideoTimelineSubtitleCueV1({
    this.storyboardNumericId,
    required this.startMs,
    required this.endMs,
    required this.text,
    this.styleId,
  });

  final int? storyboardNumericId;
  final int startMs;
  final int endMs;
  final String text;
  final String? styleId;

  factory ShortVideoTimelineSubtitleCueV1.fromJson(Map<String, dynamic> json) {
    return ShortVideoTimelineSubtitleCueV1(
      storyboardNumericId: json['storyboardNumericId'] == null
          ? null
          : (json['storyboardNumericId'] as num).toInt(),
      startMs: (json['startMs'] as num?)?.toInt() ?? 0,
      endMs: (json['endMs'] as num?)?.toInt() ?? 1000,
      text: json['text'] as String? ?? '',
      styleId: json['styleId'] as String?,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    if (storyboardNumericId != null)
      'storyboardNumericId': storyboardNumericId,
    'startMs': startMs,
    'endMs': endMs,
    'text': text,
    if (styleId != null && styleId!.trim().isNotEmpty) 'styleId': styleId,
  };

  ShortVideoTimelineSubtitleCueV1 copyWith({
    int? startMs,
    int? endMs,
    String? text,
  }) {
    return ShortVideoTimelineSubtitleCueV1(
      storyboardNumericId: storyboardNumericId,
      startMs: startMs ?? this.startMs,
      endMs: endMs ?? this.endMs,
      text: text ?? this.text,
      styleId: styleId,
    );
  }
}

class ShortVideoTimelineTransitionV1 {
  const ShortVideoTimelineTransitionV1({
    required this.type,
    required this.durationMs,
  });

  final String type;
  final int durationMs;

  factory ShortVideoTimelineTransitionV1.fromJson(Map<String, dynamic> json) {
    return ShortVideoTimelineTransitionV1(
      type: json['type'] as String? ?? 'cut',
      durationMs: (json['durationMs'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'type': type,
    'durationMs': durationMs,
  };
}

class ShortVideoTimelineVoiceoverClipV1 {
  const ShortVideoTimelineVoiceoverClipV1({
    required this.storyboardNumericId,
    required this.startMs,
    required this.sourceUrl,
    required this.volume,
  });

  final int storyboardNumericId;
  final int startMs;
  final String sourceUrl;
  final double volume;

  factory ShortVideoTimelineVoiceoverClipV1.fromJson(Map<String, dynamic> json) {
    return ShortVideoTimelineVoiceoverClipV1(
      storyboardNumericId: (json['storyboardNumericId'] as num).toInt(),
      startMs: (json['startMs'] as num?)?.toInt() ?? 0,
      sourceUrl: json['sourceUrl'] as String? ?? '',
      volume: (json['volume'] as num?)?.toDouble() ?? 1.0,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'storyboardNumericId': storyboardNumericId,
    'startMs': startMs,
    'sourceUrl': sourceUrl,
    'volume': volume,
  };

  ShortVideoTimelineVoiceoverClipV1 copyWith({double? volume}) {
    return ShortVideoTimelineVoiceoverClipV1(
      storyboardNumericId: storyboardNumericId,
      startMs: startMs,
      sourceUrl: sourceUrl,
      volume: volume ?? this.volume,
    );
  }
}

class ShortVideoTimelineTracksV1 {
  const ShortVideoTimelineTracksV1({
    required this.video,
    this.bgm,
    this.subtitles = const [],
    this.transitions = const [],
    this.voiceover = const [],
    this.templateId,
  });

  final List<ShortVideoTimelineVideoClipV1> video;
  final ShortVideoTimelineBgmTrackV1? bgm;
  final List<ShortVideoTimelineSubtitleCueV1> subtitles;
  final List<ShortVideoTimelineTransitionV1> transitions;
  final List<ShortVideoTimelineVoiceoverClipV1> voiceover;
  final String? templateId;

  factory ShortVideoTimelineTracksV1.fromJson(Map<String, dynamic> json) {
    List<T> mapList<T>(
      String key,
      T Function(Map<String, dynamic>) fromJson,
    ) {
      final raw = json[key] as List<dynamic>? ?? const [];
      return raw
          .map((e) => fromJson(e as Map<String, dynamic>))
          .toList(growable: false);
    }

    return ShortVideoTimelineTracksV1(
      video: mapList('video', ShortVideoTimelineVideoClipV1.fromJson),
      bgm: json['bgm'] == null
          ? null
          : ShortVideoTimelineBgmTrackV1.fromJson(
              json['bgm'] as Map<String, dynamic>,
            ),
      subtitles: mapList('subtitles', ShortVideoTimelineSubtitleCueV1.fromJson),
      transitions: mapList('transitions', ShortVideoTimelineTransitionV1.fromJson),
      voiceover: mapList('voiceover', ShortVideoTimelineVoiceoverClipV1.fromJson),
      templateId: json['templateId'] as String?,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'video': video.map((e) => e.toJson()).toList(growable: false),
    if (bgm != null) 'bgm': bgm!.toJson(),
    if (subtitles.isNotEmpty)
      'subtitles': subtitles.map((e) => e.toJson()).toList(growable: false),
    if (transitions.isNotEmpty)
      'transitions': transitions.map((e) => e.toJson()).toList(growable: false),
    if (voiceover.isNotEmpty)
      'voiceover': voiceover.map((e) => e.toJson()).toList(growable: false),
    if (templateId != null && templateId!.trim().isNotEmpty)
      'templateId': templateId,
  };

  ShortVideoTimelineTracksV1 copyWith({
    List<ShortVideoTimelineVideoClipV1>? video,
    ShortVideoTimelineBgmTrackV1? bgm,
    List<ShortVideoTimelineSubtitleCueV1>? subtitles,
    List<ShortVideoTimelineTransitionV1>? transitions,
    List<ShortVideoTimelineVoiceoverClipV1>? voiceover,
  }) {
    return ShortVideoTimelineTracksV1(
      video: video ?? this.video,
      bgm: bgm ?? this.bgm,
      subtitles: subtitles ?? this.subtitles,
      transitions: transitions ?? this.transitions,
      voiceover: voiceover ?? this.voiceover,
      templateId: templateId,
    );
  }
}

class ShortVideoTimelineShotV1 {
  const ShortVideoTimelineShotV1({
    required this.storyboardId,
    required this.storyboardNumericId,
    this.sbIndex,
    this.duration,
    this.selectedVideoUrl,
    this.thumbnailUrl,
    required this.subtitleSnippet,
    this.voiceoverAudioUrl,
    this.candidateStatus,
    required this.inMs,
    required this.outMs,
    this.sourceUrl,
  });

  final String storyboardId;
  final int storyboardNumericId;
  final int? sbIndex;
  final String? duration;
  final String? selectedVideoUrl;
  final String? thumbnailUrl;
  final String subtitleSnippet;
  final String? voiceoverAudioUrl;
  final String? candidateStatus;
  final int inMs;
  final int outMs;
  final String? sourceUrl;

  factory ShortVideoTimelineShotV1.fromJson(Map<String, dynamic> json) {
    return ShortVideoTimelineShotV1(
      storyboardId: json['storyboardId'] as String? ?? '',
      storyboardNumericId: (json['storyboardNumericId'] as num).toInt(),
      sbIndex: json['sbIndex'] == null ? null : (json['sbIndex'] as num).toInt(),
      duration: json['duration'] as String?,
      selectedVideoUrl: json['selectedVideoUrl'] as String?,
      thumbnailUrl: json['thumbnailUrl'] as String?,
      subtitleSnippet: json['subtitleSnippet'] as String? ?? '',
      voiceoverAudioUrl: json['voiceoverAudioUrl'] as String?,
      candidateStatus: json['candidateStatus'] as String?,
      inMs: (json['inMs'] as num?)?.toInt() ?? 0,
      outMs: (json['outMs'] as num?)?.toInt() ?? 5000,
      sourceUrl: json['sourceUrl'] as String?,
    );
  }
}

class ShortVideoTimelineScriptGroupV1 {
  const ShortVideoTimelineScriptGroupV1({
    required this.scriptNumericId,
    this.scriptName,
    required this.shots,
  });

  final int scriptNumericId;
  final String? scriptName;
  final List<ShortVideoTimelineShotV1> shots;

  factory ShortVideoTimelineScriptGroupV1.fromJson(Map<String, dynamic> json) {
    final raw = json['shots'] as List<dynamic>? ?? const [];
    return ShortVideoTimelineScriptGroupV1(
      scriptNumericId: (json['scriptNumericId'] as num).toInt(),
      scriptName: json['scriptName'] as String?,
      shots: raw
          .map(
            (e) => ShortVideoTimelineShotV1.fromJson(e as Map<String, dynamic>),
          )
          .toList(growable: false),
    );
  }
}

class ProjectShortVideoTimelineV1 {
  const ProjectShortVideoTimelineV1({
    required this.schemaVersion,
    this.timelineVersion,
    this.revision,
    required this.tracks,
    required this.scripts,
    this.voiceoverWaveformPeaks,
  });

  final int schemaVersion;
  final String? timelineVersion;
  final int? revision;
  final ShortVideoTimelineTracksV1 tracks;
  final List<ShortVideoTimelineScriptGroupV1> scripts;
  final List<double>? voiceoverWaveformPeaks;

  factory ProjectShortVideoTimelineV1.fromJson(Map<String, dynamic> json) {
    final raw = json['scripts'] as List<dynamic>? ?? const [];
    final peaksRaw = json['voiceoverWaveformPeaks'] as List<dynamic>?;
    return ProjectShortVideoTimelineV1(
      schemaVersion: (json['schemaVersion'] as num?)?.toInt() ?? 1,
      timelineVersion: json['timelineVersion'] as String?,
      revision: json['revision'] == null
          ? null
          : (json['revision'] as num).toInt(),
      tracks: json['tracks'] == null
          ? const ShortVideoTimelineTracksV1(video: [])
          : ShortVideoTimelineTracksV1.fromJson(
              json['tracks'] as Map<String, dynamic>,
            ),
      scripts: raw
          .map(
            (e) => ShortVideoTimelineScriptGroupV1.fromJson(
              e as Map<String, dynamic>,
            ),
          )
          .toList(growable: false),
      voiceoverWaveformPeaks: peaksRaw
          ?.map((e) => (e as num).toDouble())
          .toList(growable: false),
    );
  }
}

class PutProjectShortVideoTimelineResponseV1 {
  const PutProjectShortVideoTimelineResponseV1({
    required this.timelineVersion,
    required this.revision,
    required this.updatedClipCount,
  });

  final String timelineVersion;
  final int revision;
  final int updatedClipCount;

  factory PutProjectShortVideoTimelineResponseV1.fromJson(
    Map<String, dynamic> json,
  ) {
    return PutProjectShortVideoTimelineResponseV1(
      timelineVersion: json['timelineVersion'] as String? ?? '',
      revision: (json['revision'] as num?)?.toInt() ?? 0,
      updatedClipCount: (json['updatedClipCount'] as num?)?.toInt() ?? 0,
    );
  }
}

class ShortVideoTimelineRevisionItemV1 {
  const ShortVideoTimelineRevisionItemV1({
    required this.revision,
    required this.createdAt,
    this.createdBy,
    this.summary,
  });

  final int revision;
  final String createdAt;
  final String? createdBy;
  final String? summary;

  factory ShortVideoTimelineRevisionItemV1.fromJson(Map<String, dynamic> json) {
    return ShortVideoTimelineRevisionItemV1(
      revision: (json['revision'] as num).toInt(),
      createdAt: json['createdAt'] as String? ?? '',
      createdBy: json['createdBy'] as String?,
      summary: json['summary'] as String?,
    );
  }
}

class ShortVideoTimelineRestoreResponseV1 {
  const ShortVideoTimelineRestoreResponseV1({
    required this.timelineVersion,
    required this.revision,
    required this.restoredFromRevision,
  });

  final String timelineVersion;
  final int revision;
  final int restoredFromRevision;

  factory ShortVideoTimelineRestoreResponseV1.fromJson(
    Map<String, dynamic> json,
  ) {
    return ShortVideoTimelineRestoreResponseV1(
      timelineVersion: json['timelineVersion'] as String? ?? '',
      revision: (json['revision'] as num?)?.toInt() ?? 0,
      restoredFromRevision:
          (json['restoredFromRevision'] as num?)?.toInt() ?? 0,
    );
  }
}

class ShortVideoTimelinePreviewEnqueueResponseV1 {
  const ShortVideoTimelinePreviewEnqueueResponseV1({
    required this.jobId,
    required this.clipCount,
  });

  final String jobId;
  final int clipCount;

  factory ShortVideoTimelinePreviewEnqueueResponseV1.fromJson(
    Map<String, dynamic> json,
  ) {
    return ShortVideoTimelinePreviewEnqueueResponseV1(
      jobId: json['jobId'] as String? ?? '',
      clipCount: (json['clipCount'] as num?)?.toInt() ?? 0,
    );
  }
}

class ShortVideoTimelineApplyTemplateResponseV1 {
  const ShortVideoTimelineApplyTemplateResponseV1({
    required this.timelineVersion,
    required this.templateId,
    required this.videoClipCount,
  });

  final String timelineVersion;
  final String templateId;
  final int videoClipCount;

  factory ShortVideoTimelineApplyTemplateResponseV1.fromJson(
    Map<String, dynamic> json,
  ) {
    return ShortVideoTimelineApplyTemplateResponseV1(
      timelineVersion: json['timelineVersion'] as String? ?? '',
      templateId: json['templateId'] as String? ?? '',
      videoClipCount: (json['videoClipCount'] as num?)?.toInt() ?? 0,
    );
  }
}

Future<ProjectShortVideoTimelineV1> fetchProjectShortVideoTimelineByProjectId(
  String accessToken,
  String projectId,
) async {
  final uri = Uri.parse(
    '$kApiBaseUrl/api/v1/projects/$projectId/short-video-timeline',
  );
  final res = await http.get(
    uri,
    headers: {'Authorization': 'Bearer $accessToken'},
  ).timeout(const Duration(seconds: 25));
  ensureHttpSuccess(res);
  return ProjectShortVideoTimelineV1.fromJson(
    Map<String, dynamic>.from(jsonDecode(res.body) as Map),
  );
}

Future<PutProjectShortVideoTimelineResponseV1> putProjectShortVideoTimeline(
  String accessToken,
  String projectId, {
  required ShortVideoTimelineTracksV1 tracks,
  String? expectedTimelineVersion,
  int? expectedRevision,
  int schemaVersion = 4,
}) async {
  final uri = Uri.parse(
    '$kApiBaseUrl/api/v1/projects/$projectId/short-video-timeline',
  );
  final body = <String, dynamic>{
    'schemaVersion': schemaVersion,
    'tracks': tracks.toJson(),
  };
  if (expectedTimelineVersion != null &&
      expectedTimelineVersion.trim().isNotEmpty) {
    body['expectedTimelineVersion'] = expectedTimelineVersion.trim();
  }
  if (expectedRevision != null) {
    body['expectedRevision'] = expectedRevision;
  }
  final res = await http.put(
    uri,
    headers: {
      'Authorization': 'Bearer $accessToken',
      'Content-Type': 'application/json',
    },
    body: jsonEncode(body),
  ).timeout(const Duration(seconds: 25));
  ensureHttpSuccess(res);
  return PutProjectShortVideoTimelineResponseV1.fromJson(
    Map<String, dynamic>.from(jsonDecode(res.body) as Map),
  );
}

Future<ShortVideoTimelineApplyTemplateResponseV1>
postProjectShortVideoTimelineApplyTemplate(
  String accessToken,
  String projectId, {
  required String templateId,
}) async {
  final uri = Uri.parse(
    '$kApiBaseUrl/api/v1/projects/$projectId/short-video-timeline/apply-template',
  );
  final res = await http.post(
    uri,
    headers: {
      'Authorization': 'Bearer $accessToken',
      'Content-Type': 'application/json',
    },
    body: jsonEncode(<String, dynamic>{'templateId': templateId}),
  ).timeout(const Duration(seconds: 25));
  ensureHttpSuccess(res);
  return ShortVideoTimelineApplyTemplateResponseV1.fromJson(
    Map<String, dynamic>.from(jsonDecode(res.body) as Map),
  );
}

Future<ShortVideoTimelinePreviewEnqueueResponseV1>
postProjectShortVideoTimelinePreview(
  String accessToken,
  String projectId,
) async {
  final uri = Uri.parse(
    '$kApiBaseUrl/api/v1/projects/$projectId/short-video-timeline/preview',
  );
  final res = await http.post(
    uri,
    headers: {'Authorization': 'Bearer $accessToken'},
  ).timeout(const Duration(seconds: 25));
  ensureHttpSuccess(res);
  return ShortVideoTimelinePreviewEnqueueResponseV1.fromJson(
    Map<String, dynamic>.from(jsonDecode(res.body) as Map),
  );
}

Future<String?> pollTimelinePreviewJobFileUrl(
  String accessToken,
  String jobId, {
  Duration timeout = const Duration(minutes: 3),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(deadline)) {
    final job = await fetchJob(accessToken, jobId);
    final status = job.status.trim().toLowerCase();
    if (status == 'succeeded') {
      final result = job.result;
      if (result == null) {
        return null;
      }
      final preview =
          (result['preview_url'] ?? result['export_url']) as String?;
      if (preview != null && preview.trim().isNotEmpty) {
        final trimmed = preview.trim();
        if (trimmed.startsWith('http')) {
          return trimmed;
        }
        return '$kApiBaseUrl$trimmed';
      }
      return null;
    }
    if (status == 'failed' || status == 'cancelled') {
      throw RustApiException(
        job.errorMessage ?? 'timeline preview job $status',
        statusCode: 500,
      );
    }
    await Future<void>.delayed(const Duration(seconds: 2));
  }
  throw RustApiException('timeline preview timed out', statusCode: 504);
}

Future<void> postProjectShortVideoTimelineReorder(
  String accessToken,
  String projectId, {
  required int scriptNumericId,
  required List<int> orderedStoryboardIds,
}) async {
  final uri = Uri.parse(
    '$kApiBaseUrl/api/v1/projects/$projectId/short-video-timeline/reorder',
  );
  final res = await http.post(
    uri,
    headers: {
      'Authorization': 'Bearer $accessToken',
      'Content-Type': 'application/json',
    },
    body: jsonEncode(<String, dynamic>{
      'scriptNumericId': scriptNumericId,
      'orderedStoryboardIds': orderedStoryboardIds,
    }),
  ).timeout(const Duration(seconds: 20));
  ensureHttpSuccess(res);
}

Future<List<ShortVideoTimelineRevisionItemV1>>
fetchProjectShortVideoTimelineRevisions(
  String accessToken,
  String projectId,
) async {
  final uri = Uri.parse(
    '$kApiBaseUrl/api/v1/projects/$projectId/short-video-timeline/revisions',
  );
  final res = await http.get(
    uri,
    headers: {'Authorization': 'Bearer $accessToken'},
  ).timeout(const Duration(seconds: 20));
  ensureHttpSuccess(res);
  final json = Map<String, dynamic>.from(jsonDecode(res.body) as Map);
  final raw = json['revisions'] as List<dynamic>? ?? const [];
  return raw
      .map(
        (e) => ShortVideoTimelineRevisionItemV1.fromJson(
          e as Map<String, dynamic>,
        ),
      )
      .toList(growable: false);
}

Future<ShortVideoTimelineRestoreResponseV1>
postProjectShortVideoTimelineRestore(
  String accessToken,
  String projectId, {
  required int revision,
}) async {
  final uri = Uri.parse(
    '$kApiBaseUrl/api/v1/projects/$projectId/short-video-timeline/restore',
  );
  final res = await http.post(
    uri,
    headers: {
      'Authorization': 'Bearer $accessToken',
      'Content-Type': 'application/json',
    },
    body: jsonEncode(<String, dynamic>{'revision': revision}),
  ).timeout(const Duration(seconds: 25));
  ensureHttpSuccess(res);
  return ShortVideoTimelineRestoreResponseV1.fromJson(
    Map<String, dynamic>.from(jsonDecode(res.body) as Map),
  );
}

/// Known per-clip effect presets (**NLE M4b**).
const List<String> kShortVideoTimelineEffectPresets = [
  'none',
  'vivid',
  'cinematic',
  'bw',
  'speed_110',
];
