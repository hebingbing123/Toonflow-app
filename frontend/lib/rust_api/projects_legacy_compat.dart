part of 'index.dart';

/// `POST /api/v1/general/get-single-project` — legacy **`getSingleProject`**; **`id`** = **`app_project.legacy_id`**.
Future<List<ProjectRow>> postGeneralGetSingleProject(
  String accessToken,
  int legacyId,
) async {
  final uri = Uri.parse('$kApiBaseUrl/api/v1/general/get-single-project');
  final res = await http
      .post(
        uri,
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'id': legacyId}),
      )
      .timeout(const Duration(seconds: 15));
  if (res.statusCode != 200) {
    throw RustApiException(res.body, statusCode: res.statusCode);
  }
  final map = jsonDecode(res.body) as Map<String, dynamic>;
  final data = map['data'] as List<dynamic>;
  return data
      .map((e) => ProjectRow.fromJson(e as Map<String, dynamic>))
      .toList();
}

/// `POST /api/v1/general/update-project` — legacy **`updateProject`**.
///
/// [body] must include **`id`** (legacy project id) and at least one of **`intro`**,
/// **`type`**, **`artStyle`**, **`videoRatio`**, **`projectType`** (use JSON **`null`** in the map to clear).
Future<String> postGeneralUpdateProject(
  String accessToken,
  Map<String, dynamic> body,
) async {
  final uri = Uri.parse('$kApiBaseUrl/api/v1/general/update-project');
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
  if (res.statusCode == 404) {
    throw RustApiException(res.body, statusCode: 404);
  }
  if (res.statusCode != 200) {
    throw RustApiException(res.body, statusCode: res.statusCode);
  }
  final map = jsonDecode(res.body) as Map<String, dynamic>;
  return map['message'] as String? ?? '';
}

/// `POST /api/v1/project/get-project` — body `{}`; same rows as `GET /api/v1/projects`.
Future<List<ProjectRow>> postProjectGetProject(String accessToken) async {
  final uri = Uri.parse('$kApiBaseUrl/api/v1/project/get-project');
  final res = await http
      .post(
        uri,
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({}),
      )
      .timeout(const Duration(seconds: 20));
  if (res.statusCode != 200) {
    throw RustApiException(res.body, statusCode: res.statusCode);
  }
  final map = jsonDecode(res.body) as Map<String, dynamic>;
  final data = map['data'] as List<dynamic>;
  return data
      .map((e) => ProjectRow.fromJson(e as Map<String, dynamic>))
      .toList();
}

/// `POST /api/v1/project/delete-project` — [legacyId] is `app_project.legacy_id`.
Future<String> postProjectDeleteProject(
  String accessToken,
  int legacyId,
) async {
  final uri = Uri.parse('$kApiBaseUrl/api/v1/project/delete-project');
  final res = await http
      .post(
        uri,
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'id': legacyId}),
      )
      .timeout(const Duration(seconds: 20));
  if (res.statusCode == 400 || res.statusCode == 404) {
    throw RustApiException(res.body, statusCode: res.statusCode);
  }
  if (res.statusCode != 200) {
    throw RustApiException(res.body, statusCode: res.statusCode);
  }
  final map = jsonDecode(res.body) as Map<String, dynamic>;
  return map['message'] as String? ?? '';
}

/// `POST /api/v1/project/add-project` — all fields required (may be empty strings).
Future<String> postProjectAddProject(
  String accessToken, {
  required String projectType,
  required String name,
  required String intro,
  required String type,
  required String artStyle,
  required String directorManual,
  required String videoRatio,
  required String imageModel,
  required String videoModel,
  required String imageQuality,
  required String mode,
}) async {
  final uri = Uri.parse('$kApiBaseUrl/api/v1/project/add-project');
  final body = <String, dynamic>{
    'projectType': projectType,
    'name': name,
    'intro': intro,
    'type': type,
    'artStyle': artStyle,
    'directorManual': directorManual,
    'videoRatio': videoRatio,
    'imageModel': imageModel,
    'videoModel': videoModel,
    'imageQuality': imageQuality,
    'mode': mode,
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
  if (res.statusCode != 200) {
    throw RustApiException(res.body, statusCode: res.statusCode);
  }
  final map = jsonDecode(res.body) as Map<String, dynamic>;
  return map['message'] as String? ?? '';
}

/// `POST /api/v1/project/edit-project` — [id] is `app_project.legacy_id`.
Future<String> postProjectEditProject(
  String accessToken, {
  required int id,
  required String name,
  required String intro,
  required String type,
  required String artStyle,
  required String directorManual,
  required String videoRatio,
  required String imageModel,
  required String videoModel,
  required String imageQuality,
  required String projectType,
  required String mode,
}) async {
  final uri = Uri.parse('$kApiBaseUrl/api/v1/project/edit-project');
  final body = <String, dynamic>{
    'id': id,
    'name': name,
    'intro': intro,
    'type': type,
    'artStyle': artStyle,
    'directorManual': directorManual,
    'videoRatio': videoRatio,
    'imageModel': imageModel,
    'videoModel': videoModel,
    'imageQuality': imageQuality,
    'projectType': projectType,
    'mode': mode,
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
  if (res.statusCode == 400 || res.statusCode == 404) {
    throw RustApiException(res.body, statusCode: res.statusCode);
  }
  if (res.statusCode != 200) {
    throw RustApiException(res.body, statusCode: res.statusCode);
  }
  final map = jsonDecode(res.body) as Map<String, dynamic>;
  return map['message'] as String? ?? '';
}
