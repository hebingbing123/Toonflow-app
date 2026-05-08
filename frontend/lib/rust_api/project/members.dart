import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../config.dart';
import '../core.dart';

/// One row in `app_project_member` — OpenAPI **`ProjectMemberResponse`**.
class ProjectMemberResponse {
  const ProjectMemberResponse({
    required this.projectId,
    required this.userId,
    required this.role,
    required this.createdAt,
    required this.updatedAt,
  });

  final String projectId;
  final String userId;
  final String role;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory ProjectMemberResponse.fromJson(Map<String, dynamic> json) {
    return ProjectMemberResponse(
      projectId: json['projectId'] as String,
      userId: json['userId'] as String,
      role: json['role'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }
}

/// `GET /api/v1/projects/{project_id}/members` — see `listProjectMembersV1`.
Future<List<ProjectMemberResponse>> fetchProjectMembersV1(
  String accessToken,
  String projectId,
) async {
  final uri = Uri.parse('$kApiBaseUrl/api/v1/projects/$projectId/members');
  final res = await http
      .get(uri, headers: {'Authorization': 'Bearer $accessToken'})
      .timeout(const Duration(seconds: 15));
  if (res.statusCode != 200) {
    throw RustApiException(res.body, statusCode: res.statusCode);
  }
  final list = jsonDecode(res.body) as List<dynamic>;
  return list
      .map(
        (e) => ProjectMemberResponse.fromJson(e as Map<String, dynamic>),
      )
      .toList();
}

/// `POST /api/v1/projects/{project_id}/members` — see `createProjectMemberV1`.
Future<ProjectMemberResponse> createProjectMemberV1(
  String accessToken,
  String projectId, {
  required String userId,
  required String role,
}) async {
  final uri = Uri.parse('$kApiBaseUrl/api/v1/projects/$projectId/members');
  final res = await http
      .post(
        uri,
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(<String, dynamic>{'userId': userId, 'role': role}),
      )
      .timeout(const Duration(seconds: 15));
  if (res.statusCode != 200) {
    throw RustApiException(res.body, statusCode: res.statusCode);
  }
  final map = jsonDecode(res.body) as Map<String, dynamic>;
  return ProjectMemberResponse.fromJson(map);
}

/// `PATCH /api/v1/projects/{project_id}/members/{user_id}` — see `patchProjectMemberV1`.
Future<ProjectMemberResponse> patchProjectMemberV1(
  String accessToken,
  String projectId,
  String userId, {
  required String role,
}) async {
  final uri =
      Uri.parse('$kApiBaseUrl/api/v1/projects/$projectId/members/$userId');
  final res = await http
      .patch(
        uri,
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(<String, dynamic>{'role': role}),
      )
      .timeout(const Duration(seconds: 15));
  if (res.statusCode != 200) {
    throw RustApiException(res.body, statusCode: res.statusCode);
  }
  final map = jsonDecode(res.body) as Map<String, dynamic>;
  return ProjectMemberResponse.fromJson(map);
}

/// `DELETE /api/v1/projects/{project_id}/members/{user_id}` — see `deleteProjectMemberV1`.
Future<void> deleteProjectMemberV1(
  String accessToken,
  String projectId,
  String userId,
) async {
  final uri =
      Uri.parse('$kApiBaseUrl/api/v1/projects/$projectId/members/$userId');
  final res = await http
      .delete(uri, headers: {'Authorization': 'Bearer $accessToken'})
      .timeout(const Duration(seconds: 15));
  if (res.statusCode != 204) {
    throw RustApiException(res.body, statusCode: res.statusCode);
  }
}
