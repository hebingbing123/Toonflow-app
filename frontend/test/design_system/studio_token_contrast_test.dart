import 'package:flutter_test/flutter_test.dart';
import 'package:openflow_app/design_system/tokens.dart';
import 'package:openflow_app/utils/accessibility.dart';

void main() {
  final pairs = [
    ('dark', StudioTokens.dark),
    ('light', StudioTokens.light),
  ];
  for (final (name, tokens) in pairs) {
    test('$name textPrimary on bgSurface meets WCAG AA', () {
      expect(
        studioMeetsWcagAa(tokens.textPrimary, tokens.bgSurface),
        isTrue,
        reason: 'body text on surface',
      );
    });

    test('$name textSecondary on bgSurface meets WCAG AA', () {
      expect(
        studioMeetsWcagAa(tokens.textSecondary, tokens.bgSurface),
        isTrue,
        reason: 'secondary text on surface',
      );
    });

    test('$name primary on bgBase meets large-text AA', () {
      expect(
        studioMeetsWcagAa(
          tokens.primary,
          tokens.bgBase,
          isLargeText: true,
        ),
        isTrue,
        reason: 'accent links on base',
      );
    });
  }
}
