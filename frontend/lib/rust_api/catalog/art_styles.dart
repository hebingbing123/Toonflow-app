import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../../config.dart';
import '../core.dart';

/// Art-style catalog models and CRUD/extraction endpoints.
/// One row from **`GET /api/v1/art-styles`** (`ArtStyleRow` in OpenAPI).
class ArtStyleRow {
  const ArtStyleRow({
    required this.id,
    required this.numericId,
    required this.name,
    this.fileUrl,
    this.label,
    this.prompt,
  });

  final String id;
  final int numericId;
  final String name;
  final String? fileUrl;
  final String? label;
  final String? prompt;

  factory ArtStyleRow.fromJson(Map<String, dynamic> json) {
    return ArtStyleRow(
      id: json['id'] as String,
      numericId: (json['numeric_id'] as num).toInt(),
      name: json['name'] as String,
      fileUrl: json['file_url'] as String?,
      label: json['label'] as String?,
      prompt: json['prompt'] as String?,
    );
  }
}

/// **`GET /api/v1/art-styles`** list envelope.
class ListArtStylesResponse {
  const ListArtStylesResponse({required this.items, required this.total});

  final List<ArtStyleRow> items;
  final int total;

  factory ListArtStylesResponse.fromJson(Map<String, dynamic> json) {
    return ListArtStylesResponse(
      items: (json['items'] as List<dynamic>)
          .map((e) => ArtStyleRow.fromJson(e as Map<String, dynamic>))
          .toList(),
      total: (json['total'] as num).toInt(),
    );
  }
}

/// `POST /api/v1/art-styles/extract-prompt` — OpenAPI `ExtractArtStylePromptResponse`.
class ExtractArtStylePromptResponse {
  const ExtractArtStylePromptResponse({required this.text});

  final String text;

  factory ExtractArtStylePromptResponse.fromJson(Map<String, dynamic> json) {
    return ExtractArtStylePromptResponse(text: json['text'] as String);
  }
}

/// Builds `GET /api/v1/art-styles/numeric/{numeric_id}/cover`.
Uri artStyleCoverV1Uri(int numericId) =>
    Uri.parse('$kApiBaseUrl/api/v1/art-styles/numeric/$numericId/cover');

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

/// `GET /api/v1/art-styles/numeric/{numeric_id}` — OpenAPI `getArtStyleByNumericIdV1`.
Future<ArtStyleRow> fetchArtStyleByNumericId(
  String accessToken, {
  required int numericId,
}) async {
  final uri = Uri.parse('$kApiBaseUrl/api/v1/art-styles/numeric/$numericId');
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

/// `GET /api/v1/art-styles/numeric/{numeric_id}/cover` — JWT-protected local cover bytes.
Future<Uint8List> fetchArtStyleCoverByNumericId(
  String accessToken, {
  required int numericId,
}) async {
  final res = await http
      .get(
        artStyleCoverV1Uri(numericId),
        headers: {'Authorization': 'Bearer $accessToken'},
      )
      .timeout(const Duration(seconds: 20));
  if (res.statusCode == 404) {
    throw RustApiException(res.body, statusCode: 404);
  }
  if (res.statusCode != 200) {
    throw RustApiException(res.body, statusCode: res.statusCode);
  }
  return res.bodyBytes;
}

/// `PATCH /api/v1/art-styles/numeric/{numeric_id}` — OpenAPI `patchArtStyleByNumericIdV1`.
///
/// [body] uses **snake_case** keys only: **`name`**, **`file_url`**, **`label`**, **`prompt`**.
/// At least one key is required; use JSON **`null`** or empty string for optional fields to clear them.
Future<ArtStyleRow> patchArtStyleByNumericId(
  String accessToken,
  int numericId,
  Map<String, dynamic> body,
) async {
  if (body.isEmpty) {
    throw ArgumentError('patch body must include at least one allowed field');
  }
  final uri = Uri.parse('$kApiBaseUrl/api/v1/art-styles/numeric/$numericId');
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

/// `DELETE /api/v1/art-styles/numeric/{numeric_id}` — OpenAPI `deleteArtStyleByNumericIdV1` (**204**).
Future<void> deleteArtStyleByNumericId(
  String accessToken,
  int numericId,
) async {
  final uri = Uri.parse('$kApiBaseUrl/api/v1/art-styles/numeric/$numericId');
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
