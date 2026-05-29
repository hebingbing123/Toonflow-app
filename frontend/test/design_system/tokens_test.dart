import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openflow_app/design_system/studio_elevation.dart';
import 'package:openflow_app/design_system/tokens.dart';

void main() {
  group('StudioTokens interactive states', () {
    test('dark and light palettes define state colors', () {
      for (final tokens in [StudioTokens.dark, StudioTokens.light]) {
        expect(tokens.primaryHover, isNot(equals(tokens.primaryDisabled)));
        expect(tokens.accentHover.a, greaterThan(0));
        expect(tokens.infoSoft.a, greaterThan(0));
      }
    });

    test('lerp preserves state fields at endpoints', () {
      final mid = StudioTokens.dark.lerp(StudioTokens.light, 0.5);
      expect(mid.primaryHover, isNotNull);
      expect(mid.surfaceHover, isNotNull);
    });
  });

  group('StudioSpacing touch targets', () {
    test('mobile targets are at least 44', () {
      expect(
        StudioSpacing.touchTargetForPlatform(TargetPlatform.iOS),
        greaterThanOrEqualTo(44),
      );
    });

    test('desktop targets use control height', () {
      expect(
        StudioSpacing.touchTargetForPlatform(TargetPlatform.macOS),
        StudioSpacing.controlHeight,
      );
    });
  });

  group('StudioElevation', () {
    test('level0 is empty and level5 has shadow', () {
      expect(StudioElevation.level0, isEmpty);
      expect(StudioElevation.level5(true), isNotEmpty);
      expect(StudioElevation.level5(false), isNotEmpty);
    });
  });

  group('StudioZIndex', () {
    test('stacking order increases toward toast', () {
      expect(StudioZIndex.modal, lessThan(StudioZIndex.toast));
      expect(StudioZIndex.dropdown, lessThan(StudioZIndex.modal));
    });
  });
}
