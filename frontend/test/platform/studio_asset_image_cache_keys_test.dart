import 'package:flutter_test/flutter_test.dart';
import 'package:openflow_app/design_system/studio_network_image.dart';
import 'package:openflow_app/platform/studio_asset_image_cache_keys.dart';

void main() {
  group('studioAssetImageCacheKeyForUri', () {
    test('parses project asset image file route', () {
      final uri = Uri.parse(
        'http://127.0.0.1:8666/api/v1/projects/p1/assets/42/images/img-1/file?max_edge=512',
      );
      expect(
        studioAssetImageCacheKeyForUri(uri),
        'projects/p1/assets/42/images/img-1/max_512.png',
      );
    });

    test('parses project asset block file route', () {
      final uri = Uri.parse(
        'http://127.0.0.1:8666/api/v1/projects/p1/assets/7/blocks/hero/file?dpi=3',
      );
      expect(
        studioAssetImageCacheKeyForUri(uri),
        'projects/p1/assets/7/blocks/hero/dpi_3.png',
      );
    });

    test('returns null for unrelated URLs', () {
      expect(
        studioAssetImageCacheKeyForUri(Uri.parse('https://cdn.example/a.png')),
        isNull,
      );
    });
  });

  group('studioOptimizeAssetFileUrl', () {
    test('adds max_edge and dpi when missing', () {
      final imageUrl =
          'http://127.0.0.1:8666/api/v1/projects/p/assets/1/images/x/file';
      expect(
        studioOptimizeAssetFileUrl(imageUrl, maxPixelEdge: 400, dpiTier: 2),
        contains('max_edge=400'),
      );

      final blockUrl =
          'http://127.0.0.1:8666/api/v1/projects/p/assets/1/blocks/tile/file';
      final optimized = studioOptimizeAssetFileUrl(
        blockUrl,
        dpiTier: 3,
      );
      expect(optimized, contains('dpi=3'));
    });
  });

  group('studioIsOpenFlowProtectedAssetFileUrl', () {
    test('detects protected asset routes', () {
      expect(
        studioIsOpenFlowProtectedAssetFileUrl(
          'http://127.0.0.1:8666/api/v1/projects/p/assets/1/images/x/file',
        ),
        isTrue,
      );
      expect(
        studioIsOpenFlowProtectedAssetFileUrl('https://cdn.example.com/x.png'),
        isFalse,
      );
    });
  });
}
