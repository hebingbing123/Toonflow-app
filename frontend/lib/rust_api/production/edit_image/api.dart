import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../config.dart';
import '../../core.dart';
import '../project_scope.dart';
import 'models.dart';

/// `POST /api/v1/production/edit-image/get-image-flow` — OpenAPI `postEditImageGetImageFlowV1`.
Future<ImageFlowResponseV1> postProductionEditImageGetImageFlowV1(
  String accessToken,
) async {
  final uri = Uri.parse(
    '$kApiBaseUrl/api/v1/production/edit-image/get-image-flow',
  );
  final res = await http
      .post(
        uri,
        headers: rustApiJsonAuthHeaders(accessToken),
        body: jsonEncode({}),
      )
      .timeout(const Duration(seconds: 15));
  ensureHttpSuccess(res);
  final map = jsonDecode(res.body) as Map<String, dynamic>;
  return ImageFlowResponseV1.fromJson(map);
}

/// `POST /api/v1/production/edit-image/get-image-default-model` — OpenAPI `postEditImageGetImageDefaultModelV1`.
Future<ImageDefaultModelResponseV1>
postProductionEditImageGetImageDefaultModelV1(String accessToken) async {
  final uri = Uri.parse(
    '$kApiBaseUrl/api/v1/production/edit-image/get-image-default-model',
  );
  final res = await http
      .post(
        uri,
        headers: rustApiJsonAuthHeaders(accessToken),
        body: jsonEncode({}),
      )
      .timeout(const Duration(seconds: 15));
  ensureHttpSuccess(res);
  final map = jsonDecode(res.body) as Map<String, dynamic>;
  return ImageDefaultModelResponseV1.fromJson(map);
}

/// `POST /api/v1/production/edit-image/save-image-flow` — OpenAPI `postEditImageSaveImageFlowV1`.
Future<SaveImageFlowResponseV1> postProductionEditImageSaveImageFlowV1(
  String accessToken, {
  required String flowId,
  required List<Map<String, dynamic>> steps,
}) async {
  final uri = Uri.parse(
    '$kApiBaseUrl/api/v1/production/edit-image/save-image-flow',
  );
  final res = await http
      .post(
        uri,
        headers: rustApiJsonAuthHeaders(accessToken),
        body: jsonEncode({'flowId': flowId, 'steps': steps}),
      )
      .timeout(const Duration(seconds: 15));
  if (res.statusCode == 400) {
    throw RustApiException.fromHttpResponse(res);
  }
  ensureHttpSuccess(res);
  final map = jsonDecode(res.body) as Map<String, dynamic>;
  return SaveImageFlowResponseV1.fromJson(map);
}

/// `POST /api/v1/production/edit-image/update-image-flow` — OpenAPI `postEditImageUpdateImageFlowV1`.
Future<UpdateImageFlowResponseV1> postProductionEditImageUpdateImageFlowV1(
  String accessToken, {
  required String flowId,
  required String stepId,
  required Map<String, dynamic> updates,
}) async {
  final uri = Uri.parse(
    '$kApiBaseUrl/api/v1/production/edit-image/update-image-flow',
  );
  final res = await http
      .post(
        uri,
        headers: rustApiJsonAuthHeaders(accessToken),
        body: jsonEncode({
          'flowId': flowId,
          'stepId': stepId,
          'updates': updates,
        }),
      )
      .timeout(const Duration(seconds: 15));
  if (res.statusCode == 400) {
    throw RustApiException.fromHttpResponse(res);
  }
  ensureHttpSuccess(res);
  final map = jsonDecode(res.body) as Map<String, dynamic>;
  return UpdateImageFlowResponseV1.fromJson(map);
}

/// `POST /api/v1/production/edit-image/generate-flow-image` — OpenAPI `postEditImageGenerateFlowImageV1`.
///
/// Prefer **`projectUuid`** (`app_project.id`); **`projectId`** is legacy numeric id.
Future<GenerateFlowImageResponseV1> postProductionEditImageGenerateFlowImageV1(
  String accessToken, {
  int? projectId,
  String? projectUuid,
  required int scriptId,
  required String flowId,
  required String prompt,
  String? model,
}) async {
  final uri = Uri.parse(
    '$kApiBaseUrl/api/v1/production/edit-image/generate-flow-image',
  );
  final body = buildProductionProjectScopeBodyV1(
    base: <String, dynamic>{
      'scriptId': scriptId,
      'flowId': flowId,
      'prompt': prompt,
    },
    projectId: projectId,
    projectUuid: projectUuid,
  );
  if (model != null) body['model'] = model;
  final res = await http
      .post(
        uri,
        headers: rustApiJsonAuthHeaders(accessToken),
        body: jsonEncode(body),
      )
      .timeout(const Duration(seconds: 30));
  if (res.statusCode == 400) {
    throw RustApiException.fromHttpResponse(res);
  }
  ensureHttpSuccess(res);
  final map = jsonDecode(res.body) as Map<String, dynamic>;
  return GenerateFlowImageResponseV1.fromJson(map);
}

/// `POST /api/v1/production/edit-image/upload-image` — OpenAPI `postProductionEditImageUploadImageV1`.
///
/// Prefer **`projectUuid`** (`app_project.id`); **`projectId`** is legacy numeric id.
Future<EditImageUploadImageResponseV1> postProductionEditImageUploadImageV1(
  String accessToken, {
  int? projectId,
  String? projectUuid,
  required int scriptId,
  required String base64Data,
}) async {
  final uri = Uri.parse(
    '$kApiBaseUrl/api/v1/production/edit-image/upload-image',
  );
  final body = buildProductionProjectScopeBodyV1(
    base: <String, dynamic>{
      'scriptId': scriptId,
      'base64Data': base64Data,
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
      .timeout(const Duration(seconds: 30));
  if (res.statusCode == 400 || res.statusCode == 404) {
    throw RustApiException.fromHttpResponse(res);
  }
  ensureHttpSuccess(res);
  final map = jsonDecode(res.body) as Map<String, dynamic>;
  return EditImageUploadImageResponseV1.fromJson(map);
}
