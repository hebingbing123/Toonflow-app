part of 'index.dart';

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
