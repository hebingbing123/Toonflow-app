part of '../index.dart';

/// Agent memory query, append, and clear endpoints.
/// `POST /api/v1/agents/memory/query` — camelCase body; see `queryAgentMemoryV1`.
Future<List<dynamic>> queryAgentMemory(
  String accessToken, {
  required int projectId,
  required String agentType,
  int? episodesId,
}) async {
  final uri = Uri.parse('$kApiBaseUrl/api/v1/agents/memory/query');
  final body = <String, dynamic>{
    'projectId': projectId,
    'agentType': agentType,
    'episodesId': episodesId,
  };
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
  if (res.statusCode != 200) {
    throw RustApiException(res.body, statusCode: res.statusCode);
  }
  return jsonDecode(res.body) as List<dynamic>;
}

/// `POST /api/v1/agents/memory/clear` — OpenAPI `clearAgentMemoryV1` (**`clearType`**: `all` | `message` | `summary`).
///
/// Alternate field **`type`** is also accepted by the server as an alias for **`clearType`**.
Future<bool> clearAgentMemory(
  String accessToken, {
  required int projectId,
  required String agentType,
  int? episodesId,
  String clearType = 'all',
}) async {
  final uri = Uri.parse('$kApiBaseUrl/api/v1/agents/memory/clear');
  final body = <String, dynamic>{
    'projectId': projectId,
    'agentType': agentType,
    'clearType': clearType,
  };
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
    throw RustApiException(res.body, statusCode: res.statusCode);
  }
  if (res.statusCode != 200) {
    throw RustApiException(res.body, statusCode: res.statusCode);
  }
  final map = jsonDecode(res.body) as Map<String, dynamic>;
  return map['ok'] == true;
}

/// `POST /api/v1/agents/memory/append` — OpenAPI `appendAgentMemoryV1`; returns new message UUID.
Future<String> appendAgentMemory(
  String accessToken, {
  required int projectId,
  required String agentType,
  required String content,
  int? episodesId,
  String role = 'user',
  String? name,
  int? createTime,
}) async {
  final uri = Uri.parse('$kApiBaseUrl/api/v1/agents/memory/append');
  final body = <String, dynamic>{
    'projectId': projectId,
    'agentType': agentType,
    'content': content,
    'role': role,
  };
  if (episodesId != null) body['episodesId'] = episodesId;
  if (name != null) body['name'] = name;
  if (createTime != null) body['createTime'] = createTime;
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
    throw RustApiException(res.body, statusCode: res.statusCode);
  }
  if (res.statusCode != 200) {
    throw RustApiException(res.body, statusCode: res.statusCode);
  }
  final map = jsonDecode(res.body) as Map<String, dynamic>;
  return map['id'] as String;
}
