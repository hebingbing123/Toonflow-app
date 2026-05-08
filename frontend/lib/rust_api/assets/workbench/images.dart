import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../config.dart';
import '../../core.dart';
import '../models/core.dart';
import '../models/images.dart';
import '../models/polling.dart';
import '../models/workbench_data.dart';

/// Workbench-side asset image APIs stay in a dedicated subdomain file so
/// asset image CRUD can remain focused on direct resource operations.

/// `POST /api/v1/projects/{project_id}/assets/workbench/nested` — parent assets with nested `sonAssets` by **`type/name/page/limit`** (**`project_id`** = project UUID).
Future<WorkbenchAssetTreeResponse> postWorkbenchAssetsGetAssetsApi(
  String accessToken, {
  required String projectId,
  required String assetType,
  String? name,
  int page = 1,
  int limit = 10,
}) async {
  final uri = Uri.parse(
    '$kApiBaseUrl/api/v1/projects/$projectId/assets/workbench/nested',
  );
  final payload = <String, dynamic>{
    'type': assetType,
    'page': page,
    'limit': limit,
  };
  if (name != null && name.trim().isNotEmpty) {
    payload['name'] = name.trim();
  }
  final res = await http
      .post(
        uri,
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(payload),
      )
      .timeout(const Duration(seconds: 15));
  if (res.statusCode == 400) {
    throw RustApiException.fromHttpResponse(res);
  }
  ensureHttpSuccess(res);
  final map = jsonDecode(res.body) as Map<String, dynamic>;
  return WorkbenchAssetTreeResponse.fromJson(map);
}

/// `POST …/assets/workbench/image-bundle` — asset image bundle by **`assetsId`** (scoped to **`project_id`** UUID).
Future<WorkbenchImageBundleResponse> postWorkbenchAssetsGetImage(
  String accessToken,
  String projectId,
  int assetNumericId,
) async {
  final uri = Uri.parse(
    '$kApiBaseUrl/api/v1/projects/$projectId/assets/workbench/image-bundle',
  );
  final res = await http
      .post(
        uri,
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'assetsId': assetNumericId}),
      )
      .timeout(const Duration(seconds: 15));
  if (res.statusCode == 400) {
    throw RustApiException.fromHttpResponse(res);
  }
  if (res.statusCode == 404) {
    throw RustApiException('not found', statusCode: 404);
  }
  ensureHttpSuccess(res);
  final map = jsonDecode(res.body) as Map<String, dynamic>;
  return WorkbenchImageBundleResponse.fromJson(map);
}

/// `POST …/assets/workbench/upload-clip` — upload clip asset (**`base64Data`**, **`name`**, optional **`type`** = clip).
Future<WorkbenchAssetUploadClipResponse> postWorkbenchAssetsUploadClip(
  String accessToken, {
  required String projectId,
  required String base64Data,
  required String name,
  String assetType = 'clip',
}) async {
  final uri = Uri.parse(
    '$kApiBaseUrl/api/v1/projects/$projectId/assets/workbench/upload-clip',
  );
  final res = await http
      .post(
        uri,
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'base64Data': base64Data,
          'type': assetType,
          'name': name,
        }),
      )
      .timeout(const Duration(seconds: 30));
  if (res.statusCode == 400) {
    throw RustApiException.fromHttpResponse(res);
  }
  if (res.statusCode == 404) {
    throw RustApiException('not found', statusCode: 404);
  }
  ensureHttpSuccess(res);
  final map = jsonDecode(res.body) as Map<String, dynamic>;
  return WorkbenchAssetUploadClipResponse.fromJson(map);
}

/// `POST …/assets/workbench/material-data` — clip assets and generated videos for the project (**empty `{}`** body).
Future<WorkbenchAssetMaterialDataResponse> postWorkbenchAssetsGetMaterialData(
  String accessToken,
  String projectId,
) async {
  final uri = Uri.parse(
    '$kApiBaseUrl/api/v1/projects/$projectId/assets/workbench/material-data',
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
  if (res.statusCode == 400) {
    throw RustApiException.fromHttpResponse(res);
  }
  ensureHttpSuccess(res);
  final map = jsonDecode(res.body) as Map<String, dynamic>;
  return WorkbenchAssetMaterialDataResponse.fromJson(map);
}

/// `POST …/assets/workbench/batch-generation-data` — paged listing by **`type/name/page/limit`**.
Future<WorkbenchAssetBatchGenerationResponse>
postWorkbenchAssetsBatchGenerationData(
  String accessToken, {
  required String projectId,
  required String assetType,
  String? name,
  int page = 1,
  int limit = 10,
}) async {
  final uri = Uri.parse(
    '$kApiBaseUrl/api/v1/projects/$projectId/assets/workbench/batch-generation-data',
  );
  final payload = <String, dynamic>{
    'type': assetType,
    'page': page,
    'limit': limit,
  };
  if (name != null && name.trim().isNotEmpty) {
    payload['name'] = name.trim();
  }
  final res = await http
      .post(
        uri,
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(payload),
      )
      .timeout(const Duration(seconds: 15));
  if (res.statusCode == 400) {
    throw RustApiException.fromHttpResponse(res);
  }
  ensureHttpSuccess(res);
  final map = jsonDecode(res.body) as Map<String, dynamic>;
  return WorkbenchAssetBatchGenerationResponse.fromJson(map);
}

/// `POST …/assets/workbench/polling-image-assets` — selected-image polling by **`ids`**.
Future<List<WorkbenchAssetPollingImageItem>>
postWorkbenchAssetsPollingImageAssets(
  String accessToken,
  String projectId,
  List<int> assetNumericIds,
) async {
  final uri = Uri.parse(
    '$kApiBaseUrl/api/v1/projects/$projectId/assets/workbench/polling-image-assets',
  );
  final res = await http
      .post(
        uri,
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'ids': assetNumericIds}),
      )
      .timeout(const Duration(seconds: 15));
  if (res.statusCode == 400) {
    throw RustApiException.fromHttpResponse(res);
  }
  ensureHttpSuccess(res);
  final raw = jsonDecode(res.body) as List<dynamic>;
  return raw
      .map(
        (e) =>
            WorkbenchAssetPollingImageItem.fromJson(e as Map<String, dynamic>),
      )
      .toList();
}

/// `POST …/assets/workbench/polling-prompt-assets` — prompt polling by **`ids`**.
Future<List<WorkbenchAssetPollingPromptItem>>
postWorkbenchAssetsPollingPromptAssets(
  String accessToken,
  String projectId,
  List<int> assetNumericIds,
) async {
  final uri = Uri.parse(
    '$kApiBaseUrl/api/v1/projects/$projectId/assets/workbench/polling-prompt-assets',
  );
  final res = await http
      .post(
        uri,
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'ids': assetNumericIds}),
      )
      .timeout(const Duration(seconds: 15));
  if (res.statusCode == 400) {
    throw RustApiException.fromHttpResponse(res);
  }
  ensureHttpSuccess(res);
  final raw = jsonDecode(res.body) as List<dynamic>;
  return raw
      .map(
        (e) =>
            WorkbenchAssetPollingPromptItem.fromJson(e as Map<String, dynamic>),
      )
      .toList();
}
