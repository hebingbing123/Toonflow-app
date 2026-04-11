part of 'index.dart';

/// `GET /api/v1/projects/{project_id}/novels` — see `listProjectNovelsByProjectIdV1`.
Future<ListNovelsResponse> fetchProjectNovelsByProjectId(
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
  if (res.statusCode != 200) {
    throw RustApiException(res.body, statusCode: res.statusCode);
  }
  final map = jsonDecode(res.body) as Map<String, dynamic>;
  return ListNovelsResponse.fromJson(map);
}

/// `GET /api/v1/projects/{project_id}/novels/{novel_legacy_id}` — see `getProjectNovelByProjectIdV1`.
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
  if (res.statusCode != 200) {
    throw RustApiException(res.body, statusCode: res.statusCode);
  }
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
  if (res.statusCode != 201) {
    throw RustApiException(res.body, statusCode: res.statusCode);
  }
  final map = jsonDecode(res.body) as Map<String, dynamic>;
  return NovelRow.fromJson(map);
}

/// `PATCH /api/v1/projects/{project_id}/novels/{novel_legacy_id}` — see `patchProjectNovelByProjectIdV1`.
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
    throw RustApiException(res.body, statusCode: 400);
  }
  if (res.statusCode != 200) {
    throw RustApiException(res.body, statusCode: res.statusCode);
  }
  final map = jsonDecode(res.body) as Map<String, dynamic>;
  return NovelRow.fromJson(map);
}

/// `DELETE /api/v1/projects/{project_id}/novels/{novel_legacy_id}` — see `deleteProjectNovelByProjectIdV1`.
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
  if (res.statusCode != 204) {
    throw RustApiException(res.body, statusCode: res.statusCode);
  }
}
