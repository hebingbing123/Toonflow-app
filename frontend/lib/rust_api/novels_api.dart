part of 'index.dart';

class NovelRow {
  NovelRow({
    required this.id,
    required this.legacyId,
    required this.chapterIndex,
    this.reel,
    required this.chapter,
    required this.chapterData,
    this.event,
    required this.eventState,
    this.errorReason,
    this.createTimeMs,
  });

  final String id;
  final int legacyId;
  final int chapterIndex;
  final String? reel;
  final String chapter;
  final String chapterData;
  final String? event;
  final int eventState;
  final String? errorReason;
  final int? createTimeMs;

  factory NovelRow.fromJson(Map<String, dynamic> json) {
    return NovelRow(
      id: json['id'] as String,
      legacyId: (json['legacy_id'] as num).toInt(),
      chapterIndex: (json['chapter_index'] as num).toInt(),
      reel: json['reel'] as String?,
      chapter: json['chapter'] as String? ?? '',
      chapterData: json['chapter_data'] as String? ?? '',
      event: json['event'] as String?,
      eventState: (json['event_state'] as num).toInt(),
      errorReason: json['error_reason'] as String?,
      createTimeMs: json['create_time_ms'] == null
          ? null
          : (json['create_time_ms'] as num).toInt(),
    );
  }
}

/// Body of **`GET …/novels`** — OpenAPI **`ListNovelsResponse`**.
class ListNovelsResponse {
  const ListNovelsResponse({required this.items, required this.total});

  final List<NovelRow> items;
  final int total;

  factory ListNovelsResponse.fromJson(Map<String, dynamic> json) {
    final raw = json['items'] as List<dynamic>;
    return ListNovelsResponse(
      items: raw
          .map((e) => NovelRow.fromJson(e as Map<String, dynamic>))
          .toList(),
      total: (json['total'] as num).toInt(),
    );
  }
}

/// Row from **`POST /api/v1/novels/get-novel-index`** — **`id`** is **`app_novel.legacy_id`**.
class LegacyNovelIndexItem {
  const LegacyNovelIndexItem({
    required this.legacyId,
    required this.chapterIndex,
    required this.chapter,
  });

  final int legacyId;
  final int chapterIndex;
  final String chapter;

  factory LegacyNovelIndexItem.fromJson(Map<String, dynamic> json) {
    return LegacyNovelIndexItem(
      legacyId: (json['id'] as num).toInt(),
      chapterIndex: (json['index'] as num).toInt(),
      chapter: json['chapter'] as String? ?? '',
    );
  }
}

/// Row from **`POST /api/v1/novels/get-novel`** — response uses **camelCase** (**`chapterData`**, …).
class LegacyNovelPageRow {
  const LegacyNovelPageRow({
    required this.legacyId,
    required this.chapterIndex,
    this.reel,
    required this.chapter,
    required this.chapterData,
    this.event,
    required this.eventState,
    this.errorReason,
  });

  final int legacyId;
  final int chapterIndex;
  final String? reel;
  final String chapter;
  final String chapterData;
  final String? event;
  final int eventState;
  final String? errorReason;

  factory LegacyNovelPageRow.fromJson(Map<String, dynamic> json) {
    return LegacyNovelPageRow(
      legacyId: (json['id'] as num).toInt(),
      chapterIndex: (json['index'] as num).toInt(),
      reel: json['reel'] as String?,
      chapter: json['chapter'] as String? ?? '',
      chapterData: json['chapterData'] as String? ?? '',
      event: json['event'] as String?,
      eventState: (json['eventState'] as num).toInt(),
      errorReason: json['errorReason'] as String?,
    );
  }
}

/// **`POST /api/v1/novels/get-novel`** — **`{ data, total }`**.
class LegacyNovelPagedResponse {
  const LegacyNovelPagedResponse({required this.data, required this.total});

  final List<LegacyNovelPageRow> data;
  final int total;

  factory LegacyNovelPagedResponse.fromJson(Map<String, dynamic> json) {
    final raw = json['data'] as List<dynamic>;
    return LegacyNovelPagedResponse(
      data: raw
          .map((e) => LegacyNovelPageRow.fromJson(e as Map<String, dynamic>))
          .toList(),
      total: (json['total'] as num).toInt(),
    );
  }
}

/// One entry for **`POST /api/v1/novels/add-novel`** **`data`** (camelCase **`chapterData`**).
class LegacyNovelAddItem {
  const LegacyNovelAddItem({
    required this.index,
    required this.reel,
    required this.chapter,
    required this.chapterData,
  });

  final int index;
  final String reel;
  final String chapter;
  final String chapterData;

  Map<String, dynamic> toJson() => {
    'index': index,
    'reel': reel,
    'chapter': chapter,
    'chapterData': chapterData,
  };
}

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
