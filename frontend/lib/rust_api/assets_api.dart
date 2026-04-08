part of 'index.dart';

/// `POST /api/v1/projects/legacy/{project_legacy_id}/assets/corner-scape` — see `listCornerScapeAssetsByLegacyV1`.
Future<CornerScapeResponse> fetchCornerScapeAssetsByLegacyId(
  String accessToken,
  int projectLegacyId, {
  List<String>? types,
}) async {
  final uri = Uri.parse(
    '$kApiBaseUrl/api/v1/projects/legacy/$projectLegacyId/assets/corner-scape',
  );
  final body = <String, dynamic>{};
  if (types != null && types.isNotEmpty) {
    body['types'] = types;
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
      .timeout(const Duration(seconds: 30));
  if (res.statusCode != 200) {
    throw RustApiException(res.body, statusCode: res.statusCode);
  }
  final map = jsonDecode(res.body) as Map<String, dynamic>;
  return CornerScapeResponse.fromJson(map);
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

/// `GET /api/v1/projects/legacy/{project_legacy_id}/assets` — see `listProjectAssetsByLegacyV1`.
Future<ListAssetsResponse> fetchProjectAssetsByLegacyId(
  String accessToken,
  int projectLegacyId, {
  int? scriptLegacyId,
  String? assetType,
  String? name,
  int? page,
  int? limit,
}) async {
  final qp = <String, String>{};
  if (scriptLegacyId != null) {
    qp['script_legacy_id'] = '$scriptLegacyId';
  }
  if (assetType != null && assetType.isNotEmpty) {
    qp['asset_type'] = assetType;
  }
  if (name != null && name.isNotEmpty) {
    qp['name'] = name;
  }
  if (page != null) {
    qp['page'] = '$page';
  }
  if (limit != null) {
    qp['limit'] = '$limit';
  }
  var uri = Uri.parse(
    '$kApiBaseUrl/api/v1/projects/legacy/$projectLegacyId/assets',
  );
  if (qp.isNotEmpty) {
    uri = uri.replace(queryParameters: qp);
  }
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
  return ListAssetsResponse.fromJson(map);
}

/// `GET /api/v1/projects/legacy/{project_legacy_id}/assets/{asset_legacy_id}` — see `getProjectAssetByLegacyIdsV1`.
Future<AssetRow> fetchProjectAssetByLegacyIds(
  String accessToken,
  int projectLegacyId,
  int assetLegacyId,
) async {
  final uri = Uri.parse(
    '$kApiBaseUrl/api/v1/projects/legacy/$projectLegacyId/assets/$assetLegacyId',
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
  return AssetRow.fromJson(map);
}

/// `POST /api/v1/projects/legacy/{project_legacy_id}/assets` — see `createProjectAssetByLegacyV1`.
Future<AssetRow> createProjectAssetUnderLegacy(
  String accessToken,
  int projectLegacyId, {
  required String name,
  required String type,
  String? description,
}) async {
  final uri = Uri.parse(
    '$kApiBaseUrl/api/v1/projects/legacy/$projectLegacyId/assets',
  );
  final body = <String, dynamic>{'name': name, 'type': type};
  if (description != null) {
    body['description'] = description;
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
  if (res.statusCode == 409) {
    throw RustApiException(res.body, statusCode: 409);
  }
  if (res.statusCode == 400) {
    throw RustApiException(res.body, statusCode: 400);
  }
  if (res.statusCode != 201) {
    throw RustApiException(res.body, statusCode: res.statusCode);
  }
  final map = jsonDecode(res.body) as Map<String, dynamic>;
  return AssetRow.fromJson(map);
}

/// `PATCH /api/v1/projects/legacy/{project_legacy_id}/assets/{asset_legacy_id}` — see `patchProjectAssetByLegacyIdsV1`.
///
/// [body] must match OpenAPI **`PatchAssetBody`** (**`name`** / **`description`** / **`asset_type`** / **`cover_legacy_image_id`**).
Future<AssetRow> patchProjectAssetByLegacyIds(
  String accessToken,
  int projectLegacyId,
  int assetLegacyId,
  Map<String, dynamic> body,
) async {
  final uri = Uri.parse(
    '$kApiBaseUrl/api/v1/projects/legacy/$projectLegacyId/assets/$assetLegacyId',
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
  return AssetRow.fromJson(map);
}

/// `DELETE /api/v1/projects/legacy/{project_legacy_id}/assets/{asset_legacy_id}` — see `deleteProjectAssetByLegacyIdsV1`.
Future<void> deleteProjectAssetByLegacyIds(
  String accessToken,
  int projectLegacyId,
  int assetLegacyId,
) async {
  final uri = Uri.parse(
    '$kApiBaseUrl/api/v1/projects/legacy/$projectLegacyId/assets/$assetLegacyId',
  );
  final res = await http
      .delete(uri, headers: {'Authorization': 'Bearer $accessToken'})
      .timeout(const Duration(seconds: 15));
  if (res.statusCode == 404) {
    throw RustApiException('not found', statusCode: 404);
  }
  if (res.statusCode != 204) {
    throw RustApiException(res.body, statusCode: res.statusCode);
  }
}

/// `PUT …/scripts/{script_legacy_id}/assets/{asset_legacy_id}` — link script to asset (`app_script_asset`).
Future<void> linkScriptToAssetByLegacyIds(
  String accessToken,
  int projectLegacyId,
  int scriptLegacyId,
  int assetLegacyId,
) async {
  final uri = Uri.parse(
    '$kApiBaseUrl/api/v1/projects/legacy/$projectLegacyId/scripts/$scriptLegacyId/assets/$assetLegacyId',
  );
  final res = await http
      .put(uri, headers: {'Authorization': 'Bearer $accessToken'})
      .timeout(const Duration(seconds: 15));
  if (res.statusCode == 404) {
    throw RustApiException('not found', statusCode: 404);
  }
  if (res.statusCode != 204) {
    throw RustApiException(res.body, statusCode: res.statusCode);
  }
}

/// `DELETE …/scripts/{script_legacy_id}/assets/{asset_legacy_id}` — remove link (404 if link absent).
Future<void> unlinkScriptFromAssetByLegacyIds(
  String accessToken,
  int projectLegacyId,
  int scriptLegacyId,
  int assetLegacyId,
) async {
  final uri = Uri.parse(
    '$kApiBaseUrl/api/v1/projects/legacy/$projectLegacyId/scripts/$scriptLegacyId/assets/$assetLegacyId',
  );
  final res = await http
      .delete(uri, headers: {'Authorization': 'Bearer $accessToken'})
      .timeout(const Duration(seconds: 15));
  if (res.statusCode == 404) {
    throw RustApiException('not found', statusCode: 404);
  }
  if (res.statusCode != 204) {
    throw RustApiException(res.body, statusCode: res.statusCode);
  }
}
