import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openflow_app/utils/accessibility.dart';

void main() {
  test('studioMeetsWcagAa for black on white body text', () {
    expect(
      studioMeetsWcagAa(Colors.black, Colors.white),
      isTrue,
    );
  });

  test('studioContrastRatio is symmetric', () {
    final a = studioContrastRatio(Colors.black, Colors.white);
    final b = studioContrastRatio(Colors.white, Colors.black);
    expect(a, closeTo(b, 0.001));
  });
}
