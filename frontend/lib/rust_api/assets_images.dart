part of 'index.dart';

/// `POST /api/v1/assets/get-image` — legacy asset image bundle by **`assetsId`**.
Future<LegacyAssetGetImageResponse> postLegacyAssetsGetImage(
  String accessToken,
  int assetLegacyId,
) async {
  final uri = Uri.parse('$kApiBaseUrl/api/v1/assets/get-image');
  final res = await http
      .post(
        uri,
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'assetsId': assetLegacyId}),
      )
      .timeout(const Duration(seconds: 15));
  if (res.statusCode == 400) {
    throw RustApiException(res.body, statusCode: 400);
  }
  if (res.statusCode == 404) {
    throw RustApiException('not found', statusCode: 404);
  }
  if (res.statusCode != 200) {
    throw RustApiException(res.body, statusCode: res.statusCode);
  }
  final map = jsonDecode(res.body) as Map<String, dynamic>;
  return LegacyAssetGetImageResponse.fromJson(map);
}

/// `POST /api/v1/assets/upload-clip` — legacy upload clip asset by **`projectId/base64Data/name`**.
Future<LegacyAssetUploadClipResponse> postLegacyAssetsUploadClip(
  String accessToken, {
  required int projectLegacyId,
  required String base64Data,
  required String name,
  String assetType = 'clip',
}) async {
  final uri = Uri.parse('$kApiBaseUrl/api/v1/assets/upload-clip');
  final res = await http
      .post(
        uri,
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'projectId': projectLegacyId,
          'base64Data': base64Data,
          'type': assetType,
          'name': name,
        }),
      )
      .timeout(const Duration(seconds: 30));
  if (res.statusCode == 400) {
    throw RustApiException(res.body, statusCode: 400);
  }
  if (res.statusCode == 404) {
    throw RustApiException('not found', statusCode: 404);
  }
  if (res.statusCode != 200) {
    throw RustApiException(res.body, statusCode: res.statusCode);
  }
  final map = jsonDecode(res.body) as Map<String, dynamic>;
  return LegacyAssetUploadClipResponse.fromJson(map);
}

/// `POST /api/v1/assets/get-material-data` — legacy clip-assets and generated videos by **`projectId`**.
Future<LegacyAssetMaterialDataResponse> postLegacyAssetsGetMaterialData(
  String accessToken,
  int projectLegacyId,
) async {
  final uri = Uri.parse('$kApiBaseUrl/api/v1/assets/get-material-data');
  final res = await http
      .post(
        uri,
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'projectId': projectLegacyId}),
      )
      .timeout(const Duration(seconds: 15));
  if (res.statusCode == 400) {
    throw RustApiException(res.body, statusCode: 400);
  }
  if (res.statusCode != 200) {
    throw RustApiException(res.body, statusCode: res.statusCode);
  }
  final map = jsonDecode(res.body) as Map<String, dynamic>;
  return LegacyAssetMaterialDataResponse.fromJson(map);
}

/// `POST /api/v1/assets/batch-generation-data` — legacy paged listing by **`projectId/type/name/page/limit`**.
Future<LegacyAssetBatchGenerationDataResponse> postLegacyAssetsBatchGenerationData(
  String accessToken, {
  required int projectLegacyId,
  required String assetType,
  String? name,
  int page = 1,
  int limit = 10,
}) async {
  final uri = Uri.parse('$kApiBaseUrl/api/v1/assets/batch-generation-data');
  final payload = <String, dynamic>{
    'projectId': projectLegacyId,
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
    throw RustApiException(res.body, statusCode: 400);
  }
  if (res.statusCode != 200) {
    throw RustApiException(res.body, statusCode: res.statusCode);
  }
  final map = jsonDecode(res.body) as Map<String, dynamic>;
  return LegacyAssetBatchGenerationDataResponse.fromJson(map);
}

/// `POST /api/v1/assets/polling-image-assets` — legacy selected-image polling by **`ids`**.
Future<List<LegacyAssetPollingImageAssetsItem>> postLegacyAssetsPollingImageAssets(
  String accessToken,
  List<int> assetLegacyIds,
) async {
  final uri = Uri.parse('$kApiBaseUrl/api/v1/assets/polling-image-assets');
  final res = await http
      .post(
        uri,
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'ids': assetLegacyIds}),
      )
      .timeout(const Duration(seconds: 15));
  if (res.statusCode == 400) {
    throw RustApiException(res.body, statusCode: 400);
  }
  if (res.statusCode != 200) {
    throw RustApiException(res.body, statusCode: res.statusCode);
  }
  final raw = jsonDecode(res.body) as List<dynamic>;
  return raw
      .map(
        (e) => LegacyAssetPollingImageAssetsItem.fromJson(
          e as Map<String, dynamic>,
        ),
      )
      .toList();
}

/// `POST /api/v1/assets/polling-prompt-assets` — legacy prompt polling by **`ids`**.
Future<List<LegacyAssetPollingPromptAssetsItem>> postLegacyAssetsPollingPromptAssets(
  String accessToken,
  List<int> assetLegacyIds,
) async {
  final uri = Uri.parse('$kApiBaseUrl/api/v1/assets/polling-prompt-assets');
  final res = await http
      .post(
        uri,
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'ids': assetLegacyIds}),
      )
      .timeout(const Duration(seconds: 15));
  if (res.statusCode == 400) {
    throw RustApiException(res.body, statusCode: 400);
  }
  if (res.statusCode != 200) {
    throw RustApiException(res.body, statusCode: res.statusCode);
  }
  final raw = jsonDecode(res.body) as List<dynamic>;
  return raw
      .map(
        (e) => LegacyAssetPollingPromptAssetsItem.fromJson(
          e as Map<String, dynamic>,
        ),
      )
      .toList();
}

/// `GET /api/v1/projects/legacy/{project_legacy_id}/assets/{asset_legacy_id}/images` — see `listProjectAssetImagesByLegacyIdsV1`.
Future<ListAssetImagesResponse> fetchProjectAssetImagesByLegacyIds(
  String accessToken,
  int projectLegacyId,
  int assetLegacyId,
) async {
  final uri = Uri.parse(
    '$kApiBaseUrl/api/v1/projects/legacy/$projectLegacyId/assets/$assetLegacyId/images',
  );
  final res = await http
      .get(uri, headers: {'Authorization': 'Bearer $accessToken'})
      .timeout(const Duration(seconds: 15));
  if (res.statusCode == 404) {
    throw RustApiException('not found', statusCode: 404);
  }
  if (res.statusCode != 200) {
    throw RustApiException(res.body, statusCode: res.statusCode);
  }
  final map = jsonDecode(res.body) as Map<String, dynamic>;
  return ListAssetImagesResponse.fromJson(map);
}

/// `GET /api/v1/projects/legacy/{project_legacy_id}/assets/{asset_legacy_id}/images/{image_id}` — see `getProjectAssetImageByLegacyIdsV1`.
Future<AssetImageRow> fetchProjectAssetImageByLegacyIds(
  String accessToken,
  int projectLegacyId,
  int assetLegacyId,
  String imageId,
) async {
  final uri = Uri.parse(
    '$kApiBaseUrl/api/v1/projects/legacy/$projectLegacyId/assets/$assetLegacyId/images/$imageId',
  );
  final res = await http
      .get(uri, headers: {'Authorization': 'Bearer $accessToken'})
      .timeout(const Duration(seconds: 15));
  if (res.statusCode == 404) {
    throw RustApiException('not found', statusCode: 404);
  }
  if (res.statusCode != 200) {
    throw RustApiException(res.body, statusCode: res.statusCode);
  }
  final map = jsonDecode(res.body) as Map<String, dynamic>;
  return AssetImageRow.fromJson(map);
}

/// Builds `GET /api/v1/projects/legacy/{project_legacy_id}/assets/{asset_legacy_id}/images/{image_id}/file` — OpenAPI `getProjectAssetImageFileByLegacyIdsV1`.
Uri projectAssetImageFileV1Uri(
  int projectLegacyId,
  int assetLegacyId,
  String imageId,
) {
  return Uri.parse(
    '$kApiBaseUrl/api/v1/projects/legacy/$projectLegacyId/assets/$assetLegacyId/images/$imageId/file',
  );
}

/// Fetches image bytes from [`projectAssetImageFileV1Uri`].
///
/// When **`file_path`** is **`https?`**, the server responds with **307**; this client follows redirects and returns the final body (**`200`**).
/// Rows without **`https?`** **`file_path`** and without **`metadata.storage == local`** typically yield **404** from this route.
Future<Uint8List> fetchProjectAssetImageFileByLegacyIds(
  String accessToken,
  int projectLegacyId,
  int assetLegacyId,
  String imageId,
) async {
  final uri = projectAssetImageFileV1Uri(
    projectLegacyId,
    assetLegacyId,
    imageId,
  );
  final res = await http
      .get(uri, headers: {'Authorization': 'Bearer $accessToken'})
      .timeout(const Duration(seconds: 120));
  if (res.statusCode != 200) {
    throw RustApiException(
      res.body.isNotEmpty ? res.body : 'binary response ${res.statusCode}',
      statusCode: res.statusCode,
    );
  }
  return res.bodyBytes;
}

/// Loads image bytes for a corner-scape **`history_images`** row.
///
/// **`file_path`** starting with **`http://`** / **`https://`**: plain **GET** (provider URLs).
/// Otherwise: **[fetchProjectAssetImageFileByLegacyIds]** (JWT; **307** follow, **local** PNG, etc.).
/// Returns **`null`** on missing path or transport/HTTP failure.
Future<Uint8List?> fetchCornerScapeHistoryImagePreviewBytes(
  String accessToken,
  int projectLegacyId,
  int assetLegacyId,
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
  try {
    return await fetchProjectAssetImageFileByLegacyIds(
      accessToken,
      projectLegacyId,
      assetLegacyId,
      img.id,
    );
  } on RustApiException {
    return null;
  }
}

/// `POST /api/v1/projects/legacy/{project_legacy_id}/assets/{asset_legacy_id}/images` — see `createProjectAssetImageByLegacyIdsV1`.
Future<AssetImageRow> createProjectAssetImage(
  String accessToken,
  int projectLegacyId,
  int assetLegacyId, {
  String? filePath,
  String? state,
  int? sortIndex,
}) async {
  final uri = Uri.parse(
    '$kApiBaseUrl/api/v1/projects/legacy/$projectLegacyId/assets/$assetLegacyId/images',
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
    throw RustApiException(res.body, statusCode: 400);
  }
  if (res.statusCode != 201) {
    throw RustApiException(res.body, statusCode: res.statusCode);
  }
  final map = jsonDecode(res.body) as Map<String, dynamic>;
  return AssetImageRow.fromJson(map);
}

/// `PATCH /api/v1/projects/legacy/{project_legacy_id}/assets/{asset_legacy_id}/images/{image_id}` — see `patchProjectAssetImageByLegacyIdsV1`.
///
/// [body] must match OpenAPI **`PatchAssetImageBody`** (at least one of **`file_path`**, **`state`**, **`sort_index`**).
Future<AssetImageRow> patchProjectAssetImageByLegacyIds(
  String accessToken,
  int projectLegacyId,
  int assetLegacyId,
  String imageId,
  Map<String, dynamic> body,
) async {
  final uri = Uri.parse(
    '$kApiBaseUrl/api/v1/projects/legacy/$projectLegacyId/assets/$assetLegacyId/images/$imageId',
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
    throw RustApiException(res.body, statusCode: 400);
  }
  if (res.statusCode != 200) {
    throw RustApiException(res.body, statusCode: res.statusCode);
  }
  final map = jsonDecode(res.body) as Map<String, dynamic>;
  return AssetImageRow.fromJson(map);
}

/// `DELETE /api/v1/projects/legacy/{project_legacy_id}/assets/{asset_legacy_id}/images/{image_id}` — see `deleteProjectAssetImageByLegacyIdsV1`.
Future<void> deleteProjectAssetImageByLegacyIds(
  String accessToken,
  int projectLegacyId,
  int assetLegacyId,
  String imageId,
) async {
  final uri = Uri.parse(
    '$kApiBaseUrl/api/v1/projects/legacy/$projectLegacyId/assets/$assetLegacyId/images/$imageId',
  );
  final res = await http
      .delete(uri, headers: {'Authorization': 'Bearer $accessToken'})
      .timeout(const Duration(seconds: 15));
  if (res.statusCode == 404) {
    throw RustApiException('not found', statusCode: 404);
  }
  if (res.statusCode == 400) {
    throw RustApiException(res.body, statusCode: 400);
  }
  if (res.statusCode != 204) {
    throw RustApiException(res.body, statusCode: res.statusCode);
  }
}
