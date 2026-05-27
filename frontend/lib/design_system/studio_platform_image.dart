import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Logical surfaces for bundled raster brand / marketing assets.
///
/// Each [StudioPlatformImageSurface] maps to its own asset path under
/// `assets/brand/<surface>/`. Do not share one sprite or mobile-only crop
/// across surfaces — add a dedicated file per surface when art is ready.
enum StudioPlatformImageSurface { mobile, tablet, desktop, web }

/// Resolves a platform-specific asset path with fallback to [mobile].
String studioPlatformImageAsset(
  String baseName, {
  StudioPlatformImageSurface? surface,
}) {
  final resolved = surface ?? _defaultSurface();
  final folder = switch (resolved) {
    StudioPlatformImageSurface.mobile => 'mobile',
    StudioPlatformImageSurface.tablet => 'tablet',
    StudioPlatformImageSurface.desktop => 'desktop',
    StudioPlatformImageSurface.web => 'web',
  };
  return 'assets/brand/$folder/$baseName';
}

StudioPlatformImageSurface _defaultSurface() {
  if (kIsWeb) {
    return StudioPlatformImageSurface.web;
  }
  switch (defaultTargetPlatform) {
    case TargetPlatform.iOS:
    case TargetPlatform.android:
      return StudioPlatformImageSurface.mobile;
    case TargetPlatform.macOS:
    case TargetPlatform.windows:
    case TargetPlatform.linux:
      return StudioPlatformImageSurface.desktop;
    case TargetPlatform.fuchsia:
      return StudioPlatformImageSurface.mobile;
  }
}

/// High-fidelity bundled image with per-platform asset paths and [BoxFit].
class StudioPlatformImage extends StatelessWidget {
  const StudioPlatformImage({
    super.key,
    required this.baseName,
    this.surface,
    this.fit = BoxFit.contain,
    this.width,
    this.height,
    this.filterQuality = FilterQuality.high,
    this.semanticLabel,
  });

  final String baseName;
  final StudioPlatformImageSurface? surface;
  final BoxFit fit;
  final double? width;
  final double? height;
  final FilterQuality filterQuality;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final primary = studioPlatformImageAsset(baseName, surface: surface);
    final fallback = studioPlatformImageAsset(
      baseName,
      surface: StudioPlatformImageSurface.mobile,
    );

    Widget image(String asset) {
      return Image.asset(
        asset,
        fit: fit,
        width: width,
        height: height,
        filterQuality: filterQuality,
        semanticLabel: semanticLabel,
        errorBuilder: (_, _, _) {
          if (asset == fallback) {
            return const SizedBox.shrink();
          }
          return Image.asset(
            fallback,
            fit: fit,
            width: width,
            height: height,
            filterQuality: filterQuality,
            semanticLabel: semanticLabel,
          );
        },
      );
    }

    return image(primary);
  }
}
