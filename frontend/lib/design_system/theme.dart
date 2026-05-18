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
  const primaryDark = Color(0xFF6355D4);

  final base =
      ColorScheme.fromSeed(
        seedColor: tokens.primary,
        brightness: Brightness.dark,
      ).copyWith(
        primary: tokens.primary,
        onPrimary: Colors.white,
        secondary: tokens.accent,
        onSecondary: Colors.black,
        surface: tokens.bgSurface,
        onSurface: tokens.textPrimary,
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
      color: tokens.bgElevated,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(StudioSpacing.radiusCard),
        side: BorderSide(color: tokens.borderSubtle),
      ),
      margin: EdgeInsets.zero,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: tokens.primary,
        foregroundColor: Colors.white,
        elevation: 0,
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
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: tokens.textPrimary,
        side: BorderSide(color: tokens.borderDefault),
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
        foregroundColor: tokens.primary,
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
      fillColor: tokens.bgInset,
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
        borderSide: BorderSide(color: tokens.primary, width: 1.5),
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
    dropdownMenuTheme: DropdownMenuThemeData(
      textStyle: TextStyle(
        color: tokens.textPrimary,
        fontSize: typography.body,
        height: 1.4,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: tokens.bgInset,
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
      ),
    ),
    dividerTheme: DividerThemeData(color: tokens.borderSubtle, thickness: 1),
    focusColor: tokens.primary.withValues(alpha: 0.35),
    hoverColor: tokens.primary.withValues(alpha: 0.08),
    chipTheme: ChipThemeData(
      backgroundColor: tokens.bgInset,
      selectedColor: tokens.primary.withValues(alpha: 0.22),
      labelStyle: TextStyle(
        fontWeight: FontWeight.w500,
        color: tokens.textPrimary,
        fontSize: typography.hint,
        height: 1.2,
      ),
      side: BorderSide.none,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ),
    extensions: <ThemeExtension<dynamic>>[
      StudioTokens.dark,
      const StudioColors(
        sidebar: Color(0xFF12141C),
        sidebarBorder: Color(0xFF252836),
        canvas: Color(0xFF0D0F14),
        brandGradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[Color(0xFF7C6CF0), Color(0xFF00CEC9)],
        ),
        loginBackdrop: LinearGradient(
          begin: Alignment(-0.8, -1),
          end: Alignment(1.2, 1),
          colors: <Color>[
            Color(0xFF0D0F14),
            Color(0xFF1A1F2B),
            Color(0xFF12141C),
          ],
        ),
        primaryGradient: LinearGradient(
          colors: <Color>[Color(0xFF7C6CF0), primaryDark],
        ),
      ),
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
  });

  final Color sidebar;
  final Color sidebarBorder;
  final Color canvas;
  final Gradient brandGradient;
  final Gradient loginBackdrop;
  final Gradient primaryGradient;

  static StudioColors of(BuildContext context) {
    return Theme.of(context).extension<StudioColors>()!;
  }

  @override
  StudioColors copyWith({
    Color? sidebar,
    Color? sidebarBorder,
    Color? canvas,
    Gradient? brandGradient,
    Gradient? loginBackdrop,
    Gradient? primaryGradient,
  }) {
    return StudioColors(
      sidebar: sidebar ?? this.sidebar,
      sidebarBorder: sidebarBorder ?? this.sidebarBorder,
      canvas: canvas ?? this.canvas,
      brandGradient: brandGradient ?? this.brandGradient,
      loginBackdrop: loginBackdrop ?? this.loginBackdrop,
      primaryGradient: primaryGradient ?? this.primaryGradient,
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
    );
  }
}
