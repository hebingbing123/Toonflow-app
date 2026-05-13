import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../config.dart';
import '../core.dart';

class AgentMemoryContentBlock {
  const AgentMemoryContentBlock({
    required this.blockType,
    required this.status,
    required this.data,
  });

  factory AgentMemoryContentBlock.fromJson(Map<String, dynamic> json) {
    return AgentMemoryContentBlock(
      blockType: json['type']?.toString() ?? 'markdown',
      status: json['status']?.toString() ?? 'complete',
      data: json['data']?.toString() ?? '',
    );
  }

  final String blockType;
  final String status;
  final String data;
}

class AgentMemoryHistoryItem {
  const AgentMemoryHistoryItem({
    required this.scope,
    required this.id,
    required this.role,
    required this.name,
    required this.memoryTier,
    required this.status,
    required this.datetime,
    required this.content,
    required this.createTime,
  });

  factory AgentMemoryHistoryItem.fromJson(Map<String, dynamic> json) {
    final rawContent = json['content'];
    final blocks = rawContent is List
        ? rawContent
              .whereType<Map>()
              .map(
                (item) => AgentMemoryContentBlock.fromJson(
                  Map<String, dynamic>.from(item),
                ),
              )
              .toList(growable: false)
        : const <AgentMemoryContentBlock>[];
    return AgentMemoryHistoryItem(
      scope: json['scope']?.toString() ?? 'user',
      id: json['id']?.toString() ?? '',
      role: json['role']?.toString() ?? 'user',
      name: json['name']?.toString(),
      memoryTier: json['memoryTier']?.toString() ?? 'message',
      status: json['status']?.toString() ?? 'complete',
      datetime: json['datetime']?.toString() ?? '',
      content: blocks,
      createTime: (json['createTime'] as num?)?.toInt() ?? 0,
    );
  }

  final String scope;
  final String id;
  final String role;
  final String? name;
  final String memoryTier;
  final String status;
  final String datetime;
  final List<AgentMemoryContentBlock> content;
  final int createTime;

  String get plainTextContent => content.isEmpty ? '' : content.first.data;
}

class AgentMemoryCostOverview {
  const AgentMemoryCostOverview({
    required this.scope,
    required this.projectId,
    required this.styleBibleCount,
    required this.stageSummaryCount,
    required this.deltaMemoryCount,
    required this.messageCount,
    required this.avgInjectedCharsLast30,
    required this.avgHitTierCountLast30,
    required this.lastInjectedAt,
  });

  factory AgentMemoryCostOverview.fromJson(Map<String, dynamic> json) {
    return AgentMemoryCostOverview(
      scope: json['scope']?.toString() ?? 'user',
      projectId: (json['projectId'] as num?)?.toInt() ?? 0,
      styleBibleCount: (json['styleBibleCount'] as num?)?.toInt() ?? 0,
      stageSummaryCount: (json['stageSummaryCount'] as num?)?.toInt() ?? 0,
      deltaMemoryCount: (json['deltaMemoryCount'] as num?)?.toInt() ?? 0,
      messageCount: (json['messageCount'] as num?)?.toInt() ?? 0,
      avgInjectedCharsLast30:
          (json['avgInjectedCharsLast30'] as num?)?.toInt() ?? 0,
      avgHitTierCountLast30:
          (json['avgHitTierCountLast30'] as num?)?.toInt() ?? 0,
      lastInjectedAt: json['lastInjectedAt']?.toString(),
    );
  }

  final String scope;
  final int projectId;
  final int styleBibleCount;
  final int stageSummaryCount;
  final int deltaMemoryCount;
  final int messageCount;
  final int avgInjectedCharsLast30;
  final int avgHitTierCountLast30;
  final String? lastInjectedAt;
}

void _putAgentMemoryProjectRef(
  Map<String, dynamic> body, {
  int? projectId,
  String? projectUuid,
}) {
  final u = projectUuid?.trim();
  if (u != null && u.isNotEmpty) {
    body['projectUuid'] = u;
    return;
  }
  if (projectId != null) {
    body['projectId'] = projectId;
    return;
  }
  throw ArgumentError(
    'projectUuid or projectId is required for agent memory requests',
  );
}

/// Agent memory query, append, and clear endpoints.
/// `POST /api/v1/agents/memory/query` — camelCase body; see `queryAgentMemoryV1`.
///
/// Prefer **`projectUuid`** (`app_project.id`); **`projectId`** is legacy numeric id.
Future<List<AgentMemoryHistoryItem>> queryAgentMemory(
  String accessToken, {
  int? projectId,
  String? projectUuid,
  required String agentType,
  int? episodesId,
  String memoryType = 'message',
  String? memoryTier,
  Map<String, dynamic>? scopeSignature,
}) async {
  final uri = Uri.parse('$kApiBaseUrl/api/v1/agents/memory/query');
  final body = <String, dynamic>{
    'agentType': agentType,
    'episodesId': episodesId,
    'memoryType': memoryType,
  };
  _putAgentMemoryProjectRef(
    body,
    projectId: projectId,
    projectUuid: projectUuid,
  );
  if (memoryTier != null && memoryTier.isNotEmpty) {
    body['memoryTier'] = memoryTier;
  }
  if (scopeSignature != null && scopeSignature.isNotEmpty) {
    body['scopeSignature'] = scopeSignature;
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
  final decoded = jsonDecode(res.body);
  if (decoded is! List) {
    throw RustApiException('Unexpected response: ${res.body}');
  }
  return decoded
      .whereType<Map>()
      .map(
        (row) =>
            AgentMemoryHistoryItem.fromJson(Map<String, dynamic>.from(row)),
      )
      .toList(growable: false);
}

Future<AgentMemoryCostOverview> getMemoryCostOverview(
  String accessToken, {
  int? projectId,
  String? projectUuid,
  required String agentType,
}) async {
  final u = projectUuid?.trim();
  final String qs;
  if (u != null && u.isNotEmpty) {
    qs =
        'projectUuid=${Uri.encodeQueryComponent(u)}&agentType=${Uri.encodeQueryComponent(agentType)}';
  } else if (projectId != null) {
    qs =
        'projectId=$projectId&agentType=${Uri.encodeQueryComponent(agentType)}';
  } else {
    throw ArgumentError('projectUuid or projectId is required');
  }
  final uri = Uri.parse('$kApiBaseUrl/api/v1/agents/memory/cost-overview?$qs');
  final res = await http
      .get(uri, headers: {'Authorization': 'Bearer $accessToken'})
      .timeout(const Duration(seconds: 15));
  ensureHttpSuccess(res);
  final decoded = jsonDecode(res.body);
  if (decoded is! Map) {
    throw RustApiException('Unexpected response: ${res.body}');
  }
  return AgentMemoryCostOverview.fromJson(Map<String, dynamic>.from(decoded));
}

/// `POST /api/v1/agents/memory/clear` — OpenAPI `clearAgentMemoryV1` (**`clearType`**: `all` | `message` | `summary`).
///
/// Alternate field **`type`** is also accepted by the server as an alias for **`clearType`**.
Future<bool> clearAgentMemory(
  String accessToken, {
  int? projectId,
  String? projectUuid,
  required String agentType,
  int? episodesId,
  String clearType = 'all',
}) async {
  final uri = Uri.parse('$kApiBaseUrl/api/v1/agents/memory/clear');
  final body = <String, dynamic>{
    'agentType': agentType,
    'clearType': clearType,
  };
  _putAgentMemoryProjectRef(
    body,
    projectId: projectId,
    projectUuid: projectUuid,
  );
  if (episodesId != null) body['episodesId'] = episodesId;
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
  if (res.statusCode == 400 || res.statusCode == 404) {
    throw RustApiException.fromHttpResponse(res);
  }
  ensureHttpSuccess(res);
  final map = jsonDecode(res.body) as Map<String, dynamic>;
  return map['ok'] == true;
}

/// `POST /api/v1/agents/memory/optimize` — optimize scoped production video memories without crossing project/script boundaries.
Future<Map<String, dynamic>> optimizeAgentMemory(
  String accessToken, {
  int? projectId,
  String? projectUuid,
  required String agentType,
  required int episodesId,
  String? automationMode,
}) async {
  final uri = Uri.parse('$kApiBaseUrl/api/v1/agents/memory/optimize');
  final body = <String, dynamic>{
    'agentType': agentType,
    'episodesId': episodesId,
  };
  _putAgentMemoryProjectRef(
    body,
    projectId: projectId,
    projectUuid: projectUuid,
  );
  if (automationMode != null && automationMode.isNotEmpty) {
    body['automationMode'] = automationMode;
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
      .timeout(const Duration(seconds: 20));
  if (res.statusCode == 400 || res.statusCode == 404) {
    throw RustApiException.fromHttpResponse(res);
  }
  ensureHttpSuccess(res);
  return jsonDecode(res.body) as Map<String, dynamic>;
}

/// `POST /api/v1/agents/memory/append` — OpenAPI `appendAgentMemoryV1`; returns new message UUID.
Future<String> appendAgentMemory(
  String accessToken, {
  int? projectId,
  String? projectUuid,
  required String agentType,
  required String content,
  int? episodesId,
  String memoryType = 'message',
  String role = 'user',
  String? name,
  int? createTime,
  String? memoryTier,
  Map<String, dynamic>? scopeSignature,
}) async {
  final uri = Uri.parse('$kApiBaseUrl/api/v1/agents/memory/append');
  final body = <String, dynamic>{
    'agentType': agentType,
    'content': content,
    'memoryType': memoryType,
    'role': role,
  };
  _putAgentMemoryProjectRef(
    body,
    projectId: projectId,
    projectUuid: projectUuid,
  );
  if (episodesId != null) body['episodesId'] = episodesId;
  if (name != null) body['name'] = name;
  if (createTime != null) body['createTime'] = createTime;
  if (memoryTier != null && memoryTier.isNotEmpty) {
    body['memoryTier'] = memoryTier;
  }
  if (scopeSignature != null && scopeSignature.isNotEmpty) {
    body['scopeSignature'] = scopeSignature;
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
      .timeout(const Duration(seconds: 20));
  if (res.statusCode == 400 || res.statusCode == 404) {
    throw RustApiException.fromHttpResponse(res);
  }
  ensureHttpSuccess(res);
  final map = jsonDecode(res.body) as Map<String, dynamic>;
  return map['id'] as String;
}
