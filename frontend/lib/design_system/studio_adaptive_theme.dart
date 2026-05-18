import 'package:flutter/material.dart';

import 'theme.dart';
import 'studio_typography.dart';

/// Studio desktop typography stays viewport-stable.
///
/// Earlier versions scaled fonts continuously with screen width, which made
/// enterprise surfaces feel oversized and inconsistent across panes. Keep the
/// rhythm stable and switch only between a few tuned desktop profiles.
ThemeData studioAdaptiveDesktopTheme(BuildContext context) {
  final width = MediaQuery.sizeOf(context).width;
  return buildStudioDarkTheme(typography: studioTypographyForWidth(width));
}
