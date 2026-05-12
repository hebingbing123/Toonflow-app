import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../config.dart';
import '../../core.dart';
import '../project_scope.dart';
import 'models.dart';

/// `POST /api/v1/production/assets/batch-generate-assets-image` — OpenAPI `postAssetsBatchGenerateAssetsImageV1`.
///
/// Prefer **`projectUuid`** (`app_project.id`); **`projectId`** is legacy numeric id.
Future<BatchGenerateAssetsImageResponseV1>
postProductionAssetsBatchGenerateAssetsImageV1(
  String accessToken, {
  int? projectId,
  String? projectUuid,
  required int scriptId,
  required List<int> assetIds,
  String? model,
  String? resolution,
}) async {
  final uri = Uri.parse(
    '$kApiBaseUrl/api/v1/production/assets/batch-generate-assets-image',
  );
  final body = buildProductionProjectScopeBodyV1(
    base: <String, dynamic>{'scriptId': scriptId, 'assetIds': assetIds},
    projectId: projectId,
    projectUuid: projectUuid,
  );
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
    throw RustApiException.fromHttpResponse(res);
  }
  ensureHttpSuccess(res);
  final map = jsonDecode(res.body) as Map<String, dynamic>;
  return BatchGenerateAssetsImageResponseV1.fromJson(map);
}

/// `POST /api/v1/production/assets/delete-assets-derivative` — OpenAPI `postAssetsDeleteAssetsDerivativeV1`.
///
/// Prefer **`projectUuid`** (`app_project.id`); **`projectId`** is legacy numeric id.
Future<DeleteAssetsDerivativeResponseV1>
postProductionAssetsDeleteAssetsDerivativeV1(
  String accessToken, {
  int? projectId,
  String? projectUuid,
  required int scriptId,
  required List<int> assetIds,
}) async {
  final uri = Uri.parse(
    '$kApiBaseUrl/api/v1/production/assets/delete-assets-derivative',
  );
  final body = buildProductionProjectScopeBodyV1(
    base: <String, dynamic>{'scriptId': scriptId, 'assetIds': assetIds},
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
      .timeout(const Duration(seconds: 30));
  if (res.statusCode == 400 || res.statusCode == 404) {
    throw RustApiException.fromHttpResponse(res);
  }
  ensureHttpSuccess(res);
  final map = jsonDecode(res.body) as Map<String, dynamic>;
  return DeleteAssetsDerivativeResponseV1.fromJson(map);
}

/// `POST /api/v1/production/assets/get-assets-data` — OpenAPI `postAssetsGetAssetsDataV1`.
///
/// Prefer **`projectUuid`** (`app_project.id`); **`projectId`** is legacy numeric id.
Future<AssetsDataResponseV1> postProductionAssetsGetAssetsDataV1(
  String accessToken, {
  int? projectId,
  String? projectUuid,
  required int scriptId,
  String? assetType,
  int limit = 50,
  int offset = 0,
}) async {
  final uri = Uri.parse(
    '$kApiBaseUrl/api/v1/production/assets/get-assets-data',
  );
  final body = buildProductionProjectScopeBodyV1(
    base: <String, dynamic>{
      'scriptId': scriptId,
      'limit': limit,
      'offset': offset,
    },
    projectId: projectId,
    projectUuid: projectUuid,
  );
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
    throw RustApiException.fromHttpResponse(res);
  }
  ensureHttpSuccess(res);
  final map = jsonDecode(res.body) as Map<String, dynamic>;
  return AssetsDataResponseV1.fromJson(map);
}

/// `POST /api/v1/production/assets/polling-image` — OpenAPI `postAssetsPollingImageV1`.
///
/// Prefer **`projectUuid`** (`app_project.id`); **`projectId`** is legacy numeric id.
Future<AssetsPollingImageResponseV1> postProductionAssetsPollingImageV1(
  String accessToken, {
  int? projectId,
  String? projectUuid,
  required int scriptId,
  required List<int> assetIds,
}) async {
  final uri = Uri.parse('$kApiBaseUrl/api/v1/production/assets/polling-image');
  final body = buildProductionProjectScopeBodyV1(
    base: <String, dynamic>{'scriptId': scriptId, 'assetIds': assetIds},
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
  return AssetsPollingImageResponseV1.fromJson(map);
}

/// `POST /api/v1/production/assets/update-assets-url` — OpenAPI `postAssetsUpdateAssetsUrlV1`.
///
/// Prefer **`projectUuid`** (`app_project.id`); **`projectId`** is legacy numeric id.
Future<UpdateAssetsUrlResponseV1> postProductionAssetsUpdateAssetsUrlV1(
  String accessToken, {
  int? projectId,
  String? projectUuid,
  required int scriptId,
  required int assetId,
  required String imageUrl,
}) async {
  final uri = Uri.parse(
    '$kApiBaseUrl/api/v1/production/assets/update-assets-url',
  );
  final body = buildProductionProjectScopeBodyV1(
    base: <String, dynamic>{
      'scriptId': scriptId,
      'assetId': assetId,
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
  return UpdateAssetsUrlResponseV1.fromJson(map);
}
