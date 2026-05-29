import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../../config.dart';
import '../../platform/studio_asset_image_cache.dart';
import '../core.dart';
import 'block_urls.dart';

/// One `app_asset_block` row from `GET …/blocks`.
class AssetBlockRow {
  const AssetBlockRow({
    required this.id,
    required this.blockKey,
    required this.dpiTier,
    required this.width,
    required this.height,
  });

  final String id;
  final String blockKey;
  final int dpiTier;
  final int width;
  final int height;

  factory AssetBlockRow.fromJson(Map<String, dynamic> json) {
    return AssetBlockRow(
      id: json['id'] as String,
      blockKey: json['block_key'] as String,
      dpiTier: (json['dpi_tier'] as num).toInt(),
      width: (json['width'] as num).toInt(),
      height: (json['height'] as num).toInt(),
    );
  }
}

/// `GET /api/v1/projects/{project_id}/assets/{asset_numeric_id}/blocks`.
Future<List<AssetBlockRow>> listProjectAssetBlocksByProjectIds(
  String accessToken,
  String projectId,
  int assetNumericId,
) async {
  final uri = Uri.parse(
    '$kApiBaseUrl/api/v1/projects/$projectId/assets/$assetNumericId/blocks',
  );
  final res = await http
      .get(uri, headers: rustApiAuthHeaders(accessToken))
      .timeout(const Duration(seconds: 15));
  if (res.statusCode == 404) {
    throw RustApiException('not found', statusCode: 404);
  }
  ensureHttpSuccess(res);
  final map = jsonDecode(res.body) as Map<String, dynamic>;
  final blocks = map['blocks'];
  if (blocks is! List<dynamic>) {
    return const <AssetBlockRow>[];
  }
  return blocks
      .whereType<Map<String, dynamic>>()
      .map(AssetBlockRow.fromJson)
      .toList(growable: false);
}

/// Local-first block PNG bytes (`GET …/blocks/{key}/file?dpi=`).
Future<Uint8List> fetchProjectAssetBlockFileByProjectIds(
  String accessToken,
  String projectId,
  int assetNumericId,
  String blockKey, {
  int dpiTier = 1,
}) async {
  final uri = studioAssetBlockFileUri(
    apiBase: Uri.parse(kApiBaseUrl),
    projectId: projectId,
    assetNumericId: assetNumericId,
    blockKey: blockKey,
    dpiTier: dpiTier,
  );
  return studioLoadCachedAssetImageBytes(
    accessToken: accessToken,
    uri: uri,
  );
}

/// Evicts cached block file for the given tier (after regeneration).
Future<void> evictProjectAssetBlockCache(
  String projectId,
  int assetNumericId,
  String blockKey, {
  int dpiTier = 1,
}) async {
  final uri = studioAssetBlockFileUri(
    apiBase: Uri.parse(kApiBaseUrl),
    projectId: projectId,
    assetNumericId: assetNumericId,
    blockKey: blockKey,
    dpiTier: dpiTier,
  );
  await StudioAssetImageCache.evictUri(uri);
}

/// Registers or updates a block row and optionally warms the on-device cache.
Future<AssetBlockRow> createProjectAssetBlockForProject(
  String accessToken,
  String projectId,
  int assetNumericId, {
  required String blockKey,
  int dpiTier = 1,
  required int width,
  required int height,
  String? pngBase64,
  bool warmLocalCache = true,
}) async {
  final uri = Uri.parse(
    '$kApiBaseUrl/api/v1/projects/$projectId/assets/$assetNumericId/blocks',
  );
  final body = <String, dynamic>{
    'block_key': blockKey,
    'dpi_tier': dpiTier,
    'width': width,
    'height': height,
    if (pngBase64 != null && pngBase64.isNotEmpty) 'png_base64': pngBase64,
  };
  final res = await http
      .post(
        uri,
        headers: rustApiJsonAuthHeaders(accessToken),
        body: jsonEncode(body),
      )
      .timeout(const Duration(seconds: 120));
  if (res.statusCode == 404) {
    throw RustApiException('not found', statusCode: 404);
  }
  if (res.statusCode == 400) {
    throw RustApiException.fromHttpResponse(res);
  }
  ensureHttpStatus(res, 201);
  final map = jsonDecode(res.body) as Map<String, dynamic>;
  final row = AssetBlockRow.fromJson(map);
  await evictProjectAssetBlockCache(
    projectId,
    assetNumericId,
    blockKey,
    dpiTier: dpiTier,
  );
  if (warmLocalCache && pngBase64 != null && pngBase64.isNotEmpty) {
    await fetchProjectAssetBlockFileByProjectIds(
      accessToken,
      projectId,
      assetNumericId,
      blockKey,
      dpiTier: dpiTier,
    );
  }
  return row;
}
