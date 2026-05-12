import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../config.dart';
import '../../core.dart';
import 'project_scope.dart';

class UpdateStoryboardUrlResponseV1 {
  const UpdateStoryboardUrlResponseV1({
    required this.storyboardId,
    required this.imageUrl,
    required this.message,
  });

  final int storyboardId;
  final String imageUrl;
  final String message;

  factory UpdateStoryboardUrlResponseV1.fromJson(Map<String, dynamic> json) {
    return UpdateStoryboardUrlResponseV1(
      storyboardId: (json['storyboardId'] as num).toInt(),
      imageUrl: json['imageUrl'] as String,
      message: json['message'] as String,
    );
  }
}

/// `POST /api/v1/production/storyboard/update-url` — OpenAPI `postStoryboardUpdateUrlV1`.
Future<UpdateStoryboardUrlResponseV1> postStoryboardUpdateUrlV1(
  String accessToken, {
  int? projectId,
  String? projectUuid,
  required int scriptId,
  required int storyboardId,
  required String imageUrl,
}) async {
  final uri = Uri.parse('$kApiBaseUrl/api/v1/production/storyboard/update-url');
  final body = buildStoryboardProjectScopeBodyV1(
    base: <String, dynamic>{
      'scriptId': scriptId,
      'storyboardId': storyboardId,
      'imageUrl': imageUrl,
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
  return UpdateStoryboardUrlResponseV1.fromJson(map);
}

class PreviewImageResponseV1 {
  const PreviewImageResponseV1({
    required this.storyboardId,
    this.imageUrl,
    this.prompt,
  });

  final int storyboardId;
  final String? imageUrl;
  final String? prompt;

  factory PreviewImageResponseV1.fromJson(Map<String, dynamic> json) {
    return PreviewImageResponseV1(
      storyboardId: (json['storyboardId'] as num).toInt(),
      imageUrl: json['imageUrl'] as String?,
      prompt: json['prompt'] as String?,
    );
  }
}

/// `POST /api/v1/production/storyboard/preview-image` — OpenAPI `postStoryboardPreviewImageV1`.
Future<PreviewImageResponseV1> postStoryboardPreviewImageV1(
  String accessToken, {
  int? projectId,
  String? projectUuid,
  required int scriptId,
  required int storyboardId,
}) async {
  final uri = Uri.parse(
    '$kApiBaseUrl/api/v1/production/storyboard/preview-image',
  );
  final body = buildStoryboardProjectScopeBodyV1(
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
  return PreviewImageResponseV1.fromJson(map);
}

class DownPreviewImageResponseV1 {
  const DownPreviewImageResponseV1({
    required this.storyboardId,
    this.previewUrl,
    required this.message,
  });

  final int storyboardId;
  final String? previewUrl;
  final String message;

  factory DownPreviewImageResponseV1.fromJson(Map<String, dynamic> json) {
    return DownPreviewImageResponseV1(
      storyboardId: (json['storyboardId'] as num).toInt(),
      previewUrl: json['previewUrl'] as String?,
      message: json['message'] as String,
    );
  }
}

/// `POST /api/v1/production/storyboard/down-preview-image` — OpenAPI `postStoryboardDownPreviewImageV1`.
Future<DownPreviewImageResponseV1> postStoryboardDownPreviewImageV1(
  String accessToken, {
  int? projectId,
  String? projectUuid,
  required int scriptId,
  required int storyboardId,
}) async {
  final uri = Uri.parse(
    '$kApiBaseUrl/api/v1/production/storyboard/down-preview-image',
  );
  final body = buildStoryboardProjectScopeBodyV1(
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
  return DownPreviewImageResponseV1.fromJson(map);
}
