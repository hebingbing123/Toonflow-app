import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';

/// Optional `.frag` glass path (`--dart-define=STUDIO_GLASS_SHADER=true`).
///
/// Falls back to [ImageFilter.blur] when disabled, unsupported, or load fails.
abstract final class StudioGlassShader {
  static const bool fragmentShaderEnabled = bool.fromEnvironment(
    'STUDIO_GLASS_SHADER',
    defaultValue: false,
  );

  static const String assetPath = 'shaders/studio_glass_blur.frag';

  static FragmentProgram? _program;
  static bool _loadFailed = false;

  static Future<void> warmUp() async {
    if (!fragmentShaderEnabled || _program != null || _loadFailed) {
      return;
    }
    try {
      _program = await FragmentProgram.fromAsset(assetPath);
    } catch (error, stack) {
      _loadFailed = true;
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stack,
          library: 'studio_glass_shader',
          context: ErrorDescription('while loading $assetPath'),
        ),
      );
    }
  }

  static void scheduleWarmUp() {
    if (!fragmentShaderEnabled || _program != null || _loadFailed) {
      return;
    }
    SchedulerBinding.instance.scheduleFrameCallback((_) {
      warmUp();
    });
  }

  static ImageFilter blurFilter({
    required double sigma,
    required Size textureSize,
  }) {
    final program = _program;
    if (!fragmentShaderEnabled || program == null) {
      return ImageFilter.blur(sigmaX: sigma, sigmaY: sigma);
    }
    final shader = program.fragmentShader()
      ..setFloat(0, textureSize.width)
      ..setFloat(1, textureSize.height)
      ..setFloat(2, sigma);
    return ImageFilter.shader(shader);
  }
}
