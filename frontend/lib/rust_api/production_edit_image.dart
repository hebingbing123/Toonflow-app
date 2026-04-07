part of 'production.dart';

/// OpenAPI **`ImageFlowStep`**.
class ImageFlowStepV1 {
  const ImageFlowStepV1({
    required this.stepId,
    required this.stepName,
    required this.status,
  });

  final String stepId;
  final String stepName;
  final String status;

  factory ImageFlowStepV1.fromJson(Map<String, dynamic> json) {
    return ImageFlowStepV1(
      stepId: json['stepId'] as String,
      stepName: json['stepName'] as String,
      status: json['status'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {'stepId': stepId, 'stepName': stepName, 'status': status};
  }
}

/// OpenAPI **`ImageFlowResponse`**.
class ImageFlowResponseV1 {
  const ImageFlowResponseV1({
    required this.flowId,
    required this.steps,
    required this.defaultModel,
  });

  final String flowId;
  final List<ImageFlowStepV1> steps;
  final String defaultModel;

  factory ImageFlowResponseV1.fromJson(Map<String, dynamic> json) {
    final raw = json['steps'] as List<dynamic>? ?? const [];
    return ImageFlowResponseV1(
      flowId: json['flowId'] as String,
      steps: raw
          .map((e) => ImageFlowStepV1.fromJson(e as Map<String, dynamic>))
          .toList(),
      defaultModel: json['defaultModel'] as String,
    );
  }
}

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

/// OpenAPI **`ImageDefaultModelResponse`**.
class ImageDefaultModelResponseV1 {
  const ImageDefaultModelResponseV1({
    required this.model,
    required this.resolution,
  });

  final String model;
  final String resolution;

  factory ImageDefaultModelResponseV1.fromJson(Map<String, dynamic> json) {
    return ImageDefaultModelResponseV1(
      model: json['model'] as String,
      resolution: json['resolution'] as String,
    );
  }
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

/// OpenAPI **`SaveImageFlowResponse`**.
class SaveImageFlowResponseV1 {
  const SaveImageFlowResponseV1({required this.flowId, required this.saved});

  final String flowId;
  final bool saved;

  factory SaveImageFlowResponseV1.fromJson(Map<String, dynamic> json) {
    return SaveImageFlowResponseV1(
      flowId: json['flowId'] as String,
      saved: json['saved'] as bool,
    );
  }
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

/// OpenAPI **`UpdateImageFlowResponse`**.
class UpdateImageFlowResponseV1 {
  const UpdateImageFlowResponseV1({
    required this.flowId,
    required this.stepId,
    required this.updated,
  });

  final String flowId;
  final String stepId;
  final bool updated;

  factory UpdateImageFlowResponseV1.fromJson(Map<String, dynamic> json) {
    return UpdateImageFlowResponseV1(
      flowId: json['flowId'] as String,
      stepId: json['stepId'] as String,
      updated: json['updated'] as bool,
    );
  }
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

/// OpenAPI **`GenerateFlowImageResponse`**.
class GenerateFlowImageResponseV1 {
  const GenerateFlowImageResponseV1({
    required this.jobId,
    required this.status,
  });

  final String jobId;
  final String status;

  factory GenerateFlowImageResponseV1.fromJson(Map<String, dynamic> json) {
    return GenerateFlowImageResponseV1(
      jobId: json['jobId'] as String,
      status: json['status'] as String,
    );
  }
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
