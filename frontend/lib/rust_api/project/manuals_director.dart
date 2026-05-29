import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../config.dart';
import '../core.dart';
import 'manuals.dart';

/// `POST /api/v1/project/query-director-manual` — body `{}`; bundled **`story_skills`** rows.
Future<DirectorManualListResponse> postProjectQueryDirectorManual(
  String accessToken,
) async {
  final uri = Uri.parse('$kApiBaseUrl/api/v1/project/query-director-manual');
  final res = await http
      .post(
        uri,
        headers: rustApiJsonAuthHeaders(accessToken),
        body: jsonEncode({}),
      )
      .timeout(const Duration(seconds: 120));
  if (res.statusCode == 400) {
    throw RustApiException.fromHttpResponse(res);
  }
  ensureHttpSuccess(res);
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
        headers: rustApiJsonAuthHeaders(accessToken),
        body: jsonEncode(body),
      )
      .timeout(const Duration(seconds: 120));
  if (res.statusCode == 400) {
    throw RustApiException.fromHttpResponse(res);
  }
  expectEmptyObjectResponse(res);
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
        headers: rustApiJsonAuthHeaders(accessToken),
        body: jsonEncode(body),
      )
      .timeout(const Duration(seconds: 120));
  if (res.statusCode == 400) {
    throw RustApiException.fromHttpResponse(res);
  }
  expectEmptyObjectResponse(res);
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
        headers: rustApiJsonAuthHeaders(accessToken),
        body: jsonEncode({'name': folderName}),
      )
      .timeout(const Duration(seconds: 60));
  if (res.statusCode == 400) {
    throw RustApiException.fromHttpResponse(res);
  }
  ensureHttpSuccess(res);
  final map = jsonDecode(res.body) as Map<String, dynamic>;
  return map['message'] as String? ?? '';
}
