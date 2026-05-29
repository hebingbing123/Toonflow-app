import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openflow_app/design_system/glass.dart';
import 'package:openflow_app/design_system/studio_glass_shader.dart';

void main() {
  test('StudioGlassPanel.glassEnabled defaults true', () {
    expect(StudioGlassPanel.glassEnabled, isTrue);
  });

  test('StudioGlassShader.fragmentShaderEnabled defaults false', () {
    expect(StudioGlassShader.fragmentShaderEnabled, isFalse);
  });

  test('blurFilter returns ImageFilter without throwing', () {
    final filter = StudioGlassShader.blurFilter(
      sigma: 12,
      textureSize: const Size(400, 300),
    );
    expect(filter, isNotNull);
  });
}
