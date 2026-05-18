import 'package:flutter/material.dart';

import '../design_system/theme.dart';

export '../design_system/theme.dart' show StudioColors, buildStudioDarkTheme;

/// Back-compat entry for product shell.
abstract final class StudioTheme {
  StudioTheme._();
  static ThemeData build({bool useGoogleFonts = true}) =>
      buildStudioDarkTheme(useGoogleFonts: useGoogleFonts);
}
