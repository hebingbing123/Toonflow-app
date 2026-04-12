part of '../../production.dart';

/// `POST /api/v1/production/storyboard/add` — OpenAPI `postStoryboardAddV1`.
Future<StoryboardAddResponse> postStoryboardAddV1(
  String accessToken, {
  required int projectId,
  required int scriptId,
  required String prompt,
  int? duration,
}) async {
  final uri = Uri.parse('$kApiBaseUrl/api/v1/production/storyboard/add');
  final body = <String, dynamic>{
    'projectId': projectId,
    'scriptId': scriptId,
    'prompt': prompt,
  };
  if (duration != null) body['duration'] = duration;
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
    throw RustApiException(res.body, statusCode: res.statusCode);
  }
  if (res.statusCode != 200) {
    throw RustApiException(res.body, statusCode: res.statusCode);
  }
  final map = jsonDecode(res.body) as Map<String, dynamic>;
  return StoryboardAddResponse.fromJson(map);
}

/// `POST /api/v1/production/storyboard/batch-add-info` — OpenAPI `postStoryboardBatchAddInfoV1`.
Future<StoryboardBatchAddInfoResponse> postStoryboardBatchAddInfoV1(
  String accessToken, {
  required int projectId,
  required int scriptId,
  required List<StoryboardBatchAddInfoItem> storyboards,
}) async {
  final uri = Uri.parse(
    '$kApiBaseUrl/api/v1/production/storyboard/batch-add-info',
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
          'storyboards': storyboards.map((e) => e.toJson()).toList(),
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
  return StoryboardBatchAddInfoResponse.fromJson(map);
}

/// `POST /api/v1/production/storyboard/edit-info` — OpenAPI `postStoryboardEditInfoV1`.
Future<int> postStoryboardEditInfoV1(
  String accessToken, {
  required int projectId,
  required int scriptId,
  required int storyboardId,
  required String prompt,
  int? duration,
}) async {
  final uri = Uri.parse('$kApiBaseUrl/api/v1/production/storyboard/edit-info');
  final body = <String, dynamic>{
    'projectId': projectId,
    'scriptId': scriptId,
    'storyboardId': storyboardId,
    'prompt': prompt,
  };
  if (duration != null) body['duration'] = duration;
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
    throw RustApiException(res.body, statusCode: res.statusCode);
  }
  return res.statusCode;
}

/// `POST /api/v1/production/storyboard/get-data` — OpenAPI `postStoryboardGetDataV1`.
Future<ProductionStoryboardItemV1> postStoryboardGetDataV1(
  String accessToken, {
  required int projectId,
  required int scriptId,
  required int storyboardId,
}) async {
  final uri = Uri.parse('$kApiBaseUrl/api/v1/production/storyboard/get-data');
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
  return ProductionStoryboardItemV1.fromJson(map);
}

/// `POST /api/v1/production/storyboard/remove-frame` — OpenAPI `postStoryboardRemoveFrameV1`.
Future<int> postStoryboardRemoveFrameV1(
  String accessToken, {
  required int projectId,
  required int scriptId,
  required int storyboardId,
}) async {
  final uri = Uri.parse(
    '$kApiBaseUrl/api/v1/production/storyboard/remove-frame',
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
  return res.statusCode;
}

/// `POST /api/v1/production/get-storyboard-data` — OpenAPI `postProductionGetStoryboardDataV1`.
Future<ProductionGetProductionDataResponseV1> postProductionGetStoryboardDataV1(
  String accessToken, {
  required int projectId,
  required int scriptId,
}) async {
  final uri = Uri.parse('$kApiBaseUrl/api/v1/production/get-storyboard-data');
  final res = await http
      .post(
        uri,
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'projectId': projectId, 'scriptId': scriptId}),
      )
      .timeout(const Duration(seconds: 15));
  if (res.statusCode == 400 || res.statusCode == 404) {
    throw RustApiException(res.body, statusCode: res.statusCode);
  }
  if (res.statusCode != 200) {
    throw RustApiException(res.body, statusCode: res.statusCode);
  }
  final map = jsonDecode(res.body) as Map<String, dynamic>;
  return ProductionGetProductionDataResponseV1.fromJson(map);
}
