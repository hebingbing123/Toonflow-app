part of 'index.dart';

/// `POST /api/v1/project/query-director-manual` — body `{}`; bundled **`story_skills`** rows.
Future<DirectorManualListResponse> postProjectQueryDirectorManual(
  String accessToken,
) async {
  final uri = Uri.parse('$kApiBaseUrl/api/v1/project/query-director-manual');
  final res = await http
      .post(
        uri,
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({}),
      )
      .timeout(const Duration(seconds: 120));
  if (res.statusCode == 400) {
    throw RustApiException(res.body, statusCode: 400);
  }
  if (res.statusCode != 200) {
    throw RustApiException(res.body, statusCode: res.statusCode);
  }
  final map = jsonDecode(res.body) as Map<String, dynamic>;
  return DirectorManualListResponse.fromJson(map);
}

/// `POST /api/v1/project/add-director-manual`.
Future<void> postProjectAddDirectorManual(
  String accessToken, {
  required String name,
  required String directorManual,
  List<String> images = const [],
  required List<DirectorManualDataSlot> data,
}) async {
  final uri = Uri.parse('$kApiBaseUrl/api/v1/project/add-director-manual');
  final body = <String, dynamic>{
    'name': name,
    'directorManual': directorManual,
    'images': images,
    'data': data.map((e) => e.toJson()).toList(),
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
      .timeout(const Duration(seconds: 120));
  if (res.statusCode == 400) {
    throw RustApiException(res.body, statusCode: 400);
  }
  _expectEmptyObjectResponse(res);
}

/// `POST /api/v1/project/edit-director-manual`.
Future<void> postProjectEditDirectorManual(
  String accessToken, {
  required String name,
  required String directorManual,
  List<String> images = const [],
  required List<DirectorManualDataSlot> data,
}) async {
  final uri = Uri.parse('$kApiBaseUrl/api/v1/project/edit-director-manual');
  final body = <String, dynamic>{
    'name': name,
    'directorManual': directorManual,
    'images': images,
    'data': data.map((e) => e.toJson()).toList(),
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
      .timeout(const Duration(seconds: 120));
  if (res.statusCode == 400) {
    throw RustApiException(res.body, statusCode: 400);
  }
  _expectEmptyObjectResponse(res);
}

/// `POST /api/v1/project/delete-director-manual` — [folderName] is folder under **`story_skills`**.
Future<String> postProjectDeleteDirectorManual(
  String accessToken,
  String folderName,
) async {
  final uri = Uri.parse('$kApiBaseUrl/api/v1/project/delete-director-manual');
  final res = await http
      .post(
        uri,
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'name': folderName}),
      )
      .timeout(const Duration(seconds: 60));
  if (res.statusCode == 400) {
    throw RustApiException(res.body, statusCode: 400);
  }
  if (res.statusCode != 200) {
    throw RustApiException(res.body, statusCode: res.statusCode);
  }
  final map = jsonDecode(res.body) as Map<String, dynamic>;
  return map['message'] as String? ?? '';
}
