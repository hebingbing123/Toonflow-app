import 'package:flutter/material.dart';

import 'studio_typography.dart';
import 'theme.dart';

/// Studio desktop typography stays viewport-stable.
///
/// Earlier versions scaled fonts continuously with screen width, which made
/// enterprise surfaces feel oversized and inconsistent across panes. Keep the
/// rhythm stable and switch only between a few tuned desktop profiles.
ThemeData studioAdaptiveDesktopTheme(BuildContext context) {
  final width = MediaQuery.sizeOf(context).width;
  final brightness = MediaQuery.platformBrightnessOf(context);
  return buildStudioTheme(
    brightness: brightness,
    typography: studioTypographyForWidth(width),
  );
}
