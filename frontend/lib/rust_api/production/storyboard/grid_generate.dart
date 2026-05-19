import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../config.dart';
import '../../core.dart';
import 'batch.dart';
import 'project_scope.dart';

/// `POST /api/v1/production/storyboard/grid-generate-and-assign`.
Future<BatchGenerateImageResponse> postStoryboardGridGenerateAndAssignV1(
  String accessToken, {
  int? projectId,
  String? projectUuid,
  required int scriptId,
  required int rows,
  required int cols,
  List<int>? storyboardIds,
  String? basePrompt,
  String? model,
  String? resolution,
}) async {
  final uri = Uri.parse(
    '$kApiBaseUrl/api/v1/production/storyboard/grid-generate-and-assign',
  );
  final body = buildStoryboardProjectScopeBodyV1(
    base: <String, dynamic>{
      'scriptId': scriptId,
      'rows': rows,
      'cols': cols,
      if (storyboardIds != null && storyboardIds.isNotEmpty)
        'storyboardIds': storyboardIds,
      if (basePrompt != null && basePrompt.trim().isNotEmpty)
        'basePrompt': basePrompt.trim(),
    },
    projectId: projectId,
    projectUuid: projectUuid,
  );
  if (model != null) body['model'] = model;
  if (resolution != null) body['resolution'] = resolution;

  final res = await http
      .post(
        uri,
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(body),
      )
      .timeout(const Duration(seconds: 30));
  if (res.statusCode == 400 || res.statusCode == 404) {
    throw RustApiException.fromHttpResponse(res);
  }
  ensureHttpSuccess(res);
  final map = jsonDecode(res.body) as Map<String, dynamic>;
  return BatchGenerateImageResponse.fromJson(map);
}

/// Authenticated URL for `/storyboard-local/` frame paths.
Uri storyboardLocalFrameUri({
  required String projectUuid,
  required int scriptId,
  required int storyboardId,
}) {
  return Uri.parse('$kApiBaseUrl/api/v1/production/storyboard/local-frame').replace(
    queryParameters: <String, String>{
      'projectUuid': projectUuid,
      'scriptId': scriptNumericIdToQuery(scriptId),
      'storyboardId': storyboardId.toString(),
    },
  );
}

String storyboardNumericIdToQuery(int id) => id.toString();

String scriptNumericIdToQuery(int id) => id.toString();
