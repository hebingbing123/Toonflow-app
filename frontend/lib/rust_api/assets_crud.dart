part of 'index.dart';

/// `GET /api/v1/projects/{project_id}/assets` — see `listProjectAssetsByProjectIdV1`.
Future<ListAssetsResponse> fetchProjectAssetsByProjectId(
  String accessToken,
  String projectId, {
  int? scriptNumericId,
  String? assetType,
  String? name,
  int? page,
  int? limit,
}) async {
  final qp = <String, String>{};
  if (scriptNumericId != null) {
    qp['script_numeric_id'] = '$scriptNumericId';
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
  var uri = Uri.parse('$kApiBaseUrl/api/v1/projects/$projectId/assets');
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

/// `GET /api/v1/projects/{project_id}/assets/{asset_numeric_id}` — see `getProjectAssetByProjectIdV1`.
Future<AssetRow> fetchProjectAssetByProjectIds(
  String accessToken,
  String projectId,
  int assetNumericId,
) async {
  final uri = Uri.parse(
    '$kApiBaseUrl/api/v1/projects/$projectId/assets/$assetNumericId',
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

/// `POST /api/v1/projects/{project_id}/assets` — see `createProjectAssetByProjectIdV1`.
Future<AssetRow> createProjectAssetUnderProject(
  String accessToken,
  String projectId, {
  required String name,
  required String type,
  String? description,
}) async {
  final uri = Uri.parse('$kApiBaseUrl/api/v1/projects/$projectId/assets');
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

/// `PATCH /api/v1/projects/{project_id}/assets/{asset_numeric_id}` — see `patchProjectAssetByProjectIdV1`.
///
/// [body] must match OpenAPI **`PatchAssetBody`** (**`name`** / **`description`** / **`asset_type`** / **`cover_numeric_image_id`**).
Future<AssetRow> patchProjectAssetByProjectIds(
  String accessToken,
  String projectId,
  int assetNumericId,
  Map<String, dynamic> body,
) async {
  final uri = Uri.parse(
    '$kApiBaseUrl/api/v1/projects/$projectId/assets/$assetNumericId',
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

/// `DELETE /api/v1/projects/{project_id}/assets/{asset_numeric_id}` — see `deleteProjectAssetByProjectIdV1`.
Future<void> deleteProjectAssetByProjectIds(
  String accessToken,
  String projectId,
  int assetNumericId,
) async {
  final uri = Uri.parse(
    '$kApiBaseUrl/api/v1/projects/$projectId/assets/$assetNumericId',
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

/// `PUT …/projects/{project_id}/scripts/{script_numeric_id}/assets/{asset_numeric_id}` — see `linkScriptAssetByProjectIdV1`.
Future<void> linkScriptToAssetByProjectIds(
  String accessToken,
  String projectId,
  int scriptNumericId,
  int assetNumericId,
) async {
  final uri = Uri.parse(
    '$kApiBaseUrl/api/v1/projects/$projectId/scripts/$scriptNumericId/assets/$assetNumericId',
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

/// `DELETE …/projects/{project_id}/scripts/...` — see `unlinkScriptAssetByProjectIdV1`.
Future<void> unlinkScriptFromAssetByProjectIds(
  String accessToken,
  String projectId,
  int scriptNumericId,
  int assetNumericId,
) async {
  final uri = Uri.parse(
    '$kApiBaseUrl/api/v1/projects/$projectId/scripts/$scriptNumericId/assets/$assetNumericId',
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
