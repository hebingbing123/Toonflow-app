import 'dart:io';

import 'package:flutter/material.dart';

import 'components/studio_loading_placeholders.dart';
import 'studio_network_image.dart';
import '../config.dart';
import '../platform/studio_asset_image_cache.dart';

/// Local-first asset preview: disk cache, then authenticated API fetch.
class StudioCachedAssetImage extends StatefulWidget {
  const StudioCachedAssetImage({
    super.key,
    required this.accessToken,
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
    this.cacheKeyOverride,
  });

  final String accessToken;
  final String url;
  final BoxFit fit;
  final double? width;
  final double? height;
  final Alignment alignment;
  final FilterQuality filterQuality;
  final ImageErrorWidgetBuilder? errorBuilder;
  final ImageLoadingBuilder? loadingBuilder;
  final String? semanticLabel;
  final bool optimizeForDisplay;
  final String? cacheKeyOverride;

  @override
  State<StudioCachedAssetImage> createState() => _StudioCachedAssetImageState();
}

class _StudioCachedAssetImageState extends State<StudioCachedAssetImage> {
  File? _file;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant StudioCachedAssetImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url ||
        oldWidget.accessToken != widget.accessToken ||
        oldWidget.cacheKeyOverride != widget.cacheKeyOverride) {
      _file = null;
      _error = null;
      _load();
    }
  }

  Future<void> _load() async {
    final resolvedUrl = _resolvedUrl(context);
    final uri = Uri.parse(resolvedUrl);
    try {
      final file = await studioLoadCachedAssetImageFile(
        accessToken: widget.accessToken,
        uri: uri,
        cacheKeyOverride: widget.cacheKeyOverride,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _file = file;
        _error = null;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _file = null;
        _error = error;
      });
    }
  }

  String _resolvedUrl(BuildContext context) {
    final raw = widget.url.startsWith('http')
        ? widget.url
        : resolveRustApiUrl(widget.url);
    if (!widget.optimizeForDisplay) {
      return raw;
    }
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final logicalW = widget.width;
    final logicalH = widget.height;
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
    return studioOptimizeAssetFileUrl(
      raw,
      maxPixelEdge: maxEdge,
      dpiTier: dpr.ceil().clamp(1, 4),
    );
  }

  @override
  Widget build(BuildContext context) {
    final file = _file;
    if (file != null) {
      final dpr = MediaQuery.devicePixelRatioOf(context);
      int? cacheWidth;
      int? cacheHeight;
      final logicalW = widget.width;
      final logicalH = widget.height;
      if (logicalW != null && logicalW.isFinite && logicalW > 0) {
        cacheWidth = (logicalW * dpr).round().clamp(1, 4096);
      }
      if (logicalH != null && logicalH.isFinite && logicalH > 0) {
        cacheHeight = (logicalH * dpr).round().clamp(1, 4096);
      }
      return Image.file(
        file,
        fit: widget.fit,
        width: widget.width,
        height: widget.height,
        alignment: widget.alignment,
        filterQuality: widget.filterQuality,
        cacheWidth: cacheWidth,
        cacheHeight: cacheHeight,
        semanticLabel: widget.semanticLabel,
        errorBuilder: widget.errorBuilder,
      );
    }

    if (_error != null && widget.errorBuilder != null) {
      return widget.errorBuilder!(
        context,
        _error!,
        StackTrace.current,
      );
    }

    if (widget.loadingBuilder != null) {
      return widget.loadingBuilder!(
        context,
        const SizedBox.shrink(),
        null,
      );
    }

    return SizedBox(
      width: widget.width,
      height: widget.height,
      child: const StudioMediaTileSkeleton(),
    );
  }
}
