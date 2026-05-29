import 'package:flutter/material.dart';

/// Primitive colors that are allowed to appear in theme construction.
///
/// UI code should prefer semantic values from [StudioTokens] via:
/// `Theme.of(context).colorScheme`, `StudioTokens.of(context)`, or `textTheme`.
abstract final class StudioPrimitives {
  static const Color white = Color(0xFFFFFFFF);
  static const Color black = Color(0xFF000000);
  static const Color transparent = Color(0x00000000);
}

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
    required this.primaryHover,
    required this.primaryPressed,
    required this.primaryDisabled,
    required this.primaryFocus,
    required this.accentHover,
    required this.accentPressed,
    required this.accentDisabled,
    required this.accentFocus,
    required this.surfaceHover,
    required this.surfacePressed,
    required this.surfaceDisabled,
    required this.info,
    required this.infoSoft,
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
  final Color primaryHover;
  final Color primaryPressed;
  final Color primaryDisabled;
  final Color primaryFocus;
  final Color accentHover;
  final Color accentPressed;
  final Color accentDisabled;
  final Color accentFocus;
  final Color surfaceHover;
  final Color surfacePressed;
  final Color surfaceDisabled;
  final Color info;
  final Color infoSoft;

  static const StudioTokens dark = StudioTokens(
    bgBase: Color(0xFF121212),
    bgSurface: Color(0xFF181C22),
    bgElevated: Color(0xFF20252D),
    bgInset: Color(0xFF15181D),
    glass: Color(0xE614181F),
    glassBorder: Color(0x334A5F74),
    textPrimary: Color(0xFFF1F5F9),
    textSecondary: Color(0xFFBCC8D7),
    textMuted: Color(0xFF8A96A6),
    borderSubtle: Color(0xFF2A313A),
    borderDefault: Color(0xFF3A4552),
    primary: Color(0xFF7C97FF),
    primarySoft: Color(0xFF1A2436),
    accent: Color(0xFF34C8F0),
    accentSoft: Color(0xFF112B31),
    signal: Color(0xFF56B7FF),
    danger: Color(0xFFFF6D7A),
    warning: Color(0xFFFFB347),
    success: Color(0xFF35D49B),
    overlay: Color(0x99000000),
    surfaceHighlight: Color(0xFF334253),
    panelGlow: Color(0xFF4E7FFF),
    panelGlowSecondary: Color(0xFF2CC3E6),
    sidebar: Color(0xFF141922),
    sidebarBorder: Color(0xFF252D37),
    primaryHover: Color(0xFF95ABFF),
    primaryPressed: Color(0xFF6578E0),
    primaryDisabled: Color(0x617C97FF),
    primaryFocus: Color(0xFF7C97FF),
    accentHover: Color(0xFF4DD4F5),
    accentPressed: Color(0xFF2AA8C8),
    accentDisabled: Color(0x6134C8F0),
    accentFocus: Color(0xFF34C8F0),
    surfaceHover: Color(0xFF222830),
    surfacePressed: Color(0xFF1A1E24),
    surfaceDisabled: Color(0x99181C22),
    info: Color(0xFF56B7FF),
    infoSoft: Color(0xFF1A2A3A),
  );

  static const StudioTokens light = StudioTokens(
    bgBase: Color(0xFFF3F6FA),
    bgSurface: Color(0xFFFFFFFF),
    bgElevated: Color(0xFFF8FAFD),
    bgInset: Color(0xFFEAF0F6),
    glass: Color(0xE6FFFFFF),
    glassBorder: Color(0x3382A3BE),
    textPrimary: Color(0xFF0F172A),
    textSecondary: Color(0xFF475569),
    textMuted: Color(0xFF64748B),
    borderSubtle: Color(0xFFD7E0EA),
    borderDefault: Color(0xFFB9C7D6),
    primary: Color(0xFF4F79FF),
    primarySoft: Color(0xFFDDE6FF),
    accent: Color(0xFF0EA5C6),
    accentSoft: Color(0xFFDDF8FC),
    signal: Color(0xFF2980FF),
    danger: Color(0xFFDC4F63),
    warning: Color(0xFFF59E0B),
    success: Color(0xFF10B981),
    overlay: Color(0x29000000),
    surfaceHighlight: Color(0xFFC9D5E2),
    panelGlow: Color(0xFF6F92FF),
    panelGlowSecondary: Color(0xFF39BCD9),
    sidebar: Color(0xFFF1F5FA),
    sidebarBorder: Color(0xFFD8E1EB),
    primaryHover: Color(0xFF6B8EFF),
    primaryPressed: Color(0xFF3D63E8),
    primaryDisabled: Color(0x614F79FF),
    primaryFocus: Color(0xFF4F79FF),
    accentHover: Color(0xFF26B8D9),
    accentPressed: Color(0xFF0B8FA8),
    accentDisabled: Color(0x610EA5C6),
    accentFocus: Color(0xFF0EA5C6),
    surfaceHover: Color(0xFFF0F4F8),
    surfacePressed: Color(0xFFE8EEF4),
    surfaceDisabled: Color(0x99FFFFFF),
    info: Color(0xFF2980FF),
    infoSoft: Color(0xFFDEE9FF),
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
    Color? primaryHover,
    Color? primaryPressed,
    Color? primaryDisabled,
    Color? primaryFocus,
    Color? accentHover,
    Color? accentPressed,
    Color? accentDisabled,
    Color? accentFocus,
    Color? surfaceHover,
    Color? surfacePressed,
    Color? surfaceDisabled,
    Color? info,
    Color? infoSoft,
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
      primaryHover: primaryHover ?? this.primaryHover,
      primaryPressed: primaryPressed ?? this.primaryPressed,
      primaryDisabled: primaryDisabled ?? this.primaryDisabled,
      primaryFocus: primaryFocus ?? this.primaryFocus,
      accentHover: accentHover ?? this.accentHover,
      accentPressed: accentPressed ?? this.accentPressed,
      accentDisabled: accentDisabled ?? this.accentDisabled,
      accentFocus: accentFocus ?? this.accentFocus,
      surfaceHover: surfaceHover ?? this.surfaceHover,
      surfacePressed: surfacePressed ?? this.surfacePressed,
      surfaceDisabled: surfaceDisabled ?? this.surfaceDisabled,
      info: info ?? this.info,
      infoSoft: infoSoft ?? this.infoSoft,
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
      primaryHover: l(primaryHover, other.primaryHover),
      primaryPressed: l(primaryPressed, other.primaryPressed),
      primaryDisabled: l(primaryDisabled, other.primaryDisabled),
      primaryFocus: l(primaryFocus, other.primaryFocus),
      accentHover: l(accentHover, other.accentHover),
      accentPressed: l(accentPressed, other.accentPressed),
      accentDisabled: l(accentDisabled, other.accentDisabled),
      accentFocus: l(accentFocus, other.accentFocus),
      surfaceHover: l(surfaceHover, other.surfaceHover),
      surfacePressed: l(surfacePressed, other.surfacePressed),
      surfaceDisabled: l(surfaceDisabled, other.surfaceDisabled),
      info: l(info, other.info),
      infoSoft: l(infoSoft, other.infoSoft),
    );
  }
}

/// Studio spacing on 8px grid.
abstract final class StudioSpacing {
  static const double xs = 8;
  static const double sm = 16;
  static const double md = 24;
  static const double lg = 32;

  /// Minimum touch target size for tappable controls (Material guidance).
  static const double touchTarget = 48;
  static const double radiusButton = 10;
  static const double radiusCard = 14;

  /// Dense chips / compact panels (8px corners).
  static const double radiusDense = 8;

  /// Legacy medium corners (12px); prefer [radiusCard] for new surfaces.
  static const double radiusComfort = 12;

  /// Large sheets / modals (28px).
  static const double radiusSheet = 28;

  /// Fully rounded pill / stadium chip.
  static const double radiusPill = 999;

  /// Drag handles and 2px micro connectors.
  static const double radiusHairline = 2;

  /// Perfect circle avatars / round FABs.
  static const double radiusCircle = 9999;

  /// Sharp corners (tables, splitters).
  static const double radiusNone = 0;

  /// Platform-aware minimum touch target (Material / HIG).
  static double touchTargetForPlatform(TargetPlatform platform) {
    switch (platform) {
      case TargetPlatform.iOS:
      case TargetPlatform.android:
        return 44;
      case TargetPlatform.macOS:
      case TargetPlatform.windows:
      case TargetPlatform.linux:
      case TargetPlatform.fuchsia:
        return controlHeight;
    }
  }

  /// Touch target for the current [context] platform.
  static double touchTargetForContext(BuildContext context) {
    return touchTargetForPlatform(Theme.of(context).platform);
  }

  /// Shared height for dense inputs, text buttons, and labeled actions.
  static const double controlHeight = 36;

  /// Minimum square hit target for chrome icon buttons (desktop).
  static const double iconTouchTarget = touchTarget;

  /// Collapsed sidebar nav tile size.
  static const double navItemTouchTarget = 44;

  /// Gap between adjacent icon buttons in top-bar chrome groups.
  static const double chromeActionGap = 4;

  /// Vertical inset inside [controlHeight] buttons (pairs with 36px control math).
  static const double controlPaddingVertical = 6;
}

/// Icon glyph sizes in chrome, lists, and toolbars.
abstract final class StudioIconSize {
  static const double xxs = 14;
  static const double xs = 16;
  static const double sm = 18;
  static const double md = 20;
  static const double lg = 24;
  static const double xl = 22;
}

/// Z-index layers for stacking contexts (use with [Material] elevation or [Stack]).
abstract final class StudioZIndex {
  static const int base = 0;
  static const int dropdown = 1000;
  static const int sticky = 1100;
  static const int fixed = 1200;
  static const int tooltip = 1300;
  static const int overlay = 1400;
  static const int modal = 1500;
  static const int toast = 1600;
  static const int debug = 9999;
}

/// Hairline chrome and inline progress affordances.
abstract final class StudioControlSize {
  static const double progressIndicator = 18;
  static const double progressStroke = 2;
  static const double dividerThickness = 1;
  static const double linearProgressHeight = 2;
}

/// Named layout widths and heights (fields, rails, previews).
abstract final class StudioLayoutSize {
  static const double fieldMin = 180;
  static const double fieldNarrow = 240;
  static const double fieldStandard = 280;
  static const double searchField = 280;
  static const double paneMinHeight = 280;
  static const double timelineLane = 88;
  static const double timelineControl = 120;
  static const double labelColumn = 100;
  static const double sliderCompact = 60;
  static const double previewPanelHeight = 200;
  static const double previewThumbnail = 120;
  static const double wizardStepBadge = 28;
  static const double skeletonLineShort = 12;
  static const double skeletonLineMedium = 16;
  static const double skeletonLineTall = 18;
  static const double skeletonLineWide = 56;
  static const double skeletonAvatar = 40;
  static const double dialogBatchHeight = 280;
}

/// Page-level semantic spacing (prefer over ad-hoc 10/14/18 values).
abstract final class StudioLayoutSpacing {
  static const double pageTop = StudioSpacing.md;
  static const double section = StudioSpacing.md;
  static const double cardInner = StudioSpacing.sm;
  static const double titleSubtitle = StudioSpacing.xs;
  static const double actionRow = StudioSpacing.sm;
  static const double listItem = StudioSpacing.xs;

  /// Dense icon-to-label gap; prefer [StudioSpacing.xs] for new toolbar rows.
  static const double microGap = StudioSpacing.xs;

  /// Tight title/subtitle spacing — keep to 8px grid.
  static const double titleTight = StudioSpacing.xs; // 8

  /// Tight stack gap — keep to 8px grid.
  static const double inlineGap = StudioSpacing.xs; // 8

  /// Between title and body in compact panels — keep to 8px grid.
  static const double stackMedium = StudioSpacing.sm; // 16

  /// Inset padding for dense tool rows — keep to 8px grid.
  static const double insetDense = StudioSpacing.sm; // 16

  /// Comfortable card / section inset — keep to 8px grid.
  static const double insetComfortable = StudioSpacing.md; // 24
}
