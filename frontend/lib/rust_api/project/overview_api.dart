// Project overview API functions
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../config.dart';
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
      .get(uri, headers: {'Authorization': 'Bearer $accessToken'})
      .timeout(const Duration(seconds: 15));
  if (res.statusCode == 404) {
    throw RustApiException('not found', statusCode: 404);
  }
  if (res.statusCode != 200) {
    throw RustApiException(res.body, statusCode: res.statusCode);
  }
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
      .get(uri, headers: {'Authorization': 'Bearer $accessToken'})
      .timeout(const Duration(seconds: 15));
  if (res.statusCode == 404) {
    throw RustApiException('not found', statusCode: 404);
  }
  if (res.statusCode != 200) {
    throw RustApiException(res.body, statusCode: res.statusCode);
  }
  final map = jsonDecode(res.body) as Map<String, dynamic>;
  return ProjectStats.fromJson(map);
}

Future<ProjectHome> fetchProjectHomeByProjectId(
  String accessToken,
  String projectId,
) async {
  final uri = Uri.parse('$kApiBaseUrl/api/v1/projects/$projectId/home');
  final res = await http
      .get(uri, headers: {'Authorization': 'Bearer $accessToken'})
      .timeout(const Duration(seconds: 15));
  if (res.statusCode == 404) {
    throw RustApiException('not found', statusCode: 404);
  }
  if (res.statusCode != 200) {
    throw RustApiException(res.body, statusCode: res.statusCode);
  }
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
      .get(uri, headers: {'Authorization': 'Bearer $accessToken'})
      .timeout(const Duration(seconds: 20));
  if (res.statusCode == 404) {
    throw RustApiException('not found', statusCode: 404);
  }
  if (res.statusCode != 200) {
    throw RustApiException(res.body, statusCode: res.statusCode);
  }
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
      .get(uri, headers: {'Authorization': 'Bearer $accessToken'})
      .timeout(const Duration(seconds: 20));
  if (res.statusCode == 404) {
    throw RustApiException('not found', statusCode: 404);
  }
  if (res.statusCode != 200) {
    throw RustApiException(res.body, statusCode: res.statusCode);
  }
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
      .get(uri, headers: {'Authorization': 'Bearer $accessToken'})
      .timeout(const Duration(seconds: 20));
  if (res.statusCode == 404) {
    throw RustApiException('not found', statusCode: 404);
  }
  if (res.statusCode != 200) {
    throw RustApiException(res.body, statusCode: res.statusCode);
  }
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
      .get(uri, headers: {'Authorization': 'Bearer $accessToken'})
      .timeout(const Duration(seconds: 25));
  if (res.statusCode == 404) {
    throw RustApiException('not found', statusCode: 404);
  }
  if (res.statusCode != 200) {
    throw RustApiException(res.body, statusCode: res.statusCode);
  }
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
      .get(uri, headers: {'Authorization': 'Bearer $accessToken'})
      .timeout(const Duration(seconds: 25));
  if (res.statusCode == 404) {
    throw RustApiException('not found', statusCode: 404);
  }
  if (res.statusCode != 200) {
    throw RustApiException(res.body, statusCode: res.statusCode);
  }
  final map = jsonDecode(res.body) as Map<String, dynamic>;
  return ProjectShortVideoExportCheck.fromJson(map);
}

/// Maps backend **`blocking_reasons`** codes to short UI labels (Chinese).
String labelShortVideoBlockingReason(String code) {
  switch (code) {
    case 'missing_basic_slot':
      return '时间线槽位';
    case 'missing_prompt_context':
      return '脚本 / 提示词';
    case 'missing_reference_visual':
      return '参考图';
    case 'missing_live_action_reference_shot':
      return '真人参考镜头';
    case 'missing_live_action_performance_notes':
      return '表演 / 口播约束';
    case 'candidate_pending':
      return '候选确认';
    case 'blocking_job':
      return '生成任务进行中';
    default:
      return code;
  }
}

/// One-line summary for the storyboard workbench (current shot).
String formatStoryboardShortVideoReadinessSummary(
  StoryboardShortVideoReadiness row,
) {
  if (row.readyForGeneration) {
    return '短视频就绪：本条分镜检查已通过，可继续生成。';
  }
  final parts = row.blockingReasons.map(labelShortVideoBlockingReason).toList();
  if (parts.isEmpty) {
    return '短视频就绪：有待核对项。';
  }
  return '短视频就绪：待补齐 ${parts.join('、')}';
}
