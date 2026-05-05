import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../config.dart';
import '../core.dart';

/// `GET …/publish/platform-matrix`
Future<PublishPlatformMatrixResponse> fetchPublishPlatformMatrix(
  String accessToken,
  String projectId,
) async {
  final uri = Uri.parse(
    '$kApiBaseUrl/api/v1/projects/$projectId/publish/platform-matrix',
  );
  final res = await http
      .get(uri, headers: {'Authorization': 'Bearer $accessToken'})
      .timeout(const Duration(seconds: 20));
  if (res.statusCode == 404) {
    throw RustApiException('not found', statusCode: 404);
  }
  if (res.statusCode != 200) {
    throw RustApiException(res.body, statusCode: res.statusCode);
  }
  final map = jsonDecode(res.body) as Map<String, dynamic>;
  return PublishPlatformMatrixResponse.fromJson(map);
}

/// `GET …/publish/drafts`
Future<List<PublishDraftRow>> fetchPublishDrafts(
  String accessToken,
  String projectId,
) async {
  final uri = Uri.parse(
    '$kApiBaseUrl/api/v1/projects/$projectId/publish/drafts',
  );
  final res = await http
      .get(uri, headers: {'Authorization': 'Bearer $accessToken'})
      .timeout(const Duration(seconds: 20));
  if (res.statusCode != 200) {
    throw RustApiException(res.body, statusCode: res.statusCode);
  }
  final raw = jsonDecode(res.body) as List<dynamic>;
  return raw
      .map((e) => PublishDraftRow.fromJson(e as Map<String, dynamic>))
      .toList(growable: false);
}

/// `GET …/publish/drafts/{draft_id}/prepare-check`
Future<PublishPrepareCheckResponse> fetchPublishPrepareCheck(
  String accessToken,
  String projectId,
  String draftId,
) async {
  final uri = Uri.parse(
    '$kApiBaseUrl/api/v1/projects/$projectId/publish/drafts/$draftId/prepare-check',
  );
  final res = await http
      .get(uri, headers: {'Authorization': 'Bearer $accessToken'})
      .timeout(const Duration(seconds: 20));
  if (res.statusCode != 200) {
    throw RustApiException(res.body, statusCode: res.statusCode);
  }
  final map = jsonDecode(res.body) as Map<String, dynamic>;
  return PublishPrepareCheckResponse.fromJson(map);
}

/// `POST …/publish/drafts`
Future<PublishDraftRow> createPublishDraft(
  String accessToken,
  String projectId,
  Map<String, dynamic> body,
) async {
  final uri = Uri.parse(
    '$kApiBaseUrl/api/v1/projects/$projectId/publish/drafts',
  );
  final res = await http
      .post(
        uri,
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(body),
      )
      .timeout(const Duration(seconds: 25));
  if (res.statusCode != 200) {
    throw RustApiException(res.body, statusCode: res.statusCode);
  }
  final map = jsonDecode(res.body) as Map<String, dynamic>;
  return PublishDraftRow.fromJson(map);
}

/// `POST …/publish/drafts/{draft_id}/targets`
Future<List<PublishTargetRow>> upsertPublishTargets(
  String accessToken,
  String projectId,
  String draftId,
  List<Map<String, dynamic>> targets,
) async {
  final uri = Uri.parse(
    '$kApiBaseUrl/api/v1/projects/$projectId/publish/drafts/$draftId/targets',
  );
  final res = await http
      .post(
        uri,
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(<String, dynamic>{'targets': targets}),
      )
      .timeout(const Duration(seconds: 25));
  if (res.statusCode != 200) {
    throw RustApiException(res.body, statusCode: res.statusCode);
  }
  final raw = jsonDecode(res.body) as List<dynamic>;
  return raw
      .map((e) => PublishTargetRow.fromJson(e as Map<String, dynamic>))
      .toList(growable: false);
}

/// `GET …/publish/jobs`
Future<List<PublishJobRow>> fetchPublishJobs(
  String accessToken,
  String projectId,
) async {
  final uri = Uri.parse(
    '$kApiBaseUrl/api/v1/projects/$projectId/publish/jobs',
  );
  final res = await http
      .get(uri, headers: {'Authorization': 'Bearer $accessToken'})
      .timeout(const Duration(seconds: 20));
  if (res.statusCode != 200) {
    throw RustApiException(res.body, statusCode: res.statusCode);
  }
  final raw = jsonDecode(res.body) as List<dynamic>;
  return raw
      .map((e) => PublishJobRow.fromJson(e as Map<String, dynamic>))
      .toList(growable: false);
}

/// `POST …/publish/drafts/{draft_id}/jobs`
Future<PublishJobRow> createPublishJob(
  String accessToken,
  String projectId,
  String draftId, {
  Map<String, dynamic> payload = const <String, dynamic>{},
}) async {
  final uri = Uri.parse(
    '$kApiBaseUrl/api/v1/projects/$projectId/publish/drafts/$draftId/jobs',
  );
  final res = await http
      .post(
        uri,
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(<String, dynamic>{'payload': payload}),
      )
      .timeout(const Duration(seconds: 25));
  if (res.statusCode != 200) {
    throw RustApiException(res.body, statusCode: res.statusCode);
  }
  final map = jsonDecode(res.body) as Map<String, dynamic>;
  return PublishJobRow.fromJson(map);
}

/// `POST …/publish/jobs/{job_id}/confirm-semi-auto`
Future<PublishJobRow> confirmSemiAutoPublishJob(
  String accessToken,
  String projectId,
  String jobId,
) async {
  final uri = Uri.parse(
    '$kApiBaseUrl/api/v1/projects/$projectId/publish/jobs/$jobId/confirm-semi-auto',
  );
  final res = await http
      .post(
        uri,
        headers: {'Authorization': 'Bearer $accessToken'},
      )
      .timeout(const Duration(seconds: 25));
  if (res.statusCode != 200) {
    throw RustApiException(res.body, statusCode: res.statusCode);
  }
  final map = jsonDecode(res.body) as Map<String, dynamic>;
  return PublishJobRow.fromJson(map);
}

class PublishPlatformMatrixResponse {
  const PublishPlatformMatrixResponse({required this.platforms});

  final List<PublishPlatformCapabilityRow> platforms;

  factory PublishPlatformMatrixResponse.fromJson(Map<String, dynamic> json) {
    final raw = json['platforms'] as List<dynamic>? ?? const <dynamic>[];
    return PublishPlatformMatrixResponse(
      platforms: raw
          .map(
            (e) =>
                PublishPlatformCapabilityRow.fromJson(e as Map<String, dynamic>),
          )
          .toList(growable: false),
    );
  }
}

class PublishPlatformCapabilityRow {
  const PublishPlatformCapabilityRow({
    required this.platformId,
    required this.labelZh,
    required this.automationMode,
    required this.titleMaxChars,
    required this.requiresCover,
    required this.notes,
  });

  final String platformId;
  final String labelZh;
  final String automationMode;
  final int titleMaxChars;
  final bool requiresCover;
  final String notes;

  factory PublishPlatformCapabilityRow.fromJson(Map<String, dynamic> json) {
    return PublishPlatformCapabilityRow(
      platformId: json['platform_id'] as String? ?? '',
      labelZh: json['label_zh'] as String? ?? '',
      automationMode: json['automation_mode'] as String? ?? '',
      titleMaxChars: (json['title_max_chars'] as num?)?.toInt() ?? 0,
      requiresCover: json['requires_cover'] as bool? ?? false,
      notes: json['notes'] as String? ?? '',
    );
  }
}

class PublishDraftRow {
  const PublishDraftRow({
    required this.id,
    required this.projectId,
    required this.title,
    required this.description,
    required this.tags,
    required this.draftStatus,
    this.profileId,
    this.scriptId,
    this.videoAssetKey,
    this.coverAssetKey,
  });

  final String id;
  final String projectId;
  final String title;
  final String description;
  final List<String> tags;
  final String draftStatus;
  final String? profileId;
  final String? scriptId;
  final String? videoAssetKey;
  final String? coverAssetKey;

  factory PublishDraftRow.fromJson(Map<String, dynamic> json) {
    final tagRaw = json['tags'] as List<dynamic>? ?? const <dynamic>[];
    return PublishDraftRow(
      id: json['id'] as String? ?? '',
      projectId: json['project_id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      description: json['description'] as String? ?? '',
      tags: tagRaw.map((e) => '$e').toList(growable: false),
      draftStatus: json['draft_status'] as String? ?? '',
      profileId: json['profile_id'] as String?,
      scriptId: json['script_id'] as String?,
      videoAssetKey: json['video_asset_key'] as String?,
      coverAssetKey: json['cover_asset_key'] as String?,
    );
  }
}

class PublishPrepareCheckResponse {
  const PublishPrepareCheckResponse({
    required this.draftId,
    required this.ok,
    required this.issues,
  });

  final String draftId;
  final bool ok;
  final List<PublishPrepareIssue> issues;

  factory PublishPrepareCheckResponse.fromJson(Map<String, dynamic> json) {
    final raw = json['issues'] as List<dynamic>? ?? const <dynamic>[];
    return PublishPrepareCheckResponse(
      draftId: json['draft_id'] as String? ?? '',
      ok: json['ok'] as bool? ?? false,
      issues: raw
          .map((e) => PublishPrepareIssue.fromJson(e as Map<String, dynamic>))
          .toList(growable: false),
    );
  }
}

class PublishPrepareIssue {
  const PublishPrepareIssue({
    required this.code,
    required this.message,
    required this.severity,
    this.platformId,
  });

  final String code;
  final String message;
  final String severity;
  final String? platformId;

  factory PublishPrepareIssue.fromJson(Map<String, dynamic> json) {
    return PublishPrepareIssue(
      code: json['code'] as String? ?? '',
      message: json['message'] as String? ?? '',
      severity: json['severity'] as String? ?? '',
      platformId: json['platform_id'] as String?,
    );
  }
}

class PublishTargetRow {
  const PublishTargetRow({
    required this.id,
    required this.draftId,
    required this.platformId,
    required this.automationMode,
  });

  final String id;
  final String draftId;
  final String platformId;
  final String automationMode;

  factory PublishTargetRow.fromJson(Map<String, dynamic> json) {
    return PublishTargetRow(
      id: json['id'] as String? ?? '',
      draftId: json['draft_id'] as String? ?? '',
      platformId: json['platform_id'] as String? ?? '',
      automationMode: json['automation_mode'] as String? ?? '',
    );
  }
}

class PublishJobRow {
  const PublishJobRow({
    required this.id,
    required this.projectId,
    required this.draftId,
    required this.status,
    this.errorMessage,
  });

  final String id;
  final String projectId;
  final String draftId;
  final String status;
  final String? errorMessage;

  factory PublishJobRow.fromJson(Map<String, dynamic> json) {
    return PublishJobRow(
      id: json['id'] as String? ?? '',
      projectId: json['project_id'] as String? ?? '',
      draftId: json['draft_id'] as String? ?? '',
      status: json['status'] as String? ?? '',
      errorMessage: json['error_message'] as String?,
    );
  }
}
