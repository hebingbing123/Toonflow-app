part of 'production.dart';

Future<int> postProductionGetProductionDataV1(
  String accessToken, {
  required List<int> storyboardIds,
}) async {
  final uri = Uri.parse('$kApiBaseUrl/api/v1/production/get-production-data');
  final res = await http
      .post(
        uri,
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'ids': storyboardIds}),
      )
      .timeout(const Duration(seconds: 15));
  return res.statusCode;
}

/// `POST /api/v1/production/get-flow-data` — OpenAPI `postProductionGetFlowDataV1`
/// (implemented in Rust; returns **200/404/503** when DB-gated).
Future<int> postProductionGetFlowDataV1(
  String accessToken, {
  required int projectId,
  required int episodesId,
}) async {
  final uri = Uri.parse('$kApiBaseUrl/api/v1/production/get-flow-data');
  final res = await http
      .post(
        uri,
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'projectId': projectId, 'episodesId': episodesId}),
      )
      .timeout(const Duration(seconds: 15));
  return res.statusCode;
}

/// `POST /api/v1/production/save-flow-data` — OpenAPI `postProductionSaveFlowDataV1`
/// (implemented in Rust; returns **200/404/503** when DB-gated).
Future<int> postProductionSaveFlowDataV1(
  String accessToken, {
  required int projectId,
  required int episodesId,
  Map<String, dynamic> data = const {},
}) async {
  final uri = Uri.parse('$kApiBaseUrl/api/v1/production/save-flow-data');
  final res = await http
      .post(
        uri,
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'projectId': projectId,
          'episodesId': episodesId,
          'data': data,
        }),
      )
      .timeout(const Duration(seconds: 15));
  return res.statusCode;
}

/// `POST /api/v1/production/workbench/generate-video` — OpenAPI `postProductionWorkbenchGenerateVideoV1`
/// (implemented; returns **200** or **404** / **503** when DB-gated).
Future<int> postProductionWorkbenchGenerateVideoV1(
  String accessToken, {
  required int projectId,
  required int scriptId,
  required List<Map<String, dynamic>> uploadData,
  required String prompt,
  required String model,
  required String mode,
  required String resolution,
  required int duration,
  bool? audio,
  required int trackId,
}) async {
  final uri = Uri.parse(
    '$kApiBaseUrl/api/v1/production/workbench/generate-video',
  );
  final body = <String, dynamic>{
    'projectId': projectId,
    'scriptId': scriptId,
    'uploadData': uploadData,
    'prompt': prompt,
    'model': model,
    'mode': mode,
    'resolution': resolution,
    'duration': duration,
    'trackId': trackId,
  };
  if (audio != null) body['audio'] = audio;
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
  return res.statusCode;
}

/// `POST /api/v1/production/storyboard/polling-image` — OpenAPI `postProductionStoryboardPollingImageV1`
/// (implemented; returns **200** or **404** / **503** when DB-gated).
Future<int> postProductionStoryboardPollingImageV1(
  String accessToken, {
  required List<int> ids,
}) async {
  final uri = Uri.parse(
    '$kApiBaseUrl/api/v1/production/storyboard/polling-image',
  );
  final res = await http
      .post(
        uri,
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'ids': ids}),
      )
      .timeout(const Duration(seconds: 15));
  return res.statusCode;
}

/// `POST /api/v1/production/export-image` — OpenAPI `postProductionExportImageV1`
/// (implemented; returns **200** or **404** / **503** when DB-gated).
Future<int> postProductionExportImageV1(
  String accessToken, {
  required List<Map<String, dynamic>> shotId,
}) async {
  final uri = Uri.parse('$kApiBaseUrl/api/v1/production/export-image');
  final res = await http
      .post(
        uri,
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'shotId': shotId}),
      )
      .timeout(const Duration(seconds: 15));
  return res.statusCode;
}
