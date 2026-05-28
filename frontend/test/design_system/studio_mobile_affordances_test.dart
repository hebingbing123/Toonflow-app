import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openflow_app/design_system/ix/studio_mobile_affordances.dart';

void main() {
  group('StudioMobileAffordances.supportsAndroidWebBack', () {
    test('returns false in the Flutter test environment (kIsWeb is false)', () {
      expect(StudioMobileAffordances.supportsAndroidWebBack, isFalse);
    });

    test('requires both kIsWeb and Android platform', () {
      expect(
        StudioMobileAffordances.supportsAndroidWebBack,
        equals(
          kIsWeb && defaultTargetPlatform == TargetPlatform.android,
        ),
      );
    });

    test('is false on non-Android platforms when kIsWeb is false', () {
      expect(kIsWeb, isFalse);
      for (final platform in TargetPlatform.values) {
        if (platform == TargetPlatform.android) {
          continue;
        }
        final wouldEnable = kIsWeb && defaultTargetPlatform == platform;
        expect(wouldEnable, isFalse);
      }
    });
  });
}
