part of 'index.dart';

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

/// `POST /api/v1/novels/get-novel-event-state` — rows where legacy **`eventState != 0`**.
Future<List<LegacyNovelEventStateItem>> postLegacyNovelsGetNovelEventState(
  String accessToken,
  List<int> legacyIds,
) async {
  final uri = Uri.parse('$kApiBaseUrl/api/v1/novels/get-novel-event-state');
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
  if (res.statusCode != 200) {
    throw RustApiException(res.body, statusCode: res.statusCode);
  }
  final map = jsonDecode(res.body) as Map<String, dynamic>;
  final raw = map['data'] as List<dynamic>;
  return raw
      .map((e) => LegacyNovelEventStateItem.fromJson(e as Map<String, dynamic>))
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
