import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../../config.dart';
import '../core.dart';
import 'models/corner_scape.dart';
import 'models/images.dart';

/// `GET /api/v1/projects/{project_id}/assets/{asset_numeric_id}/images` — see `listProjectAssetImagesByProjectIdV1`.
Future<ListAssetImagesResponse> fetchProjectAssetImagesByProjectIds(
  String accessToken,
  String projectId,
  int assetNumericId,
) async {
  final uri = Uri.parse(
    '$kApiBaseUrl/api/v1/projects/$projectId/assets/$assetNumericId/images',
  );
  final res = await http
      .get(uri, headers: {'Authorization': 'Bearer $accessToken'})
      .timeout(const Duration(seconds: 15));
  if (res.statusCode == 404) {
    throw RustApiException('not found', statusCode: 404);
  }
  ensureHttpSuccess(res);
  final map = jsonDecode(res.body) as Map<String, dynamic>;
  return ListAssetImagesResponse.fromJson(map);
}

/// `GET /api/v1/projects/{project_id}/assets/{asset_numeric_id}/images/{image_id}` — see `getProjectAssetImageByProjectIdV1`.
Future<AssetImageRow> fetchProjectAssetImageByProjectIds(
  String accessToken,
  String projectId,
  int assetNumericId,
  String imageId,
) async {
  final uri = Uri.parse(
    '$kApiBaseUrl/api/v1/projects/$projectId/assets/$assetNumericId/images/$imageId',
  );
  final res = await http
      .get(uri, headers: {'Authorization': 'Bearer $accessToken'})
      .timeout(const Duration(seconds: 15));
  if (res.statusCode == 404) {
    throw RustApiException('not found', statusCode: 404);
  }
  ensureHttpSuccess(res);
  final map = jsonDecode(res.body) as Map<String, dynamic>;
  return AssetImageRow.fromJson(map);
}

/// Builds `GET …/projects/{project_id}/assets/.../file` — OpenAPI `getProjectAssetImageFileByProjectIdV1`.
Uri projectAssetImageFileV1UriByProjectId(
  String projectId,
  int assetNumericId,
  String imageId, {
  int? maxEdge,
}) {
  return Uri.parse(
    '$kApiBaseUrl/api/v1/projects/$projectId/assets/$assetNumericId/images/$imageId/file',
  ).replace(
    queryParameters: maxEdge != null && maxEdge > 0
        ? <String, String>{'max_edge': '$maxEdge'}
        : null,
  );
}

/// Fetches image bytes from [`projectAssetImageFileV1UriByProjectId`].
Future<Uint8List> fetchProjectAssetImageFileByProjectIds(
  String accessToken,
  String projectId,
  int assetNumericId,
  String imageId,
) async {
  final uri = projectAssetImageFileV1UriByProjectId(
    projectId,
    assetNumericId,
    imageId,
  );
  final res = await http
      .get(uri, headers: {'Authorization': 'Bearer $accessToken'})
      .timeout(const Duration(seconds: 120));
  ensureHttpSuccess(res);
  return res.bodyBytes;
}

/// Loads image bytes for a corner-scape **`history_images`** row.
///
/// **`file_path`** starting with **`http://`** / **`https://`**: plain **GET** (provider URLs).
/// Otherwise: **[fetchProjectAssetImageFileByProjectIds]** (JWT; **307** follow, **local** PNG, etc.).
/// Returns **`null`** on missing path or transport/HTTP failure.
Future<Uint8List?> fetchCornerScapeHistoryImagePreviewBytes(
  String accessToken,
  String projectId,
  int assetNumericId,
  CornerScapeHistoryImage img,
) async {
  final fp = img.filePath;
  if (fp == null || fp.isEmpty) return null;
  final t = fp.trim();
  if (t.startsWith('http://') || t.startsWith('https://')) {
    try {
      final res = await http
          .get(Uri.parse(t))
          .timeout(const Duration(seconds: 120));
      if (res.statusCode != 200) return null;
      return res.bodyBytes;
    } catch (_) {
      return null;
    }
  }
  return await fallbackOnRustApiException<Uint8List?>(
    () => fetchProjectAssetImageFileByProjectIds(
      accessToken,
      projectId,
      assetNumericId,
      img.id,
    ),
    null,
  );
}

/// `POST /api/v1/projects/{project_id}/assets/{asset_numeric_id}/images` — see `createProjectAssetImageByProjectIdV1`.
Future<AssetImageRow> createProjectAssetImageForProject(
  String accessToken,
  String projectId,
  int assetNumericId, {
  String? filePath,
  String? state,
  int? sortIndex,
}) async {
  final uri = Uri.parse(
    '$kApiBaseUrl/api/v1/projects/$projectId/assets/$assetNumericId/images',
  );
  final body = <String, dynamic>{};
  if (filePath != null) {
    body['file_path'] = filePath;
  }
  if (state != null) {
    body['state'] = state;
  }
  if (sortIndex != null) {
    body['sort_index'] = sortIndex;
  }
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
  if (res.statusCode == 404) {
    throw RustApiException('not found', statusCode: 404);
  }
  if (res.statusCode == 400) {
    throw RustApiException.fromHttpResponse(res);
  }
  ensureHttpStatus(res, 201);
  final map = jsonDecode(res.body) as Map<String, dynamic>;
  return AssetImageRow.fromJson(map);
}

/// `PATCH …/projects/{project_id}/assets/.../images/{image_id}` — see `patchProjectAssetImageByProjectIdV1`.
Future<AssetImageRow> patchProjectAssetImageByProjectIds(
  String accessToken,
  String projectId,
  int assetNumericId,
  String imageId,
  Map<String, dynamic> body,
) async {
  final uri = Uri.parse(
    '$kApiBaseUrl/api/v1/projects/$projectId/assets/$assetNumericId/images/$imageId',
  );
  final res = await http
      .patch(
        uri,
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(body),
      )
      .timeout(const Duration(seconds: 15));
  if (res.statusCode == 404) {
    throw RustApiException('not found', statusCode: 404);
  }
  if (res.statusCode == 400) {
    throw RustApiException.fromHttpResponse(res);
  }
  ensureHttpSuccess(res);
  final map = jsonDecode(res.body) as Map<String, dynamic>;
  return AssetImageRow.fromJson(map);
}

/// `DELETE …/projects/{project_id}/assets/.../images/{image_id}` — see `deleteProjectAssetImageByProjectIdV1`.
Future<void> deleteProjectAssetImageByProjectIds(
  String accessToken,
  String projectId,
  int assetNumericId,
  String imageId,
) async {
  final uri = Uri.parse(
    '$kApiBaseUrl/api/v1/projects/$projectId/assets/$assetNumericId/images/$imageId',
  );
  final res = await http
      .delete(uri, headers: {'Authorization': 'Bearer $accessToken'})
      .timeout(const Duration(seconds: 15));
  if (res.statusCode == 404) {
    throw RustApiException('not found', statusCode: 404);
  }
  if (res.statusCode == 400) {
    throw RustApiException.fromHttpResponse(res);
  }
  ensureHttpStatus(res, 204);
}
