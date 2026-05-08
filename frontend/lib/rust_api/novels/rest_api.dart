import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../config.dart';
import '../core.dart';
import 'models.dart';

/// `GET /api/v1/projects/{project_id}/novels` — see `listProjectNovelsByProjectIdV1`.
Future<ListNovelsResponse> fetchProjectNovelsByProjectId(
  String accessToken,
  String projectId, {
  String? search,
  String? intakeStatus,
  String? intakeSource,
  int? page,
  int? limit,
}) async {
  final qp = <String, String>{};
  if (search != null && search.isNotEmpty) {
    qp['search'] = search;
  }
  if (intakeStatus != null && intakeStatus.isNotEmpty) {
    qp['intake_status'] = intakeStatus;
  }
  if (intakeSource != null && intakeSource.isNotEmpty) {
    qp['intake_source'] = intakeSource;
  }
  if (page != null) {
    qp['page'] = '$page';
  }
  if (limit != null) {
    qp['limit'] = '$limit';
  }
  var uri = Uri.parse('$kApiBaseUrl/api/v1/projects/$projectId/novels');
  if (qp.isNotEmpty) {
    uri = uri.replace(queryParameters: qp);
  }
  final res = await http
      .get(uri, headers: {'Authorization': 'Bearer $accessToken'})
      .timeout(const Duration(seconds: 15));
  if (res.statusCode == 404) {
    throw RustApiException('not found', statusCode: 404);
  }
  ensureHttpSuccess(res);
  final map = jsonDecode(res.body) as Map<String, dynamic>;
  return ListNovelsResponse.fromJson(map);
}

/// `GET /api/v1/projects/{project_id}/novels/{novel_numeric_id}` — see `getProjectNovelByProjectIdV1`.
Future<NovelRow> fetchProjectNovelByProjectIds(
  String accessToken,
  String projectId,
  int novelNumericId,
) async {
  final uri = Uri.parse(
    '$kApiBaseUrl/api/v1/projects/$projectId/novels/$novelNumericId',
  );
  final res = await http
      .get(uri, headers: {'Authorization': 'Bearer $accessToken'})
      .timeout(const Duration(seconds: 15));
  if (res.statusCode == 404) {
    throw RustApiException('not found', statusCode: 404);
  }
  ensureHttpSuccess(res);
  final map = jsonDecode(res.body) as Map<String, dynamic>;
  return NovelRow.fromJson(map);
}

/// `POST /api/v1/projects/{project_id}/novels` — see `createProjectNovelByProjectIdV1`.
Future<NovelRow> createProjectNovelUnderProject(
  String accessToken,
  String projectId, {
  int? chapterIndex,
  String? reel,
  String? chapter,
  String? chapterData,
  String? intakeSource,
  String? intakeSourceUrl,
  String? intakeStatus,
  String? intakeNote,
}) async {
  final uri = Uri.parse('$kApiBaseUrl/api/v1/projects/$projectId/novels');
  final body = <String, dynamic>{};
  if (chapterIndex != null) {
    body['chapter_index'] = chapterIndex;
  }
  if (reel != null) {
    body['reel'] = reel;
  }
  if (chapter != null) {
    body['chapter'] = chapter;
  }
  if (chapterData != null) {
    body['chapter_data'] = chapterData;
  }
  if (intakeSource != null) {
    body['intake_source'] = intakeSource;
  }
  if (intakeSourceUrl != null) {
    body['intake_source_url'] = intakeSourceUrl;
  }
  if (intakeStatus != null) {
    body['intake_status'] = intakeStatus;
  }
  if (intakeNote != null) {
    body['intake_note'] = intakeNote;
  }
  final res = await http
      .post(
        uri,
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(body),
      )
      .timeout(const Duration(seconds: 15));
  if (res.statusCode == 404) {
    throw RustApiException('not found', statusCode: 404);
  }
  if (res.statusCode == 400) {
    throw RustApiException.fromHttpResponse(res);
  }
  ensureHttpStatus(res, 201);
  final map = jsonDecode(res.body) as Map<String, dynamic>;
  return NovelRow.fromJson(map);
}

/// `PATCH /api/v1/projects/{project_id}/novels/{novel_numeric_id}` — see `patchProjectNovelByProjectIdV1`.
Future<NovelRow> patchProjectNovelByProjectIds(
  String accessToken,
  String projectId,
  int novelNumericId,
  Map<String, dynamic> body,
) async {
  final uri = Uri.parse(
    '$kApiBaseUrl/api/v1/projects/$projectId/novels/$novelNumericId',
  );
  final res = await http
      .patch(
        uri,
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(body),
      )
      .timeout(const Duration(seconds: 15));
  if (res.statusCode == 404) {
    throw RustApiException('not found', statusCode: 404);
  }
  if (res.statusCode == 400) {
    throw RustApiException.fromHttpResponse(res);
  }
  ensureHttpSuccess(res);
  final map = jsonDecode(res.body) as Map<String, dynamic>;
  return NovelRow.fromJson(map);
}

/// `DELETE /api/v1/projects/{project_id}/novels/{novel_numeric_id}` — see `deleteProjectNovelByProjectIdV1`.
Future<void> deleteProjectNovelByProjectIds(
  String accessToken,
  String projectId,
  int novelNumericId,
) async {
  final uri = Uri.parse(
    '$kApiBaseUrl/api/v1/projects/$projectId/novels/$novelNumericId',
  );
  final res = await http
      .delete(uri, headers: {'Authorization': 'Bearer $accessToken'})
      .timeout(const Duration(seconds: 15));
  if (res.statusCode == 404) {
    throw RustApiException('not found', statusCode: 404);
  }
  ensureHttpStatus(res, 204);
}

/// `POST /api/v1/projects/{project_id}/novels/crawl-preview` — see `postProjectNovelCrawlPreviewByProjectIdV1`.
Future<NovelCrawlPreviewResponse> postProjectNovelCrawlPreview(
  String accessToken,
  String projectId,
  String url,
) async {
  final uri = Uri.parse(
    '$kApiBaseUrl/api/v1/projects/$projectId/novels/crawl-preview',
  );
  final res = await http
      .post(
        uri,
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(<String, dynamic>{'url': url}),
      )
      .timeout(const Duration(seconds: 60));
  if (res.statusCode == 404) {
    throw RustApiException('not found', statusCode: 404);
  }
  if (res.statusCode == 400) {
    throw RustApiException.fromHttpResponse(res);
  }
  ensureHttpSuccess(res);
  final map = jsonDecode(res.body) as Map<String, dynamic>;
  return NovelCrawlPreviewResponse.fromJson(map);
}

/// `POST /api/v1/projects/{project_id}/novels/crawl-import` — see `postProjectNovelCrawlImportByProjectIdV1`.
Future<NovelCrawlImportResponse> postProjectNovelCrawlImport(
  String accessToken,
  String projectId,
  String url, {
  required String intakeStatus,
  String? intakeNote,
}) async {
  final uri = Uri.parse(
    '$kApiBaseUrl/api/v1/projects/$projectId/novels/crawl-import',
  );
  final body = <String, dynamic>{
    'url': url,
    'intake_status': intakeStatus,
    // Rust `Option<String>` accepts `null` as missing/None.
    'intake_note': intakeNote,
  };
  final res = await http
      .post(
        uri,
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(body),
      )
      .timeout(const Duration(seconds: 60));
  if (res.statusCode == 404) {
    throw RustApiException('not found', statusCode: 404);
  }
  if (res.statusCode == 400) {
    throw RustApiException.fromHttpResponse(res);
  }
  ensureHttpSuccess(res);
  final map = jsonDecode(res.body) as Map<String, dynamic>;
  return NovelCrawlImportResponse.fromJson(map);
}

/// `POST /api/v1/projects/{project_id}/novels/crawl-import-batch` — see `postProjectNovelCrawlImportBatchByProjectIdV1`.
Future<NovelCrawlImportBatchResponse> postProjectNovelCrawlImportBatch(
  String accessToken,
  String projectId,
  List<String> urls, {
  required String intakeStatus,
  String? intakeNote,
}) async {
  final uri = Uri.parse(
    '$kApiBaseUrl/api/v1/projects/$projectId/novels/crawl-import-batch',
  );
  final body = <String, dynamic>{
    'urls': urls,
    'intake_status': intakeStatus,
    'intake_note': intakeNote,
  };
  final res = await http
      .post(
        uri,
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(body),
      )
      .timeout(const Duration(seconds: 180));
  if (res.statusCode == 404) {
    throw RustApiException('not found', statusCode: 404);
  }
  if (res.statusCode == 400) {
    throw RustApiException.fromHttpResponse(res);
  }
  ensureHttpSuccess(res);
  final map = jsonDecode(res.body) as Map<String, dynamic>;
  return NovelCrawlImportBatchResponse.fromJson(map);
}

/// `POST /api/v1/projects/{project_id}/novels/crawl-schedules` — see `postProjectNovelCrawlScheduleCreateByProjectIdV1`.
Future<NovelCrawlScheduleRow> postProjectNovelCrawlScheduleCreate(
  String accessToken,
  String projectId, {
  required List<String> urls,
  required String intakeStatus,
  String? intakeNote,
  int? runAtMs,
  int? repeatIntervalMs,
  int? projectNumericId,
}) async {
  final uri = Uri.parse(
    '$kApiBaseUrl/api/v1/projects/$projectId/novels/crawl-schedules',
  );
  final body = <String, dynamic>{
    'urls': urls,
    'intake_status': intakeStatus,
    'intake_note': intakeNote,
    'run_at_ms': runAtMs,
    'repeat_interval_ms': repeatIntervalMs,
    'project_numeric_id': projectNumericId,
  };
  final res = await http
      .post(
        uri,
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(body),
      )
      .timeout(const Duration(seconds: 20));
  if (res.statusCode == 404) {
    throw RustApiException('not found', statusCode: 404);
  }
  if (res.statusCode == 400) {
    throw RustApiException.fromHttpResponse(res);
  }
  ensureHttpSuccess(res);
  final map = jsonDecode(res.body) as Map<String, dynamic>;
  return NovelCrawlScheduleRow.fromJson(map);
}

/// `GET /api/v1/projects/{project_id}/novels/crawl-schedules` — see `getProjectNovelCrawlSchedulesByProjectIdV1`.
Future<List<NovelCrawlScheduleRow>> fetchProjectNovelCrawlSchedules(
  String accessToken,
  String projectId,
) async {
  final uri = Uri.parse(
    '$kApiBaseUrl/api/v1/projects/$projectId/novels/crawl-schedules',
  );
  final res = await http
      .get(uri, headers: {'Authorization': 'Bearer $accessToken'})
      .timeout(const Duration(seconds: 20));
  if (res.statusCode == 404) {
    throw RustApiException('not found', statusCode: 404);
  }
  ensureHttpSuccess(res);
  final list = jsonDecode(res.body) as List<dynamic>;
  return list
      .map((e) => NovelCrawlScheduleRow.fromJson(e as Map<String, dynamic>))
      .toList(growable: false);
}

/// `GET /api/v1/projects/{project_id}/novels/crawl-observability` — see `getProjectNovelCrawlObservabilityByProjectIdV1`.
Future<NovelCrawlObservabilityResponse> fetchProjectNovelCrawlObservability(
  String accessToken,
  String projectId,
) async {
  final uri = Uri.parse(
    '$kApiBaseUrl/api/v1/projects/$projectId/novels/crawl-observability',
  );
  final res = await http
      .get(uri, headers: {'Authorization': 'Bearer $accessToken'})
      .timeout(const Duration(seconds: 20));
  if (res.statusCode == 404) {
    throw RustApiException('not found', statusCode: 404);
  }
  ensureHttpSuccess(res);
  final map = jsonDecode(res.body) as Map<String, dynamic>;
  return NovelCrawlObservabilityResponse.fromJson(map);
}
