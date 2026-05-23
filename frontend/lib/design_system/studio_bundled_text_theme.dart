import 'package:flutter/material.dart';

import 'studio_font_families.dart';

/// Builds a [TextTheme] using bundled Inter / Space Grotesk + Noto Sans SC fallback.
///
/// Matches the previous `GoogleFonts.interTextTheme` + `spaceGroteskTextTheme` stack
/// without runtime network fetches.
TextTheme buildStudioBundledTextTheme(TextTheme base) {
  final withInter = base.apply(
    fontFamily: StudioFontFamilies.inter,
    fontFamilyFallback: StudioFontFamilies.cjkFallback,
  );
  return withInter.apply(
    fontFamily: StudioFontFamilies.spaceGrotesk,
    fontFamilyFallback: StudioFontFamilies.cjkFallback,
  );
}

/// Applies bundled font families to a single [TextStyle] (e.g. button themes).
TextStyle studioBundledTextStyle(
  TextStyle style, {
  String? fontFamily,
}) {
  return style.copyWith(
    fontFamily: fontFamily ?? StudioFontFamilies.spaceGrotesk,
    fontFamilyFallback: StudioFontFamilies.cjkFallback,
  );
}
