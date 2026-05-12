import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../config.dart';
import '../../core.dart';
import '../project_scope.dart';

Map<String, dynamic> buildWorkbenchVideoSelectionBodyV1({
  required Map<String, dynamic> base,
  int? projectId,
  String? projectUuid,
}) {
  return buildProductionProjectScopeBodyV1(
    base: base,
    projectId: projectId,
    projectUuid: projectUuid,
  );
}

class WorkbenchVideoMemoryFeedback {
  const WorkbenchVideoMemoryFeedback({
    required this.kind,
    required this.scope,
    this.subject,
    this.style,
    this.note,
    this.avoid,
    this.riskTags = const <String>[],
    this.rejectionCount,
    required this.charCount,
  });

  final String kind;
  final String scope;
  final String? subject;
  final String? style;
  final String? note;
  final String? avoid;
  final List<String> riskTags;
  final int? rejectionCount;
  final int charCount;

  factory WorkbenchVideoMemoryFeedback.fromJson(Map<String, dynamic> json) {
    return WorkbenchVideoMemoryFeedback(
      kind: json['kind'] as String? ?? '',
      scope: json['scope'] as String? ?? '',
      subject: json['subject'] as String?,
      style: json['style'] as String?,
      note: json['note'] as String?,
      avoid: json['avoid'] as String?,
      riskTags: (json['riskTags'] as List<dynamic>? ?? const [])
          .whereType<String>()
          .toList(growable: false),
      rejectionCount: (json['rejectionCount'] as num?)?.toInt(),
      charCount: (json['charCount'] as num?)?.toInt() ?? 0,
    );
  }
}

/// OpenAPI **`DeleteVideoResponse`**.
class DeleteVideoResponse {
  const DeleteVideoResponse({
    required this.storyboardId,
    this.negativeMemory,
    required this.message,
  });

  final int storyboardId;
  final WorkbenchVideoMemoryFeedback? negativeMemory;
  final String message;

  factory DeleteVideoResponse.fromJson(Map<String, dynamic> json) {
    return DeleteVideoResponse(
      storyboardId: (json['storyboardId'] as num).toInt(),
      negativeMemory: (json['negativeMemory'] as Map<String, dynamic>?) == null
          ? null
          : WorkbenchVideoMemoryFeedback.fromJson(
              json['negativeMemory'] as Map<String, dynamic>,
            ),
      message: json['message'] as String,
    );
  }
}

/// `POST /api/v1/production/workbench/delete-video` — OpenAPI `postWorkbenchDeleteVideoV1`.
Future<DeleteVideoResponse> postWorkbenchDeleteVideoV1(
  String accessToken, {
  int? projectId,
  String? projectUuid,
  required int scriptId,
  required int storyboardId,
}) async {
  final uri = Uri.parse(
    '$kApiBaseUrl/api/v1/production/workbench/delete-video',
  );
  final body = buildWorkbenchVideoSelectionBodyV1(
    base: <String, dynamic>{
      'scriptId': scriptId,
      'storyboardId': storyboardId,
    },
    projectId: projectId,
    projectUuid: projectUuid,
  );
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
  if (res.statusCode == 400 || res.statusCode == 404) {
    throw RustApiException.fromHttpResponse(res);
  }
  ensureHttpSuccess(res);
  final map = jsonDecode(res.body) as Map<String, dynamic>;
  return DeleteVideoResponse.fromJson(map);
}

/// OpenAPI **`SelectVideoResponse`**.
class SelectVideoResponse {
  const SelectVideoResponse({
    required this.storyboardId,
    required this.videoUrl,
    this.selectedMemory,
    required this.message,
  });

  final int storyboardId;
  final String videoUrl;
  final WorkbenchVideoMemoryFeedback? selectedMemory;
  final String message;

  factory SelectVideoResponse.fromJson(Map<String, dynamic> json) {
    return SelectVideoResponse(
      storyboardId: (json['storyboardId'] as num).toInt(),
      videoUrl: json['videoUrl'] as String,
      selectedMemory: (json['selectedMemory'] as Map<String, dynamic>?) == null
          ? null
          : WorkbenchVideoMemoryFeedback.fromJson(
              json['selectedMemory'] as Map<String, dynamic>,
            ),
      message: json['message'] as String,
    );
  }
}

/// `POST /api/v1/production/workbench/select-video` — OpenAPI `postWorkbenchSelectVideoV1`.
Future<SelectVideoResponse> postWorkbenchSelectVideoV1(
  String accessToken, {
  int? projectId,
  String? projectUuid,
  required int scriptId,
  required int storyboardId,
  required String videoUrl,
}) async {
  final uri = Uri.parse(
    '$kApiBaseUrl/api/v1/production/workbench/select-video',
  );
  final body = buildWorkbenchVideoSelectionBodyV1(
    base: <String, dynamic>{
      'scriptId': scriptId,
      'storyboardId': storyboardId,
      'videoUrl': videoUrl,
    },
    projectId: projectId,
    projectUuid: projectUuid,
  );
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
  if (res.statusCode == 400 || res.statusCode == 404) {
    throw RustApiException.fromHttpResponse(res);
  }
  ensureHttpSuccess(res);
  final map = jsonDecode(res.body) as Map<String, dynamic>;
  return SelectVideoResponse.fromJson(map);
}

/// Batch operation result for a single storyboard
class BatchOperationResult {
  const BatchOperationResult({
    required this.storyboardId,
    required this.status,
    this.videoUrl,
    this.duration,
    this.error,
  });

  final int storyboardId;
  final String status; // 'success' or 'failed'
  final String? videoUrl;
  final int? duration;
  final String? error;

  factory BatchOperationResult.fromJson(Map<String, dynamic> json) {
    return BatchOperationResult(
      storyboardId: (json['storyboardId'] as num).toInt(),
      status: json['status'] as String,
      videoUrl: json['videoUrl'] as String?,
      duration: (json['duration'] as num?)?.toInt(),
      error: json['error'] as String?,
    );
  }
}

/// OpenAPI **`BatchSelectVideoResponse`**.
class BatchSelectVideoResponse {
  const BatchSelectVideoResponse({
    required this.success,
    required this.failed,
    required this.results,
    required this.message,
  });

  final int success;
  final int failed;
  final List<BatchOperationResult> results;
  final String message;

  factory BatchSelectVideoResponse.fromJson(Map<String, dynamic> json) {
    return BatchSelectVideoResponse(
      success: (json['success'] as num).toInt(),
      failed: (json['failed'] as num).toInt(),
      results: (json['results'] as List<dynamic>)
          .map(
            (item) =>
                BatchOperationResult.fromJson(item as Map<String, dynamic>),
          )
          .toList(growable: false),
      message: json['message'] as String,
    );
  }
}

/// `POST /api/v1/production/workbench/batch-select-video` — OpenAPI `postProductionWorkbenchBatchSelectVideoV1`.
Future<BatchSelectVideoResponse> postProductionWorkbenchBatchSelectVideoV1(
  String accessToken, {
  int? projectId,
  String? projectUuid,
  required int scriptId,
  required List<Map<String, dynamic>> operations,
}) async {
  final uri = Uri.parse(
    '$kApiBaseUrl/api/v1/production/workbench/batch-select-video',
  );
  final body = buildWorkbenchVideoSelectionBodyV1(
    base: <String, dynamic>{
      'scriptId': scriptId,
      'operations': operations,
    },
    projectId: projectId,
    projectUuid: projectUuid,
  );
  final res = await http
      .post(
        uri,
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(body),
      )
      .timeout(const Duration(seconds: 60));
  if (res.statusCode == 400 || res.statusCode == 404) {
    throw RustApiException.fromHttpResponse(res);
  }
  ensureHttpSuccess(res);
  final map = jsonDecode(res.body) as Map<String, dynamic>;
  return BatchSelectVideoResponse.fromJson(map);
}

/// OpenAPI **`BatchDeleteVideoResponse`**.
class BatchDeleteVideoResponse {
  const BatchDeleteVideoResponse({
    required this.success,
    required this.failed,
    required this.results,
    required this.message,
  });

  final int success;
  final int failed;
  final List<BatchOperationResult> results;
  final String message;

  factory BatchDeleteVideoResponse.fromJson(Map<String, dynamic> json) {
    return BatchDeleteVideoResponse(
      success: (json['success'] as num).toInt(),
      failed: (json['failed'] as num).toInt(),
      results: (json['results'] as List<dynamic>)
          .map(
            (item) =>
                BatchOperationResult.fromJson(item as Map<String, dynamic>),
          )
          .toList(growable: false),
      message: json['message'] as String,
    );
  }
}

/// `POST /api/v1/production/workbench/batch-delete-video` — OpenAPI `postProductionWorkbenchBatchDeleteVideoV1`.
Future<BatchDeleteVideoResponse> postProductionWorkbenchBatchDeleteVideoV1(
  String accessToken, {
  int? projectId,
  String? projectUuid,
  required int scriptId,
  required List<int> storyboardIds,
}) async {
  final uri = Uri.parse(
    '$kApiBaseUrl/api/v1/production/workbench/batch-delete-video',
  );
  final body = buildWorkbenchVideoSelectionBodyV1(
    base: <String, dynamic>{
      'scriptId': scriptId,
      'storyboardIds': storyboardIds,
    },
    projectId: projectId,
    projectUuid: projectUuid,
  );
  final res = await http
      .post(
        uri,
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(body),
      )
      .timeout(const Duration(seconds: 60));
  if (res.statusCode == 400 || res.statusCode == 404) {
    throw RustApiException.fromHttpResponse(res);
  }
  ensureHttpSuccess(res);
  final map = jsonDecode(res.body) as Map<String, dynamic>;
  return BatchDeleteVideoResponse.fromJson(map);
}

/// OpenAPI **`BatchUpdateDurationResponse`**.
class BatchUpdateDurationResponse {
  const BatchUpdateDurationResponse({
    required this.success,
    required this.failed,
    required this.results,
    required this.message,
  });

  final int success;
  final int failed;
  final List<BatchOperationResult> results;
  final String message;

  factory BatchUpdateDurationResponse.fromJson(Map<String, dynamic> json) {
    return BatchUpdateDurationResponse(
      success: (json['success'] as num).toInt(),
      failed: (json['failed'] as num).toInt(),
      results: (json['results'] as List<dynamic>)
          .map(
            (item) =>
                BatchOperationResult.fromJson(item as Map<String, dynamic>),
          )
          .toList(growable: false),
      message: json['message'] as String,
    );
  }
}

/// `POST /api/v1/production/workbench/batch-update-duration` — OpenAPI `postProductionWorkbenchBatchUpdateDurationV1`.
Future<BatchUpdateDurationResponse>
postProductionWorkbenchBatchUpdateDurationV1(
  String accessToken, {
  int? projectId,
  String? projectUuid,
  required int scriptId,
  required List<Map<String, dynamic>> operations,
}) async {
  final uri = Uri.parse(
    '$kApiBaseUrl/api/v1/production/workbench/batch-update-duration',
  );
  final body = buildWorkbenchVideoSelectionBodyV1(
    base: <String, dynamic>{
      'scriptId': scriptId,
      'operations': operations,
    },
    projectId: projectId,
    projectUuid: projectUuid,
  );
  final res = await http
      .post(
        uri,
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(body),
      )
      .timeout(const Duration(seconds: 60));
  if (res.statusCode == 400 || res.statusCode == 404) {
    throw RustApiException.fromHttpResponse(res);
  }
  ensureHttpSuccess(res);
  final map = jsonDecode(res.body) as Map<String, dynamic>;
  return BatchUpdateDurationResponse.fromJson(map);
}
