import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../config.dart';
import '../core.dart';
import 'manuals.dart';

/// `POST /api/v1/project/add-visual-manual`.
Future<void> postProjectAddVisualManual(
  String accessToken, {
  required String name,
  required String stylePath,
  List<String> images = const [],
  required List<DirectorManualDataSlot> data,
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
        headers: rustApiJsonAuthHeaders(accessToken),
        body: jsonEncode(body),
      )
      .timeout(const Duration(seconds: 120));
  if (res.statusCode == 400) {
    throw RustApiException.fromHttpResponse(res);
  }
  expectEmptyObjectResponse(res);
}

/// `POST /api/v1/project/edit-visual-manual`.
Future<void> postProjectEditVisualManual(
  String accessToken, {
  required String name,
  required String stylePath,
  List<String> images = const [],
  required List<DirectorManualDataSlot> data,
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
        headers: rustApiJsonAuthHeaders(accessToken),
        body: jsonEncode(body),
      )
      .timeout(const Duration(seconds: 120));
  if (res.statusCode == 400) {
    throw RustApiException.fromHttpResponse(res);
  }
  expectEmptyObjectResponse(res);
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
