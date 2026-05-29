import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../config.dart';
import '../../core.dart';
import 'models.dart';
import 'project_scope.dart';

/// `POST /api/v1/production/storyboard/add` — OpenAPI `postStoryboardAddV1`.
///
/// Prefer **`projectUuid`** (`app_project.id`); **`projectId`** is legacy numeric id.
Future<StoryboardAddResponse> postStoryboardAddV1(
  String accessToken, {
  int? projectId,
  String? projectUuid,
  required int scriptId,
  required String prompt,
  int? duration,
}) async {
  final uri = Uri.parse('$kApiBaseUrl/api/v1/production/storyboard/add');
  final body = buildStoryboardProjectScopeBodyV1(
    base: <String, dynamic>{'scriptId': scriptId, 'prompt': prompt},
    projectId: projectId,
    projectUuid: projectUuid,
  );
  if (duration != null) body['duration'] = duration;
  final res = await http
      .post(
        uri,
        headers: rustApiJsonAuthHeaders(accessToken),
        body: jsonEncode(body),
      )
      .timeout(const Duration(seconds: 15));
  if (res.statusCode == 400 || res.statusCode == 404) {
    throw RustApiException.fromHttpResponse(res);
  }
  ensureHttpSuccess(res);
  final map = jsonDecode(res.body) as Map<String, dynamic>;
  return StoryboardAddResponse.fromJson(map);
}

/// `POST /api/v1/production/storyboard/batch-add-info` — OpenAPI `postStoryboardBatchAddInfoV1`.
///
/// Prefer **`projectUuid`** (`app_project.id`); **`projectId`** is legacy numeric id.
Future<StoryboardBatchAddInfoResponse> postStoryboardBatchAddInfoV1(
  String accessToken, {
  int? projectId,
  String? projectUuid,
  required int scriptId,
  required List<StoryboardBatchAddInfoItem> storyboards,
}) async {
  final uri = Uri.parse(
    '$kApiBaseUrl/api/v1/production/storyboard/batch-add-info',
  );
  final body = buildStoryboardProjectScopeBodyV1(
    base: <String, dynamic>{
      'scriptId': scriptId,
      'storyboards': storyboards.map((e) => e.toJson()).toList(),
    },
    projectId: projectId,
    projectUuid: projectUuid,
  );
  final res = await http
      .post(
        uri,
        headers: rustApiJsonAuthHeaders(accessToken),
        body: jsonEncode(body),
      )
      .timeout(const Duration(seconds: 15));
  if (res.statusCode == 400 || res.statusCode == 404) {
    throw RustApiException.fromHttpResponse(res);
  }
  ensureHttpSuccess(res);
  final map = jsonDecode(res.body) as Map<String, dynamic>;
  return StoryboardBatchAddInfoResponse.fromJson(map);
}

/// `POST /api/v1/production/storyboard/edit-info` — OpenAPI `postStoryboardEditInfoV1`.
///
/// Prefer **`projectUuid`** (`app_project.id`); **`projectId`** is legacy numeric id.
Future<int> postStoryboardEditInfoV1(
  String accessToken, {
  int? projectId,
  String? projectUuid,
  required int scriptId,
  required int storyboardId,
  required String prompt,
  int? duration,
}) async {
  final uri = Uri.parse('$kApiBaseUrl/api/v1/production/storyboard/edit-info');
  final body = buildStoryboardProjectScopeBodyV1(
    base: <String, dynamic>{
      'scriptId': scriptId,
      'storyboardId': storyboardId,
      'prompt': prompt,
    },
    projectId: projectId,
    projectUuid: projectUuid,
  );
  if (duration != null) body['duration'] = duration;
  final res = await http
      .post(
        uri,
        headers: rustApiJsonAuthHeaders(accessToken),
        body: jsonEncode(body),
      )
      .timeout(const Duration(seconds: 15));
  if (res.statusCode == 400 || res.statusCode == 404) {
    throw RustApiException.fromHttpResponse(res);
  }
  return res.statusCode;
}

/// `POST /api/v1/production/storyboard/get-data` — OpenAPI `postStoryboardGetDataV1`.
///
/// Prefer **`projectUuid`** (`app_project.id`); **`projectId`** is legacy numeric id.
Future<ProductionStoryboardItemV1> postStoryboardGetDataV1(
  String accessToken, {
  int? projectId,
  String? projectUuid,
  required int scriptId,
  required int storyboardId,
}) async {
  final uri = Uri.parse('$kApiBaseUrl/api/v1/production/storyboard/get-data');
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
        headers: rustApiJsonAuthHeaders(accessToken),
        body: jsonEncode(body),
      )
      .timeout(const Duration(seconds: 15));
  if (res.statusCode == 400 || res.statusCode == 404) {
    throw RustApiException.fromHttpResponse(res);
  }
  ensureHttpSuccess(res);
  final map = jsonDecode(res.body) as Map<String, dynamic>;
  return ProductionStoryboardItemV1.fromJson(map);
}

/// `POST /api/v1/production/storyboard/remove-frame` — OpenAPI `postStoryboardRemoveFrameV1`.
Future<int> postStoryboardRemoveFrameV1(
  String accessToken, {
  int? projectId,
  String? projectUuid,
  required int scriptId,
  required int storyboardId,
}) async {
  final uri = Uri.parse(
    '$kApiBaseUrl/api/v1/production/storyboard/remove-frame',
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
        headers: rustApiJsonAuthHeaders(accessToken),
        body: jsonEncode(body),
      )
      .timeout(const Duration(seconds: 15));
  if (res.statusCode == 400 || res.statusCode == 404) {
    throw RustApiException.fromHttpResponse(res);
  }
  return res.statusCode;
}

class UpdateStoryboardLiveActionReferenceResponseV1 {
  const UpdateStoryboardLiveActionReferenceResponseV1({
    required this.storyboardId,
    required this.referenceShotUrls,
    this.performanceNotes,
    required this.message,
  });

  final int storyboardId;
  final List<String> referenceShotUrls;
  final String? performanceNotes;
  final String message;

  factory UpdateStoryboardLiveActionReferenceResponseV1.fromJson(
    Map<String, dynamic> json,
  ) {
    return UpdateStoryboardLiveActionReferenceResponseV1(
      storyboardId: (json['storyboardId'] as num).toInt(),
      referenceShotUrls:
          (json['referenceShotUrls'] as List<dynamic>? ?? const [])
              .map((e) => e.toString())
              .toList(growable: false),
      performanceNotes: json['performanceNotes'] as String?,
      message: json['message'] as String? ?? '',
    );
  }
}

Future<UpdateStoryboardLiveActionReferenceResponseV1>
postStoryboardUpdateLiveActionReferenceV1(
  String accessToken, {
  int? projectId,
  String? projectUuid,
  required int scriptId,
  required int storyboardId,
  required List<String> referenceShotUrls,
  String? performanceNotes,
}) async {
  final uri = Uri.parse(
    '$kApiBaseUrl/api/v1/production/storyboard/update-live-action-reference',
  );
  final body = buildStoryboardProjectScopeBodyV1(
    base: <String, dynamic>{
      'scriptId': scriptId,
      'storyboardId': storyboardId,
      'referenceShotUrls': referenceShotUrls,
      'performanceNotes': performanceNotes,
    },
    projectId: projectId,
    projectUuid: projectUuid,
  );
  final res = await http
      .post(
        uri,
        headers: rustApiJsonAuthHeaders(accessToken),
        body: jsonEncode(body),
      )
      .timeout(const Duration(seconds: 15));
  if (res.statusCode == 400 || res.statusCode == 404) {
    throw RustApiException.fromHttpResponse(res);
  }
  ensureHttpSuccess(res);
  final map = jsonDecode(res.body) as Map<String, dynamic>;
  return UpdateStoryboardLiveActionReferenceResponseV1.fromJson(map);
}

/// `POST /api/v1/production/storyboard/update-duration` — OpenAPI `postStoryboardUpdateDurationV1`.
Future<int> postStoryboardUpdateDurationV1(
  String accessToken, {
  int? projectId,
  String? projectUuid,
  required int scriptId,
  required int storyboardId,
  required int duration,
}) async {
  final uri = Uri.parse(
    '$kApiBaseUrl/api/v1/production/storyboard/update-duration',
  );
  final body = buildStoryboardProjectScopeBodyV1(
    base: <String, dynamic>{
      'scriptId': scriptId,
      'storyboardId': storyboardId,
      'duration': duration,
    },
    projectId: projectId,
    projectUuid: projectUuid,
  );
  final res = await http
      .post(
        uri,
        headers: rustApiJsonAuthHeaders(accessToken),
        body: jsonEncode(body),
      )
      .timeout(const Duration(seconds: 15));
  if (res.statusCode == 400 || res.statusCode == 404) {
    throw RustApiException.fromHttpResponse(res);
  }
  return res.statusCode;
}

/// `POST /api/v1/production/get-storyboard-data` — OpenAPI `postProductionGetStoryboardDataV1`.
/// When [clientDataVersion] matches the server version,
/// [ProductionGetProductionDataResponseV1.unchanged] is true and [data] is empty.
Future<ProductionGetProductionDataResponseV1> postProductionGetStoryboardDataV1(
  String accessToken, {
  int? projectId,
  String? projectUuid,
  required int scriptId,
  String? clientDataVersion,
}) async {
  final uri = Uri.parse('$kApiBaseUrl/api/v1/production/get-storyboard-data');
  final base = <String, dynamic>{'scriptId': scriptId};
  final cached = clientDataVersion?.trim();
  if (cached != null && cached.isNotEmpty) {
    base['clientDataVersion'] = cached;
  }
  final body = buildStoryboardProjectScopeBodyV1(
    base: base,
    projectId: projectId,
    projectUuid: projectUuid,
  );
  final res = await http
      .post(
        uri,
        headers: rustApiJsonAuthHeaders(accessToken),
        body: jsonEncode(body),
      )
      .timeout(const Duration(seconds: 15));
  if (res.statusCode == 400 || res.statusCode == 404) {
    throw RustApiException.fromHttpResponse(res);
  }
  ensureHttpSuccess(res);
  final map = jsonDecode(res.body) as Map<String, dynamic>;
  return ProductionGetProductionDataResponseV1.fromJson(map);
}
