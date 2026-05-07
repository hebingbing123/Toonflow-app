import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../config.dart';
import '../core.dart';

/// One workspace row — matches OpenAPI **`WorkspaceResponse`** (snake_case JSON).
class WorkspaceResponse {
  const WorkspaceResponse({
    required this.id,
    required this.ownerUserId,
    required this.name,
    required this.workspaceType,
    required this.metadata,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String ownerUserId;
  final String name;
  final String workspaceType;
  final Map<String, dynamic> metadata;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory WorkspaceResponse.fromJson(Map<String, dynamic> json) {
    return WorkspaceResponse(
      id: json['id'] as String,
      ownerUserId: json['owner_user_id'] as String,
      name: json['name'] as String,
      workspaceType: json['workspace_type'] as String,
      metadata: (json['metadata'] is Map<String, dynamic>)
          ? json['metadata'] as Map<String, dynamic>
          : <String, dynamic>{},
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }
}

/// **`GET /api/v1/workspaces`** list row — flattened workspace + **`role`**.
class WorkspaceListItem {
  const WorkspaceListItem({
    required this.workspace,
    required this.role,
  });

  final WorkspaceResponse workspace;
  final String role;

  factory WorkspaceListItem.fromJson(Map<String, dynamic> json) {
    return WorkspaceListItem(
      workspace: WorkspaceResponse.fromJson(json),
      role: json['role'] as String,
    );
  }
}

/// `POST /api/v1/workspaces`
class CreateWorkspaceBody {
  const CreateWorkspaceBody({required this.name, this.metadata});

  final String name;
  final Map<String, dynamic>? metadata;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'name': name,
    if (metadata != null) 'metadata': metadata,
  };
}

Future<List<WorkspaceListItem>> fetchWorkspacesV1(String accessToken) async {
  final uri = Uri.parse('$kApiBaseUrl/api/v1/workspaces');
  final res = await http
      .get(uri, headers: {'Authorization': 'Bearer $accessToken'})
      .timeout(const Duration(seconds: 15));
  if (res.statusCode != 200) {
    throw RustApiException(res.body, statusCode: res.statusCode);
  }
  final list = jsonDecode(res.body) as List<dynamic>;
  return list
      .map((e) => WorkspaceListItem.fromJson(e as Map<String, dynamic>))
      .toList(growable: false);
}

Future<WorkspaceResponse> createWorkspaceV1(
  String accessToken,
  CreateWorkspaceBody body,
) async {
  final uri = Uri.parse('$kApiBaseUrl/api/v1/workspaces');
  final res = await http
      .post(
        uri,
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(body.toJson()),
      )
      .timeout(const Duration(seconds: 15));
  if (res.statusCode != 200) {
    throw RustApiException(res.body, statusCode: res.statusCode);
  }
  final map = jsonDecode(res.body) as Map<String, dynamic>;
  return WorkspaceResponse.fromJson(map);
}
