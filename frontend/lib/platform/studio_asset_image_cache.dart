import 'dart:io';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import '../rust_api/workspace_scope.dart';
import 'studio_asset_image_cache_keys.dart';

/// On-device PNG cache for OpenFlow asset image / block file routes.
///
/// Keys are scoped per workspace folder so switching workspace does not
/// reuse another tenant's files. Same device reuses disk until evicted.
abstract final class StudioAssetImageCache {
  static const _rootFolder = 'studio_asset_images';

  static Future<Directory> _cacheRoot() async {
    final support = await getApplicationSupportDirectory();
    final dir = Directory(
      '${support.path}${Platform.pathSeparator}$_rootFolder',
    );
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  static String _workspaceSegment() {
    final id = StudioWorkspaceScope.instance.workspaceId;
    if (id == null || id.isEmpty) {
      return 'personal';
    }
    return id.replaceAll(RegExp(r'[^\w\-]'), '_');
  }

  static Future<File> _fileForRelativeKey(String relativeKey) async {
    final root = await _cacheRoot();
    final file = File(
      '${root.path}${Platform.pathSeparator}${_workspaceSegment()}${Platform.pathSeparator}$relativeKey',
    );
    final parent = file.parent;
    if (!await parent.exists()) {
      await parent.create(recursive: true);
    }
    return file;
  }

  static Future<File?> readIfPresent(String relativeKey) async {
    final file = await _fileForRelativeKey(relativeKey);
    if (!await file.exists()) {
      return null;
    }
    if (await file.length() == 0) {
      return null;
    }
    return file;
  }

  static Future<File> writeBytes(String relativeKey, List<int> bytes) async {
    final file = await _fileForRelativeKey(relativeKey);
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }

  static Future<void> evict(String relativeKey) async {
    final file = await _fileForRelativeKey(relativeKey);
    if (await file.exists()) {
      await file.delete();
    }
  }

  static Future<void> evictUri(Uri uri) async {
    final key = studioAssetImageCacheKeyForUri(uri);
    if (key != null) {
      await evict(key);
    }
  }

  static Future<File> writeTempBytes(List<int> bytes) async {
    final root = await _cacheRoot();
    final temp = File(
      '${root.path}${Platform.pathSeparator}tmp_${DateTime.now().microsecondsSinceEpoch}.bin',
    );
    await temp.writeAsBytes(bytes, flush: true);
    return temp;
  }
}

/// Local-first load: disk hit → authenticated GET → write-through cache.
Future<File> studioLoadCachedAssetImageFile({
  required String accessToken,
  required Uri uri,
  String? cacheKeyOverride,
  Map<String, String>? headers,
}) async {
  final cacheKey = cacheKeyOverride ?? studioAssetImageCacheKeyForUri(uri);
  if (cacheKey != null) {
    final cached = await StudioAssetImageCache.readIfPresent(cacheKey);
    if (cached != null) {
      return cached;
    }
  }

  final resolvedHeaders = <String, String>{
    ...studioAuthorizedHeaders(accessToken),
    ...?headers,
  };
  final response = await http
      .get(uri, headers: resolvedHeaders)
      .timeout(const Duration(seconds: 120));
  if (response.statusCode < 200 || response.statusCode >= 300) {
    throw HttpException(
      'asset image fetch failed (${response.statusCode})',
      uri: uri,
    );
  }

  final bytes = response.bodyBytes;
  if (cacheKey != null) {
    return StudioAssetImageCache.writeBytes(cacheKey, bytes);
  }

  return StudioAssetImageCache.writeTempBytes(bytes);
}

/// Convenience for widgets that already decoded bytes.
Future<Uint8List> studioLoadCachedAssetImageBytes({
  required String accessToken,
  required Uri uri,
  String? cacheKeyOverride,
}) async {
  final file = await studioLoadCachedAssetImageFile(
    accessToken: accessToken,
    uri: uri,
    cacheKeyOverride: cacheKeyOverride,
  );
  return file.readAsBytes();
}
