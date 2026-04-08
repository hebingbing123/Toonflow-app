part of 'index.dart';

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
