import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../config.dart';
import '../core.dart';

enum ApiKeyScopeV1 { readOnly, readWrite }

enum ApiKeyStatusV1 { active, revoked }

enum ApiKeyExpiresAtActionV1 { preserve, clear, set }

ApiKeyScopeV1 _parseApiKeyScope(String raw) {
  switch (raw) {
    case 'read_write':
      return ApiKeyScopeV1.readWrite;
    case 'read_only':
    default:
      return ApiKeyScopeV1.readOnly;
  }
}

ApiKeyStatusV1 _parseApiKeyStatus(String raw) {
  switch (raw) {
    case 'revoked':
      return ApiKeyStatusV1.revoked;
    case 'active':
    default:
      return ApiKeyStatusV1.active;
  }
}

String encodeApiKeyScope(ApiKeyScopeV1 scope) {
  switch (scope) {
    case ApiKeyScopeV1.readOnly:
      return 'read_only';
    case ApiKeyScopeV1.readWrite:
      return 'read_write';
  }
}

class ApiKeyRecordV1 {
  const ApiKeyRecordV1({
    required this.id,
    required this.publicId,
    required this.displayName,
    required this.scope,
    required this.status,
    required this.keyHint,
    required this.useCount,
    required this.isExpired,
    required this.isUsable,
    required this.createdAt,
    required this.updatedAt,
    this.expiresAt,
    this.revokedAt,
    this.rotatedAt,
    this.lastUsedAt,
    this.lastUsedPath,
    this.lastUsedMethod,
    this.lastUsedIp,
    this.lastUsedUserAgent,
  });

  final String id;
  final String publicId;
  final String displayName;
  final ApiKeyScopeV1 scope;
  final ApiKeyStatusV1 status;
  final String keyHint;
  final String? expiresAt;
  final String? revokedAt;
  final String? rotatedAt;
  final String? lastUsedAt;
  final String? lastUsedPath;
  final String? lastUsedMethod;
  final String? lastUsedIp;
  final String? lastUsedUserAgent;
  final int useCount;
  final bool isExpired;
  final bool isUsable;
  final String createdAt;
  final String updatedAt;

  bool get isActive => status == ApiKeyStatusV1.active;

  factory ApiKeyRecordV1.fromJson(Map<String, dynamic> json) {
    return ApiKeyRecordV1(
      id: json['id'] as String,
      publicId: json['publicId'] as String? ?? '',
      displayName: json['displayName'] as String? ?? '',
      scope: _parseApiKeyScope(json['scope'] as String? ?? 'read_only'),
      status: _parseApiKeyStatus(json['status'] as String? ?? 'active'),
      keyHint: json['keyHint'] as String? ?? '',
      expiresAt: json['expiresAt'] as String?,
      revokedAt: json['revokedAt'] as String?,
      rotatedAt: json['rotatedAt'] as String?,
      lastUsedAt: json['lastUsedAt'] as String?,
      lastUsedPath: json['lastUsedPath'] as String?,
      lastUsedMethod: json['lastUsedMethod'] as String?,
      lastUsedIp: json['lastUsedIp'] as String?,
      lastUsedUserAgent: json['lastUsedUserAgent'] as String?,
      useCount: (json['useCount'] as num?)?.toInt() ?? 0,
      isExpired: json['isExpired'] as bool? ?? false,
      isUsable: json['isUsable'] as bool? ?? true,
      createdAt: json['createdAt'] as String? ?? '',
      updatedAt: json['updatedAt'] as String? ?? '',
    );
  }
}

class ApiKeyAuditRecordV1 {
  const ApiKeyAuditRecordV1({
    required this.id,
    required this.apiKeyId,
    required this.eventType,
    required this.eventSummary,
    required this.metadata,
    required this.createdAt,
  });

  final String id;
  final String apiKeyId;
  final String eventType;
  final String eventSummary;
  final Map<String, dynamic> metadata;
  final String createdAt;

  factory ApiKeyAuditRecordV1.fromJson(Map<String, dynamic> json) {
    return ApiKeyAuditRecordV1(
      id: json['id'] as String,
      apiKeyId: json['apiKeyId'] as String? ?? '',
      eventType: json['eventType'] as String? ?? '',
      eventSummary: json['eventSummary'] as String? ?? '',
      metadata: Map<String, dynamic>.from(json['metadata'] as Map? ?? {}),
      createdAt: json['createdAt'] as String? ?? '',
    );
  }
}

class ApiKeyListResponseV1 {
  const ApiKeyListResponseV1({
    required this.items,
    required this.activeCount,
    required this.revokedCount,
  });

  final List<ApiKeyRecordV1> items;
  final int activeCount;
  final int revokedCount;

  factory ApiKeyListResponseV1.fromJson(Map<String, dynamic> json) {
    return ApiKeyListResponseV1(
      items: (json['items'] as List? ?? const [])
          .map(
            (item) =>
                ApiKeyRecordV1.fromJson(Map<String, dynamic>.from(item as Map)),
          )
          .toList(growable: false),
      activeCount: (json['activeCount'] as num?)?.toInt() ?? 0,
      revokedCount: (json['revokedCount'] as num?)?.toInt() ?? 0,
    );
  }
}

class ApiKeyAuditListResponseV1 {
  const ApiKeyAuditListResponseV1({required this.items});

  final List<ApiKeyAuditRecordV1> items;

  factory ApiKeyAuditListResponseV1.fromJson(Map<String, dynamic> json) {
    return ApiKeyAuditListResponseV1(
      items: (json['items'] as List? ?? const [])
          .map(
            (item) => ApiKeyAuditRecordV1.fromJson(
              Map<String, dynamic>.from(item as Map),
            ),
          )
          .toList(growable: false),
    );
  }
}

class ApiKeyCreatedResponseV1 {
  const ApiKeyCreatedResponseV1({
    required this.record,
    required this.plaintextToken,
  });

  final ApiKeyRecordV1 record;
  final String plaintextToken;

  factory ApiKeyCreatedResponseV1.fromJson(Map<String, dynamic> json) {
    return ApiKeyCreatedResponseV1(
      record: ApiKeyRecordV1.fromJson(
        Map<String, dynamic>.from(json['record'] as Map? ?? const {}),
      ),
      plaintextToken: json['plaintextToken'] as String? ?? '',
    );
  }
}

Future<ApiKeyListResponseV1> fetchApiKeysV1(String accessToken) async {
  final uri = Uri.parse('$kApiBaseUrl/api/v1/settings/api-keys');
  final res = await http
      .get(uri, headers: {'Authorization': 'Bearer $accessToken'})
      .timeout(const Duration(seconds: 15));
  ensureHttpSuccess(res);
  return ApiKeyListResponseV1.fromJson(
    jsonDecode(res.body) as Map<String, dynamic>,
  );
}

Future<ApiKeyAuditListResponseV1> fetchApiKeyAuditV1(
  String accessToken, {
  int limit = 50,
}) async {
  final uri = Uri.parse(
    '$kApiBaseUrl/api/v1/settings/api-keys/audit?limit=$limit',
  );
  final res = await http
      .get(uri, headers: {'Authorization': 'Bearer $accessToken'})
      .timeout(const Duration(seconds: 15));
  ensureHttpSuccess(res);
  return ApiKeyAuditListResponseV1.fromJson(
    jsonDecode(res.body) as Map<String, dynamic>,
  );
}

Future<ApiKeyCreatedResponseV1> createApiKeyV1(
  String accessToken, {
  required String displayName,
  required ApiKeyScopeV1 scope,
  String? expiresAt,
}) async {
  final uri = Uri.parse('$kApiBaseUrl/api/v1/settings/api-keys');
  final body = <String, dynamic>{
    'displayName': displayName,
    'scope': encodeApiKeyScope(scope),
  };
  if (expiresAt != null && expiresAt.isNotEmpty) {
    body['expiresAt'] = expiresAt;
  }
  final res = await http
      .post(
        uri,
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(body),
      )
      .timeout(const Duration(seconds: 15));
  ensureHttpSuccess(res);
  return ApiKeyCreatedResponseV1.fromJson(
    jsonDecode(res.body) as Map<String, dynamic>,
  );
}

Future<ApiKeyCreatedResponseV1> rotateApiKeyV1(
  String accessToken, {
  required String apiKeyId,
  ApiKeyExpiresAtActionV1 expiresAtAction = ApiKeyExpiresAtActionV1.preserve,
  String? expiresAt,
}) async {
  final uri = Uri.parse(
    '$kApiBaseUrl/api/v1/settings/api-keys/$apiKeyId/rotate',
  );
  final body = <String, dynamic>{
    'expiresAtAction': switch (expiresAtAction) {
      ApiKeyExpiresAtActionV1.preserve => 'preserve',
      ApiKeyExpiresAtActionV1.clear => 'clear',
      ApiKeyExpiresAtActionV1.set => 'set',
    },
  };
  if (expiresAtAction == ApiKeyExpiresAtActionV1.set &&
      expiresAt != null &&
      expiresAt.isNotEmpty) {
    body['expiresAt'] = expiresAt;
  }
  final res = await http
      .post(
        uri,
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(body),
      )
      .timeout(const Duration(seconds: 15));
  ensureHttpSuccess(res);
  return ApiKeyCreatedResponseV1.fromJson(
    jsonDecode(res.body) as Map<String, dynamic>,
  );
}

Future<ApiKeyRecordV1> revokeApiKeyV1(
  String accessToken, {
  required String apiKeyId,
  String? reason,
}) async {
  final uri = Uri.parse(
    '$kApiBaseUrl/api/v1/settings/api-keys/$apiKeyId/revoke',
  );
  final res = await http
      .post(
        uri,
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'reason': reason}),
      )
      .timeout(const Duration(seconds: 15));
  ensureHttpSuccess(res);
  return ApiKeyRecordV1.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
}

Future<ApiKeyRecordV1> activateApiKeyV1(
  String accessToken, {
  required String apiKeyId,
}) async {
  final uri = Uri.parse(
    '$kApiBaseUrl/api/v1/settings/api-keys/$apiKeyId/activate',
  );
  final res = await http
      .post(uri, headers: {'Authorization': 'Bearer $accessToken'})
      .timeout(const Duration(seconds: 15));
  ensureHttpSuccess(res);
  return ApiKeyRecordV1.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
}

Future<void> deleteApiKeyV1(
  String accessToken, {
  required String apiKeyId,
}) async {
  final uri = Uri.parse('$kApiBaseUrl/api/v1/settings/api-keys/$apiKeyId');
  final res = await http
      .delete(uri, headers: {'Authorization': 'Bearer $accessToken'})
      .timeout(const Duration(seconds: 15));
  ensureHttpSuccess(res);
}
