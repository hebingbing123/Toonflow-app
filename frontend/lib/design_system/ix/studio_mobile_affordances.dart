import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Mobile-only helpers for immersive system chrome and tactile feedback.
class StudioMobileAffordances {
  StudioMobileAffordances._();

  static bool get supportsMobileChrome =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  static bool get supportsHaptics =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);
}

SystemUiOverlayStyle studioSystemUiOverlayStyleForSurface(Color surfaceColor) {
  final brightness = ThemeData.estimateBrightnessForColor(surfaceColor);
  final isDarkSurface = brightness == Brightness.dark;
  final iconBrightness = isDarkSurface ? Brightness.light : Brightness.dark;
  final statusBarBrightness = isDarkSurface
      ? Brightness.dark
      : Brightness.light;

  return SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: iconBrightness,
    statusBarBrightness: statusBarBrightness,
    systemNavigationBarColor: Colors.transparent,
    systemNavigationBarDividerColor: Colors.transparent,
    systemNavigationBarIconBrightness: iconBrightness,
    systemNavigationBarContrastEnforced: false,
  );
}

Future<void> studioSetEdgeToEdgeSystemUi() async {
  if (!StudioMobileAffordances.supportsMobileChrome) {
    return;
  }
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
}

Future<void> studioApplySystemUiOverlayStyle(Color surfaceColor) async {
  if (!StudioMobileAffordances.supportsMobileChrome) {
    return;
  }
  SystemChrome.setSystemUIOverlayStyle(
    studioSystemUiOverlayStyleForSurface(surfaceColor),
  );
}

/// Wraps the subtree in a matching overlay style and keeps Android edge-to-edge
/// enabled while the page is visible.
class StudioSystemUiSurface extends StatefulWidget {
  const StudioSystemUiSurface({
    super.key,
    required this.child,
    this.surfaceColor,
  });

  final Widget child;
  final Color? surfaceColor;

  @override
  State<StudioSystemUiSurface> createState() => _StudioSystemUiSurfaceState();
}

class _StudioSystemUiSurfaceState extends State<StudioSystemUiSurface> {
  SystemUiOverlayStyle? _lastStyle;

  @override
  void initState() {
    super.initState();
    unawaited(studioSetEdgeToEdgeSystemUi());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncOverlayStyle();
  }

  @override
  void didUpdateWidget(covariant StudioSystemUiSurface oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncOverlayStyle();
  }

  void _syncOverlayStyle() {
    if (!mounted) {
      return;
    }
    final surfaceColor =
        widget.surfaceColor ?? Theme.of(context).scaffoldBackgroundColor;
    final style = studioSystemUiOverlayStyleForSurface(surfaceColor);
    if (_lastStyle == style) {
      return;
    }
    _lastStyle = style;
    unawaited(studioApplySystemUiOverlayStyle(surfaceColor));
  }

  @override
  Widget build(BuildContext context) {
    final surfaceColor =
        widget.surfaceColor ?? Theme.of(context).scaffoldBackgroundColor;
    final style = studioSystemUiOverlayStyleForSurface(surfaceColor);
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: style,
      child: widget.child,
    );
  }
}

Future<void> studioLightImpact() async {
  if (!StudioMobileAffordances.supportsHaptics) {
    return;
  }
  await HapticFeedback.lightImpact();
}

Future<void> studioMediumImpact() async {
  if (!StudioMobileAffordances.supportsHaptics) {
    return;
  }
  await HapticFeedback.mediumImpact();
}
