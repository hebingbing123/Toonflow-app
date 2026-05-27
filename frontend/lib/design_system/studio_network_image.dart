import 'package:flutter/material.dart';

/// Appends `max_edge` for OpenFlow project asset image file routes (local downscale).
String studioOptimizeImageUrl(String url, {int? maxPixelEdge}) {
  if (maxPixelEdge == null || maxPixelEdge <= 0) {
    return url;
  }
  final uri = Uri.tryParse(url);
  if (uri == null) {
    return url;
  }
  final path = uri.path;
  if (!path.contains('/images/') || !path.endsWith('/file')) {
    return url;
  }
  return uri
      .replace(
        queryParameters: <String, String>{
          ...uri.queryParameters,
          'max_edge': '$maxPixelEdge',
        },
      )
      .toString();
}

/// Network / memory preview with DPR-aware decode size and high filter quality.
class StudioNetworkImage extends StatelessWidget {
  const StudioNetworkImage({
    super.key,
    required this.url,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
    this.alignment = Alignment.center,
    this.filterQuality = FilterQuality.high,
    this.errorBuilder,
    this.loadingBuilder,
    this.semanticLabel,
    this.optimizeForDisplay = true,
  });

  final String url;
  final BoxFit fit;
  final double? width;
  final double? height;
  final Alignment alignment;
  final FilterQuality filterQuality;
  final ImageErrorWidgetBuilder? errorBuilder;
  final ImageLoadingBuilder? loadingBuilder;
  final String? semanticLabel;

  /// When true, adds `max_edge` for OpenFlow `/images/.../file` URLs.
  final bool optimizeForDisplay;

  @override
  Widget build(BuildContext context) {
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final logicalW = width;
    final logicalH = height;
    int? cacheWidth;
    int? cacheHeight;
    if (logicalW != null && logicalW.isFinite && logicalW > 0) {
      cacheWidth = (logicalW * dpr).round().clamp(1, 4096);
    }
    if (logicalH != null && logicalH.isFinite && logicalH > 0) {
      cacheHeight = (logicalH * dpr).round().clamp(1, 4096);
    }

    final maxEdge = (cacheWidth != null && cacheHeight != null)
        ? (cacheWidth > cacheHeight ? cacheWidth : cacheHeight)
        : (cacheWidth ?? cacheHeight);
    final resolved = optimizeForDisplay
        ? studioOptimizeImageUrl(url, maxPixelEdge: maxEdge)
        : url;

    return Image.network(
      resolved,
      fit: fit,
      width: width,
      height: height,
      alignment: alignment,
      filterQuality: filterQuality,
      cacheWidth: cacheWidth,
      cacheHeight: cacheHeight,
      semanticLabel: semanticLabel,
      errorBuilder: errorBuilder,
      loadingBuilder: loadingBuilder,
    );
  }
}
