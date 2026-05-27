import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform;
import 'package:flutter/material.dart';

import 'ix/studio_pointer.dart';
import 'studio_bundled_text_theme.dart';
import 'studio_typography.dart';
import 'tokens.dart';

TextStyle _adjustStyle(TextStyle? style) {
  if (style == null) {
    return const TextStyle(textBaseline: TextBaseline.alphabetic);
  }
  double? height = style.height;
  if (height == null) {
    height = 1.3;
  } else if (height < 1.2) {
    height = 1.2;
  } else if (height > 1.5) {
    height = 1.5;
  }

  FontWeight? weight = style.fontWeight;
  final isWindowsOrWeb =
      kIsWeb || defaultTargetPlatform == TargetPlatform.windows;
  if (isWindowsOrWeb) {
    if (weight == null || weight == FontWeight.w400) {
      weight = FontWeight.w500;
    } else if (weight == FontWeight.w300) {
      weight = FontWeight.w400;
    }
  }

  return style.copyWith(
    textBaseline: TextBaseline.alphabetic,
    height: height,
    fontWeight: weight,
  );
}

TextTheme _adjustTextTheme(TextTheme theme) {
  return TextTheme(
    displayLarge: _adjustStyle(theme.displayLarge),
    displayMedium: _adjustStyle(theme.displayMedium),
    displaySmall: _adjustStyle(theme.displaySmall),
    headlineLarge: _adjustStyle(theme.headlineLarge),
    headlineMedium: _adjustStyle(theme.headlineMedium),
    headlineSmall: _adjustStyle(theme.headlineSmall),
    titleLarge: _adjustStyle(theme.titleLarge),
    titleMedium: _adjustStyle(theme.titleMedium),
    titleSmall: _adjustStyle(theme.titleSmall),
    bodyLarge: _adjustStyle(theme.bodyLarge),
    bodyMedium: _adjustStyle(theme.bodyMedium),
    bodySmall: _adjustStyle(theme.bodySmall),
    labelLarge: _adjustStyle(theme.labelLarge),
    labelMedium: _adjustStyle(theme.labelMedium),
    labelSmall: _adjustStyle(theme.labelSmall),
  );
}

ThemeData _buildStudioTheme({
  required Brightness brightness,
  bool useBundledFonts = true,
  StudioTypography typography = StudioTypography.regular,
}) {
  final isDark = brightness == Brightness.dark;
  final tokens = isDark ? StudioTokens.dark : StudioTokens.light;
  final colors = isDark ? StudioColors.dark : StudioColors.light;

  final base =
      ColorScheme.fromSeed(
        seedColor: tokens.primary,
        brightness: brightness,
      ).copyWith(
        primary: tokens.primary,
        onPrimary: StudioPrimitives.white,
        primaryContainer: tokens.primarySoft,
        secondary: tokens.accent,
        onSecondary: StudioPrimitives.black,
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
        onError: StudioPrimitives.white,
      );

  final fallbackTextTheme = ThemeData(brightness: brightness).textTheme;
  final displayFont = useBundledFonts
      ? buildStudioBundledTextTheme(fallbackTextTheme)
      : fallbackTextTheme;
  final textTheme = _adjustTextTheme(
    displayFont
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
            height: 1.2, // enforce min height 1.2 as recommended
          ),
          titleSmall: displayFont.titleSmall?.copyWith(
            fontSize: typography.bodyLarge,
            fontWeight: FontWeight.w600,
            height: 1.22,
          ),
          titleLarge: displayFont.titleLarge?.copyWith(
            fontSize: typography.dialogTitle + 2,
            fontWeight: FontWeight.w600,
            height: 1.2, // enforce min height 1.2 as recommended
          ),
          titleMedium: displayFont.titleMedium?.copyWith(
            fontSize: typography.paneTitle,
            fontWeight: FontWeight.w600,
            height: 1.2,
          ),
        ),
  );

  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: base,
    scaffoldBackgroundColor: tokens.bgBase,
    textTheme: textTheme,
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: <TargetPlatform, PageTransitionsBuilder>{
        // iOS keeps native-style horizontal swipe transitions.
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
        TargetPlatform.android: FadeUpwardsPageTransitionsBuilder(),
        TargetPlatform.windows: FadeUpwardsPageTransitionsBuilder(),
        TargetPlatform.linux: FadeUpwardsPageTransitionsBuilder(),
        TargetPlatform.fuchsia: FadeUpwardsPageTransitionsBuilder(),
      },
    ),
    appBarTheme: AppBarTheme(
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      backgroundColor: tokens.bgSurface,
      foregroundColor: tokens.textPrimary,
      surfaceTintColor: StudioPrimitives.transparent,
      titleTextStyle: textTheme.titleLarge,
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: tokens.bgSurface,
      surfaceTintColor: StudioPrimitives.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(StudioSpacing.radiusCard),
        side: BorderSide(color: tokens.surfaceHighlight),
      ),
      margin: EdgeInsets.zero,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: studioInteractiveButtonMouseCursor(
        FilledButton.styleFrom(
          backgroundColor: tokens.primary,
          foregroundColor: StudioPrimitives.white,
          elevation: 0,
          shadowColor: StudioPrimitives.transparent,
          padding: typography.buttonPadding,
          minimumSize: Size(0, typography.buttonHeight),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          visualDensity: VisualDensity.compact,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(StudioSpacing.radiusButton),
            side: BorderSide(color: tokens.primary.withValues(alpha: 0.36)),
          ),
          textStyle: _adjustStyle(
            studioBundledTextStyle(
              TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: typography.label,
                height: 1.2,
              ),
            ),
          ),
        ).copyWith(overlayColor: studioButtonHoverOverlay(tokens)),
      ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: studioInteractiveButtonMouseCursor(
        IconButton.styleFrom(
          minimumSize: const Size(
            StudioSpacing.iconTouchTarget,
            StudioSpacing.iconTouchTarget,
          ),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          visualDensity: VisualDensity.compact,
          iconSize: 20,
        ).copyWith(overlayColor: studioButtonHoverOverlay(tokens)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: studioInteractiveButtonMouseCursor(
        OutlinedButton.styleFrom(
          foregroundColor: tokens.textPrimary,
          backgroundColor: tokens.bgSurface.withValues(alpha: 0.74),
          side: BorderSide(color: tokens.surfaceHighlight),
          padding: typography.buttonPadding,
          minimumSize: Size(0, typography.buttonHeight),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          visualDensity: VisualDensity.compact,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(StudioSpacing.radiusButton),
          ),
          textStyle: _adjustStyle(
            studioBundledTextStyle(
              TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: typography.label,
                height: 1.2,
              ),
            ),
          ),
        ).copyWith(overlayColor: studioButtonHoverOverlay(tokens)),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: studioInteractiveButtonMouseCursor(
        TextButton.styleFrom(
          foregroundColor: tokens.accent,
          padding: typography.textButtonPadding,
          minimumSize: Size(0, typography.buttonHeight),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          visualDensity: VisualDensity.compact,
          textStyle: _adjustStyle(
            studioBundledTextStyle(
              TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: typography.label,
                height: 1.2,
              ),
            ),
          ),
        ).copyWith(overlayColor: studioButtonHoverOverlay(tokens)),
      ),
    ),
    listTileTheme: ListTileThemeData(
      mouseCursor: WidgetStateProperty.resolveWith<MouseCursor?>((states) {
        if (states.contains(WidgetState.disabled)) {
          return SystemMouseCursors.basic;
        }
        return SystemMouseCursors.click;
      }),
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
      labelStyle: _adjustStyle(
        TextStyle(
          color: tokens.textSecondary,
          fontSize: typography.hint,
          height: 1.3,
        ),
      ),
      floatingLabelStyle: _adjustStyle(
        TextStyle(
          color: tokens.textSecondary,
          fontSize: typography.hint,
          height: 1.3,
        ),
      ),
      hintStyle: _adjustStyle(
        TextStyle(
          color: tokens.textMuted,
          fontSize: typography.hint,
          height: 1.3,
        ),
      ),
      helperStyle: _adjustStyle(
        TextStyle(
          color: tokens.textSecondary,
          fontSize: typography.meta,
          height: 1.3,
        ),
      ),
    ),
    menuTheme: MenuThemeData(
      style: MenuStyle(
        backgroundColor: WidgetStatePropertyAll<Color>(tokens.bgElevated),
        elevation: WidgetStatePropertyAll<double>(isDark ? 10 : 8),
        shadowColor: WidgetStatePropertyAll<Color>(
          StudioPrimitives.black.withValues(alpha: isDark ? 0.20 : 0.12),
        ),
        surfaceTintColor: const WidgetStatePropertyAll<Color>(
          StudioPrimitives.transparent,
        ),
        shape: WidgetStatePropertyAll<OutlinedBorder>(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(StudioSpacing.radiusCard),
            side: BorderSide(color: tokens.surfaceHighlight),
          ),
        ),
        padding: const WidgetStatePropertyAll<EdgeInsets>(
          EdgeInsets.symmetric(
            vertical: StudioSpacing.xs,
            horizontal: StudioSpacing.xs,
          ),
        ),
      ),
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: tokens.bgElevated,
      surfaceTintColor: StudioPrimitives.transparent,
      elevation: isDark ? 10 : 8,
      shadowColor: StudioPrimitives.black.withValues(
        alpha: isDark ? 0.20 : 0.12,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(StudioSpacing.radiusCard),
        side: BorderSide(color: tokens.surfaceHighlight),
      ),
      labelTextStyle: WidgetStatePropertyAll<TextStyle?>(
        _adjustStyle(
          TextStyle(
            color: tokens.textPrimary,
            fontSize: typography.body,
            height: 1.4,
          ),
        ),
      ),
      textStyle: _adjustStyle(
        TextStyle(
          color: tokens.textPrimary,
          fontSize: typography.body,
          height: 1.4,
        ),
      ),
      iconColor: tokens.textSecondary,
    ),
    canvasColor: tokens.bgElevated,
    dropdownMenuTheme: DropdownMenuThemeData(
      textStyle: _adjustStyle(
        TextStyle(
          color: tokens.textPrimary,
          fontSize: typography.body,
          height: 1.4,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: tokens.bgInset.withValues(alpha: 0.92),
        labelStyle: _adjustStyle(
          TextStyle(color: tokens.textSecondary, fontSize: typography.hint),
        ),
        hintStyle: _adjustStyle(
          TextStyle(color: tokens.textMuted, fontSize: typography.hint),
        ),
      ),
      menuStyle: MenuStyle(
        backgroundColor: WidgetStatePropertyAll<Color>(tokens.bgElevated),
        elevation: WidgetStatePropertyAll<double>(isDark ? 10 : 8),
        shadowColor: WidgetStatePropertyAll<Color>(
          StudioPrimitives.black.withValues(alpha: isDark ? 0.20 : 0.12),
        ),
        surfaceTintColor: const WidgetStatePropertyAll<Color>(
          StudioPrimitives.transparent,
        ),
        shape: WidgetStatePropertyAll<OutlinedBorder>(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(StudioSpacing.radiusCard),
            side: BorderSide(color: tokens.surfaceHighlight),
          ),
        ),
        padding: const WidgetStatePropertyAll<EdgeInsets>(
          EdgeInsets.symmetric(
            vertical: StudioSpacing.xs,
            horizontal: StudioSpacing.xs,
          ),
        ),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: tokens.bgSurface,
      elevation: isDark ? 8 : 6,
      contentTextStyle: _adjustStyle(
        TextStyle(
          color: tokens.textPrimary,
          fontSize: typography.body,
          height: 1.4,
        ),
      ),
      actionTextColor: tokens.accent,
      closeIconColor: tokens.textMuted,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(StudioSpacing.radiusCard),
        side: BorderSide(color: tokens.surfaceHighlight),
      ),
    ),
    dividerTheme: DividerThemeData(color: tokens.borderSubtle, thickness: 1),
    focusColor: tokens.primary.withValues(alpha: isDark ? 0.24 : 0.12),
    hoverColor: tokens.primary.withValues(alpha: isDark ? 0.10 : 0.06),
    chipTheme: ChipThemeData(
      backgroundColor: tokens.bgSurface.withValues(alpha: isDark ? 0.92 : 1),
      selectedColor: tokens.primarySoft,
      labelStyle: _adjustStyle(
        TextStyle(
          fontWeight: FontWeight.w500,
          color: tokens.textPrimary,
          fontSize: typography.hint,
          height: 1.2,
        ),
      ),
      side: BorderSide(color: tokens.surfaceHighlight),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(StudioSpacing.radiusPill),
      ),
    ),
    extensions: <ThemeExtension<dynamic>>[tokens, colors, typography],
  );
}

/// Full studio theme for the requested brightness.
ThemeData buildStudioTheme({
  required Brightness brightness,
  bool useBundledFonts = true,
  StudioTypography typography = StudioTypography.regular,
}) {
  return _buildStudioTheme(
    brightness: brightness,
    useBundledFonts: useBundledFonts,
    typography: typography,
  );
}

/// Full-dark studio theme (product shell).
///
/// When [useBundledFonts] is true (default), uses **bundled** Inter / Space Grotesk /
/// Noto Sans SC from `assets/fonts/` — no network fetch. When false, uses platform
/// system fonts only (legacy test escape hatch).
ThemeData buildStudioDarkTheme({
  bool useBundledFonts = true,
  StudioTypography typography = StudioTypography.regular,
}) {
  return buildStudioTheme(
    brightness: Brightness.dark,
    useBundledFonts: useBundledFonts,
    typography: typography,
  );
}

/// Light studio theme for system theme switching and high-contrast previews.
ThemeData buildStudioLightTheme({
  bool useBundledFonts = true,
  StudioTypography typography = StudioTypography.regular,
}) {
  return buildStudioTheme(
    brightness: Brightness.light,
    useBundledFonts: useBundledFonts,
    typography: typography,
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

  /// Marketing / shell gradients. Flat chrome colors match [StudioTokens.dark].
  static const StudioColors dark = StudioColors(
    sidebar: Color(0xFF0A1320),
    sidebarBorder: Color(0xFF15273B),
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

  static const StudioColors light = StudioColors(
    sidebar: Color(0xFFF1F5FA),
    sidebarBorder: Color(0xFFD8E1EB),
    canvas: Color(0xFFF7FAFD),
    brandGradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: <Color>[Color(0xFF6A8CFF), Color(0xFF4F79FF), Color(0xFF2BAFD6)],
    ),
    loginBackdrop: LinearGradient(
      begin: Alignment(-1.1, -1),
      end: Alignment(1.2, 1.1),
      colors: <Color>[
        Color(0xFFF7FAFD),
        Color(0xFFF0F5FB),
        Color(0xFFE8EFF8),
        Color(0xFFF8FBFF),
      ],
    ),
    primaryGradient: LinearGradient(
      begin: Alignment.centerLeft,
      end: Alignment.centerRight,
      colors: <Color>[Color(0xFF6A8CFF), Color(0xFF4F79FF)],
    ),
    shellBackdrop: LinearGradient(
      begin: Alignment(-1.0, -1.0),
      end: Alignment(1.0, 1.0),
      colors: <Color>[Color(0xFFF8FAFD), Color(0xFFF2F6FB), Color(0xFFEAF0F6)],
    ),
    panelGradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: <Color>[Color(0xFFFFFFFF), Color(0xFFF8FBFD), Color(0xFFF0F4F8)],
    ),
    signalGradient: LinearGradient(
      begin: Alignment.centerLeft,
      end: Alignment.centerRight,
      colors: <Color>[Color(0xFF4F79FF), Color(0xFF2BAFD6)],
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
