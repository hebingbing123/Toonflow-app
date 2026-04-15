import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../config.dart';
import '../core.dart';

/// Skills catalog models and CRUD-style content endpoints.
class SkillFileMeta {
  const SkillFileMeta({required this.path, required this.sizeBytes});

  final String path;
  final int sizeBytes;

  factory SkillFileMeta.fromJson(Map<String, dynamic> json) {
    return SkillFileMeta(
      path: json['path'] as String,
      sizeBytes: (json['size_bytes'] as num).toInt(),
    );
  }
}

/// `GET /api/v1/skills/summary`. See `getSkillsSummaryV1`.
class SkillsSummary {
  const SkillsSummary({
    required this.markdownFileCount,
    required this.totalBytes,
  });

  final int markdownFileCount;
  final int totalBytes;

  factory SkillsSummary.fromJson(Map<String, dynamic> json) {
    return SkillsSummary(
      markdownFileCount: (json['markdown_file_count'] as num).toInt(),
      totalBytes: (json['total_bytes'] as num).toInt(),
    );
  }
}

class SkillContentResponse {
  const SkillContentResponse({required this.path, required this.content});

  final String path;
  final String content;

  factory SkillContentResponse.fromJson(Map<String, dynamic> json) {
    return SkillContentResponse(
      path: json['path'] as String,
      content: json['content'] as String,
    );
  }
}

/// `GET /api/v1/skills/summary`. See `getSkillsSummaryV1`.
Future<SkillsSummary> fetchSkillsSummary(String accessToken) async {
  final uri = Uri.parse('$kApiBaseUrl/api/v1/skills/summary');
  final res = await http
      .get(uri, headers: {'Authorization': 'Bearer $accessToken'})
      .timeout(const Duration(seconds: 60));
  if (res.statusCode != 200) {
    throw RustApiException(res.body, statusCode: res.statusCode);
  }
  final map = jsonDecode(res.body) as Map<String, dynamic>;
  return SkillsSummary.fromJson(map);
}

/// `GET /api/v1/skills` — Markdown paths under `data/skills`. See `listSkillsV1`.
Future<List<SkillFileMeta>> fetchSkills(String accessToken) async {
  final uri = Uri.parse('$kApiBaseUrl/api/v1/skills');
  final res = await http
      .get(uri, headers: {'Authorization': 'Bearer $accessToken'})
      .timeout(const Duration(seconds: 60));
  if (res.statusCode != 200) {
    throw RustApiException(res.body, statusCode: res.statusCode);
  }
  final list = jsonDecode(res.body) as List<dynamic>;
  return list
      .map((e) => SkillFileMeta.fromJson(e as Map<String, dynamic>))
      .toList();
}

/// `GET /api/v1/skills/content?path=…`. See `getSkillContentV1`.
Future<SkillContentResponse> fetchSkillContent(
  String accessToken,
  String relativePath,
) async {
  final uri = Uri.parse(
    '$kApiBaseUrl/api/v1/skills/content',
  ).replace(queryParameters: {'path': relativePath});
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
  return SkillContentResponse.fromJson(map);
}

/// `PUT /api/v1/skills/content` — overwrites an **existing** file only (prior `saveSkillContent`).
/// See `putSkillContentV1`.
Future<SkillContentResponse> saveSkillContent(
  String accessToken,
  String relativePath,
  String content,
) async {
  final uri = Uri.parse('$kApiBaseUrl/api/v1/skills/content');
  final res = await http
      .put(
        uri,
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'path': relativePath, 'content': content}),
      )
      .timeout(const Duration(seconds: 60));
  if (res.statusCode == 400) {
    throw RustApiException(res.body, statusCode: 400);
  }
  if (res.statusCode != 200) {
    throw RustApiException(res.body, statusCode: res.statusCode);
  }
  final map = jsonDecode(res.body) as Map<String, dynamic>;
  return SkillContentResponse.fromJson(map);
}

/// `POST /api/v1/skills/content` — creates a new file under `data/skills` (**409** if it already exists).
/// See `postSkillContentV1`.
Future<SkillContentResponse> createSkillContent(
  String accessToken,
  String relativePath,
  String content,
) async {
  final uri = Uri.parse('$kApiBaseUrl/api/v1/skills/content');
  final res = await http
      .post(
        uri,
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'path': relativePath, 'content': content}),
      )
      .timeout(const Duration(seconds: 60));
  if (res.statusCode == 409) {
    throw RustApiException('conflict', statusCode: 409);
  }
  if (res.statusCode == 400) {
    throw RustApiException(res.body, statusCode: 400);
  }
  if (res.statusCode != 201) {
    throw RustApiException(res.body, statusCode: res.statusCode);
  }
  final map = jsonDecode(res.body) as Map<String, dynamic>;
  return SkillContentResponse.fromJson(map);
}

/// `DELETE /api/v1/skills/content?path=…` — removes a regular file only (**204** empty body).
/// See `deleteSkillContentV1`.
Future<void> deleteSkillContent(String accessToken, String relativePath) async {
  final uri = Uri.parse(
    '$kApiBaseUrl/api/v1/skills/content',
  ).replace(queryParameters: {'path': relativePath});
  final res = await http
      .delete(uri, headers: {'Authorization': 'Bearer $accessToken'})
      .timeout(const Duration(seconds: 30));
  if (res.statusCode == 404) {
    throw RustApiException('not found', statusCode: 404);
  }
  if (res.statusCode == 400) {
    throw RustApiException(res.body, statusCode: 400);
  }
  if (res.statusCode != 204) {
    throw RustApiException(res.body, statusCode: res.statusCode);
  }
}
