import 'dart:math' as math;

import 'package:flutter/widgets.dart';

/// Resolves DPI tier (1–4) from device pixel ratio for block asset URLs.
int studioAssetDpiTier(BuildContext context) {
  final ratio = MediaQuery.devicePixelRatioOf(context);
  return math.min(4, math.max(1, ratio.ceil()));
}

/// Builds a block asset file URL for OpenFlow API (`/blocks/{key}/file?dpi=`).
Uri studioAssetBlockFileUri({
  required Uri apiBase,
  required String projectId,
  required int assetNumericId,
  required String blockKey,
  required int dpiTier,
}) {
  final encodedKey = Uri.encodeComponent(blockKey);
  return apiBase.replace(
    path:
        '${apiBase.path.replaceAll(RegExp(r'/+$'), '')}/api/v1/projects/$projectId/assets/$assetNumericId/blocks/$encodedKey/file',
    queryParameters: <String, String>{'dpi': '$dpiTier'},
  );
}
