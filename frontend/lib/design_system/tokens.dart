import 'package:flutter/material.dart';

/// Semantic studio tokens (LumenX-style CSS variables as ThemeExtension).
@immutable
class StudioTokens extends ThemeExtension<StudioTokens> {
  const StudioTokens({
    required this.bgBase,
    required this.bgSurface,
    required this.bgElevated,
    required this.bgInset,
    required this.glass,
    required this.glassBorder,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
    required this.borderSubtle,
    required this.borderDefault,
    required this.primary,
    required this.primarySoft,
    required this.accent,
    required this.accentSoft,
    required this.signal,
    required this.danger,
    required this.warning,
    required this.success,
    required this.overlay,
    required this.surfaceHighlight,
    required this.panelGlow,
    required this.panelGlowSecondary,
    required this.sidebar,
    required this.sidebarBorder,
  });

  final Color bgBase;
  final Color bgSurface;
  final Color bgElevated;
  final Color bgInset;
  final Color glass;
  final Color glassBorder;
  final Color textPrimary;
  final Color textSecondary;
  final Color textMuted;
  final Color borderSubtle;
  final Color borderDefault;
  final Color primary;
  final Color primarySoft;
  final Color accent;
  final Color accentSoft;
  final Color signal;
  final Color danger;
  final Color warning;
  final Color success;
  final Color overlay;
  final Color surfaceHighlight;
  final Color panelGlow;
  final Color panelGlowSecondary;
  final Color sidebar;
  final Color sidebarBorder;

  static const StudioTokens dark = StudioTokens(
    bgBase: Color(0xFF070D15),
    bgSurface: Color(0xFF101825),
    bgElevated: Color(0xFF152033),
    bgInset: Color(0xFF0A1018),
    glass: Color(0xBF0C1523),
    glassBorder: Color(0x244D86C6),
    textPrimary: Color(0xFFE8F1FF),
    textSecondary: Color(0xFFA2B4CD),
    textMuted: Color(0xFF667892),
    borderSubtle: Color(0xFF1B2A3E),
    borderDefault: Color(0xFF29435E),
    primary: Color(0xFF7C97FF),
    primarySoft: Color(0xFF162A47),
    accent: Color(0xFF34C8F0),
    accentSoft: Color(0xFF0C303A),
    signal: Color(0xFF56B7FF),
    danger: Color(0xFFFF6D7A),
    warning: Color(0xFFFFB347),
    success: Color(0xFF35D49B),
    overlay: Color(0xB3000000),
    surfaceHighlight: Color(0xFF1D3650),
    panelGlow: Color(0xFF4E7FFF),
    panelGlowSecondary: Color(0xFF2CC3E6),
    sidebar: Color(0xFF0A1320),
    sidebarBorder: Color(0xFF15273B),
  );

  static StudioTokens of(BuildContext context) {
    return Theme.of(context).extension<StudioTokens>() ?? dark;
  }

  @override
  StudioTokens copyWith({
    Color? bgBase,
    Color? bgSurface,
    Color? bgElevated,
    Color? bgInset,
    Color? glass,
    Color? glassBorder,
    Color? textPrimary,
    Color? textSecondary,
    Color? textMuted,
    Color? borderSubtle,
    Color? borderDefault,
    Color? primary,
    Color? primarySoft,
    Color? accent,
    Color? accentSoft,
    Color? signal,
    Color? danger,
    Color? warning,
    Color? success,
    Color? overlay,
    Color? surfaceHighlight,
    Color? panelGlow,
    Color? panelGlowSecondary,
    Color? sidebar,
    Color? sidebarBorder,
  }) {
    return StudioTokens(
      bgBase: bgBase ?? this.bgBase,
      bgSurface: bgSurface ?? this.bgSurface,
      bgElevated: bgElevated ?? this.bgElevated,
      bgInset: bgInset ?? this.bgInset,
      glass: glass ?? this.glass,
      glassBorder: glassBorder ?? this.glassBorder,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textMuted: textMuted ?? this.textMuted,
      borderSubtle: borderSubtle ?? this.borderSubtle,
      borderDefault: borderDefault ?? this.borderDefault,
      primary: primary ?? this.primary,
      primarySoft: primarySoft ?? this.primarySoft,
      accent: accent ?? this.accent,
      accentSoft: accentSoft ?? this.accentSoft,
      signal: signal ?? this.signal,
      danger: danger ?? this.danger,
      warning: warning ?? this.warning,
      success: success ?? this.success,
      overlay: overlay ?? this.overlay,
      surfaceHighlight: surfaceHighlight ?? this.surfaceHighlight,
      panelGlow: panelGlow ?? this.panelGlow,
      panelGlowSecondary: panelGlowSecondary ?? this.panelGlowSecondary,
      sidebar: sidebar ?? this.sidebar,
      sidebarBorder: sidebarBorder ?? this.sidebarBorder,
    );
  }

  @override
  StudioTokens lerp(ThemeExtension<StudioTokens>? other, double t) {
    if (other is! StudioTokens) return this;
    Color l(Color a, Color b) => Color.lerp(a, b, t)!;
    return StudioTokens(
      bgBase: l(bgBase, other.bgBase),
      bgSurface: l(bgSurface, other.bgSurface),
      bgElevated: l(bgElevated, other.bgElevated),
      bgInset: l(bgInset, other.bgInset),
      glass: l(glass, other.glass),
      glassBorder: l(glassBorder, other.glassBorder),
      textPrimary: l(textPrimary, other.textPrimary),
      textSecondary: l(textSecondary, other.textSecondary),
      textMuted: l(textMuted, other.textMuted),
      borderSubtle: l(borderSubtle, other.borderSubtle),
      borderDefault: l(borderDefault, other.borderDefault),
      primary: l(primary, other.primary),
      primarySoft: l(primarySoft, other.primarySoft),
      accent: l(accent, other.accent),
      accentSoft: l(accentSoft, other.accentSoft),
      signal: l(signal, other.signal),
      danger: l(danger, other.danger),
      warning: l(warning, other.warning),
      success: l(success, other.success),
      overlay: l(overlay, other.overlay),
      surfaceHighlight: l(surfaceHighlight, other.surfaceHighlight),
      panelGlow: l(panelGlow, other.panelGlow),
      panelGlowSecondary: l(panelGlowSecondary, other.panelGlowSecondary),
      sidebar: l(sidebar, other.sidebar),
      sidebarBorder: l(sidebarBorder, other.sidebarBorder),
    );
  }
}

/// Studio spacing on 8px grid.
abstract final class StudioSpacing {
  static const double xs = 8;
  static const double sm = 16;
  static const double md = 24;
  static const double lg = 32;
  static const double radiusButton = 10;
  static const double radiusCard = 14;

  /// Minimum square hit target for chrome icon buttons (desktop).
  static const double iconTouchTarget = 36;

  /// Collapsed sidebar nav tile size.
  static const double navItemTouchTarget = 44;

  /// Gap between adjacent icon buttons in top-bar chrome groups.
  static const double chromeActionGap = 4;
}

/// Page-level semantic spacing (prefer over ad-hoc 10/14/18 values).
abstract final class StudioLayoutSpacing {
  static const double pageTop = StudioSpacing.md;
  static const double section = StudioSpacing.md;
  static const double cardInner = StudioSpacing.sm;
  static const double titleSubtitle = StudioSpacing.xs;
  static const double actionRow = StudioSpacing.sm;
  static const double listItem = StudioSpacing.xs;

  /// Tight stack gap (replaces legacy `10` in cards and forms).
  static const double inlineGap = 10;

  /// Between title and body in compact panels (replaces legacy `14`).
  static const double stackMedium = 14;

  /// Inset padding for dense tool rows (replaces legacy `10`/`12` padding).
  static const double insetDense = 12;

  /// Comfortable card / section inset (replaces legacy `18`).
  static const double insetComfortable = 18;
}
