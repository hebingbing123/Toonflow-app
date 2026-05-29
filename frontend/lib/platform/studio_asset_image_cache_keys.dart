/// Relative cache paths for OpenFlow asset image / block file URLs.
String? studioAssetImageCacheKeyForUri(Uri uri) {
  final segments = uri.pathSegments;
  final projectsIdx = segments.indexOf('projects');
  if (projectsIdx < 2 || projectsIdx + 4 >= segments.length) {
    return null;
  }
  if (segments[projectsIdx - 2] != 'api' || segments[projectsIdx - 1] != 'v1') {
    return null;
  }
  if (segments[projectsIdx + 2] != 'assets') {
    return null;
  }

  final projectId = segments[projectsIdx + 1];
  final assetNumericId = segments[projectsIdx + 3];
  final kind = segments[projectsIdx + 4];

  if (kind == 'images' &&
      segments.length >= projectsIdx + 7 &&
      segments[projectsIdx + 6] == 'file') {
    final imageId = segments[projectsIdx + 5];
    final maxEdge = uri.queryParameters['max_edge'] ?? '0';
    return 'projects/$projectId/assets/$assetNumericId/images/$imageId/max_$maxEdge.png';
  }

  if (kind == 'blocks' &&
      segments.length >= projectsIdx + 7 &&
      segments[projectsIdx + 6] == 'file') {
    final blockKey = Uri.decodeComponent(segments[projectsIdx + 5]);
    final dpi = uri.queryParameters['dpi'] ?? '1';
    final safeKey = blockKey.replaceAll(RegExp(r'[^\w.\-]'), '_');
    return 'projects/$projectId/assets/$assetNumericId/blocks/$safeKey/dpi_$dpi.png';
  }

  return null;
}

/// Cache key for authenticated storyboard local-frame previews.
String studioStoryboardLocalFrameCacheKey({
  required String projectUuid,
  required int scriptNumericId,
  required int storyboardNumericId,
}) {
  return 'storyboard_local/$projectUuid/$scriptNumericId/$storyboardNumericId.png';
}

/// Whether [url] targets a JWT-protected OpenFlow asset file route.
bool studioIsOpenFlowProtectedAssetFileUrl(String url) {
  final uri = Uri.tryParse(url);
  if (uri == null) {
    return false;
  }
  return studioAssetImageCacheKeyForUri(uri) != null;
}
