import 'package:flutter/material.dart';

import '../../config.dart';
import '../../rust_api/assets/block_urls.dart';
import 'studio_network_image.dart';

/// Block-level asset preview with DPI-aware URL + local disk cache.
class StudioAssetBlockImage extends StatelessWidget {
  const StudioAssetBlockImage({
    super.key,
    required this.accessToken,
    required this.projectId,
    required this.assetNumericId,
    required this.blockKey,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
    this.errorBuilder,
  });

  final String accessToken;
  final String projectId;
  final int assetNumericId;
  final String blockKey;
  final BoxFit fit;
  final double? width;
  final double? height;
  final ImageErrorWidgetBuilder? errorBuilder;

  @override
  Widget build(BuildContext context) {
    final dpiTier = studioAssetDpiTier(context);
    final uri = studioAssetBlockFileUri(
      apiBase: Uri.parse(kApiBaseUrl),
      projectId: projectId,
      assetNumericId: assetNumericId,
      blockKey: blockKey,
      dpiTier: dpiTier,
    );
    return StudioNetworkImage(
      accessToken: accessToken,
      url: uri.toString(),
      fit: fit,
      width: width,
      height: height,
      errorBuilder: errorBuilder,
    );
  }
}
