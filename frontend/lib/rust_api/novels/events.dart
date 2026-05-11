import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../config.dart';
import '../core.dart';
import 'events_models.dart';
import 'project_scope.dart';

/// `GET /api/v1/projects/{project_id}/novel-events` — paginated events list with chapter associations.
Future<ListNovelEventsResponse> fetchProjectNovelEventsByProjectId(
  String accessToken,
  String projectId, {
  String? search,
  int? page,
  int? limit,
}) async {
  final qp = <String, String>{};
  if (search != null && search.isNotEmpty) {
    qp['search'] = search;
  }
  if (page != null) {
    qp['page'] = '$page';
  }
  if (limit != null) {
    qp['limit'] = '$limit';
  }
  var uri = Uri.parse('$kApiBaseUrl/api/v1/projects/$projectId/novel-events');
  if (qp.isNotEmpty) {
    uri = uri.replace(queryParameters: qp);
  }
  final res = await http
      .get(uri, headers: {'Authorization': 'Bearer $accessToken'})
      .timeout(const Duration(seconds: 15));
  if (res.statusCode == 404) {
    throw RustApiException('not found', statusCode: 404);
  }
  if (res.statusCode == 400) {
    throw RustApiException.fromHttpResponse(res);
  }
  ensureHttpSuccess(res);
  final map = jsonDecode(res.body) as Map<String, dynamic>;
  return ListNovelEventsResponse.fromJson(map);
}

/// `POST /api/v1/projects/{project_id}/novel-events` — create under project UUID.
Future<Map<String, dynamic>> createProjectNovelEventUnderProject(
  String accessToken,
  String projectId, {
  required String name,
  String? detail,
  List<int>? chapterIds,
}) async {
  final uri = Uri.parse('$kApiBaseUrl/api/v1/projects/$projectId/novel-events');
  final body = <String, dynamic>{'name': name};
  if (detail != null) {
    body['detail'] = detail;
  }
  if (chapterIds != null) {
    body['chapterIds'] = chapterIds;
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
  ensureHttpSuccess(res);
  return jsonDecode(res.body) as Map<String, dynamic>;
}

/// `PATCH /api/v1/projects/{project_id}/novel-events/{event_numeric_id}`.
Future<String> patchProjectNovelEventByProjectIds(
  String accessToken,
  String projectId,
  int eventNumericId,
  Map<String, dynamic> body,
) async {
  final uri = Uri.parse(
    '$kApiBaseUrl/api/v1/projects/$projectId/novel-events/$eventNumericId',
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
  return map['message'] as String? ?? '';
}

/// `DELETE /api/v1/projects/{project_id}/novel-events/{event_numeric_id}`.
Future<String> deleteProjectNovelEventByProjectIds(
  String accessToken,
  String projectId,
  int eventNumericId,
) async {
  final uri = Uri.parse(
    '$kApiBaseUrl/api/v1/projects/$projectId/novel-events/$eventNumericId',
  );
  final res = await http
      .delete(uri, headers: {'Authorization': 'Bearer $accessToken'})
      .timeout(const Duration(seconds: 15));
  if (res.statusCode == 404) {
    throw RustApiException('not found', statusCode: 404);
  }
  if (res.statusCode == 400) {
    throw RustApiException.fromHttpResponse(res);
  }
  ensureHttpSuccess(res);
  final map = jsonDecode(res.body) as Map<String, dynamic>;
  return map['message'] as String? ?? '';
}

/// `POST /api/v1/projects/{project_id}/novel-events/batch-delete` — scoped batch delete by event numeric ids.
Future<String> postProjectNovelEventsBatchDeleteByProjectId(
  String accessToken,
  String projectId,
  List<int> numericIds,
) async {
  final uri = Uri.parse(
    '$kApiBaseUrl/api/v1/projects/$projectId/novel-events/batch-delete',
  );
  final res = await http
      .post(
        uri,
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'ids': numericIds}),
      )
      .timeout(const Duration(seconds: 15));
  if (res.statusCode == 400) {
    throw RustApiException.fromHttpResponse(res);
  }
  if (res.statusCode == 404) {
    throw RustApiException.fromHttpResponse(res);
  }
  ensureHttpSuccess(res);
  final map = jsonDecode(res.body) as Map<String, dynamic>;
  return map['message'] as String? ?? '';
}

/// Compat: maps **`GET …/projects/{uuid}/novel-events`** to workbench **`{ list, total }`**.
Future<NovelEventsPageResponse> fetchNovelEventsPaged(
  String accessToken,
  int projectNumericId, {
  String? projectUuid,
  required int page,
  required int limit,
  String? search,
}) async {
  final resolvedProjectUuid = await resolveNovelProjectUuid(
    accessToken,
    projectUuid: projectUuid,
    projectNumericId: projectNumericId,
  );
  final rows = await fetchProjectNovelEventsByProjectId(
    accessToken,
    resolvedProjectUuid,
    search: search,
    page: page,
    limit: limit,
  );
  final list = rows.items
      .map(
        (e) => NovelEventPageRow(
          numericId: e.numericId,
          eventName: e.name,
          detail: e.detail.isEmpty ? null : e.detail,
          createTime: e.createTimeMs ?? 0,
          chapters: e.chapterIndexes,
        ),
      )
      .toList();
  return NovelEventsPageResponse(list: list, total: rows.total);
}

/// Compat: **`POST …/projects/{uuid}/novel-events/batch-delete`** by event numeric ids.
Future<String> batchDeleteNovelEvents(
  String accessToken,
  int projectNumericId,
  List<int> numericIds, {
  String? projectUuid,
}
) async {
  final resolvedProjectUuid = await resolveNovelProjectUuid(
    accessToken,
    projectUuid: projectUuid,
    projectNumericId: projectNumericId,
  );
  return postProjectNovelEventsBatchDeleteByProjectId(
    accessToken,
    resolvedProjectUuid,
    numericIds,
  );
}
