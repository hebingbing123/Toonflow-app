import 'package:flutter_test/flutter_test.dart';
import 'package:openflow_app/design_system/studio_platform_image.dart';

void main() {
  test('resolves per-surface brand asset paths', () {
    expect(
      studioPlatformImageAsset(
        'openflow_glyph.png',
        surface: StudioPlatformImageSurface.mobile,
      ),
      'assets/brand/mobile/openflow_glyph.png',
    );
    expect(
      studioPlatformImageAsset(
        'openflow_glyph.png',
        surface: StudioPlatformImageSurface.tablet,
      ),
      'assets/brand/tablet/openflow_glyph.png',
    );
    expect(
      studioPlatformImageAsset(
        'openflow_glyph.png',
        surface: StudioPlatformImageSurface.desktop,
      ),
      'assets/brand/desktop/openflow_glyph.png',
    );
    expect(
      studioPlatformImageAsset(
        'openflow_glyph.png',
        surface: StudioPlatformImageSurface.web,
      ),
      'assets/brand/web/openflow_glyph.png',
    );
  });

  test('default surface enum values stay stable for asset routing', () {
    expect(StudioPlatformImageSurface.values, hasLength(4));
    expect(
      StudioPlatformImageSurface.values.first,
      StudioPlatformImageSurface.mobile,
    );
    expect(
      StudioPlatformImageSurface.values.last,
      StudioPlatformImageSurface.web,
    );
  });
}
