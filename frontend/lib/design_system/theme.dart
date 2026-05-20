import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'studio_typography.dart';
import 'tokens.dart';

/// Full-dark studio theme (product shell).
ThemeData buildStudioDarkTheme({
  bool useGoogleFonts = true,
  StudioTypography typography = StudioTypography.regular,
}) {
  const tokens = StudioTokens.dark;

  final base =
      ColorScheme.fromSeed(
        seedColor: tokens.primary,
        brightness: Brightness.dark,
      ).copyWith(
        primary: tokens.primary,
        onPrimary: Colors.white,
        primaryContainer: tokens.primarySoft,
        secondary: tokens.accent,
        onSecondary: Colors.black,
        secondaryContainer: tokens.accentSoft,
        surface: tokens.bgSurface,
        onSurface: tokens.textPrimary,
        surfaceContainerLow: tokens.bgSurface,
        surfaceContainerHighest: tokens.bgElevated,
        surfaceContainer: tokens.bgElevated,
        onSurfaceVariant: tokens.textSecondary,
        outline: tokens.borderDefault,
        outlineVariant: tokens.borderSubtle,
        error: tokens.danger,
        onError: Colors.white,
      );

  final fallbackTextTheme = ThemeData(brightness: Brightness.dark).textTheme;
  final bodyFont = useGoogleFonts
      ? GoogleFonts.interTextTheme(fallbackTextTheme)
      : fallbackTextTheme;
  final displayFont = useGoogleFonts
      ? GoogleFonts.spaceGroteskTextTheme(bodyFont)
      : bodyFont;
  final textTheme = displayFont
      .apply(bodyColor: tokens.textPrimary, displayColor: tokens.textPrimary)
      .copyWith(
        bodyLarge: displayFont.bodyLarge?.copyWith(
          fontSize: typography.bodyLarge,
          height: 1.45,
        ),
        bodyMedium: displayFont.bodyMedium?.copyWith(
          fontSize: typography.body,
          height: 1.5,
        ),
        bodySmall: displayFont.bodySmall?.copyWith(
          fontSize: typography.hint,
          height: 1.45,
          color: tokens.textSecondary,
        ),
        labelLarge: displayFont.labelLarge?.copyWith(
          fontSize: typography.label,
          fontWeight: FontWeight.w600,
          height: 1.2,
        ),
        labelMedium: displayFont.labelMedium?.copyWith(
          fontSize: typography.hint,
          fontWeight: FontWeight.w500,
          height: 1.2,
        ),
        labelSmall: displayFont.labelSmall?.copyWith(
          fontSize: typography.meta,
          color: tokens.textMuted,
          height: 1.2,
        ),
        headlineSmall: displayFont.headlineSmall?.copyWith(
          fontSize: typography.display,
          fontWeight: FontWeight.w700,
          height: 1.15,
        ),
        titleSmall: displayFont.titleSmall?.copyWith(
          fontSize: typography.bodyLarge,
          fontWeight: FontWeight.w600,
          height: 1.22,
        ),
        titleLarge: displayFont.titleLarge?.copyWith(
          fontSize: typography.dialogTitle + 2,
          fontWeight: FontWeight.w600,
          height: 1.18,
        ),
        titleMedium: displayFont.titleMedium?.copyWith(
          fontSize: typography.paneTitle,
          fontWeight: FontWeight.w600,
          height: 1.2,
        ),
      );

  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: base,
    scaffoldBackgroundColor: tokens.bgBase,
    textTheme: textTheme,
    appBarTheme: AppBarTheme(
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      backgroundColor: tokens.bgSurface,
      foregroundColor: tokens.textPrimary,
      surfaceTintColor: Colors.transparent,
      titleTextStyle: textTheme.titleLarge,
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: tokens.bgSurface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(StudioSpacing.radiusCard),
        side: BorderSide(color: tokens.surfaceHighlight),
      ),
      margin: EdgeInsets.zero,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: tokens.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        shadowColor: tokens.panelGlow.withValues(alpha: 0.34),
        padding: typography.buttonPadding,
        minimumSize: Size(0, typography.buttonHeight),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        visualDensity: const VisualDensity(horizontal: -1, vertical: -1),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(StudioSpacing.radiusButton),
          side: BorderSide(color: tokens.primary.withValues(alpha: 0.36)),
        ),
        textStyle: TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: typography.label,
          height: 1.2,
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: tokens.textPrimary,
        backgroundColor: tokens.bgSurface.withValues(alpha: 0.74),
        side: BorderSide(color: tokens.surfaceHighlight),
        padding: typography.buttonPadding,
        minimumSize: Size(0, typography.buttonHeight),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        visualDensity: const VisualDensity(horizontal: -1, vertical: -1),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(StudioSpacing.radiusButton),
        ),
        textStyle: TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: typography.label,
          height: 1.2,
        ),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: tokens.accent,
        padding: typography.textButtonPadding,
        minimumSize: Size(0, typography.buttonHeight),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        visualDensity: const VisualDensity(horizontal: -1, vertical: -1),
        textStyle: TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: typography.label,
          height: 1.2,
        ),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: tokens.bgInset.withValues(alpha: 0.92),
      contentPadding: typography.inputPadding,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(StudioSpacing.radiusButton),
        borderSide: BorderSide(color: tokens.borderSubtle),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(StudioSpacing.radiusButton),
        borderSide: BorderSide(color: tokens.borderSubtle),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(StudioSpacing.radiusButton),
        borderSide: BorderSide(color: tokens.accent, width: 1.5),
      ),
      labelStyle: TextStyle(
        color: tokens.textSecondary,
        fontSize: typography.hint,
        height: 1.3,
      ),
      floatingLabelStyle: TextStyle(
        color: tokens.textSecondary,
        fontSize: typography.hint,
        height: 1.3,
      ),
      hintStyle: TextStyle(
        color: tokens.textMuted,
        fontSize: typography.hint,
        height: 1.3,
      ),
      helperStyle: TextStyle(
        color: tokens.textSecondary,
        fontSize: typography.meta,
        height: 1.3,
      ),
    ),
    menuTheme: MenuThemeData(
      style: MenuStyle(
        backgroundColor: WidgetStatePropertyAll<Color>(tokens.bgElevated),
        elevation: const WidgetStatePropertyAll<double>(16),
        shadowColor: WidgetStatePropertyAll<Color>(
          tokens.panelGlow.withValues(alpha: 0.2),
        ),
        surfaceTintColor: const WidgetStatePropertyAll<Color>(
          Colors.transparent,
        ),
        shape: WidgetStatePropertyAll<OutlinedBorder>(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(StudioSpacing.radiusCard),
            side: BorderSide(color: tokens.surfaceHighlight),
          ),
        ),
        padding: const WidgetStatePropertyAll<EdgeInsets>(
          EdgeInsets.symmetric(vertical: 6, horizontal: 6),
        ),
      ),
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: tokens.bgElevated,
      surfaceTintColor: Colors.transparent,
      elevation: 16,
      shadowColor: tokens.panelGlow.withValues(alpha: 0.2),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(StudioSpacing.radiusCard),
        side: BorderSide(color: tokens.surfaceHighlight),
      ),
      labelTextStyle: WidgetStatePropertyAll<TextStyle?>(
        TextStyle(
          color: tokens.textPrimary,
          fontSize: typography.body,
          height: 1.4,
        ),
      ),
      textStyle: TextStyle(
        color: tokens.textPrimary,
        fontSize: typography.body,
        height: 1.4,
      ),
      iconColor: tokens.textSecondary,
    ),
    canvasColor: tokens.bgElevated,
    dropdownMenuTheme: DropdownMenuThemeData(
      textStyle: TextStyle(
        color: tokens.textPrimary,
        fontSize: typography.body,
        height: 1.4,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: tokens.bgInset.withValues(alpha: 0.92),
        labelStyle: TextStyle(
          color: tokens.textSecondary,
          fontSize: typography.hint,
        ),
        hintStyle: TextStyle(
          color: tokens.textMuted,
          fontSize: typography.hint,
        ),
      ),
      menuStyle: MenuStyle(
        backgroundColor: WidgetStatePropertyAll<Color>(tokens.bgElevated),
        elevation: const WidgetStatePropertyAll<double>(16),
        shadowColor: WidgetStatePropertyAll<Color>(
          tokens.panelGlow.withValues(alpha: 0.2),
        ),
        surfaceTintColor: const WidgetStatePropertyAll<Color>(
          Colors.transparent,
        ),
        shape: WidgetStatePropertyAll<OutlinedBorder>(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(StudioSpacing.radiusCard),
            side: BorderSide(color: tokens.surfaceHighlight),
          ),
        ),
        padding: const WidgetStatePropertyAll<EdgeInsets>(
          EdgeInsets.symmetric(vertical: 6, horizontal: 6),
        ),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: tokens.bgSurface,
      elevation: 12,
      contentTextStyle: TextStyle(
        color: tokens.textPrimary,
        fontSize: typography.body,
        height: 1.4,
      ),
      actionTextColor: tokens.accent,
      closeIconColor: tokens.textMuted,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(StudioSpacing.radiusCard),
        side: BorderSide(color: tokens.surfaceHighlight),
      ),
    ),
    dividerTheme: DividerThemeData(color: tokens.borderSubtle, thickness: 1),
    focusColor: tokens.primary.withValues(alpha: 0.35),
    hoverColor: tokens.primary.withValues(alpha: 0.10),
    chipTheme: ChipThemeData(
      backgroundColor: tokens.bgSurface.withValues(alpha: 0.92),
      selectedColor: tokens.primarySoft,
      labelStyle: TextStyle(
        fontWeight: FontWeight.w500,
        color: tokens.textPrimary,
        fontSize: typography.hint,
        height: 1.2,
      ),
      side: BorderSide(color: tokens.surfaceHighlight),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
    ),
    extensions: <ThemeExtension<dynamic>>[
      StudioTokens.dark,
      StudioColors.dark,
      typography,
    ],
  );
}

/// Legacy extension used by product_shell (sidebar, login).
@immutable
class StudioColors extends ThemeExtension<StudioColors> {
  const StudioColors({
    required this.sidebar,
    required this.sidebarBorder,
    required this.canvas,
    required this.brandGradient,
    required this.loginBackdrop,
    required this.primaryGradient,
    required this.shellBackdrop,
    required this.panelGradient,
    required this.signalGradient,
  });

  final Color sidebar;
  final Color sidebarBorder;
  final Color canvas;
  final Gradient brandGradient;
  final Gradient loginBackdrop;
  final Gradient primaryGradient;
  final Gradient shellBackdrop;
  final Gradient panelGradient;
  final Gradient signalGradient;

  static const StudioColors dark = StudioColors(
    sidebar: Color(0xFF0D1524),
    sidebarBorder: Color(0xFF1B2841),
    canvas: Color(0xFF08101A),
    brandGradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: <Color>[Color(0xFF7E95FF), Color(0xFF5283F2), Color(0xFF31C2E8)],
    ),
    loginBackdrop: LinearGradient(
      begin: Alignment(-1.1, -1),
      end: Alignment(1.2, 1.1),
      colors: <Color>[
        Color(0xFF060D15),
        Color(0xFF0B1626),
        Color(0xFF0C1A28),
        Color(0xFF081018),
      ],
    ),
    primaryGradient: LinearGradient(
      begin: Alignment.centerLeft,
      end: Alignment.centerRight,
      colors: <Color>[Color(0xFF809EFF), Color(0xFF4D76D8)],
    ),
    shellBackdrop: LinearGradient(
      begin: Alignment(-1.0, -1.0),
      end: Alignment(1.0, 1.0),
      colors: <Color>[Color(0xFF06101A), Color(0xFF0A1522), Color(0xFF0A1721)],
    ),
    panelGradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: <Color>[Color(0xFF131F31), Color(0xFF0F1828), Color(0xFF0D1622)],
    ),
    signalGradient: LinearGradient(
      begin: Alignment.centerLeft,
      end: Alignment.centerRight,
      colors: <Color>[Color(0xFF5E84FF), Color(0xFF238EB8)],
    ),
  );

  static StudioColors of(BuildContext context) {
    return Theme.of(context).extension<StudioColors>() ?? dark;
  }

  @override
  StudioColors copyWith({
    Color? sidebar,
    Color? sidebarBorder,
    Color? canvas,
    Gradient? brandGradient,
    Gradient? loginBackdrop,
    Gradient? primaryGradient,
    Gradient? shellBackdrop,
    Gradient? panelGradient,
    Gradient? signalGradient,
  }) {
    return StudioColors(
      sidebar: sidebar ?? this.sidebar,
      sidebarBorder: sidebarBorder ?? this.sidebarBorder,
      canvas: canvas ?? this.canvas,
      brandGradient: brandGradient ?? this.brandGradient,
      loginBackdrop: loginBackdrop ?? this.loginBackdrop,
      primaryGradient: primaryGradient ?? this.primaryGradient,
      shellBackdrop: shellBackdrop ?? this.shellBackdrop,
      panelGradient: panelGradient ?? this.panelGradient,
      signalGradient: signalGradient ?? this.signalGradient,
    );
  }

  @override
  StudioColors lerp(ThemeExtension<StudioColors>? other, double t) {
    if (other is! StudioColors) return this;
    return StudioColors(
      sidebar: Color.lerp(sidebar, other.sidebar, t)!,
      sidebarBorder: Color.lerp(sidebarBorder, other.sidebarBorder, t)!,
      canvas: Color.lerp(canvas, other.canvas, t)!,
      brandGradient: brandGradient,
      loginBackdrop: loginBackdrop,
      primaryGradient: primaryGradient,
      shellBackdrop: shellBackdrop,
      panelGradient: panelGradient,
      signalGradient: signalGradient,
    );
  }
}
