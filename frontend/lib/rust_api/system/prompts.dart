part of '../index.dart';

/// Prompt template listing and mutation endpoints.
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

/// `GET /api/v1/prompts/{id}` — OpenAPI `getPromptByNumericIdV1`.
Future<PromptTemplateRowV1> fetchPromptByNumericIdV1(
  String accessToken,
  int numericId,
) async {
  final uri = Uri.parse('$kApiBaseUrl/api/v1/prompts/$numericId');
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

/// `PATCH /api/v1/prompts/{id}` — OpenAPI `patchPromptByNumericIdV1` (**`data`** only).
///
/// **`id`** must be **1**, **2**, or **3** (built-in template slots). Returns the updated row (same shape as GET).
Future<PromptTemplateRowV1> patchPromptByNumericIdV1(
  String accessToken,
  int numericId,
  String data,
) async {
  final uri = Uri.parse('$kApiBaseUrl/api/v1/prompts/$numericId');
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
