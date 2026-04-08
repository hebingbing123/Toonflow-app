part of 'index.dart';

/// `GET /api/v1/projects/legacy/{project_legacy_id}/novel-events` — paginated events list with chapter associations.
Future<ListNovelEventsResponse> fetchProjectNovelEventsByLegacyId(
  String accessToken,
  int projectLegacyId, {
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
  var uri = Uri.parse(
    '$kApiBaseUrl/api/v1/projects/legacy/$projectLegacyId/novel-events',
  );
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
    throw RustApiException(res.body, statusCode: 400);
  }
  if (res.statusCode != 200) {
    throw RustApiException(res.body, statusCode: res.statusCode);
  }
  final map = jsonDecode(res.body) as Map<String, dynamic>;
  return ListNovelEventsResponse.fromJson(map);
}

/// `POST /api/v1/projects/legacy/{project_legacy_id}/novel-events` — create a novel event.
Future<Map<String, dynamic>> createProjectNovelEventUnderLegacy(
  String accessToken,
  int projectLegacyId, {
  required String name,
  String? detail,
  List<int>? chapterIds,
}) async {
  final uri = Uri.parse(
    '$kApiBaseUrl/api/v1/projects/legacy/$projectLegacyId/novel-events',
  );
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
    throw RustApiException(res.body, statusCode: 400);
  }
  if (res.statusCode != 200) {
    throw RustApiException(res.body, statusCode: res.statusCode);
  }
  return jsonDecode(res.body) as Map<String, dynamic>;
}

/// `PATCH /api/v1/projects/legacy/{project_legacy_id}/novel-events/{event_legacy_id}` — update a novel event.
Future<String> patchProjectNovelEventByLegacyIds(
  String accessToken,
  int projectLegacyId,
  int eventLegacyId,
  Map<String, dynamic> body,
) async {
  final uri = Uri.parse(
    '$kApiBaseUrl/api/v1/projects/legacy/$projectLegacyId/novel-events/$eventLegacyId',
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
    throw RustApiException(res.body, statusCode: 400);
  }
  if (res.statusCode != 200) {
    throw RustApiException(res.body, statusCode: res.statusCode);
  }
  final map = jsonDecode(res.body) as Map<String, dynamic>;
  return map['message'] as String? ?? '';
}

/// `DELETE /api/v1/projects/legacy/{project_legacy_id}/novel-events/{event_legacy_id}` — delete a novel event.
Future<String> deleteProjectNovelEventByLegacyIds(
  String accessToken,
  int projectLegacyId,
  int eventLegacyId,
) async {
  final uri = Uri.parse(
    '$kApiBaseUrl/api/v1/projects/legacy/$projectLegacyId/novel-events/$eventLegacyId',
  );
  final res = await http
      .delete(uri, headers: {'Authorization': 'Bearer $accessToken'})
      .timeout(const Duration(seconds: 15));
  if (res.statusCode == 404) {
    throw RustApiException('not found', statusCode: 404);
  }
  if (res.statusCode == 400) {
    throw RustApiException(res.body, statusCode: 400);
  }
  if (res.statusCode != 200) {
    throw RustApiException(res.body, statusCode: res.statusCode);
  }
  final map = jsonDecode(res.body) as Map<String, dynamic>;
  return map['message'] as String? ?? '';
}

/// `POST /api/v1/novels/events/get-events` — legacy event list shape.
Future<LegacyNovelEventsPagedResponse> postLegacyNovelEventsGetEvents(
  String accessToken,
  int projectId, {
  required int page,
  required int limit,
  String? search,
}) async {
  final uri = Uri.parse('$kApiBaseUrl/api/v1/novels/events/get-events');
  final body = <String, dynamic>{
    'projectId': projectId,
    'page': page,
    'limit': limit,
  };
  if (search != null && search.isNotEmpty) {
    body['search'] = search;
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
  if (res.statusCode == 400) {
    throw RustApiException(res.body, statusCode: 400);
  }
  if (res.statusCode != 200) {
    throw RustApiException(res.body, statusCode: res.statusCode);
  }
  final map = jsonDecode(res.body) as Map<String, dynamic>;
  return LegacyNovelEventsPagedResponse.fromJson(map);
}

/// `POST /api/v1/novels/events/batch-delete` — legacy batch delete by event legacy ids.
Future<String> postLegacyNovelEventsBatchDelete(
  String accessToken,
  List<int> legacyIds,
) async {
  final uri = Uri.parse('$kApiBaseUrl/api/v1/novels/events/batch-delete');
  final res = await http
      .post(
        uri,
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'ids': legacyIds}),
      )
      .timeout(const Duration(seconds: 15));
  if (res.statusCode == 400) {
    throw RustApiException(res.body, statusCode: 400);
  }
  if (res.statusCode == 404) {
    throw RustApiException(res.body, statusCode: 404);
  }
  if (res.statusCode != 200) {
    throw RustApiException(res.body, statusCode: res.statusCode);
  }
  final map = jsonDecode(res.body) as Map<String, dynamic>;
  return map['message'] as String? ?? '';
}
