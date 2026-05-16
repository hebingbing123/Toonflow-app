import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../config.dart';
import '../../core.dart';
import 'project_scope.dart';

/// OpenAPI **`BatchGenerateImageItem`** — single item for batch image generation.
class BatchGenerateImageItem {
  const BatchGenerateImageItem({
    required this.storyboardId,
    required this.prompt,
    this.negativePrompt,
    this.model,
    this.resolution,
  });

  final int storyboardId;
  final String prompt;
  final String? negativePrompt;
  final String? model;
  final String? resolution;

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{
      'storyboardId': storyboardId,
      'prompt': prompt,
    };
    if (negativePrompt != null) json['negativePrompt'] = negativePrompt;
    if (model != null) json['model'] = model;
    if (resolution != null) json['resolution'] = resolution;
    return json;
  }
}

/// OpenAPI **`BatchGenerateImageResponse`** — enqueued jobs.
class BatchGenerateImageResponse {
  const BatchGenerateImageResponse({
    required this.enqueued,
    required this.total,
  });

  final List<JobRow> enqueued;
  final int total;

  factory BatchGenerateImageResponse.fromJson(Map<String, dynamic> json) {
    final raw = json['enqueued'] as List<dynamic>? ?? const [];
    return BatchGenerateImageResponse(
      enqueued: raw
          .map((e) => JobRow.fromJson(e as Map<String, dynamic>))
          .toList(),
      total: (json['total'] as num).toInt(),
    );
  }
}

/// `POST /api/v1/production/storyboard/batch-generate-image` — OpenAPI `postStoryboardBatchGenerateImageV1`.
Future<BatchGenerateImageResponse> postStoryboardBatchGenerateImageV1(
  String accessToken, {
  int? projectId,
  String? projectUuid,
  required int scriptId,
  required List<BatchGenerateImageItem> items,
  String? model,
  String? resolution,
}) async {
  final uri = Uri.parse(
    '$kApiBaseUrl/api/v1/production/storyboard/batch-generate-image',
  );
  final body = buildStoryboardProjectScopeBodyV1(
    base: <String, dynamic>{
      'scriptId': scriptId,
      'items': items.map((e) => e.toJson()).toList(),
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
