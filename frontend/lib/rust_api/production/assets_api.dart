part of '../production.dart';

/// `POST /api/v1/production/assets/batch-generate-assets-image` — OpenAPI `postAssetsBatchGenerateAssetsImageV1`.
Future<BatchGenerateAssetsImageResponseV1>
postProductionAssetsBatchGenerateAssetsImageV1(
  String accessToken, {
  required int projectId,
  required int scriptId,
  required List<int> assetIds,
  String? model,
  String? resolution,
}) async {
  final uri = Uri.parse(
    '$kApiBaseUrl/api/v1/production/assets/batch-generate-assets-image',
  );
  final body = <String, dynamic>{
    'projectId': projectId,
    'scriptId': scriptId,
    'assetIds': assetIds,
  };
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
    throw RustApiException(res.body, statusCode: res.statusCode);
  }
  if (res.statusCode != 200) {
    throw RustApiException(res.body, statusCode: res.statusCode);
  }
  final map = jsonDecode(res.body) as Map<String, dynamic>;
  return BatchGenerateAssetsImageResponseV1.fromJson(map);
}

/// `POST /api/v1/production/assets/delete-assets-derivative` — OpenAPI `postAssetsDeleteAssetsDerivativeV1`.
Future<DeleteAssetsDerivativeResponseV1>
postProductionAssetsDeleteAssetsDerivativeV1(
  String accessToken, {
  required int projectId,
  required int scriptId,
  required List<int> assetIds,
}) async {
  final uri = Uri.parse(
    '$kApiBaseUrl/api/v1/production/assets/delete-assets-derivative',
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
          'assetIds': assetIds,
        }),
      )
      .timeout(const Duration(seconds: 30));
  if (res.statusCode == 400 || res.statusCode == 404) {
    throw RustApiException(res.body, statusCode: res.statusCode);
  }
  if (res.statusCode != 200) {
    throw RustApiException(res.body, statusCode: res.statusCode);
  }
  final map = jsonDecode(res.body) as Map<String, dynamic>;
  return DeleteAssetsDerivativeResponseV1.fromJson(map);
}

/// `POST /api/v1/production/assets/get-assets-data` — OpenAPI `postAssetsGetAssetsDataV1`.
Future<AssetsDataResponseV1> postProductionAssetsGetAssetsDataV1(
  String accessToken, {
  required int projectId,
  required int scriptId,
  String? assetType,
  int limit = 50,
  int offset = 0,
}) async {
  final uri = Uri.parse(
    '$kApiBaseUrl/api/v1/production/assets/get-assets-data',
  );
  final body = <String, dynamic>{
    'projectId': projectId,
    'scriptId': scriptId,
    'limit': limit,
    'offset': offset,
  };
  if (assetType != null) body['assetType'] = assetType;
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
  return AssetsDataResponseV1.fromJson(map);
}

/// `POST /api/v1/production/assets/polling-image` — OpenAPI `postAssetsPollingImageV1`.
Future<AssetsPollingImageResponseV1> postProductionAssetsPollingImageV1(
  String accessToken, {
  required int projectId,
  required int scriptId,
  required List<int> assetIds,
}) async {
  final uri = Uri.parse('$kApiBaseUrl/api/v1/production/assets/polling-image');
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
          'assetIds': assetIds,
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
  return AssetsPollingImageResponseV1.fromJson(map);
}

/// `POST /api/v1/production/assets/update-assets-url` — OpenAPI `postAssetsUpdateAssetsUrlV1`.
Future<UpdateAssetsUrlResponseV1> postProductionAssetsUpdateAssetsUrlV1(
  String accessToken, {
  required int projectId,
  required int scriptId,
  required int assetId,
  required String imageUrl,
}) async {
  final uri = Uri.parse(
    '$kApiBaseUrl/api/v1/production/assets/update-assets-url',
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
          'assetId': assetId,
          'imageUrl': imageUrl,
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
  return UpdateAssetsUrlResponseV1.fromJson(map);
}
