part of 'production.dart';

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
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({}),
      )
      .timeout(const Duration(seconds: 15));
  if (res.statusCode != 200) {
    throw RustApiException(res.body, statusCode: res.statusCode);
  }
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
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({}),
      )
      .timeout(const Duration(seconds: 15));
  if (res.statusCode != 200) {
    throw RustApiException(res.body, statusCode: res.statusCode);
  }
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
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'flowId': flowId, 'steps': steps}),
      )
      .timeout(const Duration(seconds: 15));
  if (res.statusCode == 400) {
    throw RustApiException(res.body, statusCode: 400);
  }
  if (res.statusCode != 200) {
    throw RustApiException(res.body, statusCode: res.statusCode);
  }
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
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'flowId': flowId,
          'stepId': stepId,
          'updates': updates,
        }),
      )
      .timeout(const Duration(seconds: 15));
  if (res.statusCode == 400) {
    throw RustApiException(res.body, statusCode: 400);
  }
  if (res.statusCode != 200) {
    throw RustApiException(res.body, statusCode: res.statusCode);
  }
  final map = jsonDecode(res.body) as Map<String, dynamic>;
  return UpdateImageFlowResponseV1.fromJson(map);
}

/// `POST /api/v1/production/edit-image/generate-flow-image` — OpenAPI `postEditImageGenerateFlowImageV1`.
Future<GenerateFlowImageResponseV1> postProductionEditImageGenerateFlowImageV1(
  String accessToken, {
  required String flowId,
  required String prompt,
  String? model,
}) async {
  final uri = Uri.parse(
    '$kApiBaseUrl/api/v1/production/edit-image/generate-flow-image',
  );
  final body = <String, dynamic>{'flowId': flowId, 'prompt': prompt};
  if (model != null) body['model'] = model;
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
  if (res.statusCode == 400) {
    throw RustApiException(res.body, statusCode: 400);
  }
  if (res.statusCode != 200) {
    throw RustApiException(res.body, statusCode: res.statusCode);
  }
  final map = jsonDecode(res.body) as Map<String, dynamic>;
  return GenerateFlowImageResponseV1.fromJson(map);
}
