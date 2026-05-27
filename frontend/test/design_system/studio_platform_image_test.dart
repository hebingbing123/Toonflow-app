import 'package:flutter/material.dart';
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

  testWidgets('builds the requested desktop asset path', (tester) async {
    await tester.pumpWidget(
      const Directionality(
        textDirection: TextDirection.ltr,
        child: StudioPlatformImage(
          baseName: 'openflow_glyph.png',
          surface: StudioPlatformImageSurface.desktop,
        ),
      ),
    );

    final image = tester.widget<Image>(find.byType(Image));
    expect(
      (image.image as AssetImage).assetName,
      'assets/brand/desktop/openflow_glyph.png',
    );
  });

  testWidgets('builds the requested web asset path', (tester) async {
    await tester.pumpWidget(
      const Directionality(
        textDirection: TextDirection.ltr,
        child: StudioPlatformImage(
          baseName: 'openflow_glyph.png',
          surface: StudioPlatformImageSurface.web,
        ),
      ),
    );

    final image = tester.widget<Image>(find.byType(Image));
    expect(
      (image.image as AssetImage).assetName,
      'assets/brand/web/openflow_glyph.png',
    );
  });
}
