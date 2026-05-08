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
    this.archivedAt,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String ownerUserId;
  final String name;
  final String workspaceType;
  final Map<String, dynamic> metadata;
  final DateTime? archivedAt;
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
      archivedAt: json['archived_at'] == null
          ? null
          : DateTime.parse(json['archived_at'] as String),
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

/// One `app_workspace_member` row.
class WorkspaceMemberResponse {
  const WorkspaceMemberResponse({
    required this.workspaceId,
    required this.userId,
    required this.role,
    required this.createdAt,
    required this.updatedAt,
  });

  final String workspaceId;
  final String userId;
  final String role;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory WorkspaceMemberResponse.fromJson(Map<String, dynamic> json) {
    return WorkspaceMemberResponse(
      workspaceId: json['workspace_id'] as String,
      userId: json['user_id'] as String,
      role: json['role'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }
}

/// One `app_workspace_invite` row.
class WorkspaceInviteResponse {
  const WorkspaceInviteResponse({
    required this.id,
    required this.workspaceId,
    required this.email,
    required this.token,
    required this.role,
    required this.invitedBy,
    required this.status,
    required this.expiresAt,
    this.acceptedBy,
    this.acceptedAt,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String workspaceId;
  final String email;
  final String token;
  final String role;
  final String invitedBy;
  final String status;
  final DateTime expiresAt;
  final String? acceptedBy;
  final DateTime? acceptedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory WorkspaceInviteResponse.fromJson(Map<String, dynamic> json) {
    return WorkspaceInviteResponse(
      id: json['id'] as String,
      workspaceId: json['workspace_id'] as String,
      email: json['email'] as String,
      token: json['token'] as String,
      role: json['role'] as String,
      invitedBy: json['invited_by'] as String,
      status: json['status'] as String,
      expiresAt: DateTime.parse(json['expires_at'] as String),
      acceptedBy: json['accepted_by'] as String?,
      acceptedAt: json['accepted_at'] == null
          ? null
          : DateTime.parse(json['accepted_at'] as String),
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }
}

/// `GET /api/v1/workspaces/{workspace_id}/invites` — see `listWorkspaceInvitesV1`.
class WorkspaceInvitesListEnvelope {
  const WorkspaceInvitesListEnvelope({
    required this.items,
    required this.hasMore,
  });

  final List<WorkspaceInviteResponse> items;
  final bool hasMore;

  factory WorkspaceInvitesListEnvelope.fromJson(Map<String, dynamic> json) {
    final raw = json['items'] as List<dynamic>? ?? const <dynamic>[];
    return WorkspaceInvitesListEnvelope(
      items: raw
          .map(
            (e) => WorkspaceInviteResponse.fromJson(e as Map<String, dynamic>),
          )
          .toList(growable: false),
      hasMore: json['has_more'] as bool? ?? false,
    );
  }
}

/// `POST /api/v1/workspaces/{workspace_id}/invites/{invite_id}/resend`
class ResendWorkspaceInviteBody {
  const ResendWorkspaceInviteBody({this.expiresInHours});

  final int? expiresInHours;

  Map<String, dynamic> toJson() {
    final m = <String, dynamic>{};
    if (expiresInHours != null) {
      m['expires_in_hours'] = expiresInHours;
    }
    return m;
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

/// `PATCH /api/v1/workspaces/{workspace_id}`
class PatchWorkspaceBody {
  const PatchWorkspaceBody({this.name, this.metadata, this.archive});

  final String? name;
  final Map<String, dynamic>? metadata;
  final bool? archive;

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{};
    if (name != null) {
      map['name'] = name;
    }
    if (metadata != null) {
      map['metadata'] = metadata;
    }
    if (archive != null) {
      map['archive'] = archive;
    }
    return map;
  }
}

/// `POST /api/v1/workspaces/{workspace_id}/members`
class AddWorkspaceMemberBody {
  const AddWorkspaceMemberBody({
    required this.userId,
    required this.role,
  });

  final String userId;
  final String role;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'user_id': userId,
    'role': role,
  };
}

/// `PATCH /api/v1/workspaces/{workspace_id}/members/{user_id}`
class PatchWorkspaceMemberBody {
  const PatchWorkspaceMemberBody({required this.role});

  final String role;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'role': role,
  };
}

/// `POST /api/v1/workspaces/{workspace_id}/invites`
class CreateWorkspaceInviteBody {
  const CreateWorkspaceInviteBody({
    required this.email,
    required this.role,
    this.expiresInHours,
  });

  final String email;
  final String role;
  final int? expiresInHours;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'email': email,
    'role': role,
    if (expiresInHours != null) 'expires_in_hours': expiresInHours,
  };
}

/// `POST /api/v1/workspaces/invites/accept`
class AcceptWorkspaceInviteBody {
  const AcceptWorkspaceInviteBody({required this.token});

  final String token;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'token': token,
  };
}

Future<List<WorkspaceListItem>> fetchWorkspacesV1(
  String accessToken, {
  bool includeArchived = false,
}) async {
  final base = Uri.parse('$kApiBaseUrl/api/v1/workspaces');
  final uri = includeArchived
      ? base.replace(queryParameters: <String, String>{
          'include_archived': 'true',
        })
      : base;
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

Future<List<WorkspaceMemberResponse>> fetchWorkspaceMembersV1(
  String accessToken,
  String workspaceId,
) async {
  final uri = Uri.parse('$kApiBaseUrl/api/v1/workspaces/$workspaceId/members');
  final res = await http
      .get(uri, headers: {'Authorization': 'Bearer $accessToken'})
      .timeout(const Duration(seconds: 15));
  if (res.statusCode != 200) {
    throw RustApiException(res.body, statusCode: res.statusCode);
  }
  final list = jsonDecode(res.body) as List<dynamic>;
  return list
      .map((e) => WorkspaceMemberResponse.fromJson(e as Map<String, dynamic>))
      .toList(growable: false);
}

/// `GET /api/v1/workspaces/{workspace_id}/invites` — see `listWorkspaceInvitesV1`.
Future<WorkspaceInvitesListEnvelope> fetchWorkspaceInvitesPageV1(
  String accessToken,
  String workspaceId, {
  String? status,
  int? limit,
  int? offset,
  bool includeRevoked = false,
}) async {
  final qp = <String, String>{};
  if (status != null && status.isNotEmpty) {
    qp['status'] = status;
  }
  if (limit != null) {
    qp['limit'] = '$limit';
  }
  if (offset != null && offset > 0) {
    qp['offset'] = '$offset';
  }
  if (includeRevoked) {
    qp['include_revoked'] = 'true';
  }
  final uri = Uri.parse('$kApiBaseUrl/api/v1/workspaces/$workspaceId/invites')
      .replace(queryParameters: qp.isEmpty ? null : qp);
  final res = await http
      .get(uri, headers: {'Authorization': 'Bearer $accessToken'})
      .timeout(const Duration(seconds: 15));
  if (res.statusCode != 200) {
    throw RustApiException(res.body, statusCode: res.statusCode);
  }
  final map = jsonDecode(res.body) as Map<String, dynamic>;
  return WorkspaceInvitesListEnvelope.fromJson(map);
}

/// Loads all pages (bounded) for admin views that need a full list client-side.
Future<List<WorkspaceInviteResponse>> fetchWorkspaceInvitesAllV1(
  String accessToken,
  String workspaceId, {
  String? status,
  int pageSize = 100,
  bool includeRevoked = false,
  int maxPages = 20,
}) async {
  final out = <WorkspaceInviteResponse>[];
  var offset = 0;
  for (var i = 0; i < maxPages; i++) {
    final page = await fetchWorkspaceInvitesPageV1(
      accessToken,
      workspaceId,
      status: status,
      limit: pageSize,
      offset: offset,
      includeRevoked: includeRevoked,
    );
    out.addAll(page.items);
    if (!page.hasMore) {
      break;
    }
    offset += page.items.length;
  }
  return out;
}

Future<WorkspaceInviteResponse> revokeWorkspaceInviteV1(
  String accessToken,
  String workspaceId,
  String inviteId,
) async {
  final uri = Uri.parse(
    '$kApiBaseUrl/api/v1/workspaces/$workspaceId/invites/$inviteId',
  );
  final res = await http
      .delete(uri, headers: {'Authorization': 'Bearer $accessToken'})
      .timeout(const Duration(seconds: 15));
  if (res.statusCode != 200) {
    throw RustApiException(res.body, statusCode: res.statusCode);
  }
  final map = jsonDecode(res.body) as Map<String, dynamic>;
  return WorkspaceInviteResponse.fromJson(map);
}

Future<WorkspaceInviteResponse> resendWorkspaceInviteV1(
  String accessToken,
  String workspaceId,
  String inviteId, {
  ResendWorkspaceInviteBody? body,
}) async {
  final uri = Uri.parse(
    '$kApiBaseUrl/api/v1/workspaces/$workspaceId/invites/$inviteId/resend',
  );
  final payload = body ?? const ResendWorkspaceInviteBody();
  final res = await http
      .post(
        uri,
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(payload.toJson()),
      )
      .timeout(const Duration(seconds: 15));
  if (res.statusCode != 200) {
    throw RustApiException(res.body, statusCode: res.statusCode);
  }
  final map = jsonDecode(res.body) as Map<String, dynamic>;
  return WorkspaceInviteResponse.fromJson(map);
}

Future<WorkspaceMemberResponse> addWorkspaceMemberV1(
  String accessToken,
  String workspaceId,
  AddWorkspaceMemberBody body,
) async {
  final uri = Uri.parse('$kApiBaseUrl/api/v1/workspaces/$workspaceId/members');
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
  return WorkspaceMemberResponse.fromJson(map);
}

Future<WorkspaceMemberResponse> patchWorkspaceMemberV1(
  String accessToken,
  String workspaceId,
  String userId, {
  required PatchWorkspaceMemberBody body,
}) async {
  final uri =
      Uri.parse('$kApiBaseUrl/api/v1/workspaces/$workspaceId/members/$userId');
  final res = await http
      .patch(
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
  return WorkspaceMemberResponse.fromJson(map);
}

Future<WorkspaceMemberResponse> removeWorkspaceMemberV1(
  String accessToken,
  String workspaceId,
  String userId,
) async {
  final uri =
      Uri.parse('$kApiBaseUrl/api/v1/workspaces/$workspaceId/members/$userId');
  final res = await http
      .delete(uri, headers: {'Authorization': 'Bearer $accessToken'})
      .timeout(const Duration(seconds: 15));
  if (res.statusCode != 200) {
    throw RustApiException(res.body, statusCode: res.statusCode);
  }
  final map = jsonDecode(res.body) as Map<String, dynamic>;
  return WorkspaceMemberResponse.fromJson(map);
}

Future<WorkspaceMemberResponse> leaveWorkspaceV1(
  String accessToken,
  String workspaceId,
) async {
  final uri = Uri.parse('$kApiBaseUrl/api/v1/workspaces/$workspaceId/members/me');
  final res = await http
      .delete(uri, headers: {'Authorization': 'Bearer $accessToken'})
      .timeout(const Duration(seconds: 15));
  if (res.statusCode != 200) {
    throw RustApiException(res.body, statusCode: res.statusCode);
  }
  final map = jsonDecode(res.body) as Map<String, dynamic>;
  return WorkspaceMemberResponse.fromJson(map);
}

Future<WorkspaceInviteResponse> createWorkspaceInviteV1(
  String accessToken,
  String workspaceId,
  CreateWorkspaceInviteBody body,
) async {
  final uri = Uri.parse('$kApiBaseUrl/api/v1/workspaces/$workspaceId/invites');
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
  return WorkspaceInviteResponse.fromJson(map);
}

Future<WorkspaceMemberResponse> acceptWorkspaceInviteV1(
  String accessToken,
  AcceptWorkspaceInviteBody body,
) async {
  final uri = Uri.parse('$kApiBaseUrl/api/v1/workspaces/invites/accept');
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
  return WorkspaceMemberResponse.fromJson(map);
}

Future<WorkspaceResponse> patchWorkspaceV1(
  String accessToken,
  String workspaceId,
  PatchWorkspaceBody body,
) async {
  final uri = Uri.parse('$kApiBaseUrl/api/v1/workspaces/$workspaceId');
  final payload = body.toJson();
  if (payload.isEmpty) {
    throw StateError('PatchWorkspaceBody is empty');
  }
  final res = await http
      .patch(
        uri,
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(payload),
      )
      .timeout(const Duration(seconds: 15));
  if (res.statusCode != 200) {
    throw RustApiException(res.body, statusCode: res.statusCode);
  }
  final map = jsonDecode(res.body) as Map<String, dynamic>;
  return WorkspaceResponse.fromJson(map);
}
