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
    required this.accent,
    required this.danger,
    required this.success,
    required this.overlay,
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
  final Color accent;
  final Color danger;
  final Color success;
  final Color overlay;
  final Color sidebar;
  final Color sidebarBorder;

  static const StudioTokens dark = StudioTokens(
    bgBase: Color(0xFF0D0F14),
    bgSurface: Color(0xFF141820),
    bgElevated: Color(0xFF1A1F2B),
    bgInset: Color(0xFF0A0C10),
    glass: Color(0xB81A1F2B),
    glassBorder: Color(0x14FFFFFF),
    textPrimary: Color(0xFFE8EAEF),
    textSecondary: Color(0xFF9CA3AF),
    textMuted: Color(0xFF6B7280),
    borderSubtle: Color(0xFF252836),
    borderDefault: Color(0xFF353B4D),
    primary: Color(0xFF7C6CF0),
    accent: Color(0xFF00CEC9),
    danger: Color(0xFFFF6B6B),
    success: Color(0xFF2ECC71),
    overlay: Color(0x99000000),
    sidebar: Color(0xFF12141C),
    sidebarBorder: Color(0xFF252836),
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
    Color? accent,
    Color? danger,
    Color? success,
    Color? overlay,
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
      accent: accent ?? this.accent,
      danger: danger ?? this.danger,
      success: success ?? this.success,
      overlay: overlay ?? this.overlay,
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
      accent: l(accent, other.accent),
      danger: l(danger, other.danger),
      success: l(success, other.success),
      overlay: l(overlay, other.overlay),
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
}
