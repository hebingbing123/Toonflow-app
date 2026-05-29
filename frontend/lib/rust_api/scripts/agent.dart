import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../config.dart';
import '../core.dart';

class ScriptAgentPlanScriptRow {
  const ScriptAgentPlanScriptRow({
    required this.content,
    this.id,
    this.name,
    this.extractState,
  });

  final int? id;
  final String? name;
  final String content;
  final int? extractState;
}

class ScriptAgentPlanData {
  const ScriptAgentPlanData({
    required this.storySkeleton,
    required this.adaptationStrategy,
    required this.scriptRows,
    this.planId,
  });

  final int? planId;
  final String storySkeleton;
  final String adaptationStrategy;
  final List<ScriptAgentPlanScriptRow> scriptRows;
}

ScriptAgentPlanData parseScriptAgentPlanDataResponse(
  Map<String, dynamic> json,
) {
  final rootData = json['data'];
  final nested = switch (rootData) {
    {'data': final Map<String, dynamic> data} => data,
    final Map<String, dynamic> data => data,
    _ => const <String, dynamic>{},
  };
  final planId = switch (rootData) {
    {'id': final num id} => id.toInt(),
    _ => null,
  };
  final scriptRows = ((nested['script'] as List<dynamic>?) ?? const <dynamic>[])
      .whereType<Map<String, dynamic>>()
      .map(
        (row) => ScriptAgentPlanScriptRow(
          id: (row['id'] as num?)?.toInt(),
          name: row['name'] as String?,
          content: (row['content'] as String?) ?? '',
          extractState: (row['extract_state'] as num?)?.toInt(),
        ),
      )
      .toList(growable: false);
  return ScriptAgentPlanData(
    planId: planId,
    storySkeleton:
        (nested['storySkeleton'] as String?) ??
        (nested['story_skeleton'] as String?) ??
        '',
    adaptationStrategy:
        (nested['adaptationStrategy'] as String?) ??
        (nested['adaptation_strategy'] as String?) ??
        '',
    scriptRows: scriptRows,
  );
}

/// Script-agent plan persistence endpoints.
/// `POST /api/v1/script-agent/get-plan-data` — OpenAPI `postScriptAgentGetPlanDataV1` (**200**/**404**/**503**).
Future<int> postScriptAgentGetPlanDataV1(
  String accessToken, {
  required int projectId,
}) async {
  final uri = Uri.parse('$kApiBaseUrl/api/v1/script-agent/get-plan-data');
  final res = await http
      .post(
        uri,
        headers: rustApiJsonAuthHeaders(accessToken),
        body: jsonEncode({'projectId': projectId, 'agentType': 'scriptAgent'}),
      )
      .timeout(const Duration(seconds: 15));
  return res.statusCode;
}

Future<ScriptAgentPlanData> fetchScriptAgentPlanDataV1(
  String accessToken, {
  required int projectId,
}) async {
  final uri = Uri.parse('$kApiBaseUrl/api/v1/script-agent/get-plan-data');
  final res = await http
      .post(
        uri,
        headers: rustApiJsonAuthHeaders(accessToken),
        body: jsonEncode({'projectId': projectId, 'agentType': 'scriptAgent'}),
      )
      .timeout(const Duration(seconds: 15));
  ensureHttpSuccess(res);
  return parseScriptAgentPlanDataResponse(
    jsonDecode(res.body) as Map<String, dynamic>,
  );
}

/// `POST /api/v1/script-agent/set-plan-data` — OpenAPI `postScriptAgentSetPlanDataV1` (**200**/**404**/**503**).
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
        headers: rustApiJsonAuthHeaders(accessToken),
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

/// `POST /api/v1/script-agent/update-data` — OpenAPI `postScriptAgentUpdateDataV1` (**200**/**404**/**503**).
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
        headers: rustApiJsonAuthHeaders(accessToken),
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
