import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../config.dart';
import '../../core.dart';

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
  required int projectId,
  required int scriptId,
  required int storyboardId,
}) async {
  final uri = Uri.parse(
    '$kApiBaseUrl/api/v1/production/workbench/delete-video',
  );
  final res = await http
      .post(
        uri,
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'projectId': projectId,
          'scriptId': scriptId,
          'storyboardId': storyboardId,
        }),
      )
      .timeout(const Duration(seconds: 15));
  if (res.statusCode == 400 || res.statusCode == 404) {
    throw RustApiException(res.body, statusCode: res.statusCode);
  }
  if (res.statusCode != 200) {
    throw RustApiException(res.body, statusCode: res.statusCode);
  }
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
  required int projectId,
  required int scriptId,
  required int storyboardId,
  required String videoUrl,
}) async {
  final uri = Uri.parse(
    '$kApiBaseUrl/api/v1/production/workbench/select-video',
  );
  final res = await http
      .post(
        uri,
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'projectId': projectId,
          'scriptId': scriptId,
          'storyboardId': storyboardId,
          'videoUrl': videoUrl,
        }),
      )
      .timeout(const Duration(seconds: 15));
  if (res.statusCode == 400 || res.statusCode == 404) {
    throw RustApiException(res.body, statusCode: res.statusCode);
  }
  if (res.statusCode != 200) {
    throw RustApiException(res.body, statusCode: res.statusCode);
  }
  final map = jsonDecode(res.body) as Map<String, dynamic>;
  return SelectVideoResponse.fromJson(map);
}
