/// Bundled font family names (see [frontend/assets/fonts/] and pubspec.yaml).
abstract final class StudioFontFamilies {
  StudioFontFamilies._();

  static const String inter = 'Inter';
  static const String spaceGrotesk = 'Space Grotesk';
  static const String notoSansSC = 'Noto Sans SC';

  /// CJK glyphs for zh-CN product copy when Latin fonts lack codepoints.
  static const List<String> cjkFallback = <String>[notoSansSC];
}
