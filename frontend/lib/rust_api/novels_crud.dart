part of 'index.dart';

/// `GET /api/v1/projects/legacy/{project_legacy_id}/novels` — see `listProjectNovelsByLegacyV1`.
Future<ListNovelsResponse> fetchProjectNovelsByLegacyId(
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
    '$kApiBaseUrl/api/v1/projects/legacy/$projectLegacyId/novels',
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
  if (res.statusCode != 200) {
    throw RustApiException(res.body, statusCode: res.statusCode);
  }
  final map = jsonDecode(res.body) as Map<String, dynamic>;
  return ListNovelsResponse.fromJson(map);
}

/// `GET /api/v1/projects/legacy/{project_legacy_id}/novels/{novel_legacy_id}` — see `getProjectNovelByLegacyIdsV1`.
Future<NovelRow> fetchProjectNovelByLegacyIds(
  String accessToken,
  int projectLegacyId,
  int novelLegacyId,
) async {
  final uri = Uri.parse(
    '$kApiBaseUrl/api/v1/projects/legacy/$projectLegacyId/novels/$novelLegacyId',
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

/// `POST /api/v1/projects/legacy/{project_legacy_id}/novels` — see `createProjectNovelByLegacyV1`.
Future<NovelRow> createProjectNovelUnderLegacy(
  String accessToken,
  int projectLegacyId, {
  int? chapterIndex,
  String? reel,
  String? chapter,
  String? chapterData,
}) async {
  final uri = Uri.parse(
    '$kApiBaseUrl/api/v1/projects/legacy/$projectLegacyId/novels',
  );
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

/// `PATCH /api/v1/projects/legacy/{project_legacy_id}/novels/{novel_legacy_id}` — see `patchProjectNovelByLegacyIdsV1`.
Future<NovelRow> patchProjectNovelByLegacyIds(
  String accessToken,
  int projectLegacyId,
  int novelLegacyId,
  Map<String, dynamic> body,
) async {
  final uri = Uri.parse(
    '$kApiBaseUrl/api/v1/projects/legacy/$projectLegacyId/novels/$novelLegacyId',
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

/// `DELETE /api/v1/projects/legacy/{project_legacy_id}/novels/{novel_legacy_id}` — see `deleteProjectNovelByLegacyIdsV1`.
Future<void> deleteProjectNovelByLegacyIds(
  String accessToken,
  int projectLegacyId,
  int novelLegacyId,
) async {
  final uri = Uri.parse(
    '$kApiBaseUrl/api/v1/projects/legacy/$projectLegacyId/novels/$novelLegacyId',
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

/// `POST /api/v1/novels/get-novel-data` — full **`NovelRow`** list (legacy Electron **`getNovelData`**).
Future<List<NovelRow>> postLegacyNovelsGetNovelData(
  String accessToken,
  int projectId,
) async {
  final uri = Uri.parse('$kApiBaseUrl/api/v1/novels/get-novel-data');
  final res = await http
      .post(
        uri,
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'projectId': projectId}),
      )
      .timeout(const Duration(seconds: 15));
  if (res.statusCode == 400) {
    throw RustApiException(res.body, statusCode: 400);
  }
  if (res.statusCode != 200) {
    throw RustApiException(res.body, statusCode: res.statusCode);
  }
  final map = jsonDecode(res.body) as Map<String, dynamic>;
  final raw = map['data'] as List<dynamic>;
  return raw.map((e) => NovelRow.fromJson(e as Map<String, dynamic>)).toList();
}

/// `POST /api/v1/novels/get-novel-index` — **`{ id, index, chapter }`** per row (**`getNovelIndex`**).
Future<List<LegacyNovelIndexItem>> postLegacyNovelsGetNovelIndex(
  String accessToken,
  int projectId,
) async {
  final uri = Uri.parse('$kApiBaseUrl/api/v1/novels/get-novel-index');
  final res = await http
      .post(
        uri,
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'projectId': projectId}),
      )
      .timeout(const Duration(seconds: 15));
  if (res.statusCode == 400) {
    throw RustApiException(res.body, statusCode: 400);
  }
  if (res.statusCode != 200) {
    throw RustApiException(res.body, statusCode: res.statusCode);
  }
  final map = jsonDecode(res.body) as Map<String, dynamic>;
  final raw = map['data'] as List<dynamic>;
  return raw
      .map((e) => LegacyNovelIndexItem.fromJson(e as Map<String, dynamic>))
      .toList();
}

/// `POST /api/v1/novels/get-novel` — paginated list + **`total`** (**`getNovel`**).
Future<LegacyNovelPagedResponse> postLegacyNovelsGetNovel(
  String accessToken,
  int projectId, {
  required int page,
  required int limit,
  String? search,
}) async {
  final uri = Uri.parse('$kApiBaseUrl/api/v1/novels/get-novel');
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
  return LegacyNovelPagedResponse.fromJson(map);
}

/// `POST /api/v1/novels/add-novel` — returns Chinese **`message`** (empty **`data`** is OK without DB).
Future<String> postLegacyNovelsAddNovel(
  String accessToken,
  int projectId,
  List<LegacyNovelAddItem> data,
) async {
  final uri = Uri.parse('$kApiBaseUrl/api/v1/novels/add-novel');
  final res = await http
      .post(
        uri,
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'projectId': projectId,
          'data': data.map((e) => e.toJson()).toList(),
        }),
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

/// `POST /api/v1/novels/delete-novel` — body **`{ "id": legacy_id }`**.
Future<String> postLegacyNovelsDeleteNovel(
  String accessToken,
  int novelLegacyId,
) async {
  final uri = Uri.parse('$kApiBaseUrl/api/v1/novels/delete-novel');
  final res = await http
      .post(
        uri,
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'id': novelLegacyId}),
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

/// `POST /api/v1/novels/update-novel` — **`index`** may be int or numeric string.
Future<String> postLegacyNovelsUpdateNovel(
  String accessToken, {
  required int id,
  required Object index,
  required String reel,
  required String chapter,
  required String chapterData,
  required String event,
}) async {
  final uri = Uri.parse('$kApiBaseUrl/api/v1/novels/update-novel');
  final res = await http
      .post(
        uri,
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'id': id,
          'index': index,
          'reel': reel,
          'chapter': chapter,
          'chapterData': chapterData,
          'event': event,
        }),
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

/// `POST /api/v1/novels/batch-delete` — **`ids`** = **`app_novel.legacy_id`** (max **500**; empty → **400**).
Future<String> postLegacyNovelsBatchDelete(
  String accessToken,
  List<int> legacyIds,
) async {
  final uri = Uri.parse('$kApiBaseUrl/api/v1/novels/batch-delete');
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
