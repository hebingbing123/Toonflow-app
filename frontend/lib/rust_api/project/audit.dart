import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../config.dart';
import '../core.dart';

class ProjectAuditResponse {
  const ProjectAuditResponse({
    required this.id,
    required this.projectId,
    required this.workspaceId,
    required this.projectNumericId,
    required this.actorUserId,
    required this.action,
    required this.targetUserId,
    required this.details,
    required this.createdAt,
  });

  final int id;
  final String projectId;
  final String workspaceId;
  final int? projectNumericId;
  final String actorUserId;
  final String action;
  final String? targetUserId;
  final Map<String, dynamic> details;
  final DateTime createdAt;

  factory ProjectAuditResponse.fromJson(Map<String, dynamic> json) {
    return ProjectAuditResponse(
      id: (json['id'] as num).toInt(),
      projectId: json['projectId'] as String,
      workspaceId: json['workspaceId'] as String,
      projectNumericId: (json['projectNumericId'] as num?)?.toInt(),
      actorUserId: json['actorUserId'] as String,
      action: json['action'] as String,
      targetUserId: json['targetUserId'] as String?,
      details:
          (json['details'] as Map<String, dynamic>?) ?? <String, dynamic>{},
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }
}

class ListProjectAuditEnvelope {
  const ListProjectAuditEnvelope({required this.items, required this.hasMore});

  final List<ProjectAuditResponse> items;
  final bool hasMore;

  factory ListProjectAuditEnvelope.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'] as List<dynamic>? ?? const <dynamic>[];
    return ListProjectAuditEnvelope(
      items: rawItems
          .map(
            (item) =>
                ProjectAuditResponse.fromJson(item as Map<String, dynamic>),
          )
          .toList(growable: false),
      hasMore: json['hasMore'] == true,
    );
  }
}

Future<ListProjectAuditEnvelope> fetchProjectAuditV1(
  String accessToken,
  String projectId, {
  String? action,
  int limit = 50,
  int offset = 0,
}) async {
  final qp = <String, String>{'limit': '$limit', 'offset': '$offset'};
  final trimmedAction = action?.trim();
  if (trimmedAction != null && trimmedAction.isNotEmpty) {
    qp['action'] = trimmedAction;
  }
  final uri = Uri.parse(
    '$kApiBaseUrl/api/v1/projects/$projectId/audit',
  ).replace(queryParameters: qp);
  final res = await http
      .get(uri, headers: rustApiAuthHeaders(accessToken))
      .timeout(const Duration(seconds: 15));
  ensureHttpSuccess(res);
  return ListProjectAuditEnvelope.fromJson(
    jsonDecode(res.body) as Map<String, dynamic>,
  );
}
