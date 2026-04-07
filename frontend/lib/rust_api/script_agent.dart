part of 'index.dart';

/// `POST /api/v1/script-agent/get-plan-data` — OpenAPI `postScriptAgentGetPlanDataV1` (typically **501**).
Future<int> postScriptAgentGetPlanDataV1(
  String accessToken, {
  required int projectId,
}) async {
  final uri = Uri.parse('$kApiBaseUrl/api/v1/script-agent/get-plan-data');
  final res = await http
      .post(
        uri,
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'projectId': projectId, 'agentType': 'scriptAgent'}),
      )
      .timeout(const Duration(seconds: 15));
  return res.statusCode;
}

/// `POST /api/v1/script-agent/set-plan-data` — OpenAPI `postScriptAgentSetPlanDataV1` (typically **501**).
Future<int> postScriptAgentSetPlanDataV1(
  String accessToken, {
  required int projectId,
  String storySkeleton = '',
  String adaptationStrategy = '',
  List<Map<String, dynamic>> script = const [],
}) async {
  final uri = Uri.parse('$kApiBaseUrl/api/v1/script-agent/set-plan-data');
  final res = await http
      .post(
        uri,
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'projectId': projectId,
          'agentType': 'scriptAgent',
          'data': {
            'storySkeleton': storySkeleton,
            'adaptationStrategy': adaptationStrategy,
            'script': script,
          },
        }),
      )
      .timeout(const Duration(seconds: 15));
  return res.statusCode;
}

/// `POST /api/v1/script-agent/update-data` — OpenAPI `postScriptAgentUpdateDataV1` (typically **501**).
Future<int> postScriptAgentUpdateDataV1(
  String accessToken, {
  required int id,
  String storySkeleton = '',
  String adaptationStrategy = '',
  List<Map<String, dynamic>> script = const [
    {'id': 1, 'content': ''},
  ],
}) async {
  final uri = Uri.parse('$kApiBaseUrl/api/v1/script-agent/update-data');
  final res = await http
      .post(
        uri,
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'id': id,
          'data': {
            'storySkeleton': storySkeleton,
            'adaptationStrategy': adaptationStrategy,
            'script': script,
          },
        }),
      )
      .timeout(const Duration(seconds: 15));
  return res.statusCode;
}
