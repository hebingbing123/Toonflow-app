part of 'index.dart';

/// Body of **`GET …/assets`** — OpenAPI **`ListAssetsResponse`**.
class ListAssetsResponse {
  const ListAssetsResponse({required this.items, required this.total});

  final List<AssetRow> items;
  final int total;

  factory ListAssetsResponse.fromJson(Map<String, dynamic> json) {
    final raw = json['items'] as List<dynamic>;
    return ListAssetsResponse(
      items: raw
          .map((e) => AssetRow.fromJson(e as Map<String, dynamic>))
          .toList(),
      total: (json['total'] as num).toInt(),
    );
  }
}

/// One **`app_asset_image`** row in **`POST …/assets/corner-scape`** — OpenAPI **`CornerScapeHistoryImage`**.
class CornerScapeHistoryImage {
  const CornerScapeHistoryImage({
    required this.id,
    required this.sortIndex,
    this.filePath,
    this.state,
    this.legacyImageId,
  });

  final String id;
  final int sortIndex;
  final String? filePath;
  final String? state;
  final int? legacyImageId;

  factory CornerScapeHistoryImage.fromJson(Map<String, dynamic> json) {
    return CornerScapeHistoryImage(
      id: json['id'] as String,
      sortIndex: (json['sort_index'] as num).toInt(),
      filePath: json['file_path'] as String?,
      state: json['state'] as String?,
      legacyImageId: (json['legacy_image_id'] as num?)?.toInt(),
    );
  }
}

/// One row from **`POST …/assets/corner-scape`** — OpenAPI **`CornerScapeAssetItem`**.
class CornerScapeAssetItem {
  const CornerScapeAssetItem({
    required this.id,
    required this.legacyId,
    required this.name,
    required this.assetType,
    this.description,
    this.createTimeMs,
    required this.metadata,
    required this.historyImages,
  });

  final String id;
  final int legacyId;
  final String name;
  final String assetType;
  final String? description;
  final int? createTimeMs;
  final Map<String, dynamic> metadata;
  final List<CornerScapeHistoryImage> historyImages;

  factory CornerScapeAssetItem.fromJson(Map<String, dynamic> json) {
    final histRaw = json['history_images'] as List<dynamic>? ?? const [];
    final hist = histRaw
        .map((e) => CornerScapeHistoryImage.fromJson(e as Map<String, dynamic>))
        .toList();
    final meta = json['metadata'];
    return CornerScapeAssetItem(
      id: json['id'] as String,
      legacyId: (json['legacy_id'] as num).toInt(),
      name: json['name'] as String,
      assetType: json['asset_type'] as String,
      description: json['description'] as String?,
      createTimeMs: (json['create_time_ms'] as num?)?.toInt(),
      metadata: meta is Map<String, dynamic> ? meta : <String, dynamic>{},
      historyImages: hist,
    );
  }
}

/// OpenAPI **`AssetImageRow`** — response from **`POST …/assets/{aid}/images`** (and list items share these fields).
class AssetImageRow {
  const AssetImageRow({
    required this.id,
    required this.assetId,
    required this.sortIndex,
    this.filePath,
    this.state,
    this.legacyImageId,
    this.selected,
  });

  final String id;
  final String assetId;
  final int sortIndex;
  final String? filePath;
  final String? state;
  final int? legacyImageId;

  /// Present on **`GET …/images`** list items only (`AssetImageListItem`).
  final bool? selected;

  factory AssetImageRow.fromJson(Map<String, dynamic> json) {
    return AssetImageRow(
      id: json['id'] as String,
      assetId: json['asset_id'] as String,
      sortIndex: (json['sort_index'] as num).toInt(),
      filePath: json['file_path'] as String?,
      state: json['state'] as String?,
      legacyImageId: (json['legacy_image_id'] as num?)?.toInt(),
      selected: json['selected'] as bool?,
    );
  }
}

/// OpenAPI **`ListAssetImagesResponse`**.
class ListAssetImagesResponse {
  const ListAssetImagesResponse({this.coverLegacyImageId, required this.items});

  final int? coverLegacyImageId;
  final List<AssetImageRow> items;

  factory ListAssetImagesResponse.fromJson(Map<String, dynamic> json) {
    final raw = json['items'] as List<dynamic>;
    return ListAssetImagesResponse(
      coverLegacyImageId: (json['cover_legacy_image_id'] as num?)?.toInt(),
      items: raw
          .map((e) => AssetImageRow.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

/// OpenAPI **`CornerScapeResponse`**.
class CornerScapeResponse {
  const CornerScapeResponse({required this.items});

  final List<CornerScapeAssetItem> items;

  factory CornerScapeResponse.fromJson(Map<String, dynamic> json) {
    final raw = json['items'] as List<dynamic>;
    return CornerScapeResponse(
      items: raw
          .map((e) => CornerScapeAssetItem.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

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
