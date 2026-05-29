// Project overview API functions
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../config.dart';
import '../../l10n/app_localizations.dart';
import '../../l10n/short_video_readiness_localized.dart';
import '../core.dart';
import 'overview_models.dart';
import 'overview_models_assembly.dart';

/// `GET /api/v1/projects/{project_id}` — see `getProjectByProjectIdV1`.
Future<ProjectDetail> fetchProjectByProjectId(
  String accessToken,
  String projectId,
) async {
  final uri = Uri.parse('$kApiBaseUrl/api/v1/projects/$projectId');
  final res = await http
      .get(uri, headers: rustApiAuthHeaders(accessToken))
      .timeout(const Duration(seconds: 15));
  if (res.statusCode == 404) {
    throw RustApiException('not found', statusCode: 404);
  }
  ensureHttpSuccess(res);
  final map = jsonDecode(res.body) as Map<String, dynamic>;
  return ProjectDetail.fromJson(map);
}

/// `GET /api/v1/projects/{project_id}/stats` — see `getProjectStatsByProjectIdV1`.
Future<ProjectStats> fetchProjectStatsByProjectId(
  String accessToken,
  String projectId,
) async {
  final uri = Uri.parse('$kApiBaseUrl/api/v1/projects/$projectId/stats');
  final res = await http
      .get(uri, headers: rustApiAuthHeaders(accessToken))
      .timeout(const Duration(seconds: 15));
  if (res.statusCode == 404) {
    throw RustApiException('not found', statusCode: 404);
  }
  ensureHttpSuccess(res);
  final map = jsonDecode(res.body) as Map<String, dynamic>;
  return ProjectStats.fromJson(map);
}

Future<ProjectHome> fetchProjectHomeByProjectId(
  String accessToken,
  String projectId,
) async {
  final uri = Uri.parse('$kApiBaseUrl/api/v1/projects/$projectId/home');
  final res = await http
      .get(uri, headers: rustApiAuthHeaders(accessToken))
      .timeout(const Duration(seconds: 15));
  if (res.statusCode == 404) {
    throw RustApiException('not found', statusCode: 404);
  }
  ensureHttpSuccess(res);
  final map = jsonDecode(res.body) as Map<String, dynamic>;
  return ProjectHome.fromJson(map);
}

/// `GET /api/v1/projects/{project_id}/short-video-readiness` — see `getProjectShortVideoReadinessByProjectIdV1`.
Future<ProjectShortVideoReadiness> fetchProjectShortVideoReadinessByProjectId(
  String accessToken,
  String projectId,
) async {
  final uri = Uri.parse(
    '$kApiBaseUrl/api/v1/projects/$projectId/short-video-readiness',
  );
  final res = await http
      .get(uri, headers: rustApiAuthHeaders(accessToken))
      .timeout(const Duration(seconds: 20));
  if (res.statusCode == 404) {
    throw RustApiException('not found', statusCode: 404);
  }
  ensureHttpSuccess(res);
  final map = jsonDecode(res.body) as Map<String, dynamic>;
  return ProjectShortVideoReadiness.fromJson(map);
}

/// `GET /api/v1/projects/{project_id}/production-overview` — see `getProjectProductionOverviewByProjectIdV1`.
Future<ProjectProductionOverview> fetchProjectProductionOverviewByProjectId(
  String accessToken,
  String projectId,
) async {
  final uri = Uri.parse(
    '$kApiBaseUrl/api/v1/projects/$projectId/production-overview',
  );
  final res = await http
      .get(uri, headers: rustApiAuthHeaders(accessToken))
      .timeout(const Duration(seconds: 20));
  if (res.statusCode == 404) {
    throw RustApiException('not found', statusCode: 404);
  }
  ensureHttpSuccess(res);
  final map = jsonDecode(res.body) as Map<String, dynamic>;
  return ProjectProductionOverview.fromJson(map);
}

/// `GET /api/v1/projects/{project_id}/assets-overview` — see `getProjectAssetsOverviewByProjectIdV1`.
Future<ProjectAssetsOverview> fetchProjectAssetsOverviewByProjectId(
  String accessToken,
  String projectId,
) async {
  final uri = Uri.parse(
    '$kApiBaseUrl/api/v1/projects/$projectId/assets-overview',
  );
  final res = await http
      .get(uri, headers: rustApiAuthHeaders(accessToken))
      .timeout(const Duration(seconds: 20));
  if (res.statusCode == 404) {
    throw RustApiException('not found', statusCode: 404);
  }
  ensureHttpSuccess(res);
  final map = jsonDecode(res.body) as Map<String, dynamic>;
  return ProjectAssetsOverview.fromJson(map);
}

/// `GET /api/v1/projects/{project_id}/short-video-assembly` — see `getProjectShortVideoAssemblyByProjectIdV1`.
Future<ProjectShortVideoAssembly> fetchProjectShortVideoAssemblyByProjectId(
  String accessToken,
  String projectId,
) async {
  final uri = Uri.parse(
    '$kApiBaseUrl/api/v1/projects/$projectId/short-video-assembly',
  );
  final res = await http
      .get(uri, headers: rustApiAuthHeaders(accessToken))
      .timeout(const Duration(seconds: 25));
  if (res.statusCode == 404) {
    throw RustApiException('not found', statusCode: 404);
  }
  ensureHttpSuccess(res);
  final map = jsonDecode(res.body) as Map<String, dynamic>;
  return ProjectShortVideoAssembly.fromJson(map);
}

/// `GET /api/v1/projects/{project_id}/short-video-export-check` — see `getProjectShortVideoExportCheckByProjectIdV1`.
Future<ProjectShortVideoExportCheck>
fetchProjectShortVideoExportCheckByProjectId(
  String accessToken,
  String projectId,
) async {
  final uri = Uri.parse(
    '$kApiBaseUrl/api/v1/projects/$projectId/short-video-export-check',
  );
  final res = await http
      .get(uri, headers: rustApiAuthHeaders(accessToken))
      .timeout(const Duration(seconds: 25));
  if (res.statusCode == 404) {
    throw RustApiException('not found', statusCode: 404);
  }
  ensureHttpSuccess(res);
  final map = jsonDecode(res.body) as Map<String, dynamic>;
  return ProjectShortVideoExportCheck.fromJson(map);
}

/// `POST /api/v1/projects/{project_id}/short-video-pre-assembly` — batch rough-cut manifest job.
Future<ShortVideoPreAssemblyEnqueueResponse>
postProjectShortVideoPreAssemblyByProjectId(
  String accessToken,
  String projectId, {
  int? scriptNumericId,
}) async {
  final uri = Uri.parse(
    '$kApiBaseUrl/api/v1/projects/$projectId/short-video-pre-assembly',
  );
  final body = <String, dynamic>{
    'scriptNumericId': ?scriptNumericId,
  };
  final res = await http
      .post(
        uri,
        headers: rustApiJsonAuthHeaders(accessToken),
        body: jsonEncode(body),
      )
      .timeout(const Duration(seconds: 30));
  if (res.statusCode == 404) {
    throw RustApiException('not found', statusCode: 404);
  }
  ensureHttpSuccess(res);
  final map = jsonDecode(res.body) as Map<String, dynamic>;
  return ShortVideoPreAssemblyEnqueueResponse.fromJson(map);
}

/// `POST /api/v1/projects/{project_id}/short-video-export` — enqueue **`video.export`** job.
Future<ShortVideoExportEnqueueResponse> postProjectShortVideoExportByProjectId(
  String accessToken,
  String projectId, {
  String format = 'mp4',
  int? scriptNumericId,
}) async {
  final uri = Uri.parse(
    '$kApiBaseUrl/api/v1/projects/$projectId/short-video-export',
  );
  final body = <String, dynamic>{
    'format': format,
    'scriptNumericId': ?scriptNumericId,
  };
  final res = await http
      .post(
        uri,
        headers: rustApiJsonAuthHeaders(accessToken),
        body: jsonEncode(body),
      )
      .timeout(const Duration(seconds: 30));
  if (res.statusCode == 404) {
    throw RustApiException('not found', statusCode: 404);
  }
  ensureHttpSuccess(res);
  final map = jsonDecode(res.body) as Map<String, dynamic>;
  return ShortVideoExportEnqueueResponse.fromJson(map);
}

/// Maps backend **`blocking_reasons`** codes through localized strings.
String labelShortVideoBlockingReason(AppLocalizations l10n, String code) =>
    labelShortVideoBlockingReasonLocalized(l10n, code);

/// One-line summary for the storyboard workbench (current shot).
String formatStoryboardShortVideoReadinessSummary(
  AppLocalizations l10n,
  StoryboardShortVideoReadiness row,
) =>
    formatStoryboardShortVideoReadinessSummaryLocalized(l10n, row);
