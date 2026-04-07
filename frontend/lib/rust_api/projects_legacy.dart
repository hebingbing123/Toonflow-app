part of 'index.dart';

/// `GET /api/v1/projects` — projects owned by the JWT subject. See `listProjectsV1`.
Future<List<ProjectRow>> fetchProjects(String accessToken) async {
  final uri = Uri.parse('$kApiBaseUrl/api/v1/projects');
  final res = await http
      .get(uri, headers: {'Authorization': 'Bearer $accessToken'})
      .timeout(const Duration(seconds: 15));
  if (res.statusCode != 200) {
    throw RustApiException(res.body, statusCode: res.statusCode);
  }
  final list = jsonDecode(res.body) as List<dynamic>;
  return list
      .map((e) => ProjectRow.fromJson(e as Map<String, dynamic>))
      .toList();
}

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

/// OpenAPI **`LegacyDirectorManualDataSlot`** (also used for visual manual POST bodies).
class LegacyDirectorManualDataSlot {
  const LegacyDirectorManualDataSlot({
    required this.label,
    required this.value,
    required this.data,
  });

  final String label;
  final String value;
  final String data;

  Map<String, dynamic> toJson() => {
    'label': label,
    'value': value,
    'data': data,
  };

  factory LegacyDirectorManualDataSlot.fromJson(Map<String, dynamic> json) {
    return LegacyDirectorManualDataSlot(
      label: json['label'] as String,
      value: json['value'] as String,
      data: json['data'] as String,
    );
  }
}

/// OpenAPI **`LegacyDirectorManualStyleRow`** (`directorManual` = folder under `story_skills`).
class LegacyDirectorManualStyleRow {
  const LegacyDirectorManualStyleRow({
    required this.name,
    required this.image,
    required this.directorManual,
    required this.data,
  });

  final String name;
  final List<String> image;
  final String directorManual;
  final List<LegacyDirectorManualDataSlot> data;

  factory LegacyDirectorManualStyleRow.fromJson(Map<String, dynamic> json) {
    final imgs = json['image'] as List<dynamic>? ?? const [];
    final slots = json['data'] as List<dynamic>? ?? const [];
    return LegacyDirectorManualStyleRow(
      name: json['name'] as String,
      image: imgs.map((e) => e as String).toList(),
      directorManual: json['directorManual'] as String,
      data: slots
          .map(
            (e) => LegacyDirectorManualDataSlot.fromJson(
              e as Map<String, dynamic>,
            ),
          )
          .toList(),
    );
  }
}

/// OpenAPI **`LegacyDirectorManualListResponse`**.
class LegacyDirectorManualListResponse {
  const LegacyDirectorManualListResponse({required this.data});

  final List<LegacyDirectorManualStyleRow> data;

  factory LegacyDirectorManualListResponse.fromJson(Map<String, dynamic> json) {
    final raw = json['data'] as List<dynamic>? ?? const [];
    return LegacyDirectorManualListResponse(
      data: raw
          .map(
            (e) => LegacyDirectorManualStyleRow.fromJson(
              e as Map<String, dynamic>,
            ),
          )
          .toList(),
    );
  }
}

void _expectLegacyEmptyObjectResponse(http.Response res) {
  if (res.statusCode != 200) {
    throw RustApiException(res.body, statusCode: res.statusCode);
  }
  final decoded = jsonDecode(res.body);
  if (decoded is! Map<String, dynamic>) {
    throw RustApiException('expected JSON object', statusCode: res.statusCode);
  }
  if (decoded.isNotEmpty) {
    throw RustApiException(
      'expected empty object {{}}, got $decoded',
      statusCode: res.statusCode,
    );
  }
}

/// `POST /api/v1/project/query-director-manual` — body `{}`; bundled **`story_skills`** rows.
Future<LegacyDirectorManualListResponse> postProjectQueryDirectorManual(
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
  return LegacyDirectorManualListResponse.fromJson(map);
}

/// `POST /api/v1/project/add-director-manual`.
Future<void> postProjectAddDirectorManual(
  String accessToken, {
  required String name,
  required String directorManual,
  List<String> images = const [],
  required List<LegacyDirectorManualDataSlot> data,
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
  _expectLegacyEmptyObjectResponse(res);
}

/// `POST /api/v1/project/edit-director-manual`.
Future<void> postProjectEditDirectorManual(
  String accessToken, {
  required String name,
  required String directorManual,
  List<String> images = const [],
  required List<LegacyDirectorManualDataSlot> data,
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
  _expectLegacyEmptyObjectResponse(res);
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

/// `POST /api/v1/project/add-visual-manual`.
Future<void> postProjectAddVisualManual(
  String accessToken, {
  required String name,
  required String stylePath,
  List<String> images = const [],
  required List<LegacyDirectorManualDataSlot> data,
}) async {
  final uri = Uri.parse('$kApiBaseUrl/api/v1/project/add-visual-manual');
  final body = <String, dynamic>{
    'name': name,
    'stylePath': stylePath,
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
  _expectLegacyEmptyObjectResponse(res);
}

/// `POST /api/v1/project/edit-visual-manual`.
Future<void> postProjectEditVisualManual(
  String accessToken, {
  required String name,
  required String stylePath,
  List<String> images = const [],
  required List<LegacyDirectorManualDataSlot> data,
}) async {
  final uri = Uri.parse('$kApiBaseUrl/api/v1/project/edit-visual-manual');
  final body = <String, dynamic>{
    'name': name,
    'stylePath': stylePath,
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
  _expectLegacyEmptyObjectResponse(res);
}

/// `POST /api/v1/project/delete-visual-manual` — [folderName] is folder under **`art_skills`**.
Future<String> postProjectDeleteVisualManual(
  String accessToken,
  String folderName,
) async {
  final uri = Uri.parse('$kApiBaseUrl/api/v1/project/delete-visual-manual');
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

class ProjectsSummary {
  const ProjectsSummary({
    required this.projectCount,
    required this.scriptCount,
    required this.storyboardCount,
    required this.novelCount,
    required this.roleCount,
    required this.artStyleCount,
    required this.assetCount,
    required this.videoCount,
  });

  final int projectCount;
  final int scriptCount;
  final int storyboardCount;
  final int novelCount;
  final int roleCount;
  final int artStyleCount;
  final int assetCount;
  final int videoCount;

  factory ProjectsSummary.fromJson(Map<String, dynamic> json) {
    int n(String k) => (json[k] as num).toInt();
    return ProjectsSummary(
      projectCount: n('project_count'),
      scriptCount: n('script_count'),
      storyboardCount: n('storyboard_count'),
      novelCount: json['novel_count'] != null
          ? (json['novel_count'] as num).toInt()
          : 0,
      roleCount: json['role_count'] != null
          ? (json['role_count'] as num).toInt()
          : 0,
      artStyleCount: json['art_style_count'] != null
          ? (json['art_style_count'] as num).toInt()
          : 0,
      assetCount: json['asset_count'] != null
          ? (json['asset_count'] as num).toInt()
          : 0,
      videoCount: json['video_count'] != null
          ? (json['video_count'] as num).toInt()
          : 0,
    );
  }
}

/// `GET /api/v1/projects/summary` — totals for the caller. See `getProjectsSummaryV1`.
Future<ProjectsSummary> fetchProjectsSummary(String accessToken) async {
  final uri = Uri.parse('$kApiBaseUrl/api/v1/projects/summary');
  final res = await http
      .get(uri, headers: {'Authorization': 'Bearer $accessToken'})
      .timeout(const Duration(seconds: 15));
  if (res.statusCode != 200) {
    throw RustApiException(res.body, statusCode: res.statusCode);
  }
  final map = jsonDecode(res.body) as Map<String, dynamic>;
  return ProjectsSummary.fromJson(map);
}

/// `GET /api/v1/art-styles` — see `listArtStylesV1`.
Future<ListArtStylesResponse> fetchArtStyles(String accessToken) async {
  final uri = Uri.parse('$kApiBaseUrl/api/v1/art-styles');
  final res = await http
      .get(uri, headers: {'Authorization': 'Bearer $accessToken'})
      .timeout(const Duration(seconds: 15));
  if (res.statusCode != 200) {
    throw RustApiException(res.body, statusCode: res.statusCode);
  }
  final map = jsonDecode(res.body) as Map<String, dynamic>;
  return ListArtStylesResponse.fromJson(map);
}

/// `POST /api/v1/art-styles` — OpenAPI `createArtStyleV1` (**201** + row).
Future<ArtStyleRow> createArtStyle(
  String accessToken, {
  required String name,
  String? fileUrl,
  String? label,
  String? prompt,
}) async {
  final uri = Uri.parse('$kApiBaseUrl/api/v1/art-styles');
  final body = <String, dynamic>{'name': name};
  if (fileUrl != null) body['file_url'] = fileUrl;
  if (label != null) body['label'] = label;
  if (prompt != null) body['prompt'] = prompt;
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
  if (res.statusCode == 400) {
    throw RustApiException(res.body, statusCode: 400);
  }
  if (res.statusCode != 201) {
    throw RustApiException(res.body, statusCode: res.statusCode);
  }
  final map = jsonDecode(res.body) as Map<String, dynamic>;
  return ArtStyleRow.fromJson(map);
}

/// `GET /api/v1/art-styles/legacy/{legacy_id}` — OpenAPI `getArtStyleByLegacyIdV1`.
Future<ArtStyleRow> fetchArtStyleByLegacyId(
  String accessToken, {
  required int legacyId,
}) async {
  final uri = Uri.parse('$kApiBaseUrl/api/v1/art-styles/legacy/$legacyId');
  final res = await http
      .get(uri, headers: {'Authorization': 'Bearer $accessToken'})
      .timeout(const Duration(seconds: 15));
  if (res.statusCode == 404) {
    throw RustApiException(res.body, statusCode: 404);
  }
  if (res.statusCode != 200) {
    throw RustApiException(res.body, statusCode: res.statusCode);
  }
  final map = jsonDecode(res.body) as Map<String, dynamic>;
  return ArtStyleRow.fromJson(map);
}

/// `PATCH /api/v1/art-styles/legacy/{legacy_id}` — OpenAPI `patchArtStyleByLegacyIdV1`.
///
/// [body] uses **snake_case** keys only: **`name`**, **`file_url`**, **`label`**, **`prompt`**.
/// At least one key is required; use JSON **`null`** or empty string for optional fields to clear them.
Future<ArtStyleRow> patchArtStyleByLegacyId(
  String accessToken,
  int legacyId,
  Map<String, dynamic> body,
) async {
  if (body.isEmpty) {
    throw ArgumentError('patch body must include at least one allowed field');
  }
  final uri = Uri.parse('$kApiBaseUrl/api/v1/art-styles/legacy/$legacyId');
  final res = await http
      .patch(
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
  return ArtStyleRow.fromJson(map);
}

/// `DELETE /api/v1/art-styles/legacy/{legacy_id}` — OpenAPI `deleteArtStyleByLegacyIdV1` (**204**).
Future<void> deleteArtStyleByLegacyId(String accessToken, int legacyId) async {
  final uri = Uri.parse('$kApiBaseUrl/api/v1/art-styles/legacy/$legacyId');
  final res = await http
      .delete(uri, headers: {'Authorization': 'Bearer $accessToken'})
      .timeout(const Duration(seconds: 15));
  if (res.statusCode == 404) {
    throw RustApiException(res.body, statusCode: 404);
  }
  if (res.statusCode != 204) {
    throw RustApiException(res.body, statusCode: res.statusCode);
  }
}

/// `POST /api/v1/art-styles/extract-prompt` — vision LLM; see `extractArtStylePromptV1`.
///
/// [images] are passed through as OpenAPI **`image_url.url`** strings (HTTPS or data URI).
Future<ExtractArtStylePromptResponse> extractArtStylePrompt(
  String accessToken,
  List<String> images,
) async {
  final uri = Uri.parse('$kApiBaseUrl/api/v1/art-styles/extract-prompt');
  final res = await http
      .post(
        uri,
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(<String, dynamic>{'images': images}),
      )
      .timeout(const Duration(seconds: 120));
  if (res.statusCode == 400) {
    throw RustApiException(res.body, statusCode: 400);
  }
  if (res.statusCode != 200) {
    throw RustApiException(res.body, statusCode: res.statusCode);
  }
  final map = jsonDecode(res.body) as Map<String, dynamic>;
  return ExtractArtStylePromptResponse.fromJson(map);
}

/// `POST /api/v1/projects` — optional snake_case fields; see `createProjectV1`.
Future<ProjectRow> createProject(
  String accessToken, {
  Map<String, dynamic>? fields,
}) async {
  final uri = Uri.parse('$kApiBaseUrl/api/v1/projects');
  final res = await http
      .post(
        uri,
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(fields ?? <String, dynamic>{}),
      )
      .timeout(const Duration(seconds: 15));
  if (res.statusCode == 400) {
    throw RustApiException(res.body, statusCode: 400);
  }
  if (res.statusCode != 201) {
    throw RustApiException(res.body, statusCode: res.statusCode);
  }
  final map = jsonDecode(res.body) as Map<String, dynamic>;
  return ProjectRow.fromJson(map);
}

/// `PATCH /api/v1/projects/legacy/{legacy_id}` — merge patch for `name` / `intro` only.
///
/// [body] must only include keys allowed by OpenAPI `PatchProjectBody` (unknown keys → HTTP 400).
/// See `patchProjectByLegacyIdV1`.
Future<ProjectRow> updateProjectByLegacyId(
  String accessToken,
  int legacyId,
  Map<String, dynamic> body,
) async {
  final uri = Uri.parse('$kApiBaseUrl/api/v1/projects/legacy/$legacyId');
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
  return ProjectRow.fromJson(map);
}

/// `DELETE /api/v1/projects/legacy/{legacy_id}` — see `deleteProjectByLegacyIdV1`.
Future<void> deleteProjectByLegacyId(String accessToken, int legacyId) async {
  final uri = Uri.parse('$kApiBaseUrl/api/v1/projects/legacy/$legacyId');
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
