import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';

import '../config.dart';
import '../design_system/components/studio_loading_placeholders.dart';
import '../design_system/studio_network_image.dart';
import '../design_system/tokens.dart';
import '../platform/studio_asset_image_cache.dart';
import '../platform/studio_asset_image_cache_keys.dart';
import '../rust_api/production/storyboard/grid_generate.dart';

/// Storyboard frame preview (http(s), data URI, or authenticated local-frame).
class StoryboardFrameImage extends StatelessWidget {
  const StoryboardFrameImage({
    super.key,
    required this.accessToken,
    required this.projectUuid,
    required this.scriptNumericId,
    required this.storyboardNumericId,
    required this.imageUrl,
    this.height = 240,
    this.fit = BoxFit.contain,
  });

  final String accessToken;
  final String projectUuid;
  final int scriptNumericId;
  final int storyboardNumericId;
  final String? imageUrl;
  final double height;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    final raw = imageUrl?.trim();
    if (raw == null || raw.isEmpty) {
      return SizedBox(height: height);
    }

    if (raw.startsWith('data:image/')) {
      final payload = raw.split(',').length > 1 ? raw.split(',').last : '';
      try {
        final bytes = base64Decode(payload);
        return Image.memory(
          bytes,
          height: height,
          width: double.infinity,
          fit: fit,
          filterQuality: FilterQuality.high,
        );
      } catch (_) {
        return _errorBox(context, raw);
      }
    }

    if (raw.startsWith('/storyboard-local/')) {
      final uri = storyboardLocalFrameUri(
        projectUuid: projectUuid,
        scriptId: scriptNumericId,
        storyboardId: storyboardNumericId,
      );
      final cacheKey = studioStoryboardLocalFrameCacheKey(
        projectUuid: projectUuid,
        scriptNumericId: scriptNumericId,
        storyboardNumericId: storyboardNumericId,
      );
      return FutureBuilder<File>(
        future: studioLoadCachedAssetImageFile(
          accessToken: accessToken,
          uri: uri,
          cacheKeyOverride: cacheKey,
        ),
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return SizedBox(
              height: height,
              child: const StudioMediaTileSkeleton(),
            );
          }
          final file = snapshot.data;
          if (file == null) {
            return _errorBox(context, raw);
          }
          return Image.file(
            file,
            height: height,
            width: double.infinity,
            fit: fit,
            filterQuality: FilterQuality.high,
          );
        },
      );
    }

    final resolved = raw.startsWith('http')
        ? raw
        : resolveRustApiUrl(raw);
    return StudioNetworkImage(
      accessToken: accessToken,
      url: resolved,
      height: height,
      width: double.infinity,
      fit: fit,
      errorBuilder: (_, _, _) => _errorBox(context, resolved),
    );
  }

  Widget _errorBox(BuildContext context, String label) {
    return Container(
      height: height,
      alignment: Alignment.center,
      padding: const EdgeInsets.all(StudioSpacing.radiusComfort),
      child: Text(
        label,
        maxLines: 3,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.bodySmall,
        textAlign: TextAlign.center,
      ),
    );
  }
}
