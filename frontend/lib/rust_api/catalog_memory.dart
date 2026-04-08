part of 'index.dart';

/// `GET /api/v1/usage/summary` — see `usageSummaryV1`.
Future<UsageSummaryResponse> fetchUsageSummary(String accessToken) async {
  final uri = Uri.parse('$kApiBaseUrl/api/v1/usage/summary');
  final res = await http
      .get(uri, headers: {'Authorization': 'Bearer $accessToken'})
      .timeout(const Duration(seconds: 15));
  if (res.statusCode != 200) {
    throw RustApiException(res.body, statusCode: res.statusCode);
  }
  final map = jsonDecode(res.body) as Map<String, dynamic>;
  return UsageSummaryResponse.fromJson(map);
}

/// `GET /api/v1/prompts` — OpenAPI `listPromptsV1`.
Future<List<PromptTemplateRowV1>> fetchPromptsV1(String accessToken) async {
  final uri = Uri.parse('$kApiBaseUrl/api/v1/prompts');
  final res = await http
      .get(uri, headers: {'Authorization': 'Bearer $accessToken'})
      .timeout(const Duration(seconds: 60));
  if (res.statusCode != 200) {
    throw RustApiException(res.body, statusCode: res.statusCode);
  }
  final raw = jsonDecode(res.body) as List<dynamic>;
  return raw
      .map((e) => PromptTemplateRowV1.fromJson(e as Map<String, dynamic>))
      .toList();
}

/// `GET /api/v1/prompts/{legacy_id}` — OpenAPI `getPromptByLegacyIdV1`.
Future<PromptTemplateRowV1> fetchPromptByLegacyIdV1(
  String accessToken,
  int legacyId,
) async {
  final uri = Uri.parse('$kApiBaseUrl/api/v1/prompts/$legacyId');
  final res = await http
      .get(uri, headers: {'Authorization': 'Bearer $accessToken'})
      .timeout(const Duration(seconds: 30));
  if (res.statusCode == 404) {
    throw RustApiException('not found', statusCode: 404);
  }
  if (res.statusCode != 200) {
    throw RustApiException(res.body, statusCode: res.statusCode);
  }
  final map = jsonDecode(res.body) as Map<String, dynamic>;
  return PromptTemplateRowV1.fromJson(map);
}

/// `PATCH /api/v1/prompts/{legacy_id}` — OpenAPI `patchPromptByLegacyIdV1` (**`data`** only).
///
/// **`legacy_id`** must be **1**, **2**, or **3**. Returns the updated row (same shape as GET).
Future<PromptTemplateRowV1> patchPromptByLegacyIdV1(
  String accessToken,
  int legacyId,
  String data,
) async {
  final uri = Uri.parse('$kApiBaseUrl/api/v1/prompts/$legacyId');
  final res = await http
      .patch(
        uri,
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'data': data}),
      )
      .timeout(const Duration(seconds: 30));
  if (res.statusCode == 400 || res.statusCode == 404) {
    throw RustApiException(res.body, statusCode: res.statusCode);
  }
  if (res.statusCode != 200) {
    throw RustApiException(res.body, statusCode: res.statusCode);
  }
  final map = jsonDecode(res.body) as Map<String, dynamic>;
  return PromptTemplateRowV1.fromJson(map);
}

/// `GET /api/v1/visual-manual` — OpenAPI `getVisualManualV1`.
Future<VisualManualResponseV1> fetchVisualManualV1(String accessToken) async {
  final uri = Uri.parse('$kApiBaseUrl/api/v1/visual-manual');
  final res = await http
      .get(uri, headers: {'Authorization': 'Bearer $accessToken'})
      .timeout(const Duration(seconds: 120));
  if (res.statusCode != 200) {
    throw RustApiException(res.body, statusCode: res.statusCode);
  }
  final map = jsonDecode(res.body) as Map<String, dynamic>;
  return VisualManualResponseV1.fromJson(map);
}

/// `POST /api/v1/visual-manual` — OpenAPI `postVisualManualV1` (same JSON as GET; body ignored).
Future<VisualManualResponseV1> fetchVisualManualPostV1(
  String accessToken,
) async {
  final uri = Uri.parse('$kApiBaseUrl/api/v1/visual-manual');
  final res = await http
      .post(
        uri,
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
        body: '{}',
      )
      .timeout(const Duration(seconds: 120));
  if (res.statusCode != 200) {
    throw RustApiException(res.body, statusCode: res.statusCode);
  }
  final map = jsonDecode(res.body) as Map<String, dynamic>;
  return VisualManualResponseV1.fromJson(map);
}

/// Builds `GET /api/v1/skills/binary?path=` — OpenAPI `getSkillBinaryV1` (JWT on the request).
Uri skillsBinaryV1Uri(String pathUnderDataSkills) {
  return Uri.parse(
    '$kApiBaseUrl/api/v1/skills/binary',
  ).replace(queryParameters: {'path': pathUnderDataSkills});
}

/// Fetches raw image (or other allowed) bytes from [`skillsBinaryV1Uri`].
Future<Uint8List> fetchSkillsBinaryV1(
  String accessToken,
  String pathUnderDataSkills,
) async {
  final uri = skillsBinaryV1Uri(pathUnderDataSkills);
  final res = await http
      .get(uri, headers: {'Authorization': 'Bearer $accessToken'})
      .timeout(const Duration(seconds: 120));
  if (res.statusCode != 200) {
    throw RustApiException(
      res.body.isNotEmpty ? res.body : 'binary response ${res.statusCode}',
      statusCode: res.statusCode,
    );
  }
  return res.bodyBytes;
}

